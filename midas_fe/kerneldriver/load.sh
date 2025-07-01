# unload any existing drivers and load the given modules afterwards

REQUESTED_MODULE=$1
ALL_MODULES="mudaq mudaq_uio mupix_uio phys_addr cma_test"

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

# load the requested modules
if [[ ${REQUESTED_MODULE} == *uio ]]; then
    modprobe uio || exit $?
    echo "loaded 'uio'"
fi
insmod ./${REQUESTED_MODULE}.ko || exit $?
echo "loaded '${REQUESTED_MODULE}'"

chmod a+xrw /dev/uio0
echo "Changed permissions of /dev/uio0 -> everyone can read and execute"
