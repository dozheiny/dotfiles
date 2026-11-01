#!/usr/bin/env bash
# i3lock over a blurred, darkened screenshot (same look as hyprlock).
# Run by xss-lock (idle, `loginctl lock-session`, before sleep).
# While locked on battery, suspends after 10 more minutes (= 15 min idle, like hypridle).

pgrep -xu "$EUID" i3lock >/dev/null && exit 0

img="${XDG_RUNTIME_DIR:-/tmp}/lock.png"
size=$(xrandr | grep -oP 'current \K\d+ x \d+' | tr -d ' ')
ffmpeg -loglevel quiet -y -f x11grab -video_size "$size" -i "$DISPLAY" -frames:v 1 \
    -vf "scale=iw/6:-1,gblur=sigma=4,scale=iw*6:-1,colorchannelmixer=rr=.6:gg=.6:bb=.6" "$img" \
    || img=""

opts=(--ignore-empty-password --show-failed-attempts --color=0e1416 ${img:+--image="$img"})

on_battery() { [[ $(cat /sys/class/power_supply/ADP0/online 2>/dev/null) == 0 ]]; }

if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    # Going to sleep: hand the sleep inhibitor back once i3lock has grabbed the screen
    kill_i3lock() { pkill -xu "$EUID" "$@" i3lock; }
    trap kill_i3lock TERM INT
    i3lock "${opts[@]}" {XSS_SLEEP_LOCK_FD}<&-
    exec {XSS_SLEEP_LOCK_FD}<&-
    while kill_i3lock -0; do sleep 0.5; done
else
    i3lock --nofork "${opts[@]}" &
    lock_pid=$!
    (
        sleep 600
        kill -0 "$lock_pid" 2>/dev/null && on_battery && systemctl suspend
    ) &
    timer_pid=$!
    trap 'pkill -P "$timer_pid"; kill "$lock_pid" "$timer_pid" 2>/dev/null' TERM INT
    wait "$lock_pid"
    pkill -P "$timer_pid"                 # the timer's sleep
    kill "$timer_pid" 2>/dev/null
fi
rm -f "${XDG_RUNTIME_DIR:-/tmp}/lock.png"
