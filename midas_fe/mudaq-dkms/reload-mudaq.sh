#!/usr/bin/env bash
set -euo pipefail
if [[ ${EUID} -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi
modprobe -r mudaq 2>/dev/null || true
modprobe mudaq
udevadm trigger --subsystem-match=misc || true
ls -l /dev/mudaq* 2>/dev/null || true
