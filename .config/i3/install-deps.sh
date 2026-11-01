#!/usr/bin/env bash
# Everything this i3 setup uses on top of what Hyprland already pulled in (Ubuntu 26.04).
# Run: sudo ~/.config/i3/install-deps.sh
set -e
apt-get install -y \
    picom polybar feh xsettingsd autotiling \
    maim xclip xdotool flameshot copyq gpick \
    xserver-xephyr    # only for previewing the setup in a window from another session
