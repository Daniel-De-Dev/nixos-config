import { App } from "astal/gtk3";
import GLib from "gi://GLib?version=2.0";
import WindowSwitcher from "./widget/WindowSwitcher";
import KeybindingSearch from "./widget/KeybindingSearch";
import ApplicationLauncher from "./widget/ApplicationLauncher";

// TODO: Fix LSP to work (introduce .nvim.lua? and also linting for types that is checked (do it for all lua, ts, css ect files in repo & md files)?)

const windows = [
  "window-switcher",
  "keybinding-search",
  "application-launcher",
];

App.start({
  instanceName: "nixos-shell",
  css: GLib.getenv("AGS_SHELL_STYLE") ?? "",
  requestHandler(request, res) {
    if (windows.includes(request)) {
      const win = App.get_window(request);
      if (win) {
        const show = !win.visible;
        for (const name of windows) App.get_window(name)?.hide();
        win.visible = show;
      }
      res("ok");
    } else {
      res("unknown");
    }
  },
  main() {
    WindowSwitcher();
    KeybindingSearch();
    ApplicationLauncher();
  },
});
