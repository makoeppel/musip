#!/bin/bash

FW=../../../../common/firmware

"$FW"/util/sim.sh "$0" ./*.vhd ../*.vhd \
    "$FW"/util/*.vhd \
    "$FW"/registers/*.vhd
