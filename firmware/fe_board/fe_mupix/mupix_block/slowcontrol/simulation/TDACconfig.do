quit -sim
vlib work
project compileall
vsim work.mupix_ctrl_tb(rtl)

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate /mupix_ctrl_tb/clk
add wave -noupdate /mupix_ctrl_tb/reset_n
add wave -noupdate /mupix_ctrl_tb/reg_we
add wave -noupdate /mupix_ctrl_tb/reg_addr
add wave -noupdate /mupix_ctrl_tb/reg_wdata
add wave -noupdate -group mp_ctrl /mupix_ctrl_tb/e_mp_ctrl/*
add wave -noupdate -group mp_ctrl_regs /mupix_ctrl_tb/e_mp_ctrl/e_mupix_ctrl_reg_mapping/*
add wave -noupdate -group spi /mupix_ctrl_tb/e_mp_ctrl/gen_spi(0)/mp_ctrl_spi_inst/*
add wave -noupdate -group direct_spi /mupix_ctrl_tb/e_mp_ctrl/gen_spi(0)/mp_ctrl_direct_spi_inst/*
add wave -noupdate -group direct_spi_fifo /mupix_ctrl_tb/e_mp_ctrl/gen_spi(0)/mp_ctrl_direct_spi_inst/direct_spi_fifo/*
add wave -noupdate -group conf_storage /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/*
add wave -noupdate -group conf_splitter /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/mp_conf_splitter/*
add wave -noupdate -group bias_dpf /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/gen_dp_fifos(0)/bias/*
add wave -noupdate -group conf_dpf /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/gen_dp_fifos(0)/conf/*
add wave -noupdate -group vdac_dpf /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/gen_dp_fifos(0)/vdac/*
add wave -noupdate -group tdac_dpf /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/gen_dp_fifos(0)/tdac/*
add wave -noupdate -group tdac_mem /mupix_ctrl_tb/e_mp_ctrl/mupix_ctrl_config_storage_inst/tdac_memory/*

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
force -freeze mupix_ctrl_tb/reg_re 0
run 8000ns
set TIME_start [clock clicks -milliseconds]


--------------------------------
-- copy of nios code into sim
    set pos 0
    set hexpos 0x0
    set n_cycles_without_write 0

    echo "testing tdac write ..."
    force -freeze mupix_ctrl_tb/reg_we 1
    force -freeze mupix_ctrl_tb/reg_addr [examine mupix_registers/MP_CTRL_SPI_ENABLE_REGISTER_W]
    force -freeze mupix_ctrl_tb/reg_wdata "x00000001"
    run 8ns
    force -freeze mupix_ctrl_tb/reg_addr [examine mupix_registers/MP_CTRL_SLOW_DOWN_REGISTER_W]
    force -freeze mupix_ctrl_tb/reg_wdata "x00000004"
    run 8ns
    force -freeze mupix_ctrl_tb/reg_addr [examine mupix_registers/MP_CTRL_RESET_REGISTER_W]
    force -freeze mupix_ctrl_tb/reg_wdata "x00000001"
    run 8ns
    force -freeze mupix_ctrl_tb/reg_addr [examine mupix_registers/MP_CTRL_RESET_REGISTER_W]
    force -freeze mupix_ctrl_tb/reg_wdata "x00000000"
    run 8ns
    force -freeze mupix_ctrl_tb/reg_we 0

    set n_pages_remaining 40
    while {$n_pages_remaining > 0} {
        set n_free_pages [expr {[examine -decimal mupix_ctrl_tb/e_mp_ctrl/e_mupix_ctrl_reg_mapping/i_n_free_pages]}]
        echo "free $n_free_pages, remain $n_pages_remaining"
        if {$n_free_pages > 0} {
            set n_cycles_without_write 0
            echo "write $n_free_pages pages"
            for {set i 0} {$i < $n_free_pages} {incr i} {
                echo "write page $i"

                for {set j 0} {$j < 128} {incr j} {
                    force -freeze mupix_ctrl_tb/reg_we 1
                    force -freeze mupix_ctrl_tb/reg_addr [format 16#%x [expr $pos + 0x[examine mupix_registers/MP_CTRL_TDAC_START_REGISTER_W]]]
                    force -freeze mupix_ctrl_tb/reg_wdata "xAFFEAFFE"
                    run 8ns
                    force -freeze mupix_ctrl_tb/reg_we 0
                    run 40ns
                }
                set n_pages_remaining [expr {$n_pages_remaining - 1}]
                set pos [expr {($pos + 1)%12}]
                set hexpos [format %x $pos]
            }
        } else {
            set n_cycles_without_write [expr {$n_cycles_without_write + 1}]
            set TIME_TAKEN [expr [clock clicks -milliseconds] - $TIME_start]
            echo "usleep 50000us, time taken: $TIME_TAKEN"
            if {$n_cycles_without_write > 100} {
                echo "victory, stuck firmware reproduced"
                return
            }
            run 1000us
        }

    }
echo "done writing"
run 50000us
echo "done in 3"
run 50000us
echo "done in 2"
run 50000us
echo "done in 1"
run 50000us
echo "done"

WaveRestoreZoom 0ns 1000000ns