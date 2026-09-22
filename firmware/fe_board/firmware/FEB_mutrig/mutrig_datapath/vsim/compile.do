vcom -2008 -suppress vcom-1594 ../../../../../common/firmware/util/util_pkg.vhd
vcom -2008 -suppress vcom-1594 ../../../../../common/firmware/util/ff_sync.vhd
vcom -2008 -suppress vcom-1594 ../../../../../common/firmware/util/reset_sync.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/registers/mudaq.vhd
vcom -reportprogress 300 -2008 ../../../../../common/firmware/registers/mutrig.vhd

#vcom -reportprogress 300 -2008 ../../lvds/datadecoder.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/fifo_reg.vhd
vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/quartus/ip_dcfifo_v2.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/quartus/ip_ram_1rw.vhd
vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/quartus/ip_ram_2rw.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/a10/link/mu3e_pkg.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/stream_merger.vhd

vcom -reportprogress 300 -2008 ../../mutrig_datapath/source/ch_rate.vhd
# vcom -reportprogress 300 -2008 ../../lvds/receiver_block.vhd
# vcom -reportprogress 300 -2008 ../../frame_rcv/crc16_calc.vhd
# vcom -reportprogress 300 -2008 ../../dummys/stic_dummy_data.vhd
vcom -reportprogress 300 -2008 ../../frame_rcv/frame_rcv.vhd
 #needed?
vcom -reportprogress 300 -2008 ../../frame_rcv/replace_length.vhd
vcom -reportprogress 300 -2008 ../../frame_rcv/link_data.vhd
vcom -reportprogress 300 -2008 ../../mutrig_store/prbs48_checker.vhd

vcom -reportprogress 300 -2008 ../../../../../common/firmware/util/counter.vhd
vcom -reportprogress 300 -2008 ../../mutrig_store/mutrig_store.vhd
vcom -reportprogress 300 -2008 ../../framebuilder_mux/framebuilder_mux_v2.vhd
vcom -reportprogress 300 -2008 ../../framebuilder_mux//data_unpacker.vhd


# vcom -reportprogress 300 -2008 ../../prbs_dec/source/prbs_decoder.vhd
vcom -reportprogress 300 -2008 ../../lapse_counter.vhd

vcom -reportprogress 300 -2008 ../../mutrig_datapath/source/mutrig_datapath.vhd

#vcom -2008 ../../../FEB_common/common_fifo.vhd


vcom -2008 ../../mutrig_datapath/testbench/testbench.vhd
#com -2008 ../../mutrig_datapath/testbench/testbench_standalone.vhd
vcom -2008 -work ../../reset_shift/ip_reset_shift.vhd
vcom -2008 -work ../../reset_shift/obuf_config.vhd
vcom -2008 -work ../../reset_shift/rst_shift_block.vhd
