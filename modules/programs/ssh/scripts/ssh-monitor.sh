LIMIT=@limit@
CURRENT_TIME=$(date +%s)

for PUB_KEY in "${HOME}"/.ssh/id_ed25519_*.pub; do
  [[ -e ${PUB_KEY} ]] || continue

  FILE_MOD_TIME=$(stat -c %Y "${PUB_KEY}")
  AGE_DAYS=$(((CURRENT_TIME - FILE_MOD_TIME) / 86400))

  if [[ ${AGE_DAYS} -ge ${LIMIT} ]]; then
    KEY_NAME=$(basename "${PUB_KEY}" .pub)
    notify-send -u critical \
      -a "Security Policy" \
      "SSH Key Rotation Required" \
      "Key '${KEY_NAME}' is ${AGE_DAYS} days old. Limit is ${LIMIT} days."
  fi
done
