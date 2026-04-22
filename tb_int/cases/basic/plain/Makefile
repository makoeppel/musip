SHELL := /usr/bin/env bash

ROOT := $(abspath ../../../..)
BUILD_ROOT := $(CURDIR)/work
REPORT_DIR := $(CURDIR)/report
include $(ROOT)/tb_int/cases/basic/opq_sources.mk
REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out)
SMOKE_REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out_smoke)
QUESTA_HOME ?= /data1/questaone_sim/questasim
QUESTA_INI_PREP := $(ROOT)/tools/ip/prepare_questa_ini.sh
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
PYTHON ?= python3
VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VMAP := $(firstword $(wildcard $(QUESTA_HOME)/bin/vmap $(QUESTA_HOME)/linux_x86_64/vmap))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))
VCOVER := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcover $(QUESTA_HOME)/linux_x86_64/vcover))
QUESTA_RUNNER := $(ROOT)/tools/ip/run_questa.sh
USE_MERGE ?= 1
DMA_HIT_CHECKER := $(CURDIR)/check_dma_hits.py
ACTUAL_DMA_WORDS := $(abspath $(REPORT_DIR))/actual_dma_words.mem
ACTUAL_DMA_WORDS_SMOKE := $(abspath $(REPORT_DIR))/actual_dma_words_smoke.mem
COV ?= 0
COV_CODE ?= sbecft
BUILD_FLAVOR := $(if $(filter 1,$(COV)),cov,nocov)
BUILD_DIR := $(BUILD_ROOT)/$(BUILD_FLAVOR)
QUESTA_INI := $(BUILD_DIR)/modelsim.ini
RUN_LOG ?= $(REPORT_DIR)/run_plain_basic.log
RUN_LOG_SMOKE ?= $(REPORT_DIR)/run_plain_basic_smoke.log
COV_UCDB ?= $(REPORT_DIR)/plain_basic.ucdb
COV_UCDB_SMOKE ?= $(REPORT_DIR)/plain_basic_smoke.ucdb
COV_UCDB_ABS := $(abspath $(COV_UCDB))
COV_UCDB_SMOKE_ABS := $(abspath $(COV_UCDB_SMOKE))

export SALT_LICENSE_SERVER ?= $(ETH_MENTOR_SERVER)
export MGLS_LICENSE_FILE ?= $(ETH_MENTOR_SERVER)
export LM_LICENSE_FILE ?= $(ETH_MENTOR_SERVER)
export QSIM_INI ?= $(QUESTA_INI)

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
	$(OPQ_VHDL_DUT_SOURCES) \
	$(ROOT)/firmware/a10_board/a10/merger/ingress_egress_adaptor.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/musip_mux_4_1.vhd \
	$(ROOT)/firmware/a10_board/a10/swb/swb_block.vhd \
	$(ROOT)/tb_int/cases/basic/uvm/dut/swb_block_uvm_wrapper.vhd \
	$(CURDIR)/tb_swb_block_plain_replay.vhd

VERILOG_DUT_SOURCES = $(OPQ_VERILOG_DUT_SOURCES)

SV_DUT_SOURCES = $(OPQ_SV_DUT_SOURCES)

SIM_ARGS ?=
VSIM_FLAGS := -c -t ps -voptargs=+acc
COMPILE_STAMP := $(BUILD_DIR)/.compile-stamp.$(OPQ_SOURCE_MODE).$(OPQ_N_SHD).$(OPQ_LANE_FIFO_DEPTH).$(OPQ_TICKET_FIFO_DEPTH).$(OPQ_HANDLE_FIFO_DEPTH).$(OPQ_PAGE_RAM_DEPTH)
VCOM_FLAGS := -2008
VLOG_FLAGS := -sv

ifeq ($(COV),1)
VCOM_FLAGS += +cover=$(COV_CODE)
VLOG_FLAGS += +cover=$(COV_CODE)
VSIM_FLAGS += -coverage
endif

.PHONY: compile run run-smoke run_cov run_cov_smoke coverage_report clean

compile: $(COMPILE_STAMP)

$(COMPILE_STAMP): $(VHDL_SOURCES) $(OPQ_SIM_QSYS_VHDL_SOURCES) $(OPQ_SIM_QSYS_VERILOG_SOURCES) $(VERILOG_DUT_SOURCES) $(SV_DUT_SOURCES) $(QUESTA_INI_PREP)
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	$(QUESTA_INI_PREP) $(QUESTA_HOME) $(QUESTA_INI)
	cd $(BUILD_DIR) && QSIM_INI=$(QUESTA_INI) $(VLIB) work
	cd $(BUILD_DIR) && set -e; for lib in $(OPQ_SIM_EXTRA_LIBS); do QSIM_INI=$(QUESTA_INI) $(VLIB) $$lib; QSIM_INI=$(QUESTA_INI) $(VMAP) $$lib $$lib; done
	cd $(BUILD_DIR) && set -e; for file in $(OPQ_SIM_QSYS_VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) -work $(OPQ_SIM_QSYS_LIB) $$file; done
	cd $(BUILD_DIR) && if [ -n "$(strip $(OPQ_SIM_QSYS_VERILOG_SOURCES))" ]; then QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) -work $(OPQ_SIM_QSYS_LIB) $(OPQ_DUT_DEFINES) $(OPQ_SIM_QSYS_VERILOG_SOURCES); fi
	cd $(BUILD_DIR) && set -e; for file in $(VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) $$file; done
	cd $(BUILD_DIR) && if [ -n "$(strip $(VERILOG_DUT_SOURCES) $(SV_DUT_SOURCES))" ]; then QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) $(OPQ_DUT_DEFINES) $(VERILOG_DUT_SOURCES) $(SV_DUT_SOURCES); fi
	touch $@

run: compile
	mkdir -p $(REPORT_DIR)
	rm -f $(ACTUAL_DMA_WORDS)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(OPQ_VSIM_LIB_FLAGS) -gG_REPLAY_DIR=$(REPLAY_DIR) -gG_ACTUAL_DMA_PATH=$(ACTUAL_DMA_WORDS) -gG_USE_MERGE=$(USE_MERGE) tb_swb_block_plain_replay -do "run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG)"
	$(PYTHON) $(DMA_HIT_CHECKER) --expected "$(REPLAY_DIR)/expected_dma_words.mem" --actual "$(ACTUAL_DMA_WORDS)"

run-smoke: compile
	mkdir -p $(REPORT_DIR)
	rm -f $(ACTUAL_DMA_WORDS_SMOKE)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(OPQ_VSIM_LIB_FLAGS) -gG_REPLAY_DIR=$(SMOKE_REPLAY_DIR) -gG_ACTUAL_DMA_PATH=$(ACTUAL_DMA_WORDS_SMOKE) -gG_USE_MERGE=$(USE_MERGE) tb_swb_block_plain_replay -do "run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG_SMOKE)"
	$(PYTHON) $(DMA_HIT_CHECKER) --expected "$(SMOKE_REPLAY_DIR)/expected_dma_words.mem" --actual "$(ACTUAL_DMA_WORDS_SMOKE)"

run_cov: compile
	mkdir -p $(REPORT_DIR)
	mkdir -p $(dir $(COV_UCDB_ABS))
	rm -f $(ACTUAL_DMA_WORDS) $(COV_UCDB_ABS)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(OPQ_VSIM_LIB_FLAGS) -gG_REPLAY_DIR=$(REPLAY_DIR) -gG_ACTUAL_DMA_PATH=$(ACTUAL_DMA_WORDS) -gG_USE_MERGE=$(USE_MERGE) tb_swb_block_plain_replay -do "coverage save -onexit $(COV_UCDB_ABS); run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG)"
	$(PYTHON) $(DMA_HIT_CHECKER) --expected "$(REPLAY_DIR)/expected_dma_words.mem" --actual "$(ACTUAL_DMA_WORDS)"

run_cov_smoke: compile
	mkdir -p $(REPORT_DIR)
	mkdir -p $(dir $(COV_UCDB_SMOKE_ABS))
	rm -f $(ACTUAL_DMA_WORDS_SMOKE) $(COV_UCDB_SMOKE_ABS)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(OPQ_VSIM_LIB_FLAGS) -gG_REPLAY_DIR=$(SMOKE_REPLAY_DIR) -gG_ACTUAL_DMA_PATH=$(ACTUAL_DMA_WORDS_SMOKE) -gG_USE_MERGE=$(USE_MERGE) tb_swb_block_plain_replay -do "coverage save -onexit $(COV_UCDB_SMOKE_ABS); run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG_SMOKE)"
	$(PYTHON) $(DMA_HIT_CHECKER) --expected "$(SMOKE_REPLAY_DIR)/expected_dma_words.mem" --actual "$(ACTUAL_DMA_WORDS_SMOKE)"

coverage_report:
	@if [ -z "$(VCOVER)" ]; then \
		echo "vcover not found under $(QUESTA_HOME)"; \
		exit 1; \
	fi
	$(VCOVER) report -details -all $(COV_UCDB_ABS)

clean:
	rm -rf $(BUILD_ROOT) $(REPORT_DIR)
