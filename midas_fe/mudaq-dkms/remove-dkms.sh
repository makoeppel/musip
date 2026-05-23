#!/usr/bin/env bash
set -euo pipefail
MODULE="mudaq"
VERSION="${MUDAQ_VERSION:-0.1.1}"

if [[ ${EUID} -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

modprobe -r "$MODULE" 2>/dev/null || true
dkms remove -m "$MODULE" -v "$VERSION" --all || true
rm -rf "/usr/src/${MODULE}-${VERSION}"
rm -f /etc/udev/rules.d/99-mudaq.rules /etc/modules-load.d/mudaq.conf
udevadm control --reload-rules || true
depmod -a || true

echo "Removed ${MODULE}/${VERSION}."
