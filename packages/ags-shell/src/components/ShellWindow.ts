import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import GLib from "gi://GLib?version=2.0";

const PANEL_SIZE = { width: 640, height: 520 };

type ShellWindowProps = {
  name: string;
  title: string;
  subtitle: string;
  content: Gtk.Widget;
  hint: string;
  initialFocus?: Gtk.Widget;
  onClose?: () => void;
};

export default function ShellWindow(props: ShellWindowProps) {
  props.content.hexpand = true;
  props.content.vexpand = true;

  const anchor: Astal.WindowAnchor =
    Astal.WindowAnchor.TOP |
    Astal.WindowAnchor.BOTTOM |
    Astal.WindowAnchor.LEFT |
    Astal.WindowAnchor.RIGHT;
  const display = Gdk.Display.get_default();
  let backdrops: Widget.Window[] = [];
  let backdropSync = 0;

  function dismissArea(vertical = false) {
    return new Widget.EventBox({
      hexpand: true,
      vexpand: vertical,
      visibleWindow: false,
      events: Gdk.EventMask.BUTTON_PRESS_MASK,
      onButtonPressEvent: () => {
        window.hide();
        return true;
      },
    });
  }

  function clearBackdrops() {
    if (backdropSync) {
      GLib.source_remove(backdropSync);
      backdropSync = 0;
    }
    for (const backdrop of backdrops) backdrop.destroy();
    backdrops = [];
  }

  function syncBackdrops() {
    clearBackdrops();
    if (!window.visible || !display) return;
    const current = window.get_current_monitor();
    for (let i = 0; i < display.get_n_monitors(); i++) {
      const monitor = display.get_monitor(i);
      if (!monitor || monitor === current) continue;
      const backdrop = new Widget.Window({
        name: `${props.name}-backdrop-${String(i)}`,
        namespace: "nixos-shell",
        application: App,
        className: "shell-window",
        visible: false,
        gdkmonitor: monitor,
        anchor,
        layer: Astal.Layer.OVERLAY,
        exclusivity: Astal.Exclusivity.IGNORE,
        keymode: Astal.Keymode.NONE,
        child: dismissArea(true),
      });
      backdrops.push(backdrop);
      backdrop.show();
    }
  }

  function queueBackdrops() {
    if (backdropSync) return;
    // Let GDK process the menu's output before deciding which monitors to cover.
    backdropSync = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      backdropSync = 0;
      syncBackdrops();
      return GLib.SOURCE_REMOVE;
    });
  }

  const panel = new Widget.Box({
    vertical: true,
    widthRequest: PANEL_SIZE.width,
    heightRequest: PANEL_SIZE.height,
    hexpand: false,
    vexpand: false,
    halign: Gtk.Align.CENTER,
    valign: Gtk.Align.CENTER,
    className: "shell-panel",
    children: [
      new Widget.Box({
        vertical: true,
        className: "shell-header",
        children: [
          new Widget.Label({
            label: props.title,
            truncate: true,
            xalign: 0,
            className: "shell-heading",
          }),
          new Widget.Label({
            label: props.subtitle,
            truncate: true,
            xalign: 0,
            className: "shell-subtitle",
          }),
        ],
      }),
      props.content,
      new Widget.Box({
        className: "shell-footer",
        children: [
          new Widget.Label({
            label: props.hint,
            truncate: true,
            xalign: 0,
            className: "shell-hint",
          }),
        ],
      }),
    ],
  });

  const window = new Widget.Window({
    name: props.name,
    namespace: "nixos-shell",
    application: App,
    className: "shell-window",
    visible: false,
    anchor,
    layer: Astal.Layer.OVERLAY,
    exclusivity: Astal.Exclusivity.IGNORE,
    // Hyprland's exclusive layers also capture pointer input across monitors,
    // preventing the non-interactive backdrops from receiving dismissal clicks.
    keymode: Astal.Keymode.ON_DEMAND,
    onMap: () => {
      queueBackdrops();
      props.initialFocus?.grab_focus();
    },
    onUnmap: () => {
      clearBackdrops();
      props.onClose?.();
    },
    onFocusOutEvent: (self) => {
      self.hide();
      return false;
    },
    onKeyPressEvent: (self, event) => {
      if (event.get_keyval()[1] === Gdk.KEY_Escape) {
        self.hide();
        return true;
      }
      return false;
    },
    child: new Widget.Box({
      vertical: true,
      children: [
        dismissArea(true),
        new Widget.Box({
          children: [dismissArea(), panel, dismissArea()],
        }),
        dismissArea(true),
      ],
    }),
  });

  const added = display?.connect("monitor-added", queueBackdrops);
  const removed = display?.connect("monitor-removed", queueBackdrops);
  window.connect("destroy", () => {
    clearBackdrops();
    if (added) display?.disconnect(added);
    if (removed) display?.disconnect(removed);
  });
  return window;
}
