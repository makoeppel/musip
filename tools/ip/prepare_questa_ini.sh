#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <questa-home> <output-ini>" >&2
    exit 2
fi

questa_home=$1
output_ini=$2
intel_vhdl_root=${INTEL_QUESTA_VHDL_LIB_ROOT:-"$questa_home/intel_2026/vhdl"}
intel_verilog_root=${INTEL_QUESTA_VERILOG_LIB_ROOT:-"$questa_home/intel/verilog"}

if [ ! -f "$questa_home/modelsim.ini" ]; then
    echo "prepare_questa_ini.sh: missing $questa_home/modelsim.ini" >&2
    exit 2
fi

for lib in altera_mf altera 220model sgate; do
    if [ ! -d "$intel_vhdl_root/$lib" ]; then
        echo "prepare_questa_ini.sh: missing refreshed Intel library: $intel_vhdl_root/$lib" >&2
        exit 2
    fi
done

for lib in altera_mf 220model; do
    if [ ! -d "$intel_verilog_root/$lib" ]; then
        echo "prepare_questa_ini.sh: missing Intel Verilog library: $intel_verilog_root/$lib" >&2
        exit 2
    fi
done

mkdir -p "$(dirname "$output_ini")"
cp "$questa_home/modelsim.ini" "$output_ini"

perl -0pi -e '
  s#^altera_mf\s*=.*#altera_mf = \$QUESTASIM_DIR/../intel_2026/vhdl/altera_mf#m;
  s#^altera\s*=.*#altera = \$QUESTASIM_DIR/../intel_2026/vhdl/altera#m;
  s#^lpm\s*=.*#lpm = \$QUESTASIM_DIR/../intel_2026/vhdl/220model#m;
  s#^220model\s*=.*#220model = \$QUESTASIM_DIR/../intel_2026/vhdl/220model#m;
  s#^sgate\s*=.*#sgate = \$QUESTASIM_DIR/../intel_2026/vhdl/sgate#m;
  s#^altera_mf_ver\s*=.*#altera_mf_ver = \$QUESTASIM_DIR/../intel/verilog/altera_mf#m;
  s#^lpm_ver\s*=.*#lpm_ver = \$QUESTASIM_DIR/../intel/verilog/220model#m;
  s#^220model_ver\s*=.*#220model_ver = \$QUESTASIM_DIR/../intel/verilog/220model#m;
  s#^work\s*=.*#work = work#m;
' "$output_ini"
