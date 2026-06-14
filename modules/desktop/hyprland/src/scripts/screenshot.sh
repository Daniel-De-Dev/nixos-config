DIR="${HOME}/Screenshots"
FILE="Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
EDITOR="gimp"

mkdir -p "${DIR}"

# $1 will be "screen", "area", or "active"
MODE=$1
[[ -z ${MODE} ]] && MODE="screen"

OUT_FILE=$(grimblast --freeze save "${MODE}" "${DIR}/${FILE}")

if [[ -f ${OUT_FILE} ]]; then
  # Copy file to clipboard directly
  wl-copy <"${OUT_FILE}"

  # Send notification with action button.
  ACTION=$(notify-send \
    -i "${OUT_FILE}" \
    -a "Screenshot" \
    "Screenshot Saved" \
    "Copied to clipboard. Click to edit." \
    --action="open=Open in GIMP" \
    --wait)

  if [[ ${ACTION} == "open" ]]; then
    ${EDITOR} "${OUT_FILE}" &
  fi
fi
