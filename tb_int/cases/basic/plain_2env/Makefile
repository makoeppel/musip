SHELL := /usr/bin/env bash

ROOT := $(abspath ../../../..)
BUILD_DIR := $(CURDIR)/work
REPORT_DIR := $(CURDIR)/report
REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out)
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
VLIB := $(QUESTA_HOME)/bin/vlib
VCOM := $(QUESTA_HOME)/bin/vcom
VLOG := $(QUESTA_HOME)/bin/vlog
VSIM := $(QUESTA_HOME)/bin/vsim
QUESTA_RUNNER := $(ROOT)/tools/ip/run_questa.sh
ETH_LIC_SERVER ?= 8161@129.132.148.195
SV_LIB := $(abspath $(BUILD_DIR))/libswb_opq_2env_dpi

export MGLS_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export LM_LICENSE_FILE ?= $(MGLS_LICENSE_FILE)

VHDL_SOURCES = \
	$(ROOT)/firmware/util/util_pkg.vhd \
	$(ROOT)/firmware/util/util_slv.vhd \
	$(ROOT)/firmware/util/fifo_reg.vhd \
	$(ROOT)/firmware/util/quartus/ip_ram_2rw.vhd \
	$(ROOT)/firmware/util/quartus/ip_scfifo_v2.vhd \
	$(ROOT)/firmware/registers/mudaq.vhd \
	$(ROOT)/firmware/registers/a10_pcie_registers.vhd \
	$(ROOT)/firmware/a10_board/a10/link/mu3e_pkg.vhd \
	$(ROOT)/firmware/a10_board/a10/chip_lookup.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/hit_compactor.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/word_rate.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/mux_4_1_256.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/subtime_merger.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_event_builder.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_mux_4_1.vhd \
	$(CURDIR)/dut/swb_datapath_2env_wrapper.vhd

SV_SOURCES = \
	$(CURDIR)/sv/interfaces.sv \
	$(UVM_HOME)/src/uvm_pkg.sv \
	$(CURDIR)/sv/swb_2env_pkg.sv \
	$(CURDIR)/sv/tb_top_2env.sv

SV_INCLUDE_SOURCES = \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_types.sv \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_sequences.sv \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv \
	$(CURDIR)/sv/swb_2env_agents.sv \
	$(CURDIR)/sv/swb_2env_env.sv \
	$(CURDIR)/sv/swb_2env_test.sv

C_SOURCES = \
	$(CURDIR)/dpi/swb_opq_2env_dpi.c

UVM_DEFINES ?= +define+UVM_NO_DPI
SIM_ARGS ?=

.PHONY: compile run clean

compile: $(BUILD_DIR)/.compile-stamp

$(BUILD_DIR)/.compile-stamp: $(VHDL_SOURCES) $(SV_SOURCES) $(SV_INCLUDE_SOURCES) $(C_SOURCES)
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	gcc -O2 -fPIC -shared -o $(SV_LIB).so $(C_SOURCES)
	cd $(BUILD_DIR) && $(VLIB) work
	cd $(BUILD_DIR) && set -e; for file in $(VHDL_SOURCES); do $(VCOM) -2008 $$file; done
	cd $(BUILD_DIR) && $(VLOG) -sv $(UVM_DEFINES) +incdir+$(UVM_HOME)/src +incdir+$(CURDIR)/sv $(SV_SOURCES)
	touch $@

run: compile
	mkdir -p $(REPORT_DIR)
	cd $(BUILD_DIR) && set -o pipefail; \
	$(QUESTA_RUNNER) $(VSIM) -c -L altera_mf -sv_lib $(SV_LIB) tb_top_2env +SWB_REPLAY_DIR=$(REPLAY_DIR) -do "run -all; quit -f" $(SIM_ARGS) | tee "$(REPORT_DIR)/run_plain_basic_2env.log"

clean:
	rm -rf $(BUILD_DIR) $(REPORT_DIR)
