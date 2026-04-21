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

# The ETH server exposes standard Questa features such as msimhdlmix and
# mtiverification. Intel FPGA Edition binaries always boot as intelqsim* and
# cannot consume those floating features.
if printf '%s\n%s\n' "$vsim_bin" "$vsim_version" | grep -Eq 'questa_fse|questa_fe|Intel FPGA Edition|Intel Starter FPGA Edition'; then
    cat >&2 <<'EOF'
run_questa.sh: the selected vsim binary is an Intel FPGA Edition build.
It requests the intelqsim/intelqsimstarter product at runtime, while the ETH
floating server provides standard Mentor features such as msimhdlmix and
mtiverification.

Point QUESTA_HOME at a full Mentor/Questa installation to run the UVM harness.
The compile flow can still use the Intel binaries, but runtime cannot.
Use make ip-tlm-basic to build/reference vectors, and make ip-plain-basic once
a standard mixed-language Mentor runtime is available.
EOF
    exit 2
fi

if [ -d /usr/tmp ]; then
    exec "$vsim_bin" "$@"
fi

if ! command -v bwrap >/dev/null 2>&1; then
    cat >&2 <<'EOF'
run_questa.sh: /usr/tmp is missing and bubblewrap is unavailable.
Questa SALT needs /usr/tmp/.salt_mgls for its control cache on this host.
Create /usr/tmp or install bubblewrap, then rerun.
EOF
    exit 2
fi

exec bwrap \
    --share-net \
    --ro-bind /bin /bin \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --ro-bind /usr/bin /usr/bin \
    --ro-bind /usr/lib /usr/lib \
    --ro-bind /usr/lib64 /usr/lib64 \
    --ro-bind /etc /etc \
    --ro-bind /data1 /data1 \
    --ro-bind /home /home \
    --ro-bind /opt /opt \
    --bind /tmp /tmp \
    --proc /proc \
    --dev /dev \
    --symlink /tmp /usr/tmp \
    --chdir "$PWD" \
    /bin/sh -c 'exec "$@"' sh "$vsim_bin" "$@"
