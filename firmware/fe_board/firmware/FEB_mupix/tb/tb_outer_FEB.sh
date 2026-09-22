#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=500ns

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity.vhd" \
../*.vhd ../../../../common/firmware/registers/*.vhd \
../../../fe_mupix/*.vhd \
../../../fe_mupix/mupix_block/comp_type_const/*.vhd \
../../../fe_mupix/mupix_block/data_unpacker/*.vhd \
../../../fe_mupix/mupix_block/receiver_block/*.vhd \
../../../fe_mupix/mupix_block/slowcontrol/*.vhd \
../../../fe_mupix/mupix_block/sorter/*.vhd \
../../../fe_mupix/mupix_block/*.vhd \
../../FEB_common/*.vhd ../../../fe/*.vhd \
../../../../common/firmware/util/quartus/*.vhd \
../../FEB_common/sorter_common/*.vhd ../../FEB_common/sorter_common/*.vhd \
../../FEB_common/lvds/*.vhd \
../../FEB_mutrig/*.vhd \
../../../../common/firmware/a10/swb/*.vhd ../../../../common/firmware/a10/link/*.vhd \
../../../fe/util/*.vhd ../../../fe/util/quartus/*.vhd ../../../../common/firmware/a10/*.vhd
