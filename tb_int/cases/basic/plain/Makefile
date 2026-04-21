SHELL := /usr/bin/env bash

ROOT := $(abspath ../../../..)
BUILD_DIR := $(CURDIR)/work
REPORT_DIR := $(CURDIR)/report
REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out)
SMOKE_REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out_smoke)
QUESTA_PREFER_FE ?= 0
ifeq ($(QUESTA_PREFER_FE),1)
ifneq ($(wildcard /data1/intelFPGA_pro/23.1/questa_fe),)
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
else
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
endif
else
ifneq ($(wildcard /data1/intelFPGA_pro/23.1/questa_fse),)
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fse
else
QUESTA_HOME ?= /data1/intelFPGA_pro/23.1/questa_fe
endif
endif
QUESTA_LICENSE ?= $(firstword $(wildcard $(QUESTA_HOME)/LR-*_License.dat))
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
TB_LICENSE_CHAIN := $(ETH_MENTOR_SERVER)
ifneq ($(wildcard $(QUESTA_LICENSE)),)
TB_LICENSE_CHAIN := $(QUESTA_LICENSE)
endif
VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))

export MGLS_LICENSE_FILE := $(TB_LICENSE_CHAIN)
export LM_LICENSE_FILE := $(MGLS_LICENSE_FILE)

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
	$(ROOT)/tb_int/cases/basic/uvm/dut/swb_block_uvm_wrapper.vhd \
	$(CURDIR)/tb_swb_block_plain_replay.vhd

VERILOG_DUT_SOURCES = \
	$(ROOT)/firmware/a10_board/a10/merger/ticket_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/lane_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/handle_fifo.v \
	$(ROOT)/firmware/a10_board/a10/merger/page_ram.v \
	$(ROOT)/firmware/a10_board/a10/merger/tile_fifo.v

SIM_ARGS ?=
VSIM_FLAGS := -c -L altera_mf -t ps -voptargs=+acc

.PHONY: compile run run-smoke clean

compile: $(BUILD_DIR)/.compile-stamp

$(BUILD_DIR)/.compile-stamp: $(VHDL_SOURCES) $(VERILOG_DUT_SOURCES)
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VLIB) work
	cd $(BUILD_DIR) && set -e; for file in $(VHDL_SOURCES); do $(VCOM) -2008 $$file; done
	cd $(BUILD_DIR) && $(VLOG) $(VERILOG_DUT_SOURCES)
	touch $@

run: compile
	mkdir -p $(REPORT_DIR)
	cd $(BUILD_DIR) && set -o pipefail; \
	$(VSIM) $(VSIM_FLAGS) -gG_REPLAY_DIR=$(REPLAY_DIR) tb_swb_block_plain_replay -do "run -all; quit -f" $(SIM_ARGS) | tee "$(REPORT_DIR)/run_plain_basic.log"

run-smoke: compile
	mkdir -p $(REPORT_DIR)
	cd $(BUILD_DIR) && set -o pipefail; \
	$(VSIM) $(VSIM_FLAGS) -gG_REPLAY_DIR=$(SMOKE_REPLAY_DIR) tb_swb_block_plain_replay -do "run -all; quit -f" $(SIM_ARGS) | tee "$(REPORT_DIR)/run_plain_basic_smoke.log"

clean:
	rm -rf $(BUILD_DIR) $(REPORT_DIR)
