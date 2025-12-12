{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkMerge
    mapAttrsToList
    concatStringsSep
    ;

  allUsers = config.my.host.users;

  enabledConfigs = lib.concatLists (
    mapAttrsToList (
      userName: userCfg:
      mapAttrsToList (
        programName: programCfg:
        if programCfg.enable then
          let
            modulePath =
              if programCfg.moduleFile == null then null else programCfg.src + "/${programCfg.moduleFile}";
            moduleValue =
              if modulePath == null then
                { }
              else
                import modulePath {
                  inherit
                    pkgs
                    lib
                    config
                    userName
                    programName
                    ;
                  userConfig = userCfg;
                };
          in
          {
            inherit userName programName moduleValue;
            cfg = programCfg;
          }
        else
          null
      ) userCfg.config
    ) allUsers
  );

  activeConfigs = lib.filter (x: x != null) enabledConfigs;
in
{
  options.my.host.users = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        let
          userOptName = name;
        in
        {
          options.config = mkOption {
            description = "Generic program configurations tied to individual user.";
            default = { };
            type = types.attrsOf (
              types.submodule (
                { name, ... }:
                let
                  programName = name;
                in
                {
                  options = {
                    enable = mkEnableOption "configuration for ${programName}";
                    src = mkOption { type = types.path; };
                    moduleFile = mkOption {
                      type = types.nullOr types.str;
                      default = "default.nix";
                    };

                    variables = mkOption {
                      type = types.attrsOf (
                        types.oneOf [
                          types.str
                          types.int
                          types.bool
                          types.package
                          types.path
                        ]
                      );
                      default = { };
                      description = "Variables to substitute in the config files (@var@). Overrides module defaults.";
                    };

                    symlink = mkOption {
                      type = types.bool;
                      default = true;
                      description = "If true, symlink files. If false, copy them.";
                    };

                    deploy = mkOption {
                      description = "Files or Directories to deploy.";
                      default = { };
                      type = types.attrsOf (
                        types.submodule {
                          options = {
                            source = mkOption { type = types.str; };
                            target = mkOption { type = types.str; };
                            mode = mkOption {
                              type = types.str;
                              default = "u=rwX,go=rX";
                              description = "Permissions to set when copying";
                            };
                            user = mkOption {
                              type = types.str;
                              default = config.users.users.${userOptName}.name;
                            };
                            group = mkOption {
                              type = types.str;
                              default = config.users.users.${userOptName}.group;
                            };
                          };
                        }
                      );
                    };
                  };
                }
              )
            );
          };
        }
      )
    );
  };

  config = mkMerge [
    # Packages
    {
      users.users = mkMerge (
        map (item: {
          ${item.userName}.packages = item.moduleValue.packages or [ ];
        }) activeConfigs
      );
    }

    # Assertions/Warnings
    {
      assertions = lib.concatLists (map (item: item.moduleValue.assertions or [ ]) activeConfigs);
      warnings = lib.concatLists (map (item: item.moduleValue.warnings or [ ]) activeConfigs);
    }

    # Activation Service
    {
      systemd.services.my-user-configs = {
        description = "Deploy user configurations";
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.coreutils ];
        after = [
          "users.service"
          "local-fs.target"
        ];
        requires = [ "local-fs.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };

        script =
          let
            # Collect all target paths that will be created in this generation
            allTargets = lib.concatMap (
              item: lib.mapAttrsToList (_: d: d.target) item.cfg.deploy
            ) activeConfigs;

            # Write them to a file in the Nix store
            newManifest = pkgs.writeText "new-manifest" (lib.concatStringsSep "\n" allTargets);

            deployCommands = map (
              item:
              let
                # Merge variables (Config overrides Module)
                moduleVars = item.moduleValue.variables or { };
                configVars = item.cfg.variables;
                allVars = moduleVars // configVars;

                # Check if substitution is needed
                doSubstitute = allVars != { };

                # Generate substitution flags for substituteInPlace
                substFlags = concatStringsSep " " (
                  lib.mapAttrsToList (
                    name: value:
                    "--replace-warn " + lib.escapeShellArg "@${name}@" + " " + lib.escapeShellArg (toString value)
                  ) allVars
                );
              in
              ''
                # --- Deploying ${item.programName} for user ${item.userName} ---
                ${concatStringsSep "\n" (
                  mapAttrsToList (
                    _: d:
                    let
                      # Calculate the source path
                      rawSource = "${item.cfg.src}/${d.source}";

                      # If variables exist, create a new processed file in the Nix Store
                      finalSource =
                        if doSubstitute then
                          pkgs.runCommand
                            "processed-conf-${
                              if d.source == "" || d.source == "." then "root" else builtins.baseNameOf d.source
                            }"
                            { }
                            ''
                              if [ -d "${rawSource}" ]; then
                                cp -r "${rawSource}" $out
                                chmod -R u+w $out

                                find "$out" -type f | while read -r file; do
                                  if grep -Iq . "$file"; then
                                    echo "Applying substitution to $file"
                                    # silence "pattern not found" warnings
                                    substituteInPlace "$file" ${substFlags} 2>/dev/null
                                  fi
                                done
                              else
                                cp "${rawSource}" $out
                                chmod u+w $out
                                # silence "pattern not found" warnings
                                substituteInPlace $out ${substFlags} 2>/dev/null
                              fi
                            ''
                        else
                          rawSource;
                    in
                    if item.cfg.symlink then
                      ''
                        echo "Symlinking ${d.target} (Substitute: ${if doSubstitute then "Yes" else "No"})"
                        mkdir -p "$(dirname "${d.target}")"
                        ln -sfn "${finalSource}" "${d.target}"
                        chown -h "${d.user}:${d.group}" "${d.target}"
                      ''
                    else
                      ''
                        echo "Copying ${d.target} (Substitute: ${if doSubstitute then "Yes" else "No"})"
                        mkdir -p "$(dirname "${d.target}")"
                        rm -rf "${d.target}"
                        cp -Lr --no-preserve=mode,ownership "${finalSource}" "${d.target}"
                        chown -R "${d.user}:${d.group}" "${d.target}"
                        chmod -R "${d.mode}" "${d.target}"
                      ''
                  ) item.cfg.deploy
                )}
              ''
            ) activeConfigs;
          in
          ''
            unset LD_PRELOAD

            # --- CLEANUP ---
            MANIFEST_FILE="/var/lib/nixos-config/user_configs_manifest"
            mkdir -p "$(dirname "$MANIFEST_FILE")"

            if [ -f "$MANIFEST_FILE" ]; then
              echo "Checking for stale files..."
              comm -23 <(sort "$MANIFEST_FILE") <(sort "${newManifest}") | while read -r file; do
                if [ -e "$file" ] || [ -L "$file" ]; then
                  echo "Cleaning up stale config: $file"
                  rm -rf "$file"

                  # Try to remove the parent directory if it's empty
                  rmdir "$(dirname "$file")" 2>/dev/null || true
                fi
              done
            fi

            # Update the manifest for the next run
            cp "${newManifest}" "$MANIFEST_FILE"
            # ---------------------

            ${concatStringsSep "\n" deployCommands}
          '';
      };
    }
  ];
}
