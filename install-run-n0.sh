#!/usr/bin/env bash
# Installs "run-n0-if-no-docker" nightly cron, logs, and logrotate.
# Idempotent: safe to run multiple times.
set -euo pipefail

# --- Config (change if you like) ---
RUN_SCRIPT="/usr/local/bin/run-n0-if-no-docker.sh"
LOG_FILE="/var/log/run-n0.log"
LOGROTATE_CONF="/etc/logrotate.d/run-n0"
CRON_COMMENT="# run-n0-if-no-docker (managed)"
CRON_ENTRY="0 0 * * * $RUN_SCRIPT"
OWNER_USER="root"
OWNER_GROUP="adm"
RUN_USER="root"   # cron owner; root is simplest since it touches /var/log

# If you want n0 to run as a non-root account (recommended if n0 expects non-root), set this:
EXEC_USER=""      # e.g. "dimi" or leave empty to run as the cron user
# -----------------------------------

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This installer needs root. Re-running with sudo..."
    exec sudo -E bash "$0" "$@"
  fi
}
need_root "$@"

echo "Installing run-n0-if-no-docker…"

# 1) Install the runner script
install_runner() {
  cat >"$RUN_SCRIPT" <<"EOF"
#!/usr/bin/env bash
# Run "n0 -n 5" at midnight only if no Docker containers are running.
# Logs all runs (with duration) to /var/log/run-n0.log (rotated by logrotate).

set -euo pipefail

# --- Cron-safe environment ---
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export TERM="dumb"
umask 027

LOGFILE="/var/log/run-n0.log"

log() {
  echo "$(date -Is) $*" | tee -a "$LOGFILE"
}

# === Header for each run ===
{
  echo ""
  echo "==============================================="
  echo " Run started at $(date -Is)"
  echo "==============================================="
} >>"$LOGFILE"

# Single-instance lock (silent if another run is in progress)
exec 9>/var/lock/run-n0.lock
if ! flock -n 9; then
  exit 0
fi

# Robust running-container counter (works if docker is missing or daemon is down)
docker_running_count() {
  if ! command -v docker >/dev/null 2>&1; then
    printf '0\n'
    return 0
  fi
  # Avoid pipefail within command substitution: capture output safely
  local out
  if out="$(docker ps -q 2>/dev/null)"; then
    # wc -l can add spaces; trim with awk
    printf '%s\n' "$out" | wc -l | awk '{print $1}'
  else
    printf '0\n'
  fi
}

running="$(docker_running_count)"

if [[ "$running" -eq 0 ]]; then
  log "No active Docker containers detected. Running: n0 -n 5"

  start_ts=$(date +%s)

  # Optionally run n0 as a specific non-root user if EXEC_USER is set in the environment
  # (The installer can write EXEC_USER into this script's environment via a wrapper; we also read /etc/default)
  # We intentionally do NOT change any log messages.
  if [[ -n "${EXEC_USER:-}" && "${EUID}" -eq 0 && "${EXEC_USER}" != "root" ]]; then
    if command -v runuser >/dev/null 2>&1; then
      if runuser -l "$EXEC_USER" -c "n0 -n 5" >>"$LOGFILE" 2>&1; then
        end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
        log "n0 completed successfully. Duration: ${duration}s"
      else
        rc=$?; end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
        log "ERROR: n0 failed with exit code $rc. Duration: ${duration}s"
        exit 1
      fi
    else
      if sudo -u "$EXEC_USER" -- sh -lc "n0 -n 5" >>"$LOGFILE" 2>&1; then
        end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
        log "n0 completed successfully. Duration: ${duration}s"
      else
        rc=$?; end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
        log "ERROR: n0 failed with exit code $rc. Duration: ${duration}s"
        exit 1
      fi
    fi
  else
    if n0 -n 5 >>"$LOGFILE" 2>&1; then
      end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
      log "n0 completed successfully. Duration: ${duration}s"
    else
      rc=$?; end_ts=$(date +%s); duration=$(( end_ts - start_ts ))
      log "ERROR: n0 failed with exit code $rc. Duration: ${duration}s"
      exit 1
    fi
  fi
else
  log "Found $running active Docker container(s). Skipping n0."
fi
EOF

  chmod +x "$RUN_SCRIPT"
  echo "✓ Runner installed at $RUN_SCRIPT"
}
install_runner

# 2) Ensure logfile exists with sane perms
setup_logfile() {
  touch "$LOG_FILE"
  chown "$OWNER_USER:$OWNER_GROUP" "$LOG_FILE"
  chmod 664 "$LOG_FILE"
  echo "✓ Logfile ready at $LOG_FILE"
}
setup_logfile

# 3) Install logrotate config
install_logrotate() {
  cat >"$LOGROTATE_CONF" <<EOF
$LOG_FILE {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 664 $OWNER_USER $OWNER_GROUP
}
EOF
  echo "✓ Logrotate config at $LOGROTATE_CONF"
}
install_logrotate

# 4) Install/ensure cron entry for RUN_USER
install_cron() {
  # Fetch existing crontab (if any)
  tmp_cron="$(mktemp)"
  crontab -u "$RUN_USER" -l 2>/dev/null | sed "/$CRON_COMMENT/d" > "$tmp_cron" || true

  # Add our managed block fresh each time (idempotent)
  {
    echo "$CRON_COMMENT"
    echo "$CRON_ENTRY"
  } >> "$tmp_cron"

  crontab -u "$RUN_USER" "$tmp_cron"
  rm -f "$tmp_cron"
  echo "✓ Cron installed for user '$RUN_USER': $CRON_ENTRY"
}
install_cron

# 5) Dry-run logrotate to validate config (optional)
if command -v logrotate >/dev/null 2>&1; then
  logrotate -f "$LOGROTATE_CONF" || true
  echo "✓ Logrotate forced once (to initialize)."
else
  echo "ℹ logrotate not found; skipping test run."
fi

# Persist EXEC_USER for the runner without changing its messages:
# We export it via a small env file and a wrapper, to avoid editing your log strings.
ENV_FILE="/etc/default/run-n0"
WRAPPER="/usr/local/bin/run-n0-if-no-docker-wrapper.sh"

if [[ -n "$EXEC_USER" ]]; then
  printf 'EXEC_USER="%s"\n' "$EXEC_USER" > "$ENV_FILE"
  chmod 644 "$ENV_FILE"
  cat >"$WRAPPER" <<'WRAP'
#!/usr/bin/env bash
set -euo pipefail
[ -f /etc/default/run-n0 ] && source /etc/default/run-n0
exec /usr/local/bin/run-n0-if-no-docker.sh
WRAP
  chmod +x "$WRAPPER"
  # Update cron to call wrapper so the env var is present
  tmp_cron="$(mktemp)"
  crontab -u "$RUN_USER" -l 2>/dev/null | sed "/$CRON_COMMENT/d" > "$tmp_cron" || true
  {
    echo "$CRON_COMMENT"
    echo "${CRON_ENTRY//$RUN_SCRIPT/$WRAPPER}"
  } >> "$tmp_cron"
  crontab -u "$RUN_USER" "$tmp_cron"
  rm -f "$tmp_cron"
fi

echo "All set!
- Script:   $RUN_SCRIPT
- Log:      $LOG_FILE  (rotated daily, keep 7)
- Cron:     (root) $CRON_ENTRY
"
