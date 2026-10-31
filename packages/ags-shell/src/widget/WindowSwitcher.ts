import { App, Gtk, Widget } from "astal/gtk3";
import Hyprland from "gi://AstalHyprland";
import GLib from "gi://GLib?version=2.0";
import { Variable, bind } from "astal";
import ActionRow from "../components/ActionRow";
import ShellWindow from "../components/ShellWindow";
import { fuzzyRank } from "../lib/search";

function getIcon(cls: string) {
  if (!cls) return "image-x-generic";
  return Gtk.IconTheme.get_default().has_icon(cls) ? cls : "image-x-generic";
}

function focusClient(client: Hyprland.Client) {
  const window = App.get_window("window-switcher");
  const selector = JSON.stringify(`address:0x${client.address}`);

  window?.hide();
  GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    // Astal's focus helper uses legacy IPC; Lua sessions need a Lua dispatcher.
    const response = Hyprland.get_default().message(
      `dispatch hl.dsp.focus({ window = ${selector} })`,
    );
    if (response.trim() !== "ok") {
      console.error(`Cannot focus window ${client.address}: ${response}`);
      window?.show();
    }
    return GLib.SOURCE_REMOVE;
  });
}

function ClientItem(client: Hyprland.Client) {
  return ActionRow({
    title: client.title || client.class,
    description: client.class,
    icon: getIcon(client.class),
    onActivate: () => {
      focusClient(client);
    },
  });
}

export default function WindowSwitcher() {
  const hypr = Hyprland.get_default();
  const query = Variable("");
  const matches = Variable.derive(
    [bind(hypr, "clients"), query],
    (clients, q) => fuzzyRank(clients, q, (c) => `${c.title} ${c.class}`),
  );

  const SearchInput = new Widget.Entry({
    className: "shell-search window-switcher-search",
    placeholderText: "Search open windows...",
    onChanged: (self) => {
      query.set(self.text);
    },
    onActivate: () => {
      const first = matches.get()[0];

      if (first) {
        focusClient(first);
      }
    },
  });

  const ClientList = new Widget.Scrollable({
    className: "shell-scrollable",
    hexpand: true,
    vexpand: true,
    child: new Widget.Box({
      vertical: true,
      className: "window-switcher-list",
      children: bind(matches).as((clients) => [
        ...clients.map(ClientItem),
        new Widget.Label({
          label: "No matching windows",
          className: "window-switcher-empty",
          visible: clients.length === 0,
        }),
      ]),
    }),
  });

  const window = ShellWindow({
    name: "window-switcher",
    title: "Open windows",
    subtitle: "Fuzzy search by title or application",
    hint: "Enter to switch · Esc to close",
    initialFocus: SearchInput,
    onClose: () => {
      SearchInput.text = "";
      query.set("");
      ClientList.get_vadjustment().set_value(0);
    },
    content: new Widget.Box({
      vertical: true,
      children: [SearchInput, ClientList],
    }),
  });
  window.connect("destroy", () => {
    matches.drop();
    query.drop();
  });
  return window;
}
