#!/usr/bin/env bash
# region-edit: select → annotate in flameshot | region: select → file + clipboard | screen: focused monitor → file + clipboard

dir="$HOME/Pictures/Screenshots"
file="$dir/Screenshot From $(date '+%Y-%m-%d %H-%M-%S').png"
mkdir -p "$dir"

case $1 in
    region-edit)
        exec flameshot gui --path "$dir"
        ;;
    region)
        maim -u -s -b 3 -c 0.37,0.77,0.71,0.9 "$file" || exit 0
        ;;
    screen)
        # Monitor under the mouse
        eval "$(xdotool getmouselocation --shell)"
        geom=$(xrandr --listactivemonitors | awk -v x="$X" -v y="$Y" 'NR > 1 {
            split($3, a, /[\/x+]/)   # W/mmW x H/mmH + X + Y
            if (x >= a[5] && x < a[5] + a[1] && y >= a[6] && y < a[6] + a[3]) { print a[1] "x" a[3] "+" a[5] "+" a[6]; exit }
        }')
        maim -u ${geom:+-g "$geom"} "$file"
        ;;
esac

if [[ -f $file ]]; then
    xclip -selection clipboard -t image/png <"$file"
    notify-send -a screenshot -i "$file" "Screenshot saved" "Copied to clipboard"
fi
