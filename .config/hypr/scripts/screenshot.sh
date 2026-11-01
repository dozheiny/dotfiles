#!/usr/bin/env bash
# region-edit: select → annotate in swappy | region: select → file + clipboard | screen: focused monitor → file + clipboard

dir="$HOME/Pictures/Screenshots"
file="$dir/Screenshot From $(date '+%Y-%m-%d %H-%M-%S').png"
mkdir -p "$dir"

case $1 in
    region-edit)
        geom=$(slurp -d) || exit 0
        grim -g "$geom" - | swappy -f -
        ;;
    region)
        geom=$(slurp -d) || exit 0
        grim -g "$geom" "$file"
        ;;
    screen)
        output=$(hyprctl activeworkspace -j | jq -r .monitor)
        grim -o "$output" "$file"
        ;;
esac

if [[ -f $file ]]; then
    wl-copy <"$file"
    notify-send -a screenshot -i "$file" "Screenshot saved" "Copied to clipboard"
fi
