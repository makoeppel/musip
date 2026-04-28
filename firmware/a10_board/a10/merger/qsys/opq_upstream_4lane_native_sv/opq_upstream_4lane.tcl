package require -exact qsys 16.1

create_system {opq_upstream_4lane}

set_project_property DEVICE_FAMILY {Arria 10}
set_project_property HIDE_FROM_IP_CATALOG {false}

add_instance opq_0 ordered_priority_queue_native_sv_fixed4 26.4.13.0428

add_interface clk clock sink
set_interface_property clk EXPORT_OF opq_0.clk_interface

add_interface reset reset sink
set_interface_property reset EXPORT_OF opq_0.rst_interface

add_interface ingress_0 avalon_streaming sink
set_interface_property ingress_0 EXPORT_OF opq_0.ingress_0

add_interface ingress_1 avalon_streaming sink
set_interface_property ingress_1 EXPORT_OF opq_0.ingress_1

add_interface ingress_2 avalon_streaming sink
set_interface_property ingress_2 EXPORT_OF opq_0.ingress_2

add_interface ingress_3 avalon_streaming sink
set_interface_property ingress_3 EXPORT_OF opq_0.ingress_3

add_interface egress avalon_streaming source
set_interface_property egress EXPORT_OF opq_0.egress

add_interface csr avalon slave
set_interface_property csr EXPORT_OF opq_0.csr

save_system {opq_upstream_4lane.qsys}
