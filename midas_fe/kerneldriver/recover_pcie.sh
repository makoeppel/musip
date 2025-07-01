#!/bin/sh

device=$(lspci -nn | grep "\[1172:0004\]" | cut -d" " -f1)
if [[ ! -f /sys/bus/pci/devices/0000\:$device/config ]]
then
    echo "PCIE configuration device file $file does not exist, something is wrong"
else
    echo 1 > /sys/bus/pci/devices/0000:$device/remove
    sleep 1
fi

echo 1 > /sys/bus/pci/rescan
sleep 1
./load_mudaq.sh

