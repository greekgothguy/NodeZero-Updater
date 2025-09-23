#!/usr/bin/env bash
LOGFILE="/var/log/run-n0.log"
mkdir -p "$(dirname "$LOGFILE")"

# Run n0 as non-root; log as root
sudo -u nodezero bash -c 'TERM=dumb PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" n0 -n 5' \
  | tee -a "$LOGFILE" >/dev/null
