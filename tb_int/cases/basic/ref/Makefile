SHELL := /usr/bin/env bash

OUT_DIR ?= $(CURDIR)/out
SMOKE_OUT_DIR ?= $(CURDIR)/out_smoke
PYTHON ?= python3
SIM_ARGS ?=

.PHONY: run run-smoke clean

run:
	$(PYTHON) $(CURDIR)/run_basic_ref.py --out-dir $(OUT_DIR) $(SIM_ARGS)

run-smoke:
	$(PYTHON) $(CURDIR)/run_basic_ref.py --profile smoke --out-dir $(SMOKE_OUT_DIR) $(SIM_ARGS)

clean:
	rm -rf $(OUT_DIR) $(SMOKE_OUT_DIR)
