SHELL := /usr/bin/env bash

ROOT := $(abspath ../../../..)
BUILD_ROOT := $(CURDIR)/work
REPORT_DIR := $(CURDIR)/report
REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out)
SMOKE_REPLAY_DIR ?= $(abspath $(ROOT)/tb_int/cases/basic/ref/out_smoke)
QUESTA_HOME ?= /data1/questaone_sim/questasim
ETH_MENTOR_SERVER ?= 8161@lic-mentor.ethz.ch
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
QUESTA_INI_PREP := $(ROOT)/tools/ip/prepare_questa_ini.sh
VLIB := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlib $(QUESTA_HOME)/linux_x86_64/vlib))
VCOM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcom $(QUESTA_HOME)/linux_x86_64/vcom))
VLOG := $(firstword $(wildcard $(QUESTA_HOME)/bin/vlog $(QUESTA_HOME)/linux_x86_64/vlog))
VSIM := $(firstword $(wildcard $(QUESTA_HOME)/bin/vsim $(QUESTA_HOME)/linux_x86_64/vsim))
VCOVER := $(firstword $(wildcard $(QUESTA_HOME)/bin/vcover $(QUESTA_HOME)/linux_x86_64/vcover))
QUESTA_RUNNER := $(ROOT)/tools/ip/run_questa.sh
UVM_DPI_LIB := $(firstword $(wildcard $(QUESTA_HOME)/uvm-1.2/linux_x86_64/uvm_dpi.so $(QUESTA_HOME)/uvm-1.2/linux/uvm_dpi.so))
UVM_DPI_LIB_OPT := $(if $(UVM_DPI_LIB),-sv_lib $(basename $(UVM_DPI_LIB)))
COV ?= 0
COV_CODE ?= sbecft
BUILD_FLAVOR := $(if $(filter 1,$(COV)),cov,nocov)
BUILD_DIR := $(BUILD_ROOT)/$(BUILD_FLAVOR)
QUESTA_INI := $(BUILD_DIR)/modelsim.ini
SV_LIB := $(abspath $(BUILD_DIR))/libswb_opq_2env_dpi
RUN_LOG ?= $(REPORT_DIR)/run_plain_basic_2env.log
RUN_LOG_SMOKE ?= $(REPORT_DIR)/run_plain_basic_2env_smoke.log
COV_UCDB ?= $(REPORT_DIR)/plain_basic_2env.ucdb
COV_UCDB_SMOKE ?= $(REPORT_DIR)/plain_basic_2env_smoke.ucdb
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
	$(CURDIR)/sv/swb_opq_boundary_contract_sva.sv \
	$(CURDIR)/sv/tb_top_2env.sv

SV_INCLUDE_SOURCES = \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_types.sv \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_sequences.sv \
	$(ROOT)/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv \
	$(CURDIR)/sv/swb_2env_agents.sv \
	$(CURDIR)/sv/swb_2env_boundary_scoreboard.sv \
	$(CURDIR)/sv/swb_2env_env.sv \
	$(CURDIR)/sv/swb_2env_test.sv

C_SOURCES = \
	$(CURDIR)/dpi/swb_opq_2env_dpi.c

UVM_DEFINES ?=
SIM_ARGS ?=
VSIM_FLAGS := -c -L altera_mf_ver -L 220model_ver -L altera_mf -L 220model -voptargs=+acc
VCOM_FLAGS := -2008
VLOG_FLAGS := -sv

ifeq ($(COV),1)
VCOM_FLAGS += +cover=$(COV_CODE)
VLOG_FLAGS += +cover=$(COV_CODE)
VSIM_FLAGS += -coverage
endif

.PHONY: compile run run-smoke run_cov run_cov_smoke coverage_report clean

compile: $(BUILD_DIR)/.compile-stamp

$(BUILD_DIR)/.compile-stamp: $(VHDL_SOURCES) $(SV_SOURCES) $(SV_INCLUDE_SOURCES) $(C_SOURCES) $(QUESTA_INI_PREP)
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	$(QUESTA_INI_PREP) $(QUESTA_HOME) $(QUESTA_INI)
	gcc -O2 -fPIC -shared -o $(SV_LIB).so $(C_SOURCES)
	cd $(BUILD_DIR) && QSIM_INI=$(QUESTA_INI) $(VLIB) work
	cd $(BUILD_DIR) && set -e; for file in $(VHDL_SOURCES); do QSIM_INI=$(QUESTA_INI) $(VCOM) $(VCOM_FLAGS) $$file; done
	cd $(BUILD_DIR) && QSIM_INI=$(QUESTA_INI) $(VLOG) $(VLOG_FLAGS) $(UVM_DEFINES) +incdir+$(UVM_HOME)/src +incdir+$(CURDIR)/sv $(SV_SOURCES)
	touch $@

run: compile
	mkdir -p $(REPORT_DIR)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(UVM_DPI_LIB_OPT) -sv_lib $(SV_LIB) tb_top_2env +SWB_REPLAY_DIR=$(REPLAY_DIR) -do "run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG)"

run-smoke: compile
	mkdir -p $(REPORT_DIR)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(UVM_DPI_LIB_OPT) -sv_lib $(SV_LIB) tb_top_2env +SWB_REPLAY_DIR=$(SMOKE_REPLAY_DIR) -do "run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG_SMOKE)"

run_cov: compile
	mkdir -p $(REPORT_DIR)
	mkdir -p $(dir $(COV_UCDB_ABS))
	rm -f $(COV_UCDB_ABS)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(UVM_DPI_LIB_OPT) -sv_lib $(SV_LIB) tb_top_2env +SWB_REPLAY_DIR=$(REPLAY_DIR) -do "coverage save -onexit $(COV_UCDB_ABS); run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG)"

run_cov_smoke: compile
	mkdir -p $(REPORT_DIR)
	mkdir -p $(dir $(COV_UCDB_SMOKE_ABS))
	rm -f $(COV_UCDB_SMOKE_ABS)
	cd $(BUILD_DIR) && set -o pipefail; \
	QSIM_INI=$(QUESTA_INI) $(QUESTA_RUNNER) $(VSIM) $(VSIM_FLAGS) $(UVM_DPI_LIB_OPT) -sv_lib $(SV_LIB) tb_top_2env +SWB_REPLAY_DIR=$(SMOKE_REPLAY_DIR) -do "coverage save -onexit $(COV_UCDB_SMOKE_ABS); run -all; quit -f" $(SIM_ARGS) | tee "$(RUN_LOG_SMOKE)"

coverage_report:
	@if [ -z "$(VCOVER)" ]; then \
		echo "vcover not found under $(QUESTA_HOME)"; \
		exit 1; \
	fi
	$(VCOVER) report -details -all $(COV_UCDB_ABS)

clean:
	rm -rf $(BUILD_ROOT) $(REPORT_DIR)
