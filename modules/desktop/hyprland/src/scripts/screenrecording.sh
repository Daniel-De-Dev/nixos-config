DIR="${HOME}/Videos"
LOCK="${HOME}/.cache/screenrecording.lock"
INFO="${HOME}/.cache/screenrecording.info"
VIDEO_EDITOR="davinci-resolve"
LOG="/tmp/screenrecording.log"

mkdir -p "${DIR}"

# Stop existing recording if lock file exists
if [[ -f ${LOCK} ]]; then
  PID=$(cat "${LOCK}")
  # Send SIGINT to gracefully finalize the mp4 container
  kill -SIGINT "${PID}" 2>/dev/null
  rm "${LOCK}"

  if [[ -f ${INFO} ]]; then
    OUT_FILE=$(cat "${INFO}")
    rm "${INFO}"

    # Wait for the recording process to actually finish writing the file
    while kill -0 "${PID}" 2>/dev/null; do
      sleep 0.1
    done

    echo "file://${OUT_FILE}" | wl-copy -t text/uri-list

    ACTION=$(notify-send \
      -i "video-x-generic" \
      -a "Screen Recording" \
      "Recording Stopped" \
      "Saved to Videos and copied to clipboard." \
      --action="open=Open in Editor" \
      --wait)

    if [[ ${ACTION} == "open" ]]; then
      # Check if ffmpeg exists
      if ! command -v ffmpeg &>/dev/null; then
        notify-send -u critical -a "Screen Recording" "Dependency Missing" "ffmpeg is required for DaVinci Resolve conversion."
        exit 1
      fi

      EDIT_FILE="${OUT_FILE%.mp4}_edit.mov"

      notify-send -a "Screen Recording" "Preparing for Editor" "Converting audio for DaVinci Resolve..."

      # Run ffmpeg in the foreground and wait for it to finish
      if ffmpeg -i "${OUT_FILE}" -c:v copy -c:a pcm_s16le "${EDIT_FILE}" -y >/dev/null 2>&1; then
        ${VIDEO_EDITOR} "${EDIT_FILE}" &
      else
        notify-send -u critical -a "Screen Recording" "Conversion Failed" "Failed to create DaVinci compatible file."
      fi
    fi
  fi
  exit 0
fi

# Start New Recording
FILE="${DIR}/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

# Safely resolve the audio source
DEFAULT_SINK=$(pactl get-default-sink || true)
if [[ -n ${DEFAULT_SINK} ]]; then
  AUDIO_FLAGS=(--audio="${DEFAULT_SINK}.monitor")
else
  AUDIO_FLAGS=()
fi

if [[ $1 == "area" ]]; then
  AREA=$(slurp -b "#00000080" -c "#888888ff" -w 1)
  [[ -z ${AREA} ]] && exit 0
  wf-recorder -g "${AREA}" "${AUDIO_FLAGS[@]}" -c h264_nvenc -x yuv420p -f "${FILE}" >"${LOG}" 2>&1 &
else
  MONITOR=$(hyprctl -j activeworkspace | jq -r '.monitor' 2>/dev/null || true)
  if [[ -z ${MONITOR} || ${MONITOR} == "null" ]]; then
    MONITOR=$(hyprctl -j monitors | jq -r '.[0].name' 2>/dev/null || true)
  fi
  wf-recorder -o "${MONITOR}" "${AUDIO_FLAGS[@]}" -c h264_nvenc -x yuv420p -f "${FILE}" >"${LOG}" 2>&1 &
fi

PID=$!
sleep 0.5

if ! kill -0 "${PID}" 2>/dev/null; then
  notify-send -u critical -a "Screen Recording" "Recording Failed" "Check ${LOG} for details."
  exit 1
fi

# Store process info to allow stopping later
echo "${PID}" >"${LOCK}"
echo "${FILE}" >"${INFO}"

notify-send -a "Screen Recording" "Recording Started" "Click keybind again to stop."
