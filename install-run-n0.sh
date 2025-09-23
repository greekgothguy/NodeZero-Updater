#!/usr/bin/env bash
# Root-only runner: executes "n0 -n 5" as root when no Docker containers are running.
# Logs to /var/log/run-n0.log with duration and separators.

set -euo pipefail

# Cron-safe env
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="dumb"
umask 022

LOGFILE="/var/log/run-n0.log"
DOCKER="/usr/bin/docker"   # adjust if docker is elsewhere

log(){ echo "$(date -Is) $*" | tee -a "$LOGFILE"; }

# Header
{
  echo ""
  echo "==============================================="
  echo " Run started at $(date -Is)"
  echo "==============================================="
} >>"$LOGFILE"

# Count running containers (treat errors as zero)
running=$("$DOCKER" ps -q 2>/dev/null | wc -l || echo 0)

if [[ "$running" -eq 0 ]]; then
  log "No active Docker containers detected. Running as ROOT: n0 -n 5"

  start_ts=$(date +%s)
  if n0 -n 5 >>"$LOGFILE" 2>&1; then
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
