#!/usr/bin/env bash
# (Re)start polybar: the bar with the tray on the primary screen, a plain one everywhere else.

pkill -x polybar
# tail scripts (mpris) outlive polybar; stop them too or they pile up on every restart
pkill -f "$HOME/.config/polybar/scripts/"
pkill -f '~/.config/polybar/scripts/'
pkill -f 'playerctl --follow metadata --format'
while pgrep -x polybar >/dev/null; do sleep 0.1; done

primary=$(xrandr --query | awk '/ connected primary/ {print $1; exit}')
for m in $(polybar --list-monitors | cut -d: -f1); do
    bar=secondary
    [[ $m == "${primary:-$m}" ]] && { bar=main; primary=$m; }
    MONITOR=$m polybar --reload "$bar" >/dev/null 2>&1 &
done
disown -a
