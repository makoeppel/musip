import sys
sys.path.append("../../../python/")
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.rate_calibration as rc
import mutrig.ethreshold_scan as eth
import mutrig.Mutrig_basic_functions as m
import sys
import os

# Standalone / Tests main routine
if __name__ == "__main__":
    global seq;
    #constrate_value = 10 #10Hz for now, idk 
    constrate_value = 10000 #LED rate
    
    #filename = "/home/mu3e/measurements/SingleMutrigChip/eth_scans/ZiF0_25-02_eth.json"
    filename = "/home/mu3e/git-repos/online_chipQA/online/userfiles/sequencer/MutrigTB/ThresholdScans/scans/Mutrig4/SSBO_eth_35pe.json"
    #filename_output = "./eth_calib_TL2_22-01.json"
    filename_output = "/home/mu3e/measurements/SingleMutrigChip/Mutrig4_2026batch//SSB0_eth_test.json"
    #eths_arr = rc.select_eth(filename,constrate_value,led = True,high_to_low = False,debug = False)
    eths_arr = rc.select_eth_zero(filename, debug=False)
    ths, rates, temperature, settings = eth.read_json(filename)
    eth.write_config_db(eths_arr, settings, path = filename_output)