# Shared applications, appearance and visual services for both desktop launch modes.
{
  lib,
  pkgs,
  wrapper-manager,
}:
let
  applications = {
    terminal = pkgs.ghostty;
    browser =
      (wrapper-manager.lib {
        inherit pkgs;
        modules = [
          {
            wrappers.brave = {
              basePackage = pkgs.brave;
              programs.brave.prependFlags = [
                "--force-dark-mode"
                "--enable-features=WebUIDarkMode"
                "--load-extension=${../../modules/programs/brave/pdf-dark}"
                "--ozone-platform-hint=auto"
                "--enable-wayland-ime"
              ];
            };
          }
        ];
      }).config.wrappers.brave.wrapped;
    fileManager = pkgs.yazi;
    emojiPicker = pkgs.bemoji;
    calculator = pkgs.qalculate-qt;
  };
  commands = {
    terminal = lib.getExe applications.terminal;
    browser = lib.getExe applications.browser;
    fileManager = "${lib.getExe applications.terminal} --class=yazi-files -e ${lib.getExe applications.fileManager}";
    emojiPicker = "${lib.getExe applications.emojiPicker} -t -n -c";
    calculator = lib.getExe applications.calculator;
  };
  cursor = {
    package = pkgs.posy-cursors;
    name = "Posy_Cursor_Black";
    size = 24;
  };
  wallpaper = ../../modules/desktop/hyprland/src/wallpaper.jpg;
  setWallpaper = pkgs.writeShellApplication {
    name = "hyprland-wallpaper";
    runtimeInputs = [ pkgs.awww ];
    text = ''
      for _ in {1..50}; do
        if awww query >/dev/null 2>&1; then
          exec awww img ${wallpaper}
        fi
        sleep 0.1
      done
      echo 'Wallpaper daemon did not become ready.' >&2
      exit 1
    '';
  };
  fileManagerDesktop = pkgs.makeDesktopItem {
    name = "yazi-ghostty";
    desktopName = "File Manager";
    exec = "${commands.fileManager} %U";
    icon = "system-file-manager";
    terminal = false;
    categories = [
      "System"
      "FileTools"
      "FileManager"
    ];
    mimeTypes = [ "inode/directory" ];
  };
  emojiList = pkgs.runCommand "hyprland-emojis" { } ''
    ${pkgs.gnused}/bin/sed -n 's/^.*; fully-qualified.*# \(\S*\) \S* \(.*$\)/\1 \2/gp' \
      ${pkgs.unicode-emoji.emoji-test}/share/unicode/emoji/emoji-test.txt > "$out"
  '';
in
{
  inherit
    applications
    commands
    cursor
    wallpaper
    ;
  browserDesktop = "brave-browser.desktop";
  fileManagerDesktopId = fileManagerDesktop.name;
  unfree = map lib.getName [
    pkgs.brave
    cursor.package
  ];
  packages = lib.attrValues applications ++ [
    fileManagerDesktop
    cursor.package
    pkgs.bemenu
    pkgs.awww
    pkgs.wtype
    pkgs.wl-clipboard
  ];
  environment = {
    GTK_THEME = "Adwaita:dark";
    NIXOS_OZONE_WL = "1";
    XCURSOR_THEME = cursor.name;
    XCURSOR_SIZE = toString cursor.size;
    TERMINAL = commands.terminal;
    FILEMANAGER = lib.getExe applications.fileManager;
    BEMOJI_CUSTOM_LIST = "${emojiList}";
  };
  # NixOS runs these as user units; the preview starts the same commands directly.
  services = {
    awww = {
      command = "${pkgs.awww}/bin/awww-daemon";
      afterStart = lib.getExe setWallpaper;
    };
    cliphist.command = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
    mako.command = lib.getExe pkgs.mako;
  };
  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = [
      pkgs.gimp
      pkgs.grimblast
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = builtins.readFile ../../modules/desktop/hyprland/src/scripts/screenshot.sh;
  };
}
