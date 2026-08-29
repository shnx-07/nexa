#!/usr/bin/env bash
# Open system monitor with robust environment
exec 2> /tmp/open-monitor.log

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

if command -v btop >/dev/null 2>&1; then
    exec btop --force-utf
elif command -v htop >/dev/null 2>&1; then
    exec htop
else
    exec top
fi
