#!/bin/bash


REQUESTED_MODULE=mudaq
ALL_MODULES="mudaq mudaq_uio mupix_uio phys_addr cma_test dma_addr"

if [[ `whoami` != 'root' ]]; then
    echo "ERROR: you must be root to run this script" 1>&2
    exit 1
fi

# remove any existing modules
for module in ${ALL_MODULES}; do
    # extra space to search for an exact match
    if lsmod | grep "${module} " >/dev/null; then
        rmmod ${module} || exit $?
        echo "unloaded '${module}'"
    fi
done

pwd
sleep 5
insmod ./${REQUESTED_MODULE}.ko || exit $?
echo "loaded '${REQUESTED_MODULE}'"

sleep 1

chmod a+rw /dev/mudaq0*

