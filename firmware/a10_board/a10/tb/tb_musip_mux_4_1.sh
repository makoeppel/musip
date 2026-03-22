#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
cd "$SCRIPT_DIR" || exit 1

export STOPTIME=10000000ns

entity=$(basename "$0" .sh)

../../util/sim.sh "$entity" "$entity.vhd" \
    ../chip_lookup.vhd ../swb/*.vhd \
    ../link/mu3e_pkg.vhd ../../util/util_pkg.vhd \
    ../../util/util_slv.vhd ../../../registers/mudaq.vhd \
    ../../../registers/a10_pcie_registers.vhd