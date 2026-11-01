#!/usr/bin/env bash
# Volume / brightness change + a single replacing dunst notification with a progress bar.

notify() { # icon, text, value
    notify-send -a osd -u low -t 1200 -i "$1" \
        -h string:x-dunst-stack-tag:osd -h int:value:"$3" "$2"
}

volume() {
    local out vol
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    vol=$(awk '{printf "%d", $2 * 100}' <<<"$out")
    if [[ $out == *MUTED* ]]; then
        notify audio-volume-muted-symbolic "Muted" 0
    else
        notify audio-volume-high-symbolic "Volume  $vol%" "$vol"
    fi
}

brightness() {
    local pct
    pct=$(brightnessctl -m | cut -d, -f4 | tr -d %)
    notify display-brightness-symbolic "Brightness  $pct%" "$pct"
}

case $1 in
    volume-up)       wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+; volume ;;
    volume-down)     wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-; volume ;;
    volume-mute)     wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; volume ;;
    mic-mute)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
            notify microphone-sensitivity-muted-symbolic "Microphone off" 0
        else
            notify microphone-sensitivity-high-symbolic "Microphone on" 100
        fi ;;
    brightness-up)   brightnessctl -e4 -n2 set 5%+ >/dev/null; brightness ;;
    brightness-down) brightnessctl -e4 -n2 set 5%- >/dev/null; brightness ;;
esac
