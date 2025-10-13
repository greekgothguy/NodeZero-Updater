#!/usr/bin/env bash
set -Euo pipefail

LOGFILE="/var/log/run-n0.log"
CMD=(sudo -n -u nodezero env TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" n0 -n 5)

mkdir -p "$(dirname "$LOGFILE")"

{
  printf '\n========================================\n'
  printf 'Run started: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf 'Host: %s\n' "$(hostname -f 2>/dev/null || hostname)"
  printf 'Invoker user: %s\n' "${SUDO_USER:-$USER}"
  printf 'Command:'; printf ' %q' "${CMD[@]}"; printf '\n'
  printf '========================================\n'
} >>"$LOGFILE"

start_ts=$(date +%s)

# Don't let -e abort on pipeline failure; capture the real rc from PIPESTATUS[0]
set +e
"${CMD[@]}" 2>&1 | tee -a "$LOGFILE" || true
cmd_rc=${PIPESTATUS[0]}
set -e

end_ts=$(date +%s)
duration=$(( end_ts - start_ts ))

{
  printf 'Exit code: %d | Duration: %ds\n' "$cmd_rc" "$duration"
  printf '=============== End of run ===============\n'
} >>"$LOGFILE"

exit "$cmd_rc"
