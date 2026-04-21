SHELL := /usr/bin/env bash

FORMAL_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
OSS_FORMAL_HOME ?= /data1/oss_formal/current
SBY := $(OSS_FORMAL_HOME)/bin/sby

.PHONY: oss-contract clean

oss-contract:
	@PATH="$(OSS_FORMAL_HOME)/bin:$$PATH" && \
	  cd $(FORMAL_DIR)/oss && \
	  $(SBY) -f swb_opq_boundary_contract.sby

clean:
	rm -rf $(FORMAL_DIR)/oss/swb_opq_boundary_contract
