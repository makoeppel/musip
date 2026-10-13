#!/usr/bin/env -S python3
import sys
sys.path.append("../../")

import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.tth_selection as tth_ana
import mutrig.tthreshold_scan as tth_scan
import mutrig.Mutrig_basic_functions as m
import sys
import os

# Standalone / Tests main routine
if __name__ == "__main__":
    global seq;

    args = sys.argv[1:]
    if len(args) < 1:
        quit()
    
    filename = args[0]
    filename_output=filename+".calib.json"
    if len(args) > 1:
        filename_output = args[1]
        
    tths_arr, offsets_arr, bad_channels, channels_details = tth_ana.select_rate(filename,constrate_value=1e5,ratecut=2e5, skip=4)
    tth_scan.write_config_odb(tths_arr, offsets_arr, path = filename_output)


