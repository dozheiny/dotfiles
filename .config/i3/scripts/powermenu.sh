#!/usr/bin/env bash
# Lock / logout / suspend / reboot / shutdown — rofi version of wlogout

options=$'  Lock\n  Logout\n  Suspend\n  Reboot\n  Shutdown'
choice=$(rofi -dmenu -i -p "" -config ~/.config/rofi/i3.rasi \
    -theme-str 'window { width: 420px; } listview { lines: 5; } inputbar { enabled: false; } element-text { font: "JetBrainsMono Nerd Font 12"; }' <<<"$options") || exit 0

case ${choice##* } in
    Lock)     loginctl lock-session ;;
    Logout)   i3-msg exit ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
