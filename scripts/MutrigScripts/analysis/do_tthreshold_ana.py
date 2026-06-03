#!/usr/bin/env -S python3
import sys
#sys.path.append("../../../python/")
sys.path.append("../../")
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.rate_calibration as rc
import mutrig.tthreshold_scan as tth_scan
import mutrig.Mutrig_basic_functions as m
import sys
import os

# Standalone / Tests main routine
if __name__ == "__main__":
    global seq;
    filename = "/home/nemu/musip/scripts/MutrigScripts/data/FP_adptrB.json"
    filename_output = "/home/nemu/musip/scripts/MutrigScripts/data/FP_tth.json"

        
    tths_arr, offsets_arr, bad_channels, channels_details = rc.select_tth(filename,constrate=True,constrate_value=100000,high_to_low = False,debug = False)
    #tths_arr, offsets_arr, bad_channels, channels_details = rc.select_tth(filename, 16)
    tth_scan.write_config_odb(tths_arr, offsets_arr, path = filename_output)


