#!/bin/sh
set -eu
IFS="$(printf '\n\t')"
unset CDPATH
cd "$(dirname -- "$(readlink -e -- "$0")")" || exit 1

export STOPTIME=1000us

TB_VHD_FILE="$1"

./firmware/util/sim.sh "mupix_ctrl_tb" "TB_VHD_FILE" \
    firmware/util/*.vhd firmware/util/quartus/*.vhd \
    firmware/registers/*.vhd \
    ../mupix_ctrl.vhd ../../comp_type_const/mupix_ctrl_reg_mapping.vhd ../mupix_ctrl_config_storage.vhd
