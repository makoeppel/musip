#!/usr/bin/env bash

set -euo pipefail

questa_home=${QUESTA_HOME:-/data1/intelFPGA_pro/23.1/questa_fe}
lic_server_default=8161@129.132.148.195
lic_server=${MGLS_LICENSE_FILE:-$lic_server_default}
mgls_ok="$questa_home/linux_x86_64/mgls_ok"

if [ ! -x "$mgls_ok" ]; then
    echo "check_questa_license.sh: missing mgls_ok under $questa_home" >&2
    exit 2
fi

echo "Checking ETH Questa features via $mgls_ok"
echo "License source: $lic_server"

env -u SALT_LICENSE_SERVER MGLS_LICENSE_FILE="$lic_server" "$mgls_ok" msimhdlsim
env -u SALT_LICENSE_SERVER MGLS_LICENSE_FILE="$lic_server" "$mgls_ok" msimhdlmix
env -u SALT_LICENSE_SERVER MGLS_LICENSE_FILE="$lic_server" "$mgls_ok" mtiverification
