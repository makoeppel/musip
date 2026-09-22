# Makefile to compile the [cocotb](https://docs.cocotb.org) testbenches in this directory
# These are python files but they get compiled into executables along with the VHDL files
# they're testing.

# defaults
SIM ?= ghdl
TOPLEVEL_LANG ?= vhdl
COCOTB_MAKEFILE = $(shell cocotb-config --makefiles)/Makefile.sim

# Path to the Altera simulation library. To get this you need to run GHDL's compile-altera.sh
# script on a machine that has Quartus installed. Note that the original Quartus VHDL files
# also need to be available (see https://github.com/ghdl/ghdl/issues/3260).
ALTERA_SIM_LIB ?= /usr/local/lib/ghdl/vendors/altera

# -- run everything ------------------------------------------
all: tb_data_unpacker_outer tb_sorter

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
# COCOTB_TEST_MODULES is the basename of the Python test file(s)
tb_data_unpacker_outer: VHDL_SOURCES += $(PWD)/../../../../common/firmware/registers/mupix_registers.vhd \
        $(PWD)/../../../../common/firmware/registers/mudaq.vhd \
        $(PWD)/../../../../common/firmware/registers/mupix.vhd \
        $(PWD)/../../../fe/util/util_slv.vhd \
        $(PWD)/../../../fe/util/util_pkg.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/mapping_functions.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/hit_ts_conversion.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/data_unpacker_outer.vhd
tb_data_unpacker_outer: COCOTB_TOPLEVEL = data_unpacker_outer
tb_data_unpacker_outer: COCOTB_TEST_MODULES = tb_data_unpacker_outer
tb_data_unpacker_outer:
	$(run_test)


tb_sorter: VHDL_SOURCES = $(PWD)/../../../../common/firmware/registers/mupix_registers.vhd \
        $(PWD)/../../../../common/firmware/registers/mudaq.vhd \
        $(PWD)/../../../../common/firmware/registers/mupix.vhd \
        $(PWD)/../../../fe/util/util_slv.vhd \
        $(PWD)/../../../fe/util/util_pkg.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/mapping_functions.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/hit_ts_conversion.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/data_unpacker_outer.vhd \
        $(PWD)/../../../fe_mupix/mupix_block/data_unpacker/hit_multiplexer.vhd \
        $(PWD)/../../FEB_common/sorter_common/sorter_pkg.vhd \
        $(PWD)/../../FEB_common/sorter_common/hitsorter.vhd \
        $(PWD)/../../FEB_mutrig/mutrig_types.vhd \
        $(PWD)/../../FEB_common/sorter_common/sequencer_NG.vhd \
        $(PWD)/../../FEB_common/sorter_common/sorter_reg_mapping.vhd \
        $(PWD)/../../../../common/firmware/registers/sorter_registers.vhd \
        $(PWD)/top_sorter_test.vhd
tb_sorter: COCOTB_TOPLEVEL = top_sorter_test
tb_sorter: COCOTB_TEST_MODULES = tb_sorter
tb_sorter: COMPILE_ARGS += -P$(ALTERA_SIM_LIB)
tb_sorter:
	$(run_test)

# Common to all tests
COMPILE_ARGS += --std=08 --ieee=standard -fexplicit -fsynopsys --mb-comments -fpsl
SIM_ARGS += --disp-tree=inst --ieee-asserts=disable-at-0 --assert-level=failure --backtrace-severity=warning --vcd=$(COCOTB_TOPLEVEL).vcd --wave=$(COCOTB_TOPLEVEL).ghw --fst=$(COCOTB_TOPLEVEL).fst --psl-report=$(COCOTB_TOPLEVEL).psl-report
export PYTHONPATH := $(PWD):$(PWD)/../../../../common/firmware/util:$(PYTHONPATH)

# -- shared runner -------------------------------------------
define run_test
	mkdir -p cocotb_results/$(COCOTB_TOPLEVEL)
	cd cocotb_results/$(COCOTB_TOPLEVEL) && $(MAKE) -f $(COCOTB_MAKEFILE) \
	    SIM=$(SIM) \
	    TOPLEVEL_LANG=$(TOPLEVEL_LANG) \
	    COCOTB_TOPLEVEL=$(COCOTB_TOPLEVEL) \
	    COCOTB_TEST_MODULES=$(COCOTB_TEST_MODULES) \
	    COMPILE_ARGS="$(COMPILE_ARGS)" \
	    SIM_ARGS="$(SIM_ARGS)" \
	    VHDL_SOURCES="$(VHDL_SOURCES)"
endef

.PHONY: all tb_data_unpacker_outer tb_sorter
