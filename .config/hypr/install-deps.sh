#!/usr/bin/env bash
# Everything this Hyprland setup uses (Ubuntu 26.04). Run: sudo ~/.config/hypr/install-deps.sh
set -e
apt-get install -y \
    hyprpaper hyprlock hypridle hyprpicker hyprpolkitagent hyprland-qtutils \
    xdg-desktop-portal-gtk \
    waybar rofi dunst kitty wlogout \
    grim slurp swappy wl-clipboard cliphist jq \
    brightnessctl playerctl pavucontrol blueman nwg-look htop \
    fonts-noto-color-emoji
