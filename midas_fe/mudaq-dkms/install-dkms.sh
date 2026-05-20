#!/usr/bin/env bash
set -euo pipefail

MODULE="mudaq"
VERSION="${MUDAQ_VERSION:-0.1.1}"
LOAD_AFTER_INSTALL=1
INSTALL_AUTOLOAD=0
INSTALL_SYSTEMD=0
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<USAGE
Usage: $0 [--version VERSION] [--no-load] [--autoload] [--systemd] [--source DIR]

Installs the self-contained mudaq PCIe driver as a DKMS module.

Options:
  --version VERSION  DKMS package version, default: ${VERSION}
  --no-load          Build/install but do not modprobe after install
  --autoload         Install /etc/modules-load.d/mudaq.conf fallback autoload
  --systemd          Install and enable mudaq-load.service fallback loader
  --source DIR       Source directory; default: this package directory
  -h, --help         Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --no-load) LOAD_AFTER_INSTALL=0; shift ;;
        --autoload) INSTALL_AUTOLOAD=1; shift ;;
        --systemd) INSTALL_SYSTEMD=1; shift ;;
        --source) SOURCE_DIR="$(cd "$2" && pwd)"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ ${EUID} -ne 0 ]]; then
    exec sudo -E bash "$0" \
        --version "$VERSION" \
        $([[ $LOAD_AFTER_INSTALL -eq 0 ]] && echo --no-load) \
        $([[ $INSTALL_AUTOLOAD -eq 1 ]] && echo --autoload) \
        $([[ $INSTALL_SYSTEMD -eq 1 ]] && echo --systemd) \
        --source "$SOURCE_DIR"
fi

for cmd in dkms make sed install cp depmod modprobe udevadm; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }
done

if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
    echo "Kernel headers for the running kernel are missing: /lib/modules/$(uname -r)/build" >&2
    echo "Install your distro's kernel header/devel package, then rerun this script." >&2
    exit 1
fi

required_files=(
    "mudaq.c"
    "mudaq.h"
    "mudaq_fops.h"
    "Kbuild"
    "Makefile"
    "dkms.conf.in"
    "99-mudaq.rules"
    "dmabuf/dmabuf.h"
    "dmabuf/dmabuf_fops.h"
    "dmabuf/module.h"
    "registers.h"
    "registers/a10_counters.h"
    "registers/a10_pcie_registers.h"
    "registers/feb_sc_registers.h"
    "registers/lvds_registers.h"
    "registers/mupix_registers.h"
    "registers/mutrig_registers.h"
    "registers/sorter_registers.h"
)

missing=0
for rel in "${required_files[@]}"; do
    if [[ ! -f "$SOURCE_DIR/$rel" ]]; then
        echo "Missing required source file: $SOURCE_DIR/$rel" >&2
        missing=1
    fi
done
if [[ $missing -ne 0 ]]; then
    echo "This DKMS package must be self-contained before installation." >&2
    exit 1
fi

DEST="/usr/src/${MODULE}-${VERSION}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/dmabuf" "$TMP/registers"
for rel in "${required_files[@]}"; do
    install -m 0644 "$SOURCE_DIR/$rel" "$TMP/$rel"
done

# Normalize legacy upstream source layout, if someone supplies an older source tree.
sed -i 's|#include "../registers.h"|#include "registers.h"|' "$TMP/mudaq.c"

sed "s/@VERSION@/${VERSION}/g" "$SOURCE_DIR/dkms.conf.in" > "$TMP/dkms.conf"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$TMP"/. "$DEST"/

install -o root -g root -m 0644 "$DEST/99-mudaq.rules" /etc/udev/rules.d/99-mudaq.rules
udevadm control --reload-rules || true

if [[ $INSTALL_AUTOLOAD -eq 1 ]]; then
    install -o root -g root -m 0644 "$SOURCE_DIR/mudaq.conf.modules-load" /etc/modules-load.d/mudaq.conf
fi

if [[ $INSTALL_SYSTEMD -eq 1 ]]; then
    install -o root -g root -m 0644 "$SOURCE_DIR/mudaq-load.service" /etc/systemd/system/mudaq-load.service
    systemctl daemon-reload
    systemctl enable mudaq-load.service
fi

if dkms status -m "$MODULE" -v "$VERSION" >/dev/null 2>&1; then
    dkms remove -m "$MODULE" -v "$VERSION" --all || true
fi

dkms add -m "$MODULE" -v "$VERSION"
dkms build -m "$MODULE" -v "$VERSION"
dkms install -m "$MODULE" -v "$VERSION"
depmod -a

if [[ $LOAD_AFTER_INSTALL -eq 1 ]]; then
    modprobe -r "$MODULE" 2>/dev/null || true
    modprobe "$MODULE"
    udevadm trigger --subsystem-match=misc || true
fi

echo "Installed ${MODULE}/${VERSION} with DKMS."
echo "Check: dkms status -m ${MODULE}; modinfo ${MODULE}; ls -l /dev/mudaq*"
