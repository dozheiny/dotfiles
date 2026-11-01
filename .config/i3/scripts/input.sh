#!/usr/bin/env bash
# Keyboard: EN/FA on Super+Space, fast repeat. Touchpad: tap, natural scroll, no typing palms.

setxkbmap -layout us,ir -option '' -option grp:win_space_toggle
xset r rate 300 40

xinput list --name-only | grep -i touchpad | sort -u | while read -r dev; do
    set_prop() { xinput set-prop "pointer:$dev" "$@" 2>/dev/null; }
    set_prop "libinput Tapping Enabled" 1
    set_prop "libinput Natural Scrolling Enabled" 1
    set_prop "libinput Disable While Typing Enabled" 1
    set_prop "libinput Click Method Enabled" 0 1         # clickfinger
    set_prop "libinput Scrolling Pixel Distance" 25      # ~0.6 scroll factor
done
