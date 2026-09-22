quit -sim
vlib work
project compileall
vsim work.tb_sc_new(rtl)

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group tb_top /tb_sc_new/*
add wave -noupdate -group sc_ram /tb_sc_new/e_sc_ram/*
add wave -noupdate -group sc_node_lvl0 /tb_sc_new/e_lvl0_sc_node/*
add wave -noupdate -group sc_node_lvl1 /tb_sc_new/e_lvl1_sc_node/*
add wave -noupdate -group sc_node_lvl2 /tb_sc_new/e_lvl2_sc_node/*
add wave -noupdate -group reg_mapping /tb_sc_new/e_reg_mapping/*
add wave -noupdate -group reg_mapping_mupix_ctrl /tb_sc_new/e_reg_mapping_mupix_ctrl/*
add wave -noupdate -group reg_mapping_mupix_datapath /tb_sc_new/e_reg_mapping_mupix_datapath/*

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4127596 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 367
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
radix -hexadecimal

-- read feb common sc regs
force -freeze /tb_sc_new/data_in x"000000BC"
force -freeze /tb_sc_new/datak_in x"1"
run 100ns
force -freeze /tb_sc_new/data_in x"1C0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"0000fC25"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000002"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- write mupix datapath sc regs
run 100ns
force -freeze /tb_sc_new/data_in x"1D0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"00001006"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000002"
run 20ns
force -freeze /tb_sc_new/data_in x"CAFECAFE"
run 20ns
force -freeze /tb_sc_new/data_in x"AFFEAFFE"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- read mupix ctrl
run 100ns
force -freeze /tb_sc_new/data_in x"1C0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"0000040F"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000003"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- read mupix datapath sc regs
run 100ns
force -freeze /tb_sc_new/data_in x"1E0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"00001006"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000003"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- write to internal RAM
force -freeze /tb_sc_new/data_in x"1D0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"00000025"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000003"
run 20ns
force -freeze /tb_sc_new/data_in x"00000012"
run 20ns
force -freeze /tb_sc_new/data_in x"00000013"
run 20ns
force -freeze /tb_sc_new/data_in x"00000014"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- read internal RAM
force -freeze /tb_sc_new/data_in x"1C0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"00000025"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000005"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 300ns

-- read req from nios to feb common registers
force -freeze /tb_sc_new/av_sc_address x"0000fc25"
force -freeze /tb_sc_new/av_sc_read '1'
run 160ns
force -freeze /tb_sc_new/av_sc_read '0'
run 200ns

-- write req from nios to feb common registers
force -freeze /tb_sc_new/av_sc_address x"0000FC25"
force -freeze /tb_sc_new/av_sc_writedata x"C0FFEE00"
force -freeze /tb_sc_new/av_sc_write '1'
run 60ns
force -freeze /tb_sc_new/av_sc_write '0'
run 200ns

-- send nios read into sc read
force -freeze /tb_sc_new/data_in x"1C0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"0000FC25"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000010"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 180ns
force -freeze /tb_sc_new/av_sc_address x"0000FC26"
force -freeze /tb_sc_new/av_sc_read '1'
run 340ns
force -freeze /tb_sc_new/av_sc_read '0'
run 1000ns

-- send sc read into nios read
force -freeze /tb_sc_new/av_sc_address x"0000FC25"
force -freeze /tb_sc_new/av_sc_read '1'
run 20ns
force -freeze /tb_sc_new/data_in x"1C0000BC"
run 20ns
force -freeze /tb_sc_new/data_in x"0000FC25"
force -freeze /tb_sc_new/datak_in x"0"
run 20ns
force -freeze /tb_sc_new/data_in x"00000020"
run 20ns
force -freeze /tb_sc_new/data_in x"0000009C"
force -freeze /tb_sc_new/datak_in x"1"
run 20ns
force -freeze /tb_sc_new/data_in x"000000BC"
run 60ns
force -freeze /tb_sc_new/av_sc_read '0'
run 2000ns
WaveRestoreZoom 0ns 10000ns
