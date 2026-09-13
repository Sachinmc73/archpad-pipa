#!/bin/sh
# ArchPad pipa: Suspend/resume hook for Snapdragon Sensor Core (FastRPC)
# Installed to /usr/lib/systemd/system-sleep/10-archpad-sensors.sh

case "$1/$2" in
    pre/*)
        # Pre-suspend: Stop iio-sensor-proxy so FastRPC sensor streams
        # are cleanly closed before the host freezes and remoteproc sleeps.
        systemctl stop iio-sensor-proxy.service 2>/dev/null || true
        ;;
    post/*)
        # Post-resume: Clear any failed state and restart sensor proxy asynchronously
        systemctl reset-failed iio-sensor-proxy.service 2>/dev/null || true
        systemctl restart --no-block iio-sensor-proxy.service 2>/dev/null || systemctl start --no-block iio-sensor-proxy.service 2>/dev/null || true
        ;;
esac
