"""
A testbench for cocotb to test the outer pixel unpacker, hit multiplexer and sorter.
It reads data from a .stp file and pumps it through the chain.

** Note that you don't execute this python file in the traditional sense **
There is a Makefile in this directory that will compile it into an executable. Just `cd`
to this directory and run `make`.

** The input file used in this test has not been included in the repository **
We haven't figured out how we're going to distribute these large files yet. When we
do I'll update here. Until then just ask me for the file.

Mark Grimes 2026-06-04
"""

import cocotb, os, types
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# Reuse the code from tb_data_unpacker_outer.py to pull out the signal we need from the .stp file
from tb_data_unpacker_outer import ParseMupix11BitstreamReceiver, testDirectory, getParser, getInputs

@cocotb.test()
async def test_source_scan(dut):
    """Run a log taken from a source scan. Currently no tests, just checking what data is in the file"""

    # Pick out particular logs from the file. If `selectedLogs = None` then all logs
    # are processed, but this is much, much slower.
    selectedLogs = [
        'log: Trig @ 2026/06/04 10:10:54 (0:0:0.1 elapsed)'  # has 41 hits coming out of the multiplexer and currently 1 out of the sorter
    ]
    cocotb.log.info("Starting parse of .stp file")
    # If you get an error here it's because we don't ship the test file with the code.
    # It's too large. So you'll need to get it by some other method.
    allLogs = getParser("source_scan0_04062026.stp", selectedLogs).parsedData
    cocotb.log.info(f"Finished parse of .stp file. Have data from {len(allLogs)} logs")

    for logName, parsedData in allLogs.items():
        # cocotb.log.info(f'Processing log "{logName}"')

        dut.i_reset_n.value        = 0
        dut.i_clk.value            = 0
        dut.datain_0.value         = 0x0
        dut.datain_1.value         = 0x0
        dut.datain_2.value         = 0x0
        dut.kin.value              = 0
        dut.i_bad.value            = 0
        dut.readyin.value          = 0
        dut.i_slowctrl_empty.value = 0
        dut.i_sync_reset_cnt.value = 0
        dut.i_running.value        = 0

        # First run a couple of cycles with reset on (which for this device, means holding it low)
        dut.i_reset_n.value = 0
        input_clock = Clock(dut.i_clk, 10, unit="ns")
        input_clock.start()
        await Timer(5, "ns")

        # Re-synchronize with the clock
        await RisingEdge(dut.i_clk)
        dut.i_reset_n.value = 1
        # Also set the sorter into running
        dut.i_running.value = 1

        for index in range(len(parsedData.data_0)):
            all_kin     = (parsedData.k_2[index]     << 2) | (parsedData.k_1[index]     << 1) | parsedData.k_0[index]
            all_bad     = (parsedData.bad_2[index]   << 2) | (parsedData.bad_1[index]   << 1) | parsedData.bad_0[index]
            all_readyin = (parsedData.ready_2[index] << 2) | (parsedData.ready_1[index] << 1) | parsedData.ready_0[index]
            # Set the signals to the correct test data
            dut.datain_0.value  = parsedData.data_0[index]
            dut.datain_1.value  = parsedData.data_1[index]
            dut.datain_2.value  = parsedData.data_2[index]
            dut.kin.value     = all_kin
            dut.i_bad.value   = all_bad
            dut.readyin.value = all_readyin

            # Move one cycle
            await RisingEdge(dut.i_clk)

        #
        # We want to give the sorter enough time to provide its output. So run until
        # we see the end packet sequence, or an arbitrary cut off
        #
        # Clear the input signals
        dut.datain_0.value = 0
        dut.datain_1.value = 0
        dut.datain_2.value = 0
        dut.kin.value      = 0
        dut.i_bad.value    = 0
        dut.readyin.value  = 0
        MERGER_FIFO_PAKET_END_MARKER = 0x0011 # From common/firmware/registers/mudaq.vhd
        arbitrary_limit_exceeded = True
        for index in range(10000):
            await RisingEdge(dut.i_clk)
            if dut.e_sorter.out_type.value == MERGER_FIFO_PAKET_END_MARKER:
                arbitrary_limit_exceeded = False
                break
        if arbitrary_limit_exceeded: cocotb.log.info(f"Cut short before sorter end packet marker")

        # Make sure the number of hits going into the sorter is the same that come out of the sorter
        assert int(dut.debug_nmultiplexer_hits.value) == int(dut.debug_nsorter_out_hits.value)
