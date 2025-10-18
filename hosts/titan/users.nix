{ ... }:
{
  # For now just define a single "admin" user meant for daily use
  users.users.zeus = {
    isNormalUser = true;
    group = "zeus";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  users.groups.zeus = { };
}
