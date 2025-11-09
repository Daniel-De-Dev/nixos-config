{
  lib,
  config,
  pkgs,
  ...
}:
let
  declaredUsers = config.my.host.users;
  sshUsers = lib.filterAttrs (_: u: (u.features.ssh.enable or false)) declaredUsers;

  sshInitScript = ''
    # --- auto ssh key generation (NixOS) ---
    _nixos_auto_sshgen() {
      set +e

      currentUser=$(id -un)
      email=""
      activated=0

      case "$currentUser" in
      ${lib.concatStrings (
        lib.mapAttrsToList (
          _: u:
          let
            cfg = u.features.ssh;
          in
          ''
            "${u.name}")
              email="${cfg.email}"
              activated=1
              ;;
          ''
        ) sshUsers
      )}
      esac

      # user not in list
      if [ "$activated" -ne 1 ]; then
        return 0
      fi

      sshDir="$HOME/.ssh"
      keyFile="$sshDir/id_ed25519"

      # key already exists
      if [ -f "$keyFile" ]; then
        return 0
      fi

      if [ -z "$PS1" ]; then
        echo "[ssh-setup] $currentUser: SSH key missing but shell is non-interactive, skipping." >&2
        return 0
      fi

      if ! mkdir -p "$sshDir"; then
        echo "[ssh-setup] $currentUser: ERROR: could not create directory $sshDir" >&2
        return 0
      fi
      chmod 700 "$sshDir" 2>/dev/null || true

      umask 077

      if [ -z "$email" ]; then
        echo "[ssh-setup] $currentUser: ERROR: ssh settings incomplete (email=''${email})" >&2
        return 0
      fi

      echo "[ssh-setup] $currentUser: No SSH key at $keyFile - generating ed25519"
      echo "[ssh-setup] $currentUser: You will be prompted for a passphrase."

      if ! ${pkgs.openssh}/bin/ssh-keygen \
          -t ed25519 \
          -a 100 \
          -o \
          -C "$email" \
          -f "$keyFile"
      then
        echo "[ssh-setup] $currentUser: ERROR: ssh-keygen failed." >&2
        return 0
      fi

      # harden permissions
      chmod 600 "$keyFile" 2>/dev/null || true
      if [ -f "''${keyFile}.pub" ]; then
        chmod 644 "''${keyFile}.pub" 2>/dev/null || true
      fi

      echo "[ssh-setup] $currentUser: Done. Public key: $keyFile.pub"
    }
    _nixos_auto_sshgen
    unset -f _nixos_auto_sshgen
    # --- end auto ssh key generation ---
  '';
in
{
  assertions = lib.flatten (
    lib.mapAttrsToList (name: u: [
      {
        assertion = (u.features.ssh.email or null) != null;
        message = "User '${u.name}' enabled my.host.users.${name}.features.ssh but did not set email.";
      }
    ]) sshUsers
  );

  environment.interactiveShellInit = lib.mkAfter sshInitScript;
}
