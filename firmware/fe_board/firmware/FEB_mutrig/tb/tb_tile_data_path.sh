#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=50ns

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity" "$entity.vhd" \
../*.vhd ../dummys/*.vhd ../../../../common/firmware/registers/*.vhd \
../../../../common/firmware/util/*.vhd ../../../fe_scitile/tile_path.vhd \
../../FEB_common/*.vhd ../mutrig_datapath/source/*.vhd ../../../fe/*.vhd \
../../../../common/firmware/util/quartus/*.vhd ../lvds/*.vhd ../framebuilder_mux/*.vhd \
../frame_rcv/*.vhd ../prbs_dec/source/*.vhd ../mutrig_types.vhd ../channelmux/vhd/channelmux.vhd \
../reset_shift/*.vhd ../../../../common/firmware/a10/link/*.vhd
