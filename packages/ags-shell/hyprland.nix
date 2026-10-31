# One declaration of AGS shortcuts and layer styling for both launch modes.
{ lib }:
let
  actions = {
    keybinding = {
      keys = "SUPER + CTRL + Tab";
      request = "window-switcher";
      description = "Windows: Switch window";
    };
    keybindingSearch = {
      keys = "SUPER + CTRL + K";
      request = "keybinding-search";
      description = "Help: Search keyboard shortcuts";
    };
    applicationLauncher = {
      keys = "SUPER + CTRL + Return";
      request = "application-launcher";
      description = "Applications: Open application launcher";
    };
    clipboardManager = {
      keys = "SUPER + V";
      request = "clipboard-manager";
      description = "Clipboard: Search clipboard history";
    };
  };
in
{
  options = lib.mapAttrs (
    _: action:
    lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = action.keys;
      description = "${action.description}; null disables this shortcut.";
    }
  ) actions;
  render =
    {
      command,
      bindings ? lib.mapAttrs (_: action: action.keys) actions,
    }:
    {
      extraLayerRules = [
        ''hl.layer_rule({ name = "nixos-shell-no-animation", match = { namespace = "^nixos-shell$" }, no_anim = true })''
      ];
      extraBindings = lib.concatLists (
        lib.mapAttrsToList (
          name: action:
          lib.optional (bindings.${name} != null)
            "nixos_shortcuts.bind(${builtins.toJSON bindings.${name}}, hl.dsp.exec_cmd(${
              builtins.toJSON (
                lib.escapeShellArgs [
                  command
                  action.request
                ]
              )
            }), ${builtins.toJSON action.description}, nil, ${
              lib.boolToString (name != "keybindingSearch")
            })"
        ) actions
      );
    };
}
