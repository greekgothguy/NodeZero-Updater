#!/usr/bin/env bash
set -Eeuo pipefail

LOGFILE="/var/log/run-n0.log"

CMD=(sudo -u nodezero env TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" n0 -n 5)

# Ensure logfile path exists
mkdir -p "$(dirname "$LOGFILE")"

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

# Run command + capture
start_ts=$(date +%s)
"${CMD[@]}" 2>&1 | tee -a "$LOGFILE"
cmd_rc=${PIPESTATUS[0]}
end_ts=$(date +%s)
duration=$(( end_ts - start_ts ))

# Footer
{
  printf 'Exit code: %d | Duration: %ds\n' "$cmd_rc" "$duration"
  printf '=============== End of run ===============\n'
} >>"$LOGFILE"

exit "$cmd_rc"
