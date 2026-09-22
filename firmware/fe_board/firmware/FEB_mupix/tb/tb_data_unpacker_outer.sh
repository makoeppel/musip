#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=2515ns

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity.vhd" \
    test_data/linksel3_timerend2.vhd \
    ../../../../common/firmware/registers/mupix_registers.vhd \
    ../../../../common/firmware/registers/mudaq.vhd \
    ../../../../common/firmware/registers/mupix.vhd \
    ../../../fe/util/util_slv.vhd \
    ../../../fe/util/util_pkg.vhd \
    ../../../fe_mupix/mupix_block/data_unpacker/mapping_functions.vhd \
    ../../../fe_mupix/mupix_block/data_unpacker/hit_ts_conversion.vhd \
    ../../../fe_mupix/mupix_block/data_unpacker/data_unpacker_outer.vhd
