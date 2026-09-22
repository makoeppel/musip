#

CABLE?=USB
CABLE_DEVICE:=^10M

IPs = \
    nios.tcl \
    adc.tcl

include util/quartus/makefile.mk

.PHONY : pof
pof : $(POF)

.PHONY : pgm_pof
pgm_pof : $(POF)
	CABLE=$$($(call find_file,jtagconfig_match.sh) "$(CABLE)" "$(CABLE_DEVICE)")
	quartus_pgm --cable "$$CABLE" --mode jtag --operation="p;$(POF)"
