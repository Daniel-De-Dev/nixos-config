import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";

type ShellWindowProps = {
  name: string;
  title: string;
  subtitle: string;
  content: Gtk.Widget;
  hint: string;
  initialFocus?: Gtk.Widget;
};

export default function ShellWindow(props: ShellWindowProps) {
  return new Widget.Window({
    name: props.name,
    application: App,
    className: "shell-window",
    visible: false,
    keymode: Astal.Keymode.EXCLUSIVE,
    onMap: () => props.initialFocus?.grab_focus(),
    onKeyPressEvent: (self, event) => {
      if (event.get_keyval()[1] === Gdk.KEY_Escape) {
        self.hide();
        return true;
      }
      return false;
    },
    child: new Widget.Box({
      vertical: true,
      className: "shell-panel",
      children: [
        new Widget.Box({
          vertical: true,
          className: "shell-header",
          children: [
            new Widget.Label({
              label: props.title,
              xalign: 0,
              className: "shell-heading",
            }),
            new Widget.Label({
              label: props.subtitle,
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
              xalign: 0,
              className: "shell-hint",
            }),
          ],
        }),
      ],
    }),
  });
}
