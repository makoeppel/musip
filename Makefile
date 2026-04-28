SHELL := /usr/bin/env bash

IP_UVM_DIR := tb_int/cases/basic/uvm
IP_REF_DIR := tb_int/cases/basic/ref
IP_PLAIN_DIR := tb_int/cases/basic/plain
IP_PLAIN_2ENV_DIR := tb_int/cases/basic/plain_2env
IP_PLAIN_2ENV_FORMAL_DIR := tb_int/cases/basic/plain_2env/formal
IP_GHDL_CROSS_DIR := tb_int/cases/cross/ghdl
OPQ_QSYS_DIR := firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv
OPQ_SVD_OUT := $(OPQ_QSYS_DIR)/opq_upstream_4lane.svd
OPQ_SOPCINFO := $(OPQ_QSYS_DIR)/opq_upstream_4lane.sopcinfo
OPQ_CSR_LOG_DIR := build/ip
OPQ_CSR_MASTER ?=
SYSTEM_CONSOLE ?= /data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console
QUESTA_HOME ?= /data1/questaone_sim/questasim
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export QUESTA_HOME
export UVM_HOME
export SALT_LICENSE_SERVER ?= $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export LM_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export QSIM_INI ?= $(QUESTA_HOME)/modelsim.ini

.PHONY: help ip-init ip-sync-opq ip-svd ip-csr-lint ip-opq-csr-probe ip-opq-csr-dump ip-opq-csr-monitor ip-check-license ip-compile-basic ip-compile-basic-cov ip-compile-plain ip-compile-plain-cov ip-compile-plain-2env ip-compile-plain-2env-cov ip-uvm-basic ip-uvm-basic-cov ip-uvm-longrun ip-tlm-basic ip-tlm-basic-smoke ip-plain-basic ip-plain-basic-smoke ip-plain-basic-cov ip-plain-basic-cov-smoke ip-plain-basic-2env ip-plain-basic-2env-smoke ip-plain-basic-2env-cov ip-plain-basic-2env-cov-smoke ip-formal-boundary ip-cov-closure ip-cross-baselines ip-ghdl-cross-objects ip-ghdl-cross-run ip-ghdl-cross-gtkw ip-ghdl-cross-checkpoints ip-ghdl-cross-view ip-ghdl-cross-clean ip-e2e ip-e2e-ref ip-e2e-plain ip-e2e-plain-2env ip-clean ip-lint-rtl

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make ip-init          # init submodules and generate the upstream packaged OPQ Qsys wrapper for musip' \
	  '  make ip-sync-opq      # materialize and validate the musip-local upstream OPQ Qsys wrapper' \
	  '  make ip-svd           # generate the OPQ CSR SVD used by JTAG CSR dump/monitor' \
	  '  make ip-csr-lint      # lint OPQ _hw.tcl files for common UID/META CSR header compliance' \
	  '  make ip-opq-csr-probe # probe the OPQ JTAG Avalon master service and CSR UID when hardware is live' \
	  '  make ip-opq-csr-dump  # dump OPQ CSR registers through System Console using the generated SVD' \
	  '  make ip-opq-csr-monitor # monitor/trigger on an OPQ CSR field and log cleanly under build/ip/' \
	  '  make ip-check-license # verify ETH Questa features for the UVM flow' \
	  '  make ip-compile-basic # compile the mixed-language basic UVM harness' \
	  '  make ip-compile-basic-cov # compile the mixed-language basic UVM harness with coverage enabled' \
	  '  make ip-compile-plain # compile the plain mixed-language replay bench' \
	  '  make ip-compile-plain-cov # compile the plain mixed-language replay bench with coverage enabled' \
	  '  make ip-compile-plain-2env # compile the split 2-env DPI replay harness' \
	  '  make ip-compile-plain-2env-cov # compile the split 2-env DPI replay harness with coverage enabled' \
	  '  make ip-uvm-basic     # run the basic UVM SWB case (merge enabled by default)' \
	  '  make ip-uvm-basic-cov # run the basic UVM SWB case and save a UCDB' \
	  '  make ip-uvm-longrun   # run the musip UVM long-run campaign wrapper' \
	  '  make ip-tlm-basic     # run the simulatorless basic reference case' \
	  '  make ip-tlm-basic-smoke # run the minimal directed replay generator' \
	  '  make ip-plain-basic   # run the plain mixed-language replay bench (merge enabled by default)' \
	  '  make ip-plain-basic-smoke # run the plain mixed-language directed smoke bench' \
	  '  make ip-plain-basic-cov # run the plain mixed-language replay bench and save a UCDB' \
	  '  make ip-plain-basic-cov-smoke # run the plain smoke replay bench and save a UCDB' \
	  '  make ip-plain-basic-2env # run the split 2-env DPI replay harness' \
	  '  make ip-plain-basic-2env-smoke # run the split 2-env directed smoke harness' \
	  '  make ip-plain-basic-2env-cov # run the split 2-env replay harness and save a UCDB' \
	  '  make ip-plain-basic-2env-cov-smoke # run the split 2-env smoke harness and save a UCDB' \
	  '  make ip-formal-boundary # run the OPQ-boundary formal scaffold' \
	  '  make ip-cov-closure   # run the promoted UCDB closure bundle and regenerate the DV report' \
	  '  make ip-cross-baselines # run promoted CROSS-001..005 continuous-frame baseline evidence' \
	  '  make ip-ghdl-cross-objects # compile the lightweight GHDL all-bucket cross waveform fixture' \
	  '  make ip-ghdl-cross-run # run the lightweight GHDL all-bucket cross waveform fixture' \
	  '  make ip-ghdl-cross-gtkw # generate the SignalTap-aligned GTKWave save file for the GHDL fixture' \
	  '  make ip-ghdl-cross-checkpoints # verify named VCD checkpoints for the GHDL fixture' \
	  '  make ip-ghdl-cross-view # run the GHDL fixture and open GTKWave when DISPLAY is available' \
	  '  make ip-e2e           # alias for the basic end-to-end UVM case' \
	  '  make ip-e2e-ref       # alias for the simulatorless basic reference case' \
	  '  make ip-e2e-plain     # alias for the plain mixed-language replay bench' \
	  '  make ip-e2e-plain-2env # alias for the split 2-env DPI replay harness' \
	  '  make ip-clean         # clean UVM build products' \
	  '  make ip-lint-rtl      # strict lint for clean modules, hygiene lint for legacy/snapshot RTL'

ip-init:
	git submodule sync --recursive
	@if [ -d external/mu3e-ip-cores ]; then \
	  git -C external/mu3e-ip-cores config --local url."https://github.com/".insteadOf git@github.com:; \
	  git -C external/mu3e-ip-cores config --local url."https://github.com/".insteadOf ssh://git@github.com/; \
	  git -C external/mu3e-ip-cores submodule sync --recursive || true; \
	fi
	git submodule update --init --recursive
	$(MAKE) ip-sync-opq

ip-sync-opq:
	tools/ip/sync_opq_from_mu3e_ip_cores.sh

ip-svd:
	python3 tools/ip/generate_opq_svd.py --lanes 4 --output $(OPQ_SVD_OUT)

ip-csr-lint:
	/home/yifeng/.codex/skills/ip-packaging/scripts/lint_csr_header.py \
	  external/mu3e-ip-cores/packet_scheduler/script/ordered_priority_queue_hw.tcl \
	  $(OPQ_QSYS_DIR)/ordered_priority_queue_native_sv_fixed4_hw.tcl

ip-opq-csr-probe:
	env -u DISPLAY OPQ_CSR_CMD=probe OPQ_CSR_ARGS='--sopcinfo $(OPQ_SOPCINFO) --log $(OPQ_CSR_LOG_DIR)/opq_jtag_probe.log $(if $(OPQ_CSR_MASTER),--master $(OPQ_CSR_MASTER),)' \
	  $(SYSTEM_CONSOLE) -cli -disable_readline -disable_timeout --script=$(abspath tools/ip/opq_jtag_csr.tcl)

ip-opq-csr-dump: ip-svd
	env -u DISPLAY OPQ_CSR_CMD=dump OPQ_CSR_ARGS='--svd $(OPQ_SVD_OUT) --base 0x0 --log $(OPQ_CSR_LOG_DIR)/opq_jtag_dump.log $(if $(OPQ_CSR_MASTER),--master $(OPQ_CSR_MASTER),)' \
	  $(SYSTEM_CONSOLE) -cli -disable_readline -disable_timeout --script=$(abspath tools/ip/opq_jtag_csr.tcl)

ip-opq-csr-monitor: ip-svd
	env -u DISPLAY OPQ_CSR_CMD=monitor OPQ_CSR_ARGS='--svd $(OPQ_SVD_OUT) --base 0x0 --register STATUS --field MASK_EFFECTIVE --equals 1 --samples 100 --period-ms 100 --log $(OPQ_CSR_LOG_DIR)/opq_jtag_monitor.log $(if $(OPQ_CSR_MASTER),--master $(OPQ_CSR_MASTER),)' \
	  $(SYSTEM_CONSOLE) -cli -disable_readline -disable_timeout --script=$(abspath tools/ip/opq_jtag_csr.tcl)

ip-check-license:
	tools/ip/check_questa_license.sh

ip-compile-basic:
	$(MAKE) -C $(IP_UVM_DIR) compile

ip-compile-basic-cov:
	$(MAKE) -C $(IP_UVM_DIR) COV=1 compile

ip-compile-plain:
	$(MAKE) -C $(IP_PLAIN_DIR) compile

ip-compile-plain-cov:
	$(MAKE) -C $(IP_PLAIN_DIR) COV=1 compile

ip-compile-plain-2env:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) compile

ip-compile-plain-2env-cov:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) COV=1 compile

ip-uvm-basic:
	$(MAKE) -C $(IP_UVM_DIR) run

ip-uvm-basic-cov:
	$(MAKE) -C $(IP_UVM_DIR) COV=1 run_cov

ip-uvm-longrun:
	$(MAKE) -C $(IP_UVM_DIR) longrun

ip-tlm-basic:
	$(MAKE) -C $(IP_REF_DIR) run

ip-tlm-basic-smoke:
	$(MAKE) -C $(IP_REF_DIR) run-smoke

ip-plain-basic:
	$(MAKE) -C $(IP_PLAIN_DIR) run

ip-plain-basic-smoke:
	$(MAKE) -C $(IP_PLAIN_DIR) run-smoke

ip-plain-basic-cov:
	$(MAKE) -C $(IP_PLAIN_DIR) COV=1 run_cov

ip-plain-basic-cov-smoke:
	$(MAKE) -C $(IP_PLAIN_DIR) COV=1 run_cov_smoke

ip-plain-basic-2env:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) run

ip-plain-basic-2env-smoke:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) run-smoke

ip-plain-basic-2env-cov:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) COV=1 run_cov

ip-plain-basic-2env-cov-smoke:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) COV=1 run_cov_smoke

ip-formal-boundary:
	$(MAKE) -C $(IP_PLAIN_2ENV_FORMAL_DIR) oss-contract

ip-cov-closure:
	bash tb_int/scripts/run_cov_closure.sh

ip-cross-baselines:
	python3 tb_int/scripts/run_cross_baselines.py --tb tb_int

ip-ghdl-cross-objects:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) objects

ip-ghdl-cross-run:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) run

ip-ghdl-cross-gtkw:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) gtkw

ip-ghdl-cross-checkpoints:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) checkpoints

ip-ghdl-cross-view:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) view

ip-ghdl-cross-clean:
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) clean

ip-e2e: ip-uvm-basic

ip-e2e-ref: ip-tlm-basic

ip-e2e-plain: ip-plain-basic

ip-e2e-plain-2env: ip-plain-basic-2env

ip-clean:
	$(MAKE) -C $(IP_UVM_DIR) clean
	$(MAKE) -C $(IP_REF_DIR) clean
	$(MAKE) -C $(IP_PLAIN_DIR) clean
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) clean
	$(MAKE) -C $(IP_GHDL_CROSS_DIR) clean

ip-lint-rtl:
	python3 tools/ip/lint_rtl.py
