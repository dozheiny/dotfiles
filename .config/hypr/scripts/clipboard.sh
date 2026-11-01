#!/usr/bin/env bash
# Clipboard history picker
cliphist list | rofi -dmenu -p "clipboard" -display-columns 2 | cliphist decode | wl-copy
