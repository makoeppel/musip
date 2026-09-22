#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=10000ns

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity.vhd" \
../*.vhd ../../../../common/firmware/registers/*.vhd \
../../../../common/firmware/util/*.vhd ../../../fe/*.vhd \
../../../../common/firmware/util/quartus/*.vhd \
../sorter_common/*.vhd ../../FEB_mutrig/*.vhd \
../../../../common/firmware/a10/swb/*.vhd ../../../../common/firmware/a10/link/*.vhd \
../../../fe/util/*.vhd ../../../fe/util/quartus/*.vhd ../../../../common/firmware/a10/*.vhd
