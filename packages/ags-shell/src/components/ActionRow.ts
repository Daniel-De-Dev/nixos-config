import { Widget } from "astal/gtk3";
import { type Binding } from "astal";
import type Gio from "gi://Gio?version=2.0";

type ActionRowProps = {
  title: string;
  description: string;
  icon: string | Gio.Icon;
  visible?: boolean | Binding<boolean>;
  onActivate: () => void;
};

export default function ActionRow(props: ActionRowProps) {
  return new Widget.Button({
    className: "shell-action-row",
    visible: props.visible ?? true,
    onClicked: props.onActivate,
    child: new Widget.Box({
      children: [
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
