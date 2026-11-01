#!/usr/bin/env bash
# Pick a color anywhere on screen → hex to clipboard
hex=$(gpick -s -o --no-newline 2>/dev/null) || exit 0
[[ -z $hex ]] && exit 0
printf %s "$hex" | xclip -selection clipboard
notify-send -a colorpick -u low "Color copied" "$hex"
