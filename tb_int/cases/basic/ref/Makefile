SHELL := /usr/bin/env bash

OUT_DIR ?= $(CURDIR)/out
PYTHON ?= python3
SIM_ARGS ?=

.PHONY: run clean

run:
	$(PYTHON) $(CURDIR)/run_basic_ref.py --out-dir $(OUT_DIR) $(SIM_ARGS)

clean:
	rm -rf $(OUT_DIR)
