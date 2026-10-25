# Evaluation-only identity. The account is locked and its private key is discarded.
{
  global = {
    operator = {
      username = "fixture-operator";
      hashedPassword = "*";
      fullName = "Evaluation Operator";
      email = "operator@example.invalid";
    };
  };
  profiles.evaluation.ssh.authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMlhT3BujklPoJn9Oc3o3gdbtdYIFcymJEUBOWWAYF45 evaluation-fixture"
  ];
  hosts = {
    box-01 = {
      profiles = [ "evaluation" ];
      hostId = "11111111";
    };
    box-02 = {
      profiles = [ "evaluation" ];
      hostId = "22222222";
    };
  };
}
