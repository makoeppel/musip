# scan IV for one module - 4 HV channels, based on the TLD_IV_Scan_per_module.msl

#CALL TLD_IV_scan_per_module, $start_voltage(def = 45), $stop_voltage(def = 57), $num_steps(def = 30), $at_psi, $Module_number
#should depend on start/stop voltage, number of steps, module number(?), HV board number (0 or 1)

import time
import midas.client as client
import midas.sequencer as sequencer
import re
import json
import os
from datetime import datetime
import numpy as np
import mutrig.base_variables as cfg
import mutrig.Mutrig_basic_functions as m
import sys

import matplotlib.pyplot as plt

path_this_scan = f"/Tests/Mutrig/iv_scan"


def Get_HV_path(setting, index=None):
    if index is not None:
        return f"{cfg.path_hv}/Variables/{setting}[{index}]"
    else:
        return f"{cfg.path_hv}/Variables/{setting}"


def Store_HV_Settings(client):
    settings=client.odb_get(f"{cfg.path_hv}/Variables/Demand")
    return settings
        
def Restore_HV_Settings(client,settings):
    settings=client.odb_set(f"{cfg.path_hv}/Variables/Demand",settings)
        
def scan(seq, start_voltage, stop_voltage, num_steps, wait_time, enable_odb_storage=False):
    '''
    Pythonized version of original sequencer script for IV scan
    args:
        seq - MIDAS seq that connects with the ODB
        start_voltage - starting voltage value
        stop_voltage - stopping voltage value
        num_steps - number of steps for voltage
        wait_time - time to wait after setting new voltage before reading out current
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
    
    channel_indices=[]
    channel_names=[]
    eq_channel_names = seq.odb_get(f"{cfg.path_hv}/Settings/Names")
    for chn in cfg.hv_channel_names:
        try:
            channel_indices.append(eq_channel_names.index(chn))
            channel_names.append(chn)
        except:
            pass
    hv_channels = len(channel_indices)


    seq.msg(f"IV scan: Scanning IV for voltages from {start_voltage} to {stop_voltage} in steps of {step_size} in ({num_steps} steps). Channels: {channel_names}")
    
    # Delete old output
    if enable_odb_storage:
        try:
            seq.odb_delete(f"{path_this_scan}/Output")
        except:
            seq.msg(f"No previous ODB output to delete at {path_this_scan}/Output")
    
    # Store current values
    global original_settings
    original_settings = Store_HV_Settings(seq)
    
    # create arrays for V and I:
    V = [[] for i in range(hv_channels)]
    I = [[] for i in range(hv_channels)]
    
    # scanning part - setup:
    for hv_idx, hv_name in zip(channel_indices, channel_names):
        print("hv_name: ",hv_name,"; index_hv: ",hv_idx)
        seq.odb_set(f"{cfg.path_hv}/Variables/Demand[{hv_idx}]",start_voltage) 
        output_on_check = seq.odb_get(f"{cfg.path_hv}/Settings/Output On[{hv_idx}]")
        if (output_on_check != True):
            seq.msg(f"Output_on for HV {hv_name} is False, please verify")
    next_demand = start_voltage
    time.sleep(2*wait_time)
   
    for num in range(num_steps):
        time.sleep(wait_time)
        current_demand = next_demand
        #print("Next voltage: ",next_demand," out of ",stop_voltage)
        next_demand = start_voltage + step_size * num
        for chIdx, (hv_idx, hv_name) in enumerate(zip(channel_indices, channel_names)):
            vm = seq.odb_get(f"{cfg.path_hv}/Variables/Voltage[{hv_idx}]")
            cm = seq.odb_get(f"{cfg.path_hv}/Variables/Current[{hv_idx}]")
            print(f"Step {num+1}/{num_steps}: HV {hv_name} (index {hv_idx}) - Demand: {current_demand:.2f} V, Measured Voltage: {vm:.2f} V, Measured Current: {cm:.2f} mA")
            seq.odb_set(f"{cfg.path_hv}/Variables/Demand[{hv_idx}]",next_demand)

            V[chIdx].append(vm)
            I[chIdx].append(cm)

            if enable_odb_storage:
                seq.odb_set(f"{path_this_scan}/Output/V_{hv_name}[{num}]",vm)
                seq.odb_set(f"{path_this_scan}/Output/I_{hv_name}[{num}]",cm)

            seq.odb_set(f"{cfg.path_hv}/Variables/Demand[{hv_idx}]",next_demand)
        
    Restore_HV_Settings(seq, original_settings)    
    return channel_names, V, I

# Write data to json
def write_json(path, names, V, I):
    current_date = datetime.today().strftime('%d-%m-%Y') # to be used as the file ending for scans/configs
    print("Date: ", current_date)
    output = {'IV scan': current_date}
    for i, name in enumerate(names):
        V_dict = {f'V_{name}' : V[i]}
        I_dict = {f'I_{name}' : I[i]}
        output.update(V_dict)
        output.update(I_dict)
    with open(path, 'w') as json_file:
        json.dump(output, json_file, indent=2)
    json_file.close()


def read_json(path):
    with open(path, 'r') as json_file:
        data = json.load(json_file)
    json_file.close()
    V=[]
    I=[]
    names=[]
    for key in data.keys():
        if key.startswith('V_'):
            hv_name = key[2:]
            V.append(data[key])
            I.append(data[f'I_{hv_name}'])
            names.append(hv_name)
            print(f"HV channel: {hv_name}, V: {V}, I: {I}")
    return names, V, I

def plot_iv(names, V, I, output_path_iv, title):


    plt.figure(figsize=(8, 6))
    for i, name in enumerate(names):
        plt.plot(V[i], I[i], "-", label=name)
    
    plt.title(f'IV Scan for {title}')
    plt.xlabel('Voltage (V)')
    plt.ylabel('Current (mA)')
    #plt.xlim([V_min - (V_max - V_min)*0.01, V_max + (V_max - V_min)*0.01])
    #plt.ylim([1e-3, 1e0])
    #plt.yscale('log')
    
    plt.legend()
    plt.grid()
    plt.savefig(output_path_iv)
    plt.close()
    
    print(f"Saved to {output_path_iv}")

def plot_iv_from_json(json_path, output_path, title):
    names, V, I = read_json(json_path)
    ofilename = os.path.splitext(os.path.basename(json_path))[0]
    plot_iv(names, V, I, output_path, title, ofilename)