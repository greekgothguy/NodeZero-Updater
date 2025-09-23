#!/usr/bin/env bash
# Cron-safe runner: executes "n0 -n 5" as a non-root user when no Docker containers are running.
# Logs to /var/log/run-n0.log with duration and separators. Uses sudo to drop privileges just for n0.

set -euo pipefail

# --- Cron-safe env ---
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="dumb"      # avoid tput errors in cron
umask 022

LOGFILE="/var/log/run-n0.log"
RUN_AS_USER="nodezero"        # <-- change to your non-root user if needed
DOCKER="/usr/bin/docker"      # adjust if docker is elsewhere
SUDO="/usr/bin/sudo"          # adjust if sudo is elsewhere

log(){ echo "$(date -Is) $*" | tee -a "$LOGFILE"; }

# Header
{
  echo ""
  echo "==============================================="
  echo " Run started at $(date -Is)"
  echo "==============================================="
} >>"$LOGFILE"

# Ensure target user exists
if ! id -u "$RUN_AS_USER" >/dev/null 2>&1; then
  log "ERROR: target user '$RUN_AS_USER' does not exist."
  exit 1
fi

# Count running containers (treat errors as zero)
running=$("$DOCKER" ps -q 2>/dev/null | wc -l || echo 0)

if [[ "$running" -eq 0 ]]; then
  log "No active Docker containers detected. Running as $RUN_AS_USER via sudo: n0 -n 5"

  start_ts=$(date +%s)
  # -n = non-interactive (no password prompts); bash -lc to load user's login env
  if "$SUDO" -n -u "$RUN_AS_USER" bash -lc 'TERM=dumb n0 -n 5' >>"$LOGFILE" 2>&1; then
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
