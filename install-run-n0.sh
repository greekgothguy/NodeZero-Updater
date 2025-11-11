#!/usr/bin/env bash
set -Euo pipefail

LOGFILE="/var/log/run-n0.log"
CMD=(sudo -n -u nodezero env TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" n0 -n 5)

# Prepare log file
sudo -n install -m 664 -o root -g adm /dev/null "$LOGFILE" 2>/dev/null || true

# Check if any Docker container is currently running
running_containers=$(sudo docker ps --format '{{.ID}}' | wc -l | tr -d ' ')
if (( running_containers > 0 )); then
  {
    printf '[%s] Detected %d running Docker container(s). Skipping update.\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$running_containers"
    sudo docker ps --format '  - {{.Names}} ({{.Status}})'
    printf '=====================================================\n'
  } | sudo tee -a "$LOGFILE" >/dev/null
  exit 0
fi

{
  printf '\n========================================\n'
  printf 'Run started: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'Host: %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Invoker user: %s\n' "${SUDO_USER:-$USER}"
  printf 'Command:'; printf ' %q' "${CMD[@]}"; printf '\n'
  printf '========================================\n'
} | sudo -n tee -a "$LOGFILE" >/dev/null

start_ts=$(date +%s)

# Execute the command if no container is running
"${CMD[@]}" 2>&1 | sudo -n tee -a "$LOGFILE"
cmd_rc=${PIPESTATUS[0]}

end_ts=$(date +%s)
duration=$(( end_ts - start_ts ))

{
  printf 'Exit code: %d | Duration: %ds\n' "$cmd_rc" "$duration"
  printf '=============== End of run ===============\n'
} | sudo -n tee -a "$LOGFILE" >/dev/null

exit "$cmd_rc"
