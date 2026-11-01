#!/usr/bin/env bash
# Decides whether the laptop panel is on, from what is connected right now:
#   LG connected (home)             → LG only
#   lid closed + any other external → that external only (clamshell)
#   otherwise                       → panel on, next to any external (work desk)
#
#   monitors.sh          apply once (lid switch)
#   monitors.sh --watch  apply, then again on every hotplug/config reload (exec-once)
#
# Hotplug must not depend on event payloads: toggling the panel fires events itself,
# and a config reload re-enables it through the monitor rule in hyprland.conf.

home_monitor=${HOME_MONITOR:-"LG Electronics LG ULTRAGEAR 307NTJJ33116"}
panel_rule="eDP-1, 2880x1620@120, 0x0, 1.5"
runtime=$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE

apply() {
    local lid disabled off
    read -r _ lid < <(cat /proc/acpi/button/lid/*/state)
    read -r disabled off < <(hyprctl monitors all -j | jq -r --arg home "$home_monitor" --arg lid "$lid" '
        map(select(.name != "eDP-1" and (.disabled | not))) as $external
        | [(.[] | select(.name == "eDP-1") | .disabled),
           (any($external[]; .description == $home) or ($lid == "closed" and ($external | length) > 0))]
        | @tsv')

    [[ $disabled == "$off" ]] && return
    if [[ $off == true ]]; then
        hyprctl keyword monitor "eDP-1, disable"
        # waybar hangs for good (40% CPU, and as much in Hyprland) if an output goes
        # away while it maps a bar there, which the config reload flash always does
        pkill -x waybar && hyprctl dispatch exec waybar
    else
        hyprctl keyword monitor "$panel_rule"
    fi
}

if [[ $1 == --watch ]]; then
    exec 9> "$runtime/monitors.lock"
    flock -n 9 || exit 0

    nc -dU "$runtime/.socket2.sock" | {
        apply
        while read -r event; do
            case $event in
                monitoradded*|monitorremoved*|configreloaded*) apply ;;
            esac
        done
    }
else
    apply
fi
