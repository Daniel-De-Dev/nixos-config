import { App, Gtk, Widget } from "astal/gtk3";
import Hyprland from "gi://AstalHyprland";
import GLib from "gi://GLib?version=2.0";
import { Variable, bind } from "astal";
import ActionRow from "../components/ActionRow";
import ShellWindow from "../components/ShellWindow";

const CONFIG = {
  window: { width: 560, height: 320 },
};

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

function ClientItem(client: Hyprland.Client, query: Variable<string>) {
  return ActionRow({
    title: client.title || client.class,
    description: client.class,
    icon: getIcon(client.class),
    visible: bind(query).as((q) =>
      (client.title + client.class).toLowerCase().includes(q.toLowerCase()),
    ),
    onActivate: () => focusClient(client),
  });
}

export default function WindowSwitcher() {
  const hypr = Hyprland.get_default();
  const query = Variable("");

  const SearchInput = new Widget.Entry({
    className: "shell-search window-switcher-search",
    placeholderText: "Search open windows...",
    onChanged: (self) => query.set(self.text),
    onActivate: () => {
      const q = query.get().toLowerCase();
      const first = hypr
        .get_clients()
        .find((c) => (c.title + c.class).toLowerCase().includes(q));

      if (first) {
        focusClient(first);
      }
    },
  });

  const ClientList = new Widget.Scrollable({
    className: "shell-scrollable",
    widthRequest: CONFIG.window.width,
    heightRequest: CONFIG.window.height,
    child: new Widget.Box({
      vertical: true,
      className: "window-switcher-list",
      children: bind(hypr, "clients").as((clients) => [
        ...clients.map((client) => ClientItem(client, query)),
        new Widget.Label({
          label: "No matching windows",
          className: "window-switcher-empty",
          visible: bind(query).as(
            (q) =>
              !clients.some((client) =>
                (client.title + client.class)
                  .toLowerCase()
                  .includes(q.toLowerCase()),
              ),
          ),
        }),
      ]),
    }),
  });

  return ShellWindow({
    name: "window-switcher",
    title: "Open windows",
    subtitle: "Search by title or application",
    hint: "Enter to switch · Esc to close",
    initialFocus: SearchInput,
    content: new Widget.Box({
      vertical: true,
      children: [SearchInput, ClientList],
    }),
  });
}
