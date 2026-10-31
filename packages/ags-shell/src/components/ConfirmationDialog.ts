import { Gdk, Gtk, Widget } from "astal/gtk3";
import Atk from "gi://Atk?version=1.0";
import Pango from "gi://Pango?version=1.0";

type ConfirmationRequest = {
  title: string;
  description: string;
  confirmLabel: string;
  onConfirm: () => void;
};

export default function ConfirmationDialog(onClose: () => void) {
  let request: ConfirmationRequest | null = null;

  function close(accepted = false) {
    if (!request) return;
    const current = request;
    request = null;
    widget.hide();
    onClose();
    if (accepted) current.onConfirm();
  }

  const title = new Widget.Label({
    className: "shell-heading",
    xalign: 0,
    wrap: true,
  });
  const description = new Widget.Label({
    className: "shell-dialog-description",
    xalign: 0,
    wrap: true,
    wrapMode: Pango.WrapMode.WORD_CHAR,
    maxWidthChars: 48,
  });
  const cancel = new Widget.Button({
    label: "Cancel",
    className: "shell-dialog-button",
    hexpand: true,
    onClicked: () => {
      close();
    },
  });
  const confirm = new Widget.Button({
    className: "shell-dialog-button shell-danger-button",
    hexpand: true,
    onClicked: () => {
      close(true);
    },
  });
  const panel = new Widget.Box({
    vertical: true,
    widthRequest: 440,
    hexpand: false,
    vexpand: false,
    halign: Gtk.Align.CENTER,
    valign: Gtk.Align.CENTER,
    className: "shell-dialog",
    children: [
      new Widget.Box({
        vertical: true,
        className: "shell-dialog-content",
        children: [title, description],
      }),
      new Widget.Box({
        homogeneous: true,
        children: [cancel, confirm],
      }),
    ],
  });
  panel.get_accessible().set_role(Atk.Role.DIALOG);

  function cancelArea(vertical = false) {
    return new Widget.EventBox({
      hexpand: true,
      vexpand: vertical,
      visibleWindow: false,
      events: Gdk.EventMask.BUTTON_PRESS_MASK,
      onButtonPressEvent: () => {
        close();
        return true;
      },
    });
  }

  // Keep the modal on the same layer surface, including its keyboard focus.
  const widget = new Widget.Box({
    vertical: true,
    visible: false,
    hexpand: true,
    vexpand: true,
    className: "shell-modal-scrim",
    children: [
      cancelArea(true),
      new Widget.Box({
        children: [cancelArea(), panel, cancelArea()],
      }),
      cancelArea(true),
    ],
  });

  return {
    widget,
    get visible() {
      return request !== null;
    },
    open(next: ConfirmationRequest) {
      request = next;
      title.label = next.title;
      description.label = next.description;
      confirm.label = next.confirmLabel;
      panel.get_accessible().set_name(next.title);
      panel.get_accessible().set_description(next.description);
      widget.show();
      // A destructive action must always require moving away from Cancel.
      cancel.grab_focus();
    },
    cancel: () => {
      close();
    },
    handleKey(event: Gdk.Event): boolean {
      if (!request) return false;
      const key = event.get_keyval()[1];
      if (key === Gdk.KEY_Escape) {
        close();
      } else if (key === Gdk.KEY_Left || key === Gdk.KEY_Up) {
        cancel.grab_focus();
      } else if (key === Gdk.KEY_Right || key === Gdk.KEY_Down) {
        confirm.grab_focus();
      } else if (key === Gdk.KEY_Tab || key === Gdk.KEY_ISO_Left_Tab) {
        (cancel.has_focus ? confirm : cancel).grab_focus();
      } else if (
        key === Gdk.KEY_Return ||
        key === Gdk.KEY_KP_Enter ||
        key === Gdk.KEY_space
      ) {
        close(confirm.has_focus);
      }
      // Trap focus and keep all background shortcuts inactive while modal.
      return true;
    },
  };
}
