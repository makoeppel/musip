#
# This file is a [cocotb](https://docs.cocotb.org) testbench to test data_unpacker_outer.vhd
# in simulation. It requires GHDL and cocotb to be installed. You do not invoke this file
# directly from python, there is a Makefile in this directory that builds the simulation
# and runs the test, so just run `make` in this directory.
#

import cocotb, os, types
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from parseQuartusSTPFile import STPFileParser

class ParseMupix11BitstreamReceiver:
    """
    A "receiver" that can be used with `parseQuartusSTPFile` to pull out log data for an outer
    ladder of Mupix11 chips.

    In the constructor you can specify a log name or list of names. If this is provided, only
    logs with one of these names will be processed. Everything else will be ignored. This can
    dramatically speed up processing of a large file containing lots of logs when you're only
    interested in one or two of them.
    """
    def __init__(self, logName):
        # Turn logName into an array of strings if it is not already
        if isinstance(logName, str):
            self._logName = [logName]
        else:
            self._logName = logName

        self.parsedData = {}
        self._currentParse = None

    def dataStart(self, name, signalDescriptions):
        self._rx_data_0 = None
        self._rx_data_1 = None
        self._rx_data_2 = None
        self._rx_k = None
        self._rx_bad = None
        self._rx_ready = None
        self._debug = False

        # If the name of this log doesn't match the one requested by the user, skip all processing.
        # This will speed up analysis of large .stp files significantly.
        if self._logName != None and name not in self._logName:
            return False

        self._currentParse = self.parsedData.setdefault(name, types.SimpleNamespace())
        self._currentParse.data_0 = [];
        self._currentParse.data_1 = [];
        self._currentParse.data_2 = [];
        self._currentParse.k_0 = [];
        self._currentParse.k_1 = [];
        self._currentParse.k_2 = [];
        self._currentParse.bad_0 = [];
        self._currentParse.bad_1 = [];
        self._currentParse.bad_2 = [];
        self._currentParse.ready_0 = [];
        self._currentParse.ready_1 = [];
        self._currentParse.ready_2 = [];

        for index, signal in enumerate(signalDescriptions):
            if signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_data[0][0..7]":
                self._rx_data_0 = index
            elif signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_data[1][0..7]":
                self._rx_data_1 = index
            elif signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_data[2][0..7]":
                self._rx_data_2 = index
            elif signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_k[35..0]":
                self._rx_k = index
            elif signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_bad[35..0]":
                self._rx_bad = index
            elif signal.name() == "mupix_block:e_mupix_block|mupix_datapath:e_mupix_datapath|mupix_receiver_block:lvds_block|o_rx_ready[35..0]":
                self._rx_ready = index

        #
        # Check that we have all of the signals that we need.
        #
        if self._rx_data_0 == None or self._rx_data_1 == None or self._rx_data_2 == None or self._rx_k == None or self._rx_bad == None or self._rx_ready == None:
            print("Unable to find correct signals in", name, self._rx_data_0, self._rx_data_1, self._rx_data_2, self._rx_k, self._rx_bad, self._rx_ready)
            for signal in signalDescriptions:
                print(signal.name(), signal._data_indices)

    def data(self, signalDescriptions, signalData, fullData):
        if self._rx_data_0 == None or self._rx_k == None:
            return

        # These signals appear in the log as we want them
        self._currentParse.data_0.append(signalData[self._rx_data_0])
        self._currentParse.data_1.append(signalData[self._rx_data_1])
        self._currentParse.data_2.append(signalData[self._rx_data_2])
        # These signals only appear as part of a larger bus, so we need to bit manipulate them out
        self._currentParse.k_0.append((signalData[self._rx_k] >> 35) & 0x1)
        self._currentParse.k_1.append((signalData[self._rx_k] >> 34) & 0x1)
        self._currentParse.k_2.append((signalData[self._rx_k] >> 33) & 0x1)
        self._currentParse.bad_0.append((signalData[self._rx_bad] >> 35) & 0x1)
        self._currentParse.bad_1.append((signalData[self._rx_bad] >> 34) & 0x1)
        self._currentParse.bad_2.append((signalData[self._rx_bad] >> 33) & 0x1)
        self._currentParse.ready_0.append((signalData[self._rx_ready] >> 35) & 0x1)
        self._currentParse.ready_1.append((signalData[self._rx_ready] >> 34) & 0x1)
        self._currentParse.ready_2.append((signalData[self._rx_ready] >> 33) & 0x1)

    def dataFinished(self, signalDescriptions):
        pass

def testDirectory():
    """Return the directory where the test inputs are stored."""
    return os.path.join(os.path.dirname(__file__), "test_data")

def getParser(inputStpFilename, logName=None):
    """Returns the parser once it has finished parsing the file with the provided path."""
    fullInputPath = os.path.join(testDirectory(), inputStpFilename)
    reader = STPFileParser()
    receiver = ParseMupix11BitstreamReceiver(logName)
    reader.setReceiver(receiver)
    reader.parse(fullInputPath)
    return receiver

def getInputs(inputStpFilename, logName):
    """Shorthand to get the parsed data for a paricular log name in a particular .stp file"""
    return getParser(inputStpFilename, logName).parsedData[logName]

@cocotb.test()
async def test_no_hits_received(dut):
    """Run a log with no hits where the data_unpacker_outer has previously been reporting hits"""

    # This log is an instance of the unpacker taking data for a while, then `readyin` drops low for
    # a bit, and comes back high. At no point are there hits in this log. The firmware as of commit
    # a8c221f (2026-05-04) reports hits because it is in an inconsistent state when `readyin` comes
    # back high.
    parsedData = getInputs("stp_datalog.stp", "log: Trig @ 2026/03/25 09:41:46 (0:0:0.0 elapsed)")

    dut.reset_n.value           = 0
    dut.clk.value               = 0
    dut.datain.value            = 0x0
    dut.kin.value               = 0
    dut.i_bad.value             = 0
    dut.readyin.value           = 0
    dut.i_mp_readout_mode.value = 0x00000000
    dut.i_slowctrl_empty.value  = 0

    # First run a couple of cycles with reset on (which for this device, means holding it low)
    dut.reset_n.value = 0
    input_clock = Clock(dut.clk, 10, unit="ns")
    input_clock.start()
    await Timer(5, "ns")

    # Re-synchronize with the clock
    await RisingEdge(dut.clk)
    dut.reset_n.value = 1

    not_been_high = True

    for index in range(len(parsedData.data_0)):
        # Set the signals to the correct test data
        dut.datain.value  = parsedData.data_0[index]
        dut.kin.value     = parsedData.k_0[index]
        dut.i_bad.value   = parsedData.bad_0[index]
        dut.readyin.value = parsedData.ready_0[index]

        # Move one cycle
        await RisingEdge(dut.clk)

        # Perform tests.
        # There should be no hits in this file
        assert dut.o_hit_ena.value == 0
