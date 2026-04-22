#!/usr/bin/env bash

set -euo pipefail

questa_home=${QUESTA_HOME:-/data1/questaone_sim/questasim}
source_vhdl_lib_root=${INTEL_FE_VHDL_LIB_ROOT:-/data1/intelFPGA_pro/23.1/questa_fe/questa_fe/intel/vhdl}
dest_vhdl_lib_root=${INTEL_QUESTA_VHDL_LIB_ROOT:-$questa_home/intel_2026/vhdl}
libs=(220model altera sgate altera_mf)

vcom_bin=${VCOM_BIN:-}
if [ -z "$vcom_bin" ]; then
    for candidate in "$questa_home/bin/vcom" "$questa_home/linux_x86_64/vcom"; do
        if [ -x "$candidate" ]; then
            vcom_bin=$candidate
            break
        fi
    done
fi

if [ -z "${vcom_bin:-}" ] || [ ! -x "$vcom_bin" ]; then
    echo "refresh_questa_intel_libs.sh: missing vcom under $questa_home" >&2
    exit 2
fi

if [ ! -d "$source_vhdl_lib_root" ]; then
    echo "refresh_questa_intel_libs.sh: missing Intel source library root: $source_vhdl_lib_root" >&2
    exit 2
fi

if [ ! -d "$questa_home/intel/vhdl/src" ]; then
    cat >&2 <<EOF
refresh_questa_intel_libs.sh: missing $questa_home/intel/vhdl/src

The refreshed libraries load Quartus source files through \$MODEL_TECH/../intel/vhdl/src.
Create that source tree or symlink it before refreshing.
EOF
    exit 2
fi

tmp_ini=$(mktemp /tmp/questa_intel_refresh.XXXXXX)
trap 'rm -f "$tmp_ini"' EXIT

cp "$questa_home/modelsim.ini" "$tmp_ini"
perl -0pi -e "
  s#^std = .*#std = $questa_home/std#m;
  s#^ieee = .*#ieee = $questa_home/ieee#m;
  s#^vital2000 = .*#vital2000 = $questa_home/vital2000#m;
  s#^std_developerskit = .*#std_developerskit = $questa_home/std_developerskit#m;
  s#^synopsys = .*#synopsys = $questa_home/synopsys#m;
  s#^modelsim_lib = .*#modelsim_lib = $questa_home/modelsim_lib#m;
  s#^sv_std = .*#sv_std = $questa_home/sv_std#m;
  s#^mgc_ams = .*#mgc_ams = $questa_home/mgc_ams#m;
  s#^ieee_env = .*#ieee_env = $questa_home/ieee_env#m;
  s#^vh_flcov_lib = .*#vh_flcov_lib = $questa_home/vh_flcov_lib#m;
  s#^vhdlopt_lib = .*#vhdlopt_lib = $questa_home/vhdlopt_lib#m;
  s#^vh_ux01v_lib = .*#vh_ux01v_lib = $questa_home/vh_ux01v_lib#m;
  s#^altera_mf = .*#altera_mf = $dest_vhdl_lib_root/altera_mf#m;
  s#^altera = .*#altera = $dest_vhdl_lib_root/altera#m;
  s#^lpm = .*#lpm = $dest_vhdl_lib_root/220model#m;
  s#^220model = .*#220model = $dest_vhdl_lib_root/220model#m;
  s#^sgate = .*#sgate = $dest_vhdl_lib_root/sgate#m;
" "$tmp_ini"

mkdir -p "$dest_vhdl_lib_root"

export QSIM_INI="$tmp_ini"
for lib in "${libs[@]}"; do
    rm -rf "$dest_vhdl_lib_root/$lib"
    cp -a "$source_vhdl_lib_root/$lib" "$dest_vhdl_lib_root/"
    "$vcom_bin" -refresh -work "$dest_vhdl_lib_root/$lib"
done

cat <<EOF
Refreshed Intel VHDL libraries under:
  $dest_vhdl_lib_root

Use these logical mappings in $questa_home/modelsim.ini:
  altera_mf = \$QUESTASIM_DIR/../intel_2026/vhdl/altera_mf
  altera    = \$QUESTASIM_DIR/../intel_2026/vhdl/altera
  lpm       = \$QUESTASIM_DIR/../intel_2026/vhdl/220model
  220model  = \$QUESTASIM_DIR/../intel_2026/vhdl/220model
  sgate     = \$QUESTASIM_DIR/../intel_2026/vhdl/sgate
EOF
