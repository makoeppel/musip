#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=800us

entity=$(basename "$0" .sh)

../../../../common/firmware/util/sim.sh "$entity" "$entity.vhd" ../lapse/*.vhd
