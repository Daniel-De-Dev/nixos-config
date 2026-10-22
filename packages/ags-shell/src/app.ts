import { App } from "astal/gtk3";
import WindowSwitcher from "./widget/WindowSwitcher";
import style from "./style.css";

App.start({
  instanceName: "nixos-shell",
  css: style,
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
