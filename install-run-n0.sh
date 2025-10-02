#!/usr/bin/env bash
LOGFILE="/var/log/run-n0.log"
mkdir -p "$(dirname "$LOGFILE")"

sudo -u nodezero env TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  n0 -n 5 2>&1 | tee -a "$LOGFILE"
