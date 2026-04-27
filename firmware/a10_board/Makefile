#

CABLE:=DE5
CABLE_DEVICE:=^10A

VERILOG_MACROS += \
    SYNTHESIS=1 \
    OPQ_USE_NATIVE_SV \
    OPQ_N_LANE=4 \
    OPQ_N_SHD=256 \
    OPQ_N_HIT=2047 \
    OPQ_TICKET_FIFO_DEPTH=1024 \
    OPQ_PAGE_RAM_DEPTH=65536

OPQ_QSYS_DIR := a10/merger/qsys/opq_upstream_4lane_native_sv
OPQ_QSYS_HW_TCL := $(OPQ_QSYS_DIR)/ordered_priority_queue_native_sv_fixed4_hw.tcl
OPQ_QSYS_TCL := $(OPQ_QSYS_DIR)/opq_upstream_4lane.tcl
OPQ_QSYS_FILE := $(OPQ_QSYS_DIR)/opq_upstream_4lane.qsys
OPQ_QSYS_QIP := $(OPQ_QSYS_DIR)/generated/opq_upstream_4lane.qip
QSYS_SCRIPT ?= $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-script
QSYS_GENERATE ?= $(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-generate

IPs = \
    $(wildcard a10/ip/*.tcl) \
    $(wildcard a10/pcieapp/*.tcl) \
    $(wildcard a10/*.vhd.envsubst) \
    nios.tcl

include util/quartus/makefile.mk

.PHONY : opq_qsys_unpack opq_qsys_regen
opq_qsys_unpack : $(OPQ_QSYS_QIP)

$(OPQ_QSYS_FILE) : $(OPQ_QSYS_TCL) $(OPQ_QSYS_HW_TCL)
	( cd "$(OPQ_QSYS_DIR)" && "$(QSYS_SCRIPT)" --search-path=".,$$" --script="$(notdir $(OPQ_QSYS_TCL))" )

$(OPQ_QSYS_QIP) : $(OPQ_QSYS_FILE) $(OPQ_QSYS_HW_TCL)
	"$(QSYS_GENERATE)" --synthesis=VHDL --output-directory="$(OPQ_QSYS_DIR)/generated" --search-path="$(abspath $(OPQ_QSYS_DIR)),$$" "$(OPQ_QSYS_FILE)"

opq_qsys_regen :
	rm -rf -- "$(OPQ_QSYS_DIR)/generated"
	rm -f -- "$(OPQ_QSYS_FILE)" "$(OPQ_QSYS_DIR)/opq_upstream_4lane.sopcinfo"
	$(MAKE) opq_qsys_unpack

all app flow_map : opq_qsys_unpack
flow :: opq_qsys_unpack

flash :
	../a10_tcl/program.sh
