#!/usr/bin/env bash
# Simple runner: executes "n0 -n 5" as current user when no Docker containers are running.
# Logs to /var/log/run-n0.log with duration and separators.

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="dumb"

LOGFILE="/var/log/run-n0.log"
DOCKER="$(command -v docker || echo /usr/bin/docker)"

log(){ echo "$(date -Is) $*" | tee -a "$LOGFILE"; }

{
  echo ""
  echo "==============================================="
  echo " Run started at $(date -Is)"
  echo "==============================================="
} >>"$LOGFILE"

running=$("$DOCKER" ps -q 2>/dev/null | wc -l || echo 0)

if [[ "$running" -eq 0 ]]; then
  log "No active Docker containers detected. Running: n0 -n 5"
  start_ts=$(date +%s)
  if SUDO_USER="$USER" n0 -n 5 >>"$LOGFILE" 2>&1; then
    end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
    log "n0 completed successfully. Duration: ${duration}s"
  else
    rc=$?; end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
    log "ERROR: n0 failed with exit code $rc. Duration: ${duration}s"
    exit 1
  fi
else
  log "Found $running active Docker container(s). Skipping n0."
fi
