#!/usr/bin/env bash
# Laptop panel at 2880x1620@120. Any external screen: best mode, above the laptop,
# drawn at 1.5x so UI looks the same size as on Hyprland (scale 1 there, DPI is global on X11).
# Lid closed with an external screen → laptop panel off.
# Afterwards: wallpaper + bar on every screen.

EXTERNAL_SCALE=1.5   # set to 1 for native pixels (UI will look 1.5x bigger)

xr=$(xrandr)
internal=$(awk '/^eDP/ {print $1; exit}' <<<"$xr")
external=$(awk '/ connected/ && $1 !~ /^eDP/ {print $1; exit}' <<<"$xr")
lid=${LID_STATE:-$(awk '{print $2}' /proc/acpi/button/lid/*/state 2>/dev/null | head -1)}   # LID_STATE: for testing

args=()
# Turn off anything that's gone (keeps xrandr from leaving ghost screens)
for out in $(awk '/ disconnected/ {print $1}' <<<"$xr"); do args+=(--output "$out" --off); done

if [[ -n $external ]]; then
    # preferred resolution at its highest refresh rate (many monitors mark 60 Hz as preferred)
    read -r ext_mode ext_rate < <(awk -v out="$external" '
        $1 == out { inblock = 1; next }
        inblock && /^[^ ]/ { exit }
        inblock && /\+/ { best = 0; for (i = 2; i <= NF; i++) { r = $i; gsub(/[*+]/, "", r); if (r + 0 > best) best = r + 0 } print $1, best; exit }
    ' <<<"$xr")
    args+=(--output "$external")
    if [[ -n $ext_mode ]]; then args+=(--mode "$ext_mode" --rate "$ext_rate"); else args+=(--auto); fi
    args+=(--scale "${EXTERNAL_SCALE}x${EXTERNAL_SCALE}" --primary)
    if [[ $lid == closed ]]; then
        args+=(--output "$internal" --off)
    else
        args+=(--output "$internal" --mode 2880x1620 --rate 120 --scale 1x1 --below "$external")
    fi
else
    args+=(--output "$internal" --mode 2880x1620 --rate 120 --pos 0x0 --primary --scale 1x1)
fi

xrandr "${args[@]}" || xrandr --output "$internal" --auto --primary   # fallback if 120 Hz is refused

feh --no-fehbg --bg-fill ~/Pictures/Wallpapers/osselo-Ask_a_friend.jpg
~/.config/polybar/launch.sh
