# Map external data into defaults for the typed identity interface.
{ lib }:
{
  data,
  machine ? null,
}:
let
  requireAttrs =
    name: value:
    if builtins.isAttrs value then
      value
    else
      throw "privacy data: ${name} must be an attribute set";

  root = requireAttrs "root" data;
  globalData = requireAttrs "global" (root.global or { });
  profiles = requireAttrs "profiles" (root.profiles or { });
  hosts = requireAttrs "hosts" (root.hosts or { });
  hostData =
    if machine != null && machine != "" then
      requireAttrs "hosts.${machine}" (hosts.${machine} or { })
    else
      { };
  selectedProfiles = hostData.profiles or [ ];
  profileNames =
    if
      builtins.isList selectedProfiles
      && lib.all (name: builtins.isString name && name != "") selectedProfiles
    then
      selectedProfiles
    else
      throw "privacy data: hosts.${toString machine}.profiles must be a list of non-empty profile names";
  profileData =
    name:
    if builtins.hasAttr name profiles then
      requireAttrs "profiles.${name}" profiles.${name}
    else
      throw "privacy data: hosts.${toString machine}.profiles references unknown profile '${name}'";

  # Flat, ordered overlays: global -> selected profiles -> host.
  # Attribute sets merge recursively; later scalars and lists replace earlier ones.
  merged = builtins.seq profiles (
    lib.foldl' lib.recursiveUpdate globalData (
      map profileData profileNames ++ [ (removeAttrs hostData [ "profiles" ]) ]
    )
  );

  operator = requireAttrs "operator" (merged.operator or { });
  locale = requireAttrs "locale" (merged.locale or { });
  network = requireAttrs "network" (merged.network or { });
  ssh = requireAttrs "ssh" (merged.ssh or { });
  security = requireAttrs "security" (merged.security or { });

  defaultsFor =
    names: values:
    lib.mapAttrs (_: value: lib.mkDefault value) (
      lib.filterAttrs (name: _: builtins.elem name names) values
    );
in
{
  operator =
    defaultsFor [
      "username"
      "hashedPassword"
      "sshKeys"
      "fullName"
      "email"
      "signingKey"
    ] operator
    // {
      locale = defaultsFor [ "default" "measurement" ] locale;
    };

  host =
    defaultsFor [ "timeZone" "keyMap" ] merged
    // {
      network = defaultsFor [ "macRandomize" ] network;
      ssh = defaultsFor [ "authorizedKeys" "matchBlocks" ] ssh;
      security = defaultsFor [ "usbguard" "strictKernel" "kernelLockdown" ] security;
    }
    // lib.optionalAttrs (merged ? hostId) { id = lib.mkDefault merged.hostId; }
    // (
      if merged ? hostName then
        { name = lib.mkDefault merged.hostName; }
      else
        lib.optionalAttrs (machine != null && machine != "") {
          name = lib.mkDefault machine;
        }
    );
}
