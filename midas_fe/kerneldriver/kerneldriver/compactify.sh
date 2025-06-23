#!/bin/bash
cat /proc/buddyinfo
printf "\n\n"
echo 1 > /proc/sys/vm/compact_memory
printf "\n\n"
sleep 1
cat /proc/buddyinfo
