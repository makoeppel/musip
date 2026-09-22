#

CABLE_DEVICE ?= ^5A
TAG := $(shell date +%Y%m%d_%H%M%S)_$(shell git rev-parse --short=8 HEAD)_$(shell basename -- $(PWD))

IPs := \
    ../fe/ip/clk_ctrl_single.tcl \
    $(wildcard ../fe/a5/*.vhd.qmegawiz) \
    nios.tcl

include util/quartus/makefile.mk

$(BUILD_DIR)/output_files/top.rbf : $(SOF)
	quartus_cpf -o bitstream_compression=on --convert $< $@

rbf : $(BUILD_DIR)/output_files/top.rbf
	if [ -e "../../online/userfiles/firmware" ] ; then
	    cp -- "$(BUILD_DIR)/output_files/top.rbf" \
	        ../../online/userfiles/firmware/$(TAG)_top.rbf
	    git diff > ../../online/userfiles/firmware/$(TAG).diff
	fi

GENERATED := ../../registers

$(GENERATED)/%.h : ../../registers/%.vhd
	mkdir -p -- $(GENERATED)
	../../registers/makeheader.py $< $@

$(APP_DIR)/main.elf : \
    $(GENERATED)/lvds_registers.h \
    $(GENERATED)/feb_sc_registers.h \
    $(GENERATED)/mupix_registers.h \
    $(GENERATED)/mutrig_registers.h \
    $(GENERATED)/sorter_registers.h

# with running make print-VARIABLE the content can be printed
print-% : ; @echo $* = $($*)

# always build nios
flow :: app
