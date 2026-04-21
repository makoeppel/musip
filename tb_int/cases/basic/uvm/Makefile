SHELL := /usr/bin/env bash

ROOT := $(abspath ../../../..)
BUILD_DIR := $(CURDIR)/work
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
VLIB := $(QUESTA_HOME)/bin/vlib
VCOM := $(QUESTA_HOME)/bin/vcom
VLOG := $(QUESTA_HOME)/bin/vlog
VSIM := $(QUESTA_HOME)/bin/vsim
QUESTA_RUNNER := $(ROOT)/tools/ip/run_questa.sh
ETH_LIC_SERVER ?= 8161@129.132.148.195

export MGLS_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export LM_LICENSE_FILE ?= $(MGLS_LICENSE_FILE)

VHDL_SOURCES = \
	$(ROOT)/firmware/util/util_pkg.vhd \
	$(ROOT)/firmware/util/util_slv.vhd \
	$(ROOT)/firmware/util/fifo_reg.vhd \
	$(ROOT)/firmware/util/quartus/ip_ram_2rw.vhd \
	$(ROOT)/firmware/util/quartus/ip_scfifo_v2.vhd \
	$(ROOT)/firmware/util/histogram_generic_half_rate.vhd \
	$(ROOT)/firmware/registers/mudaq.vhd \
	$(ROOT)/firmware/registers/a10_pcie_registers.vhd \
	$(ROOT)/firmware/registers/a10_counters.vhd \
	$(ROOT)/firmware/a10_board/a10/link/mu3e_pkg.vhd \
	$(ROOT)/firmware/a10_board/a10/link/link32_scfifo.vhd \
	$(ROOT)/firmware/a10_board/a10/chip_lookup.vhd \
	$(ROOT)/firmware/a10_board/a10/data_generator_a10.vhd \
	$(ROOT)/firmware/a10_board/a10/run_control_link_listener.vhd \
	$(ROOT)/firmware/a10_board/a10/run_control.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/hit_compactor.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/word_rate.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/mux_4_1_256.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/subtime_merger.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_event_builder.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_data_demerger.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_sc_main.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_sc_secondary.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/qc_histos.vhd \
	$(ROOT)/firmware/a10_board/a10/merger/opq_monolithic_4lane_merge_opq_0.vhd \
	$(ROOT)/firmware/a10_board/a10/merger/ingress_egress_adaptor.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_mux_4_1.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_block.vhd \
	$(CURDIR)/dut/swb_block_uvm_wrapper.vhd

VERILOG_DUT_SOURCES = \
	$(ROOT)/firmware/a10_board/a10/merger/ticket_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/lane_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/handle_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/page_ram.v \
	$(ROOT)/firmware/a10_board/a10/merger/tile_fifo.v

SV_SOURCES = \
	$(CURDIR)/sv/interfaces.sv \
	$(UVM_HOME)/src/uvm_pkg.sv \
	$(CURDIR)/sv/swb_uvm_pkg.sv \
	$(CURDIR)/sv/tb_top.sv

SV_INCLUDE_SOURCES = \
	$(CURDIR)/sv/swb_types.sv \
	$(CURDIR)/sv/swb_sequences.sv \
	$(CURDIR)/sv/swb_agents.sv \
	$(CURDIR)/sv/swb_scoreboard.sv \
	$(CURDIR)/sv/swb_env.sv \
	$(CURDIR)/sv/swb_basic_test.sv

SIM_ARGS ?=

.PHONY: compile run clean

compile: $(BUILD_DIR)/.compile-stamp

$(BUILD_DIR)/.compile-stamp: $(VHDL_SOURCES) $(SV_SOURCES) $(SV_INCLUDE_SOURCES)
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VLIB) work
	cd $(BUILD_DIR) && set -e; for file in $(VHDL_SOURCES); do $(VCOM) -2008 $$file; done
	cd $(BUILD_DIR) && $(VLOG) $(VERILOG_DUT_SOURCES)
	cd $(BUILD_DIR) && $(VLOG) -sv +incdir+$(UVM_HOME)/src +incdir+$(CURDIR)/sv $(SV_SOURCES)
	touch $@

run: compile
	cd $(BUILD_DIR) && $(QUESTA_RUNNER) $(VSIM) -c -L altera_mf tb_top -do "run -all; quit -f" $(SIM_ARGS)

clean:
	rm -rf $(BUILD_DIR)
