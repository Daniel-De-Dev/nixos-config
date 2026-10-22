import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import Hyprland from "gi://AstalHyprland";
import GLib from "gi://GLib?version=2.0";
import { Variable, bind } from "astal";

const CONFIG = {
  window: { width: 600, height: 400 },
  list: { spacing: 8 },
  item: { spacing: 12 },
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
  return new Widget.Button({
    className: "window-switcher-item",
    visible: bind(query).as((q) =>
      (client.title + client.class).toLowerCase().includes(q.toLowerCase()),
    ),
    onClicked: () => focusClient(client),
    child: new Widget.Box({
      spacing: CONFIG.item.spacing,
      children: [
        new Widget.Icon({
          icon: getIcon(client.class),
          className: "window-switcher-icon",
        }),
        new Widget.Label({
          label: `${client.class} - ${client.title}`,
          truncate: true,
          xalign: 0,
          className: "window-switcher-label",
        }),
      ],
    }),
  });
}

export default function WindowSwitcher() {
  const hypr = Hyprland.get_default();
  const query = Variable("");

  const SearchInput = new Widget.Entry({
    className: "window-switcher-search",
    placeholderText: "Search applications...",
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
    widthRequest: CONFIG.window.width,
    heightRequest: CONFIG.window.height,
    child: new Widget.Box({
      vertical: true,
      spacing: CONFIG.list.spacing,
      children: bind(hypr, "clients").as((clients) =>
        clients.map((client) => ClientItem(client, query)),
      ),
    }),
  });

  return new Widget.Window({
    name: "window-switcher",
    application: App,
    visible: false,
    keymode: Astal.Keymode.EXCLUSIVE,
    onKeyPressEvent: (self, event) => {
      if (event.get_keyval()[1] === Gdk.KEY_Escape) {
        self.hide();
      }
    },
    child: new Widget.Box({
      vertical: true,
      className: "window-switcher-container",
      children: [SearchInput, ClientList],
    }),
  });
}
