#!/usr/bin/env bash
# Bluetooth: grey when off, accent + device name when connected.

if ! bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
    echo "%{F#6b7f86}%{F-}"
    exit
fi
device=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
if [[ -n $device ]]; then
    echo "%{F#5ec4b6}%{F-}  ${device:0:18}"
else
    echo ""
fi
