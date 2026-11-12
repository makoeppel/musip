#!/bin/sh

MODULE="mudaq"
VERSION="${MUDAQ_VERSION:-0.1.2}"
SOURCE_DIR="$(dirname "$(readlink -f "$0")")"
LOAD_AFTER_INSTALL=1

usage() {
	cat <<USAGE
Usage: $0 [--version VERSION] [--no-load]

Installs the self-contained mudaq PCIe driver as a DKMS module.

Options:
  --version VERSION  DKMS package version, default: ${VERSION}
  --no-load          Build/install but do not modprobe after install
  -h, --help         Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--version) VERSION="$2"; shift 2 ;;
		--no-load) LOAD_AFTER_INSTALL=0; shift ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

if [[ ! -d "/lib/modules/$(uname -r)/build" ]]; then
	echo "Kernel headers for the running kernel are missing: /lib/modules/$(uname -r)/build" >&2
	echo "Install your distro's kernel header/devel package, then rerun this script." >&2
	exit 1
fi

DEST="/usr/src/${MODULE}-${VERSION}"

rm -rf $DEST
mkdir -p "$DEST/dmabuf" "$DEST/registers"
for FILE in Kbuild Makefile *.c *.h */*.c */*.h; do
	install -m 0644 "$SOURCE_DIR/$FILE" "$DEST/$FILE"
done

sed "s/@VERSION@/${VERSION}/g" "$SOURCE_DIR/dkms.conf.in" > "$DEST/dkms.conf"

install -o root -g root -m 0644 "$SOURCE_DIR/99-mudaq.rules" /etc/udev/rules.d/99-mudaq.rules
udevadm control --reload-rules || true

if dkms status -m "$MODULE" -v "$VERSION" >/dev/null 2>&1; then
	dkms remove -m "$MODULE" -v "$VERSION" --all || true   
fi

dkms add -m "$MODULE" -v "$VERSION"
dkms build -m "$MODULE" -v "$VERSION"
dkms install -m "$MODULE" -v "$VERSION"

if [[ $LOAD_AFTER_INSTALL -eq 1 ]]; then
	modprobe -r "$MODULE" 2>/dev/null || true
	modprobe "$MODULE"
	udevadm trigger --subsystem-match=misc || true
fi
