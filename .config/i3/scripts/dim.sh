#!/usr/bin/env bash
# xss-lock notifier: dim until activity (or until the locker starts), then restore.
brightnessctl -q -s set 10%
trap 'brightnessctl -q -r; kill %% 2>/dev/null; exit 0' TERM INT
sleep infinity &
wait
