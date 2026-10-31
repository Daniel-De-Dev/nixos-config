DIR="${HOME}/Screenshots"
FILE="Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
EDITOR="gimp"

mkdir -p "${DIR}"

# $1 will be "screen", "area", or "active"
MODE="${1:-screen}"

OUT_FILE="${DIR}/${FILE}"
grimblast --freeze save "${MODE}" "${OUT_FILE}"

if [[ -f ${OUT_FILE} ]]; then
  ags-clipboard copy-file "${OUT_FILE}"

  # Send notification with action button.
  ACTION=$(notify-send \
    -i "${OUT_FILE}" \
    -a "Screenshot" \
    "Screenshot Saved" \
    "Copied to clipboard. Click to edit." \
    --action="open=Open in GIMP" \
    --wait)

  # TODO: Fix that the action actually works
  if [[ ${ACTION} == "open" ]]; then
    ${EDITOR} "${OUT_FILE}" &
  fi
fi
