#!/usr/bin/env bash
set -euo pipefail

MODULE="mudaq"
PCI_ID="1172:0004"

echo "== DKMS =="
dkms status -m "$MODULE" || true

echo
echo "== Module info =="
modinfo "$MODULE" 2>/dev/null | sed -n '1,80p' || echo "modinfo failed; module may not be installed yet"

echo
echo "== Loaded module =="
lsmod | grep -E "^${MODULE}\b" || echo "${MODULE} is not currently loaded"

echo
echo "== Matching PCI devices =="
lspci -Dnnd "$PCI_ID" || echo "No PCI device matching ${PCI_ID} was found"

echo
echo "== Device nodes =="
ls -l /dev/mudaq* 2>/dev/null || echo "No /dev/mudaq* nodes found"

echo
echo "== Recent kernel messages =="
dmesg | grep -iE "mudaq|1172|0004|pcie|dma" | tail -n 80 || true
