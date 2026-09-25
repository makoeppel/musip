quit -sim
vlib work
project compileall
vsim work.tdac_dp_fifo_tb(rtl)

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate /tdac_dp_fifo_tb/*
add wave -noupdate /tdac_dp_fifo_tb/e_dut/*

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
force -freeze tdac_dp_fifo_tb/we 0
force -freeze tdac_dp_fifo_tb/re1 0
force -freeze tdac_dp_fifo_tb/re2 0
force -freeze tdac_dp_fifo_tb/wdata "x0000000"
run 204ns

-- test read from empty
force -freeze tdac_dp_fifo_tb/re1 1
run 8ns
force -freeze tdac_dp_fifo_tb/re1 0
run 24ns

-- write until full
force -freeze tdac_dp_fifo_tb/we 1
force -freeze tdac_dp_fifo_tb/wdata "xF0F01FC"
run 8ns
force -freeze tdac_dp_fifo_tb/wdata "xAACCAAB"
run 8ns
force -freeze tdac_dp_fifo_tb/wdata "x1111111"
run 8ns
force -freeze tdac_dp_fifo_tb/wdata "xF0F01FC"
run 8ns
force -freeze tdac_dp_fifo_tb/we 0
force -freeze tdac_dp_fifo_tb/wdata "x0000000"
run 80ns

-- read 1 once
force -freeze tdac_dp_fifo_tb/re1 1
run 8ns
force -freeze tdac_dp_fifo_tb/re1 0
run 40ns

-- read 1
force -freeze tdac_dp_fifo_tb/re1 1
run 40ns
force -freeze tdac_dp_fifo_tb/re1 0
run 40ns

-- read 2 until empty
force -freeze tdac_dp_fifo_tb/re2 1
run 80ns
force -freeze tdac_dp_fifo_tb/re2 0
run 80ns

WaveRestoreZoom 0ns 5000ns
