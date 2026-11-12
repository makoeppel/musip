#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=4us

entity=$(basename "$0" .sh)

../util/sim.sh "$entity.vhd" \
    ../sc_rx.vhd \
    ../util/*.vhd ../util/quartus/*.vhd
