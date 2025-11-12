{
  lib,
  config,
  pkgs,
  ...
}:
let
  declaredUsers = config.my.host.users;
  gpgUsers = lib.filterAttrs (_: u: (u.features.gpg.enable or false)) declaredUsers;

  gpgInitScript = ''
    # --- auto gpg key generation (NixOS) ---
    _nixos_auto_gpggen() {
      set +e

      currentUser=$(id -un)
      realName=""
      email=""
      activated=0

      case "$currentUser" in
      ${lib.concatStrings (
        lib.mapAttrsToList (
          name: u:
          let
            cfg = u.features.gpg;
          in
          ''
            "${u.name}")
              realName="${cfg.realName}"
              email="${cfg.email}"
              activated=1
              ;;
          ''
        ) gpgUsers
      )}
      esac

      # user not managed / gpg feature not enabled
      if [ "$activated" -ne 1 ]; then
        return 0
      fi

      # skip if we already have a secret key for this email
      if ${pkgs.gnupg}/bin/gpg --list-secret-keys --with-colons "$email" 2>/dev/null | grep -q '^sec:'; then
        return 0
      fi

      # don’t hang in non-interactive shells
      if [ -z "$PS1" ]; then
        echo "[gpg-setup] $currentUser: GPG key missing but shell is non-interactive, skipping." >&2
        return 0
      fi

      gpgDir="$HOME/.gnupg"
      if ! mkdir -p "$gpgDir"; then
        echo "[gpg-setup] $currentUser: ERROR: could not create $gpgDir" >&2
        return 0
      fi
      chmod 700 "$gpgDir" 2>/dev/null || true

      echo "[gpg-setup] $currentUser: creating modern ECC key (ed25519 + cv25519), 1y expiry..."
      echo "[gpg-setup] $currentUser: you will be prompted by gpg/pinentry for a passphrase."

      # primary key: ed25519, for cert/sign, 1 year
      if ! ${pkgs.gnupg}/bin/gpg --quick-generate-key "$realName <$email>" ed25519 sign 1y; then
        echo "[gpg-setup] $currentUser: ERROR: primary key generation failed." >&2
        return 0
      fi

      # get fingerprint of the key just made
      fpr=$(${pkgs.gnupg}/bin/gpg --list-keys --with-colons "$email" 2>/dev/null | awk -F: '/^fpr:/ {print $10; exit}')
      if [ -z "$fpr" ]; then
        echo "[gpg-setup] $currentUser: ERROR: could not determine key fingerprint." >&2
        return 0
      fi

      # subkey: cv25519 for encryption, 1 year
      if ! ${pkgs.gnupg}/bin/gpg --quick-add-key "$fpr" cv25519 encrypt 1y; then
        echo "[gpg-setup] $currentUser: WARNING: encryption subkey creation failed." >&2
      fi

      # make a revocation certificate
      revokeFile="$gpgDir/revoke-$currentUser.asc"
      if ! ${pkgs.gnupg}/bin/gpg --output "$revokeFile" --gen-revoke "$fpr"; then
        echo "[gpg-setup] $currentUser: WARNING: could not create revocation certificate." >&2
      else
        chmod 600 "$revokeFile" 2>/dev/null || true
        echo "[gpg-setup] $currentUser: revocation certificate saved at $revokeFile — store it safely."
      fi

      echo "[gpg-setup] $currentUser: GPG setup complete (expires in 1y). You can extend later with: gpg --quick-set-expire $fpr 1y"
    }
    _nixos_auto_gpggen
    unset -f _nixos_auto_gpggen
    # --- end auto gpg key generation ---
  '';
in
{
  assertions = lib.flatten (
    lib.mapAttrsToList (name: u: [
      {
        assertion = (u.features.gpg.realName or null) != null;
        message = "User '${u.name}' enabled my.host.users.${name}.features.gpg but did not set realName.";
      }
      {
        assertion = (u.features.gpg.email or null) != null;
        message = "User '${u.name}' enabled my.host.users.${name}.features.gpg but did not set email.";
      }
      {
        assertion = config.programs.gnupg.agent.enable == true;
        message = "User '${u.name}' enabled my.host.users.${name}.features.gpg but config.programs.gnupg.agent.enable is false.";
      }
    ]) gpgUsers
  );

  environment.interactiveShellInit = lib.mkAfter gpgInitScript;
}
