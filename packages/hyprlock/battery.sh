# The configured battery takes priority. Otherwise use the first system battery.
# An absent battery produces no label, including on systems without batteries.
: "${battery_id?battery_id must be supplied by default.nix}"
: "${low_color:?low_color must be supplied by default.nix}"
power_supply_dir="${HYPRLOCK_POWER_SUPPLY_DIR:-/sys/class/power_supply}"
supplies=()
if [[ -n ${battery_id} ]]; then
  supplies+=("${power_supply_dir}/${battery_id}")
fi
supplies+=("${power_supply_dir}"/*)

for supply in "${supplies[@]}"; do
  [[ -r "${supply}/type" && -r "${supply}/capacity" ]] || continue
  [[ "$(<"${supply}/type")" == Battery ]] || continue
  if [[ -r "${supply}/scope" && "$(<"${supply}/scope")" == Device ]]; then
    continue
  fi
  capacity=$(<"${supply}/capacity")
  [[ ${capacity} =~ ^[0-9]{1,3}$ ]] || continue
  capacity=$((10#${capacity}))
  ((capacity <= 100)) || continue
  status=Unknown
  if [[ -r "${supply}/status" ]]; then
    status=$(<"${supply}/status")
  fi
  # Keep arbitrary sysfs strings out of the Pango markup below.
  case "${status}" in
  Charging | Discharging | Full | "Not charging") ;;
  *) status=Unknown ;;
  esac
  text="Battery ${capacity}% · ${status}"
  if ((capacity <= 15)) && [[ ${status} == Discharging ]]; then
    printf '<span foreground="%s">%s</span>\n' "${low_color}" "${text}"
  else
    printf '%s\n' "${text}"
  fi
  exit 0
done
