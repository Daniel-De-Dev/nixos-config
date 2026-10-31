import { Gdk, Widget } from "astal/gtk3";
import Hyprland from "gi://AstalHyprland";
import GLib from "gi://GLib?version=2.0";
import { Variable, bind } from "astal";
import ShellWindow from "../components/ShellWindow";
import { fuzzyRank } from "../lib/search";
import {
  activationRequest,
  parseActionIds,
  parseKeybindings,
  type Keybinding,
} from "../lib/keybindings";

function BindingItem(
  binding: Keybinding,
  activate: (binding: Keybinding) => void,
) {
  return new Widget.Button({
    className: "shell-action-row",
    sensitive: Boolean(binding.action),
    tooltipText: binding.action
      ? "Run once"
      : "Use this shortcut on the keyboard",
    onClicked: () => {
      activate(binding);
    },
    child: new Widget.Box({
      vertical: true,
      children: [
        new Widget.Label({
          label: binding.description,
          tooltipText: binding.description,
          className: "shell-item-title",
          xalign: 0,
          truncate: true,
        }),
        new Widget.Label({
          label: [
            binding.shortcut,
            binding.context,
            binding.action ? "Run once" : "Keyboard only",
          ]
            .filter(Boolean)
            .join(" · "),
          className: "shell-item-description",
          xalign: 0,
        }),
      ],
    }),
  });
}

export default function KeybindingSearch() {
  const hypr = Hyprland.get_default();
  const query = Variable("");
  const bindings = Variable<Keybinding[]>([]);
  const error = Variable("");
  let running = false;
  const matches = Variable.derive([bindings, query], (items, q) =>
    fuzzyRank(
      items,
      q,
      (item) => `${item.description} ${item.shortcut} ${item.context}`,
    ),
  );

  function refresh() {
    try {
      const ids = parseActionIds(
        hypr.message(
          "repl return nixos_shortcuts and nixos_shortcuts.list() or '[]'",
        ),
      );
      bindings.set(parseKeybindings(hypr.message("j/binds"), ids));
      error.set("");
    } catch (err) {
      bindings.set([]);
      error.set("Cannot read Hyprland bindings. See the AGS service journal.");
      console.error("Cannot read Hyprland bindings:", err);
    }
  }

  function activate(binding?: Keybinding) {
    const request = binding && activationRequest(binding);
    if (!request || running) return;
    running = true;
    window.hide();
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      try {
        // Finish unmapping the layer surfaces before acting on the focused client.
        Gdk.Display.get_default()?.sync();
        const response = hypr.message(request);
        if (response.trim() !== "ok") throw new Error(response);
      } catch (err) {
        console.error("Cannot run shortcut:", err);
        window.show();
        error.set(
          "Cannot run this shortcut. Reopen search to refresh, or check the AGS journal.",
        );
      } finally {
        running = false;
      }
      return GLib.SOURCE_REMOVE;
    });
  }

  const search = new Widget.Entry({
    className: "shell-search",
    placeholderText: "Search descriptions or shortcuts...",
    onChanged: (self) => {
      query.set(self.text);
    },
    onActivate: () => {
      activate(matches.get()[0]);
    },
  });
  const results = new Widget.Box({
    vertical: true,
    children: bind(matches).as((items) =>
      items.map((item) => BindingItem(item, activate)),
    ),
  });
  const list = new Widget.Scrollable({
    className: "shell-scrollable",
    hexpand: true,
    vexpand: true,
    child: new Widget.Box({
      vertical: true,
      children: [
        results,
        new Widget.Label({
          label: "No matching bindings",
          visible: bind(matches).as((items) => items.length === 0),
          className: "shell-hint",
          wrap: true,
        }),
      ],
    }),
  });
  const window = ShellWindow({
    name: "keybinding-search",
    title: "Keyboard shortcuts",
    subtitle: "Fuzzy search through the running Hyprland configuration",
    hint: "Enter to run first result · Tab to choose · Esc to close",
    initialFocus: search,
    onClose: () => {
      search.text = "";
      query.set("");
      error.set("");
      list.get_vadjustment().set_value(0);
    },
    content: new Widget.Box({
      vertical: true,
      children: [
        search,
        new Widget.Label({
          label: bind(error),
          visible: bind(error).as(Boolean),
          className: "shell-hint",
          wrap: true,
        }),
        list,
      ],
    }),
  });
  window.connect("map", refresh);
  const reload = hypr.connect("config-reloaded", () => {
    if (window.visible) refresh();
  });
  window.connect("destroy", () => {
    hypr.disconnect(reload);
    matches.drop();
    bindings.drop();
    query.drop();
    error.drop();
  });
  return window;
}
