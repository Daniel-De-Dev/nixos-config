import { Gtk, Widget } from "astal/gtk3";
import { type Binding } from "astal";
import type Gio from "gi://Gio?version=2.0";

type ActionRowProps = {
  title: string;
  description: string;
  icon: string | Gio.Icon;
  leading?: Gtk.Widget;
  tooltip?: string;
  visible?: boolean | Binding<boolean>;
  selected?: boolean | Binding<boolean>;
  onFocus?: () => void;
  onActivate: () => void;
};

export default function ActionRow(props: ActionRowProps) {
  return new Widget.Button({
    className:
      typeof props.selected === "object"
        ? props.selected.as((selected) =>
            selected ? "shell-action-row selected" : "shell-action-row",
          )
        : props.selected
          ? "shell-action-row selected"
          : "shell-action-row",
    visible: props.visible ?? true,
    tooltipText: props.tooltip ?? props.title,
    onClicked: props.onActivate,
    onFocusInEvent: () => {
      props.onFocus?.();
      return false;
    },
    child: new Widget.Box({
      children: [
        props.leading ??
          new Widget.Icon({
            ...(typeof props.icon === "string"
              ? { icon: props.icon }
              : { gicon: props.icon }),
            className: "shell-item-icon",
          }),
        new Widget.Box({
          vertical: true,
          hexpand: true,
          children: [
            new Widget.Label({
              label: props.title,
              truncate: true,
              xalign: 0,
              className: "shell-item-title",
            }),
            new Widget.Label({
              label: props.description,
              truncate: true,
              xalign: 0,
              className: "shell-item-description",
            }),
          ],
        }),
      ],
    }),
  });
}
