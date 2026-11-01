#!/usr/bin/env bash
# Re-run displays.sh when the lid opens/closes (clamshell mode with an external screen).
# logind already ignores the lid while docked; this only flips the laptop panel.

pidfile="${XDG_RUNTIME_DIR:-/tmp}/i3-lid-watch.pid"
[[ -f $pidfile ]] && kill "$(cat "$pidfile")" 2>/dev/null
echo $$ >"$pidfile"

state() { cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2; exit}'; }
last=$(state)
while sleep 2; do
    now=$(state)
    if [[ $now != "$last" ]]; then
        last=$now
        ~/.config/i3/scripts/displays.sh
    fi
done
