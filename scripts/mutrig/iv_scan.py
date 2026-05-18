# scan IV for one module - 4 HV channels, based on the TLD_IV_Scan_per_module.msl

#CALL TLD_IV_scan_per_module, $start_voltage(def = 45), $stop_voltage(def = 57), $num_steps(def = 30), $at_psi, $Module_number
#should depend on start/stop voltage, number of steps, module number(?), HV board number (0 or 1)

import time
import midas.client as client
import midas.sequencer as sequencer
import re
import json
from datetime import datetime
import numpy as np
import mutrig.base_variables as cfg

import mutrig.Mutrig_basic_functions as m

path_this_scan = f"/Tests/Mutrig/iv_scan"
# module-level storage so an external interrupt handler can restore settings
_original_settings = {}
hv_channels = 4 # change this if we want to scan more than one module

def Get_HV_path(setting, index=None):
    if index is not None:
        return f"{cfg.path_hv}/Variables/{setting}[{index}]"
    else:
        return f"{cfg.path_hv}/Variables/{setting}"

def Get_HV_index(client, name):
    index = -1
    #channel_names = client.odb_get(f"{cfg.path_hv}/Settings/Names");
    for i in range(8): # change this to have len(HV channels)
        channel_name = client.odb_get(f"{cfg.path_hv}/Settings/Names[{i}]");
        #channel_name = channel_names[i]
        if channel_name == name:
            index = i
    return index

def Store_HV_Settings(client):
    settings=client.odb_get(f"{cfg.path_hv}/Variables/Demand")
    return settings
        
def Restore_HV_Settings(client,settings):
    settings=client.odb_set(f"{cfg.path_hv}/Variables/Demand",settings)
        
def scan(seq, hv_board, start_voltage, stop_voltage, num_steps, wait_time):
    '''
    Pythonized version of original sequencer script for IV scan
    args:
        seq - MIDAS seq that connects with the ODB
        start_voltage - starting voltage value
        stop_voltage - stopping voltage value
        num_steps - number of steps for voltage
        wait_time - time to wait after setting new voltage before reading out current
        hv_board - number/name of the HV board used
    returns:
        V_{hv_board}_{hv_channel} - list of voltages for each channel of the used HV board
        I_{hv_board}_{hv_channel} - list of corresponding current for each channel of the used HV board
        original_settings - original settings before the scan
    '''
    cfg.check_defined()
    
    #Assert valit parameters
    if start_voltage < 0 or stop_voltage < start_voltage:
        seq.msg("Error: start_voltage must be >= 0 and <= stop_voltage")
        return None
        
    # any other checks?
    num_steps = num_steps + 1 # add one step for stop_voltage
    step_size = (stop_voltage - start_voltage) / (num_steps - 1)
    
    seq.msg(f"IV scan: Scanning IV for voltages from {start_voltage} to {stop_voltage} in steps of {step_size} in ({num_steps} steps)")
    
    # Delete old output
    seq.msg("Does not touch ChState, you're responsible for turning on the channels")
    print(f"Check that the output for HV board {hv_board} is active!")
    input("Press Enter to continue ...")
    try:
        seq.odb_delete(f"{path_this_scan}/Output")
    except:
        seq.msg(f"No previous output to delete at {path_this_scan}/Output")
    
    # Store current values
    global original_settings
    original_settings = Store_HV_Settings(seq)
    
    # create arrays for V and I:
    V = [ [] for i in range(hv_channels) ]
    I = [ [] for i in range(hv_channels) ]
    
    # scanning part:
    for hv_ch in range(hv_channels):
        # Choose hv name for the channel
        hv_name = f"TL_DS_{hv_board}_{hv_ch}"
        print("hv_name: ",hv_name)
        # find which index the name corresponds to
        index_hv = Get_HV_index(seq, hv_name)
        print("index_hv: ",index_hv)
        
        seq.odb_set(f"{cfg.path_hv}/Variables/Demand[{index_hv}]",start_voltage)
    time.sleep(wait_time)
    
    for num in range(num_steps):
        time.sleep(wait_time)
        next_demand = start_voltage + step_size * num
        print("Next voltage: ",next_demand," out of ",stop_voltage)
        
        for hv_ch in range(hv_channels):
            hv_name = f"TL_DS_{hv_board}_{hv_ch}"
            index_hv = Get_HV_index(seq, hv_name)
            volt = seq.odb_get(f"{cfg.path_hv}/Variables/Voltage[{index_hv}]")
            curr = seq.odb_get(f"{cfg.path_hv}/Variables/Current[{index_hv}]")
            V[hv_ch].append(volt)
            I[hv_ch].append(curr)
            
            seq.odb_set(f"{cfg.path_hv}/Variables/Demand[{index_hv}]",next_demand)
        
    Restore_HV_Settings(seq, original_settings)
    
    return V, I


# Write data to json
def write_json(path, V, I, hv_board):
    current_date = "13-02-26"
    output = {'IV scan': current_date}
    for hv_ch in range(hv_channels):
        V_dict = {f'V_{hv_board}_{hv_ch}' : V[hv_ch]}
        I_dict = {f'I_{hv_board}_{hv_ch}' : I[hv_ch]}
        output.update(V_dict)
        output.update(I_dict)
    with open(path, 'w') as json_file:
        json.dump(output, json_file, indent=2)
    json_file.close()
