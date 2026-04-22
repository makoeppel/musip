#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "usage: $0 <vsim-bin> [vsim-args...]" >&2
    exit 2
fi

vsim_bin=$1
shift

if [ ! -x "$vsim_bin" ]; then
    echo "run_questa.sh: vsim binary not executable: $vsim_bin" >&2
    exit 2
fi

vsim_version=$("$vsim_bin" -version 2>&1 | head -n 1 || true)
lic_server_default=8161@lic-mentor.ethz.ch
lic_server=${SALT_LICENSE_SERVER:-${MGLS_LICENSE_FILE:-${LM_LICENSE_FILE:-$lic_server_default}}}

qsim_ini=${QSIM_INI:-}
if [ -z "$qsim_ini" ]; then
    if [ -n "${QUESTA_HOME:-}" ] && [ -f "${QUESTA_HOME}/modelsim.ini" ]; then
        qsim_ini=${QUESTA_HOME}/modelsim.ini
    else
        questa_root=$(cd "$(dirname "$vsim_bin")/.." && pwd)
        if [ -f "${questa_root}/modelsim.ini" ]; then
            qsim_ini=${questa_root}/modelsim.ini
        fi
    fi
fi

# The ETH server exposes standard Questa features such as msimhdlmix and
# mtiverification. Intel FPGA Edition binaries always boot as intelqsim* and
# cannot consume those floating features.
if printf '%s\n%s\n' "$vsim_bin" "$vsim_version" | grep -Eq 'questa_fse|questa_fe|Intel FPGA Edition|Intel Starter FPGA Edition'; then
    cat >&2 <<'EOF'
run_questa.sh: the selected vsim binary is an Intel FPGA Edition build.
It requests the intelqsim/intelqsimstarter product at runtime, while the ETH
floating server provides standard Mentor features such as msimhdlmix and
mtiverification.

Point QUESTA_HOME at the full Siemens/Mentor install for this workspace,
for example /data1/questaone_sim/questasim.
EOF
    exit 2
fi

run_env=(
    env
    "SALT_LICENSE_SERVER=$lic_server"
    "MGLS_LICENSE_FILE=$lic_server"
    "LM_LICENSE_FILE=$lic_server"
)
if [ -n "$qsim_ini" ]; then
    run_env+=("QSIM_INI=$qsim_ini")
fi

exec "${run_env[@]}" "$vsim_bin" "$@"
