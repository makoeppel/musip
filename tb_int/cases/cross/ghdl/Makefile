SHELL := /usr/bin/env bash

GHDL ?= $(or $(firstword $(wildcard $(HOME)/.local/ghdl/ghdl-mcode-ubuntu20.04/bin/ghdl $(HOME)/conda-ghdl/bin/ghdl /usr/local/bin/ghdl /usr/bin/ghdl)),ghdl)
GTKWAVE ?= gtkwave
PYTHON ?= python3
GDK_PIXBUF_QUERY_LOADERS ?= $(or $(firstword $(wildcard /opt/anaconda3/bin/gdk-pixbuf-query-loaders $(HOME)/.conda/envs/gtkwave/bin/gdk-pixbuf-query-loaders $(HOME)/conda-ghdl/bin/gdk-pixbuf-query-loaders /usr/bin/gdk-pixbuf-query-loaders)),gdk-pixbuf-query-loaders)
GTKWAVE_XPM_LOADER ?= $(firstword $(wildcard $(HOME)/.conda/envs/gtkwave/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-xpm.so $(HOME)/conda-ghdl/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-xpm.so /usr/lib64/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-xpm.so /usr/lib/gdk-pixbuf-2.0/2.10.0/loaders/libpixbufloader-xpm.so))

TB := tb_swb_cross_ghdl
SRC := $(CURDIR)/tb_swb_cross_ghdl.vhd
BUILD_DIR := $(CURDIR)/build
REPORT_DIR := $(CURDIR)/report
REPLAY_DIR := $(CURDIR)/replay
GHDL_CASE_CYCLES ?= 24576
GHDL_CLOCK_PERIOD_NS ?= 4
GHDL_WAVE_FORMAT ?= vcd
GHDL_FLAGS ?= --std=08 --ieee=standard -fexplicit
UVM_B001_VCD ?=
RUN_LOG := $(REPORT_DIR)/$(TB).log
GTKW_FILE := $(REPORT_DIR)/$(TB).gtkw
GTKWAVE_PIXBUF_CACHE := $(REPORT_DIR)/gdk_pixbuf_loaders.cache

ifeq ($(GHDL_WAVE_FORMAT),vcd)
WAVE_FILE := $(REPORT_DIR)/$(TB).vcd
WAVE_ARG := --vcd=$(WAVE_FILE)
else ifeq ($(GHDL_WAVE_FORMAT),fst)
WAVE_FILE := $(REPORT_DIR)/$(TB).fst
WAVE_ARG := --fst=$(WAVE_FILE)
else ifeq ($(GHDL_WAVE_FORMAT),ghw)
WAVE_FILE := $(REPORT_DIR)/$(TB).ghw
WAVE_ARG := --wave=$(WAVE_FILE)
else
$(error GHDL_WAVE_FORMAT must be one of vcd, fst, ghw)
endif

.PHONY: help check-tools replay objects run gtkw checkpoints gtkwave-pixbuf-cache view clean

help:
	@printf '%s\n' \
	  'Available targets:' \
	  '  make objects # analyze/elaborate the GHDL cross fixture' \
	  '  make replay  # regenerate UVM-sequence-derived scheduled replay files' \
	  '  make run     # run the packet-evidence cross fixture and emit a wave dump' \
	  '  make gtkw    # generate GTKWave save file with packet decode/groups' \
	  '  make checkpoints # check named VCD checkpoints used for visual review' \
	  '  make view    # run, generate GTKWave save file, and open GTKWave if DISPLAY is set' \
	  '  make clean   # remove local GHDL build/report output'

check-tools:
	@command -v $(GHDL) >/dev/null 2>&1 || { echo "error: ghdl not found in PATH" >&2; exit 127; }

replay:
	mkdir -p $(REPLAY_DIR)
	$(PYTHON) $(CURDIR)/scripts/gen_swb_cross_replay.py \
	  --out-dir $(REPLAY_DIR) \
	  --case-cycles $(GHDL_CASE_CYCLES)
ifneq ($(strip $(UVM_B001_VCD)),)
	$(PYTHON) $(CURDIR)/scripts/extract_uvm_replay_from_vcd.py \
	  --vcd $(UVM_B001_VCD) \
	  --case-dir $(REPLAY_DIR)/B001 \
	  --case-cycles $(GHDL_CASE_CYCLES)
endif

objects: check-tools
	mkdir -p $(BUILD_DIR)
	$(GHDL) -a $(GHDL_FLAGS) --workdir=$(BUILD_DIR) $(SRC)
	$(GHDL) -e $(GHDL_FLAGS) --workdir=$(BUILD_DIR) $(TB)

run: replay objects gtkw
	mkdir -p $(REPORT_DIR)
	rm -f $(WAVE_FILE) $(RUN_LOG)
	set -o pipefail; \
	$(GHDL) -r $(GHDL_FLAGS) --workdir=$(BUILD_DIR) $(TB) \
	  -gG_CASE_CYCLES=$(GHDL_CASE_CYCLES) \
	  -gG_CLOCK_PERIOD_NS=$(GHDL_CLOCK_PERIOD_NS) \
	  --assert-level=error \
	  --ieee-asserts=disable-at-0 \
	  $(WAVE_ARG) 2>&1 | tee $(RUN_LOG)

gtkw:
	mkdir -p $(REPORT_DIR)
	$(PYTHON) $(CURDIR)/scripts/gen_swb_cross_gtkw.py \
	  --out $(GTKW_FILE) \
	  --wave-file $(WAVE_FILE) \
	  --case-cycles $(GHDL_CASE_CYCLES) \
	  --clock-period-ns $(GHDL_CLOCK_PERIOD_NS)

checkpoints: gtkw
	$(PYTHON) $(CURDIR)/scripts/check_swb_cross_vcd.py \
	  --vcd $(WAVE_FILE) \
	  --out $(REPORT_DIR)/$(TB)_checkpoints.md \
	  --case-cycles $(GHDL_CASE_CYCLES) \
	  --clock-period-ns $(GHDL_CLOCK_PERIOD_NS)

gtkwave-pixbuf-cache:
	mkdir -p $(REPORT_DIR)
	@if [ -n "$(GTKWAVE_XPM_LOADER)" ] && command -v "$(GDK_PIXBUF_QUERY_LOADERS)" >/dev/null 2>&1; then \
	  "$(GDK_PIXBUF_QUERY_LOADERS)" "$(GTKWAVE_XPM_LOADER)" > "$(GTKWAVE_PIXBUF_CACHE)"; \
	else \
	  rm -f "$(GTKWAVE_PIXBUF_CACHE)"; \
	fi

view: run checkpoints gtkwave-pixbuf-cache
	@if [ -z "$${DISPLAY:-}" ]; then \
	  echo "DISPLAY is not set; generated $(WAVE_FILE) and $(GTKW_FILE)"; \
	elif [ -s "$(GTKWAVE_PIXBUF_CACHE)" ]; then \
	  GDK_PIXBUF_MODULE_FILE="$(GTKWAVE_PIXBUF_CACHE)" $(GTKWAVE) $(WAVE_FILE) $(GTKW_FILE); \
	else \
	  $(GTKWAVE) $(WAVE_FILE) $(GTKW_FILE); \
	fi

clean:
	rm -rf $(BUILD_DIR) $(REPORT_DIR) $(REPLAY_DIR)
