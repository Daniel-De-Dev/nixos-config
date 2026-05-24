SCOPE=${1:-}
if [ -z "$SCOPE" ]; then
  echo "Usage: ssh-forge <scope> (e.g., git, sign, infra)"
  exit 1
fi

KEY_FILE="$HOME/.ssh/id_ed25519_$SCOPE"
ALLOWED_SIGNERS="$HOME/.ssh/allowed_signers"
EMAIL="@email@"

if [ -f "$KEY_FILE" ]; then
  echo "Error: Key $KEY_FILE already exists."
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "Forging new SSH key for scope: $SCOPE..."
ssh-keygen -t ed25519 -a 100 -C "$EMAIL" -f "$KEY_FILE"

if [ "$SCOPE" = "sign" ]; then
  echo "Registering signing key to $ALLOWED_SIGNERS..."
  echo "$EMAIL namespaces=\"git\" $(cat "${KEY_FILE}.pub")" >>"$ALLOWED_SIGNERS"
  chmod 644 "$ALLOWED_SIGNERS"
  echo "Git signing identity successfully registered."
fi
