onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /spiflash_tb/reset_n
add wave -noupdate -radix hexadecimal /spiflash_tb/clk
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_strobe
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_ack
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_command
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_addr
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_data
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_next_byte
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_continue
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_byte_out
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_byte_ready
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_sclk
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_csn
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_mosi
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_miso
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_D2
add wave -noupdate -radix hexadecimal /spiflash_tb/spi_D3
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/spi_state
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/strobe_last
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/shiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/dualshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/quadshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/count
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/dummycount
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/toggle
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/readbyteshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/dualreadbyteshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/quadreadbyteshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/dummyread
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/writeshiftreg
add wave -noupdate -radix hexadecimal /spiflash_tb/dut/quadwriteshiftreg
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 206
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
WaveRestoreZoom {7854014 ps} {8852708 ps}
