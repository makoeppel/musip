#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=20ns

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity.vhd" \
../*.vhd ../dummys/*.vhd ../../../../common/firmware/registers/*.vhd \
../../../../common/firmware/util/*.vhd ../../../fe_scifi/scifi_path.vhd \
../../FEB_common/*.vhd ../mutrig_datapath/source/*.vhd ../../../fe/*.vhd \
../../../../common/firmware/util/quartus/*.vhd ../framebuilder_mux/*.vhd \
../frame_rcv/*.vhd ../prbs_dec/source/*.vhd ../../FEB_common/lvds/*.vhd \
../../../fe_scifi/scifi_path.vhd ../lapse/vhd/*.vhd \
../CC_recalculation/vhd/*.vhd ../../FEB_common/sorter_common/*.vhd ../../FEB_common/sorter_common/*.vhd \
../channelmux/vhd/*.vhd ../lvds/*.vhd \
../../../../common/firmware/a10/swb/*.vhd ../../../../common/firmware/a10/link/*.vhd \
../../../fe/util/*.vhd ../../../fe/util/quartus/*.vhd ../../../../common/firmware/a10/*.vhd
