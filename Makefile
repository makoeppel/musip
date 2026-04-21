SHELL := /usr/bin/env bash

IP_UVM_DIR := tb_int/cases/basic/uvm
IP_REF_DIR := tb_int/cases/basic/ref
IP_PLAIN_DIR := tb_int/cases/basic/plain
IP_PLAIN_2ENV_DIR := tb_int/cases/basic/plain_2env
IP_PLAIN_2ENV_FORMAL_DIR := tb_int/cases/basic/plain_2env/formal
OPQ_SVD_OUT := build/ip/opq_monolithic_4lane_merge.svd
ETH_LIC_SERVER ?= 8161@129.132.148.195

export MGLS_LICENSE_FILE ?= $(ETH_LIC_SERVER)

.PHONY: help ip-init ip-sync-opq ip-svd ip-check-license ip-compile-basic ip-compile-plain ip-compile-plain-2env ip-uvm-basic ip-tlm-basic ip-tlm-basic-smoke ip-plain-basic ip-plain-basic-smoke ip-plain-basic-2env ip-plain-basic-2env-smoke ip-formal-boundary ip-e2e ip-e2e-ref ip-e2e-plain ip-e2e-plain-2env ip-clean ip-lint-rtl

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make ip-init          # init submodules and refresh the OPQ snapshot' \
	  '  make ip-sync-opq      # refresh the OPQ snapshot only' \
	  '  make ip-svd           # generate a basic OPQ CSR SVD under build/ip/' \
	  '  make ip-check-license # verify ETH Questa features for the UVM flow' \
	  '  make ip-compile-basic # compile the mixed-language basic UVM harness' \
	  '  make ip-compile-plain # compile the plain mixed-language replay bench' \
	  '  make ip-compile-plain-2env # compile the split 2-env DPI replay harness' \
	  '  make ip-uvm-basic     # run the basic UVM OPQ/SWB case' \
	  '  make ip-tlm-basic     # run the simulatorless basic reference case' \
	  '  make ip-tlm-basic-smoke # run the minimal directed replay generator' \
	  '  make ip-plain-basic   # run the plain mixed-language replay bench' \
	  '  make ip-plain-basic-smoke # run the plain mixed-language directed smoke bench' \
	  '  make ip-plain-basic-2env # run the split 2-env DPI replay harness' \
	  '  make ip-plain-basic-2env-smoke # run the split 2-env directed smoke harness' \
	  '  make ip-formal-boundary # run the OPQ-boundary formal scaffold' \
	  '  make ip-e2e           # alias for the basic end-to-end UVM case' \
	  '  make ip-e2e-ref       # alias for the simulatorless basic reference case' \
	  '  make ip-e2e-plain     # alias for the plain mixed-language replay bench' \
	  '  make ip-e2e-plain-2env # alias for the split 2-env DPI replay harness' \
	  '  make ip-clean         # clean UVM build products' \
	  '  make ip-lint-rtl      # strict lint for clean modules, hygiene lint for legacy/snapshot RTL'

ip-init:
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

ip-compile-plain:
	$(MAKE) -C $(IP_PLAIN_DIR) compile

ip-compile-plain-2env:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) compile

ip-uvm-basic:
	$(MAKE) -C $(IP_UVM_DIR) run

ip-tlm-basic:
	$(MAKE) -C $(IP_REF_DIR) run

ip-tlm-basic-smoke:
	$(MAKE) -C $(IP_REF_DIR) run-smoke

ip-plain-basic:
	$(MAKE) -C $(IP_PLAIN_DIR) run

ip-plain-basic-smoke:
	$(MAKE) -C $(IP_PLAIN_DIR) run-smoke

ip-plain-basic-2env:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) run

ip-plain-basic-2env-smoke:
	$(MAKE) -C $(IP_PLAIN_2ENV_DIR) run-smoke

ip-formal-boundary:
	$(MAKE) -C $(IP_PLAIN_2ENV_FORMAL_DIR) oss-contract

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
