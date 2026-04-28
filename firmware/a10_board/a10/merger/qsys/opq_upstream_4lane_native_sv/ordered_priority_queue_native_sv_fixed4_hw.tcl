package require -exact qsys 16.1

set_module_property NAME                         ordered_priority_queue_native_sv_fixed4
set_module_property DISPLAY_NAME                 "Ordered Priority Queue Native SV Fixed4"
set_module_property VERSION                      26.4.13.0428
set_module_property GROUP                        "Mu3e Data Plane/Modules"
set_module_property DESCRIPTION                  "Fixed-profile 4-lane native-SV OPQ wrapper for MuSiP integration"
set_module_property AUTHOR                       "Yifeng Wang / Codex local packaging"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     false
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false

add_fileset synth QUARTUS_SYNTH
set_fileset_property synth TOP_LEVEL ordered_priority_queue_dut_sv
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_dut_sv.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_block_path.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ordered_priority_queue_monolithic_frame_table_presenter.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_basic_presenter.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_frame_table_tracker.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_ingress_parser.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv" SYSTEM_VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/ordered_priority_queue/monolithic_sv/ordered_priority_queue_monolithic_page_allocator.sv"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/handle_fifo.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/handle_fifo.v"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/lane_fifo.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/lane_fifo.v"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/page_ram.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/page_ram.v"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/syn/quartus/opq_native_sv_4lane_signoff/src_compat/ticket_fifo.v"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/vendor/alt_ram/frame_table.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/vendor/alt_ram/frame_table.v"
add_fileset_file "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/vendor/alt_ram/tile_fifo.v" VERILOG PATH "../../../../../../external/mu3e-ip-cores/packet_scheduler/rtl/sv_ver/vendor/alt_ram/tile_fifo.v"

add_interface egress avalon_streaming start
set_interface_property egress associatedClock clk_interface
set_interface_property egress associatedReset rst_interface
set_interface_property egress dataBitsPerSymbol 36
set_interface_property egress errorDescriptor {hit_err shd_err hdr_err}
set_interface_property egress firstSymbolInHighOrderBits true
set_interface_property egress readyLatency 0
set_interface_property egress ENABLED true
add_interface_port egress aso_egress_startofpacket startofpacket Output 1
add_interface_port egress aso_egress_endofpacket endofpacket Output 1
add_interface_port egress aso_egress_valid valid Output 1
add_interface_port egress aso_egress_ready ready Input 1
add_interface_port egress aso_egress_error error Output 3
add_interface_port egress aso_egress_data data Output 36

add_interface clk_interface clock end
set_interface_property clk_interface clockRate 0
set_interface_property clk_interface ENABLED true
add_interface_port clk_interface d_clk clk Input 1

add_interface rst_interface reset end
set_interface_property rst_interface associatedClock clk_interface
set_interface_property rst_interface synchronousEdges BOTH
set_interface_property rst_interface ENABLED true
add_interface_port rst_interface d_reset reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clk_interface
set_interface_property csr associatedReset rst_interface
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr burstcountUnits WORDS
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 1
set_interface_property csr maximumPendingWriteTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input 9
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_readdatavalid readdatavalid Output 1
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
add_interface_port csr avs_csr_burstcount burstcount Input 1

foreach lane {0 1 2 3} {
    add_interface ingress_${lane} avalon_streaming end
    set_interface_property ingress_${lane} associatedClock clk_interface
    set_interface_property ingress_${lane} associatedReset rst_interface
    set_interface_property ingress_${lane} dataBitsPerSymbol 36
    set_interface_property ingress_${lane} errorDescriptor {hit_err shd_err hdr_err}
    set_interface_property ingress_${lane} firstSymbolInHighOrderBits true
    set_interface_property ingress_${lane} maxChannel 3
    set_interface_property ingress_${lane} readyLatency 0
    set_interface_property ingress_${lane} ENABLED true
    add_interface_port ingress_${lane} asi_ingress_${lane}_channel channel Input 2
    add_interface_port ingress_${lane} asi_ingress_${lane}_startofpacket startofpacket Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_endofpacket endofpacket Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_data data Input 36
    add_interface_port ingress_${lane} asi_ingress_${lane}_valid valid Input 1
    add_interface_port ingress_${lane} asi_ingress_${lane}_error error Input 3
}
