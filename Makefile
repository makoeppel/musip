SHELL := /usr/bin/env bash

IP_UVM_DIR := tb_int/cases/basic/uvm
IP_REF_DIR := tb_int/cases/basic/ref
IP_PLAIN_DIR := tb_int/cases/basic/plain
IP_PLAIN_2ENV_DIR := tb_int/cases/basic/plain_2env
IP_PLAIN_2ENV_FORMAL_DIR := tb_int/cases/basic/plain_2env/formal
OPQ_SVD_OUT := build/ip/opq_monolithic_4lane_merge.svd
QUESTA_HOME ?= /data1/questaone_sim/questasim
UVM_HOME ?= $(QUESTA_HOME)/verilog_src/uvm-1.2
ETH_LIC_SERVER ?= 8161@lic-mentor.ethz.ch

export QUESTA_HOME
export UVM_HOME
export SALT_LICENSE_SERVER ?= $(ETH_LIC_SERVER)
export MGLS_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export LM_LICENSE_FILE ?= $(ETH_LIC_SERVER)
export QSIM_INI ?= $(QUESTA_HOME)/modelsim.ini

.PHONY: help ip-init ip-sync-opq ip-svd ip-check-license ip-compile-basic ip-compile-basic-cov ip-compile-plain ip-compile-plain-cov ip-compile-plain-2env ip-compile-plain-2env-cov ip-uvm-basic ip-uvm-basic-cov ip-uvm-longrun ip-tlm-basic ip-tlm-basic-smoke ip-plain-basic ip-plain-basic-smoke ip-plain-basic-cov ip-plain-basic-cov-smoke ip-plain-basic-2env ip-plain-basic-2env-smoke ip-plain-basic-2env-cov ip-plain-basic-2env-cov-smoke ip-formal-boundary ip-cov-closure ip-cross-baselines ip-e2e ip-e2e-ref ip-e2e-plain ip-e2e-plain-2env ip-clean ip-lint-rtl

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make ip-init          # init submodules and generate the upstream packaged OPQ Qsys wrapper for musip' \
	  '  make ip-sync-opq      # regenerate and validate the musip-local upstream OPQ Qsys wrapper' \
	  '  make ip-svd           # generate a basic OPQ CSR SVD under build/ip/' \
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

ip-e2e: ip-uvm-basic

ip-e2e-ref: ip-tlm-basic

ip-e2e-plain: ip-plain-basic

ip-e2e-plain-2env: ip-plain-basic-2env

ip-clean:
	$(MAKE) -C $(IP_UVM_DIR) clean
	$(MAKE) -C $(IP_REF_DIR) clean
	$(MAKE) -C $(IP_PLAIN_DIR) clean
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) clean

ip-lint-rtl:
	python3 tools/ip/lint_rtl.py
