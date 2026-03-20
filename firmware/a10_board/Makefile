#

CABLE:=DE5
CABLE_DEVICE:=^10A

IPs = \
    $(wildcard a10/ip/*.tcl) \
    $(wildcard a10/pcieapp/*.tcl) \
    $(wildcard a10/*.vhd.envsubst) \
    nios.tcl

include util/quartus/makefile.mk

flash :
	../a10_tcl/program.sh
