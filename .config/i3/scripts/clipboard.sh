#!/usr/bin/env bash
# Clipboard history picker (copyq keeps the history, rofi shows it)
items=$(copyq eval -- '
    for (var i = 0; i < Math.min(size(), 100); ++i)
        print(i + "\t" + str(read(i)).replace(/\s+/g, " ").trim().substring(0, 120) + "\n")')
[[ -z $items ]] && exit 0
pick=$(rofi -dmenu -i -p "" -config ~/.config/rofi/i3.rasi -display-columns 2 -display-column-separator '\t' <<<"$items") || exit 0
copyq select "${pick%%$'\t'*}"
