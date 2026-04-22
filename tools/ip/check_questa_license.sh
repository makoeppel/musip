#!/usr/bin/env bash

set -euo pipefail

shopt -s nullglob

questa_home=${QUESTA_HOME:-/data1/questaone_sim/questasim}
lic_server_default=8161@lic-mentor.ethz.ch
lic_server=${SALT_LICENSE_SERVER:-${MGLS_LICENSE_FILE:-${LM_LICENSE_FILE:-$lic_server_default}}}
mgls_ok=

for candidate in \
    "$questa_home"/linux_x86_64/mgls_ok \
    "$questa_home"/QPS_*/linux_x86_64/bin/mgls_ok \
    "$questa_home"/QPS_*/linux/bin/mgls_ok
do
    if [ -x "$candidate" ]; then
        mgls_ok=$candidate
        break
    fi
done

if [ -z "$mgls_ok" ]; then
    echo "check_questa_license.sh: missing mgls_ok under $questa_home" >&2
    exit 2
fi

echo "Checking ETH Questa features via $mgls_ok"
echo "License source: $lic_server"

env \
    SALT_LICENSE_SERVER="$lic_server" \
    MGLS_LICENSE_FILE="$lic_server" \
    LM_LICENSE_FILE="$lic_server" \
    "$mgls_ok" msimhdlsim
env \
    SALT_LICENSE_SERVER="$lic_server" \
    MGLS_LICENSE_FILE="$lic_server" \
    LM_LICENSE_FILE="$lic_server" \
    "$mgls_ok" msimhdlmix
env \
    SALT_LICENSE_SERVER="$lic_server" \
    MGLS_LICENSE_FILE="$lic_server" \
    LM_LICENSE_FILE="$lic_server" \
    "$mgls_ok" mtiverification
