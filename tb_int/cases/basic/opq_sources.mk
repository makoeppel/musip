OPQ_SOURCE_MODE ?= upstream_qsys_generated
MU3E_IP_CORES_ROOT ?= $(ROOT)/external/mu3e-ip-cores
OPQ_N_SHD ?= 128
OPQ_LANE_FIFO_DEPTH ?= 1024
OPQ_TICKET_FIFO_DEPTH ?= 512
OPQ_HANDLE_FIFO_DEPTH ?= 64
OPQ_PAGE_RAM_DEPTH ?= 65536

OPQ_LOCAL_DIR := $(ROOT)/firmware/a10_board/a10/merger
OPQ_QSYS_DIR := $(OPQ_LOCAL_DIR)/qsys/opq_upstream_4lane_native_sv
OPQ_QSYS_GEN_DIR := $(OPQ_QSYS_DIR)/generated
OPQ_QSYS_SYNTH_DIR := $(OPQ_QSYS_GEN_DIR)/synth
OPQ_QSYS_WRAPPER_VHDL := $(OPQ_QSYS_SYNTH_DIR)/opq_upstream_4lane.vhd
OPQ_QSYS_COMPONENT_LIB := $(strip $(shell awk '/^library / && $$2 != "IEEE;" { gsub(/;/, "", $$2); print $$2; exit }' $(OPQ_QSYS_SYNTH_DIR)/opq_upstream_4lane.vhd 2>/dev/null))
OPQ_QSYS_COMPONENT_SYNTH_DIR := $(patsubst %/,%,$(firstword $(sort $(dir $(wildcard $(OPQ_QSYS_GEN_DIR)/*/synth/*_pkg.vhd)))))
OPQ_QSYS_FILE := $(OPQ_QSYS_DIR)/opq_upstream_4lane.qsys
OPQ_QSYS_TCL := $(OPQ_QSYS_DIR)/opq_upstream_4lane.tcl
OPQ_QSYS_QIP := $(OPQ_QSYS_GEN_DIR)/opq_upstream_4lane.qip
OPQ_AUTH_QSYS_DIR := $(MU3E_IP_CORES_ROOT)/packet_scheduler/syn/quartus/opq_monolithic_4lane_merge
OPQ_AUTH_SYN_DIR := $(OPQ_AUTH_QSYS_DIR)/generated/synthesis
OPQ_AUTH_SUBMODULE_DIR := $(OPQ_AUTH_SYN_DIR)/submodules
OPQ_AUTH_QSYS_FILE := $(OPQ_AUTH_QSYS_DIR)/opq_monolithic_4lane_merge.qsys
OPQ_AUTH_QSYS_TCL := $(OPQ_AUTH_QSYS_DIR)/opq_monolithic_4lane_merge.tcl
OPQ_AUTH_HW_TCL := $(MU3E_IP_CORES_ROOT)/packet_scheduler/script/ordered_priority_queue_v2_hw.tcl

OPQ_SIGNOFF_DIR := $(MU3E_IP_CORES_ROOT)/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff
OPQ_SIGNOFF_COMPAT_DIR := $(OPQ_SIGNOFF_DIR)/src_compat
OPQ_SIGNOFF_RTL_DIR := $(MU3E_IP_CORES_ROOT)/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv
OPQ_SIGNOFF_VENDOR_DIR := $(MU3E_IP_CORES_ROOT)/packet_scheduler/rtl/sv_ver/vendor/alt_ram
OPQ_SIGNOFF_HW_TCL := $(MU3E_IP_CORES_ROOT)/packet_scheduler/script/ordered_priority_queue_hw.tcl

OPQ_VHDL_DUT_SOURCES =
OPQ_VERILOG_DUT_SOURCES =
OPQ_SV_DUT_SOURCES =
OPQ_SIM_EXTRA_LIBS =
OPQ_SIM_QSYS_LIB =
OPQ_SIM_QSYS_VHDL_SOURCES =
OPQ_SIM_QSYS_VERILOG_SOURCES =
OPQ_VSIM_LIB_FLAGS =
OPQ_INTEL_PRIM_SIM_LIB_FLAGS = -L altera_mf_ver -L 220model_ver -L altera_mf -L 220model
OPQ_DUT_DEFINES =

ifeq ($(OPQ_SOURCE_MODE),upstream_qsys_generated)
OPQ_SIM_EXTRA_LIBS = $(OPQ_QSYS_COMPONENT_LIB)
OPQ_SIM_QSYS_LIB = $(OPQ_QSYS_COMPONENT_LIB)
OPQ_VSIM_LIB_FLAGS = $(OPQ_INTEL_PRIM_SIM_LIB_FLAGS) -L $(OPQ_SIM_QSYS_LIB)

OPQ_VHDL_DUT_SOURCES = \
	$(OPQ_QSYS_WRAPPER_VHDL)

OPQ_SIM_QSYS_VHDL_SOURCES = \
	$(shell find $(OPQ_QSYS_COMPONENT_SYNTH_DIR) -type f -name '*.vhd' | sort)

OPQ_SIM_QSYS_VERILOG_SOURCES = \
	$(shell find $(OPQ_QSYS_COMPONENT_SYNTH_DIR) -type f \( -name '*.v' -o -name '*.sv' \) | sort)

# The generated Qsys wrapper bakes the fixed profile into its top-level SV,
# but the submodules are compiled as separate SystemVerilog units. Keep the
# command-line defines pinned to the same packaged values so every compile unit
# sees the identical 4-lane / N_SHD contract as the synthesis QIP.
OPQ_DUT_DEFINES = \
	+define+OPQ_USE_NATIVE_SV \
	+define+OPQ_N_LANE=4 \
	+define+OPQ_N_SHD=$(OPQ_N_SHD) \
	+define+OPQ_N_HIT=2047 \
	+define+OPQ_LANE_FIFO_DEPTH=$(OPQ_LANE_FIFO_DEPTH) \
	+define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH) \
	+define+OPQ_HANDLE_FIFO_DEPTH=$(OPQ_HANDLE_FIFO_DEPTH) \
	+define+OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH)

else ifeq ($(OPQ_SOURCE_MODE),native_sv_signoff)
OPQ_VSIM_LIB_FLAGS = $(OPQ_INTEL_PRIM_SIM_LIB_FLAGS)
OPQ_VHDL_DUT_SOURCES = \
	$(OPQ_LOCAL_DIR)/opq_native_sv_pkg.vhd

OPQ_VERILOG_DUT_SOURCES = \
	$(OPQ_SIGNOFF_VENDOR_DIR)/frame_table.v \
	$(OPQ_SIGNOFF_COMPAT_DIR)/handle_fifo.v \
	$(OPQ_SIGNOFF_COMPAT_DIR)/lane_fifo.v \
	$(OPQ_SIGNOFF_COMPAT_DIR)/page_ram.v \
	$(OPQ_SIGNOFF_COMPAT_DIR)/ticket_fifo.v \
	$(OPQ_SIGNOFF_VENDOR_DIR)/tile_fifo.v

OPQ_SV_DUT_SOURCES = \
	$(OPQ_SIGNOFF_RTL_DIR)/ordered_priority_queue_monolithic_ingress_parser.sv \
	$(OPQ_SIGNOFF_RTL_DIR)/ordered_priority_queue_monolithic_page_allocator.sv \
	$(OPQ_SIGNOFF_COMPAT_DIR)/ordered_priority_queue_monolithic_block_path.sv \
	$(OPQ_SIGNOFF_RTL_DIR)/ordered_priority_queue_monolithic_frame_table_tracker.sv \
	$(OPQ_SIGNOFF_COMPAT_DIR)/ordered_priority_queue_monolithic_frame_table_presenter.sv \
	$(OPQ_SIGNOFF_RTL_DIR)/ordered_priority_queue_monolithic_basic_presenter.sv \
	$(OPQ_SIGNOFF_COMPAT_DIR)/ordered_priority_queue_monolithic.sv \
	$(OPQ_SIGNOFF_COMPAT_DIR)/ordered_priority_queue_dut_sv.sv
OPQ_DUT_DEFINES = \
	+define+OPQ_USE_NATIVE_SV \
	+define+OPQ_N_LANE=4 \
	+define+OPQ_N_SHD=$(OPQ_N_SHD) \
	+define+OPQ_LANE_FIFO_DEPTH=$(OPQ_LANE_FIFO_DEPTH) \
	+define+OPQ_TICKET_FIFO_DEPTH=$(OPQ_TICKET_FIFO_DEPTH) \
	+define+OPQ_HANDLE_FIFO_DEPTH=$(OPQ_HANDLE_FIFO_DEPTH) \
	+define+OPQ_PAGE_RAM_DEPTH=$(OPQ_PAGE_RAM_DEPTH)
else ifeq ($(OPQ_SOURCE_MODE),qsys_authentic)
OPQ_VSIM_LIB_FLAGS = $(OPQ_INTEL_PRIM_SIM_LIB_FLAGS)

OPQ_VHDL_DUT_SOURCES = \
	$(OPQ_AUTH_SUBMODULE_DIR)/opq_monolithic_4lane_merge_opq_0.vhd

OPQ_VERILOG_DUT_SOURCES = \
	$(OPQ_AUTH_SUBMODULE_DIR)/handle_fifo.v \
	$(OPQ_AUTH_SUBMODULE_DIR)/lane_fifo.v \
	$(OPQ_AUTH_SUBMODULE_DIR)/ticket_fifo.v \
	$(OPQ_AUTH_SUBMODULE_DIR)/page_ram.v \
	$(OPQ_AUTH_SUBMODULE_DIR)/tile_fifo.v
else ifeq ($(OPQ_SOURCE_MODE),qsys_wrapper)
OPQ_SIM_EXTRA_LIBS = opq_monolithic_4lane_merge
OPQ_SIM_QSYS_LIB = opq_monolithic_4lane_merge
OPQ_VSIM_LIB_FLAGS = $(OPQ_INTEL_PRIM_SIM_LIB_FLAGS) -L $(OPQ_SIM_QSYS_LIB)

OPQ_VHDL_DUT_SOURCES = \
	$(OPQ_LOCAL_DIR)/opq_upstream_4lane_compat.vhd

OPQ_SIM_QSYS_VHDL_SOURCES = \
	$(OPQ_LOCAL_DIR)/opq_monolithic_4lane_merge_opq_0.vhd \
	$(OPQ_LOCAL_DIR)/opq_monolithic_4lane_merge.vhd

OPQ_SIM_QSYS_VERILOG_SOURCES = \
	$(OPQ_LOCAL_DIR)/frame_table.v \
	$(OPQ_LOCAL_DIR)/ticket_fifo.v \
	$(OPQ_LOCAL_DIR)/lane_fifo.v \
	$(OPQ_LOCAL_DIR)/handle_fifo.v \
	$(OPQ_LOCAL_DIR)/page_ram.v \
	$(OPQ_LOCAL_DIR)/tile_fifo.v
else
$(error Unsupported OPQ_SOURCE_MODE='$(OPQ_SOURCE_MODE)'; expected 'qsys_authentic', 'upstream_qsys_generated', 'native_sv_signoff', or 'qsys_wrapper')
endif
