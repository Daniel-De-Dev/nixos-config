import { App } from "astal/gtk3";
import GLib from "gi://GLib?version=2.0";
import WindowSwitcher from "./widget/WindowSwitcher";

App.start({
  instanceName: "nixos-shell",
  css: GLib.getenv("AGS_SHELL_STYLE") ?? "",
  requestHandler(request, res) {
    if (request === "window-switcher") {
      const win = App.get_window("window-switcher");
      if (win) {
        win.visible = !win.visible;
      }
      res("ok");
    } else {
      res("unknown");
    }
  },
  main() {
    WindowSwitcher();
  },
});
