#!/usr/bin/env bash
# Now playing — "  title - artist", paused in grey, hidden when nothing plays.

playerctl --follow metadata --format '{{status}}'$'\t''{{title}}'$'\t''{{artist}}' 2>/dev/null |
while IFS=$'\t' read -r status title artist; do
    text=$title${artist:+ - $artist}
    (( ${#text} > 30 )) && text="${text:0:29}…"
    case $status in
        Playing) echo "  $text" ;;
        Paused)  echo "%{F#6b7f86}  $text%{F-}" ;;
        *)       echo "" ;;
    esac
done
