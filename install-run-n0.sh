#!/usr/bin/env bash
set -Eeuo pipefail

LOGFILE="/var/log/run-n0.log"
LOCKFILE="/var/lock/run-n0.lock"

# The command to run (edit here if you change args/env later)
CMD=(sudo -u nodezero env TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" n0 -n 5)

# Ensure log/lock locations exist
mkdir -p "$(dirname "$LOGFILE")"
mkdir -p "$(dirname "$LOCKFILE")"

# Prevent concurrent runs
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "Another run appears to be in progress (lock: $LOCKFILE). Exiting."
  exit 1
fi

# Header
{
  printf '\n========================================\n'
  printf 'Run started: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'Host: %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Invoker user: %s\n' "${SUDO_USER:-$USER}"
  printf 'Command:'
  printf ' %q' "${CMD[@]}"
  printf '\n========================================\n'
} >>"$LOGFILE"

# Run + log
start_ts=$(date +%s)
"${CMD[@]}" 2>&1 | tee -a "$LOGFILE"
cmd_rc=${PIPESTATUS[0]}
end_ts=$(date +%s)
duration=$(( end_ts - start_ts ))

# Footer
{
  printf 'Exit code: %d | Duration: %ds\n' "$cmd_rc" "$duration"
  printf '--------------- End of run ---------------\n'
} >>"$LOGFILE"

exit "$cmd_rc"
