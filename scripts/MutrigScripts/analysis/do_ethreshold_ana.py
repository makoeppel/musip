import sys
sys.path.append("../../")

import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.eth_selection as eth_ana
import mutrig.ethreshold_scan as eth_scan
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
    data = eth_ana.read_data(filename)    
    eths_arr, bad_channels, channels_details = eth_ana.select_rate(data,constrate_value=1e0,ratecut=10, skip=4)
    eth_scan.write_config_odb(eths_arr, data['settings'], path = filename_output)
