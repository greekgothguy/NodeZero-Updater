#!/usr/bin/env bash

LOGFILE="/var/log/run-n0.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

# Run n0 and append both stdout and stderr to the log
n0 -n 5 >>"$LOGFILE" 2>&1
