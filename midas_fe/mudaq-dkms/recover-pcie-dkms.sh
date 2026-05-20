#!/usr/bin/env bash
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

DEVICE="$(lspci -Dnnd 1172:0004 | awk '{print $1; exit}')"
if [[ -n "${DEVICE}" && -e "/sys/bus/pci/devices/${DEVICE}/remove" ]]; then
    modprobe -r mudaq 2>/dev/null || true
    echo 1 > "/sys/bus/pci/devices/${DEVICE}/remove"
    sleep 1
fi

echo 1 > /sys/bus/pci/rescan
sleep 1
modprobe mudaq
udevadm trigger --subsystem-match=misc || true
ls -l /dev/mudaq* 2>/dev/null || true
