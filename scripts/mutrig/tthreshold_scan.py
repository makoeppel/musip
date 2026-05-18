import time
import midas.client as client
import midas.sequencer as sequencer
from datetime import datetime
import numpy as np
import re
import os
import json
import mutrig.base_variables as cfg

import mutrig.iv_scan as ivscan
import mutrig.Mutrig_basic_functions as m
import mutrig.rate_calibration as rc

path_this_scan = f"/Tests/Mutrig/tthreshold_scan"
# module-level storage so an external interrupt handler can restore settings
_original_settings = {}

# Scan the T-threshold of the Mutrig chips
# Record rate per channel at each e-threshold setting
def scan(seq, start_threshold, stop_threshold, step_threshold, wait_time, start_offset=0, stop_offset=0, do_start_run_on_step=false):
    '''
    Pythonized version of original sequencer script to scan the e-threshold of the Mutrig chips
    args:
        seq - MIDAS seq that connects with the ODB
        start_threshold - starting T-threshold value
        stop_threshold - stopping T-threshold value
        step_threshold - step size for T-threshold
        wait_time - time to wait after setting new T-threshold before reading out rates
        start_offset - T-threshold-offset scan start (default: 0)
        stop_offset - T-threshold-offset scan end (default: 0)
    returns:
        th - list of T-thresholds per channel
        rates - list of rates per channel
        original_settings - original settings before the scan
    '''
    cfg.check_defined()
    print(f"Config: {cfg.path_asicsettings}")

    #Assert valid parameters
    if start_threshold < 0 and stop_threshold < start_threshold:
        seq.msg("Error: start_threshold must be >= 0 and <= stop_threshold")
        return None

    if start_offset < 0 and stop_offset < start_offset:
        seq.msg("Error: start_offset must be >= 0 and <= stop_offset")
        return None

    # For each offset, extend the threshold list
    th_list_extended = []
    for offset in range(start_offset, stop_offset + 1):
        for th in range(start_threshold, stop_threshold + 1, step_threshold):
            th_list_extended.append(th + offset * 64)
    n_steps = len(th_list_extended)
    seq.msg(f"Mutrig T-Threshold scan: Scanning T-Threshold from {start_threshold}@{start_offset} to {stop_threshold}@{stop_offset} in steps of {step_threshold} ({n_steps} steps)")
    # Delete old output
    try:
        seq.odb_delete(f"{path_this_scan}/Output")
    except:
        seq.msg(f"No previous output to delete at {path_this_scan}/Output")
    
    # Store current values
    global original_settings
    original_settings = m.Store_Settings(seq)
    NChannels = len(original_settings['ASICs']['Channels']['ethresh'])
    # Prepare output arrays
    th    = [ [] for i in range(NChannels) ]
    rates = [ [] for i in range(NChannels) ]
    temperatures = []

    # Set system up for scan
    tmp_ethresh = [0] * NChannels
    m.Set_eth(seq,tmp_ethresh)
    m.Mutrig_TorE_ASIC_configure(seq)

    # Scan Threshold
    for thr_iteration, current_threshold in enumerate(th_list_extended):
        current_tthreshold = 63-(current_threshold % 64)
        current_offset = (current_threshold // 64)

        # Set e-threshold
        path_tth = m.Get_channel_odb_path("tthresh")
        seq.msg(f"Setting T-threshold at {path_tth} to {current_tthreshold} @ offset {current_offset}")
        seq.odb_set(m.Get_channel_odb_path("tthresh"),  [current_tthreshold] * NChannels)
        seq.odb_set(m.Get_channel_odb_path("tthresh_offset"),  [current_offset] * NChannels)
        
        # Configure all asics
        m.Configure_all_asics(seq)

        if do_start_run_on_step:
            # === MIDAS Run start if requested ===
            run_number = 
            seq.msg(f"Starting Run {run_number} for E-Threshold {current_ethreshold}")
            seq.odb_exec(f"/RunControl/start now")

            # Warten, damit Hitdaten gesammelt werden
            time.sleep(wait_time)

            # Run stoppen
            seq.msg(f"Stopping Run {run_number}")
            seq.odb_exec("/RunControl/stop")
        else:
            # Wait for settings in effect & readout to be updated
            #seq.wait_seconds(wait_time)
            time.sleep(wait_time)


        # Readout rates
        path_rate = f"{cfg.path_variables}/TDCR"
        current_rate = seq.odb_get(path_rate);
        #Readout Temperature
        path_temp = f"{cfg.path_variables}/TDTM"
        current_temp = seq.odb_get(path_temp);
        temp_value = current_temp[0]

        # Store output
        seq.odb_set(f"{path_this_scan}/Output/thresh{thr_iteration}", [current_threshold] * len(current_rate))
        seq.odb_set(f"{path_this_scan}/Output/rate{thr_iteration}", current_rate)
        seq.odb_set(f"{path_this_scan}/Output/temp{thr_iteration}", temp_value)
        # Store output as python array, to return later, in the form of th[channel][th_iteration]
        temperatures.append(temp_value)
        for i in range(len(current_rate)):
            th[i].append(current_threshold)
            rates[i].append(current_rate[i])


    # Restore previous values
    m.Restore_Settings(seq, original_settings)

    return th, rates, temperatures, original_settings;

def scan_no_offset(seq, start_threshold, stop_threshold, step_threshold, wait_time):
    '''
    Pythonized version of original sequencer script to scan the e-threshold of the Mutrig chips
    args:
        seq - MIDAS seq that connects with the ODB
        start_threshold - starting T-threshold value
        stop_threshold - stopping T-threshold value
        step_threshold - step size for T-threshold
        wait_time - time to wait after setting new T-threshold before reading out rates
    returns:
        th - list of T-thresholds per channel (actual threshold values including channel offset)
        rates - list of rates per channel
        original_settings - original settings before the scan
    '''
    cfg.check_defined()

    #Assert valid parameters
    if start_threshold < 0 and stop_threshold < start_threshold:
        seq.msg("Error: start_threshold must be >= 0 and <= stop_threshold")
        return None

    # Store current values and get channel offsets
    global original_settings
    original_settings = m.Store_Settings(seq)
    NChannels = len(original_settings['ASICs']['Channels']['ethresh'])
    
    # Get current individual channel offsets
    path_tth_offset = m.Get_channel_odb_path("tthresh_offset")
    channel_offsets = seq.odb_get(path_tth_offset)
    
    seq.msg(f"Current channel offsets: {channel_offsets}")
    seq.msg(f"Mutrig T-Threshold scan: Scanning T-Threshold from {start_threshold} to {stop_threshold} in steps of {step_threshold}")
    
    # Delete old output
    try:
        seq.odb_delete(f"{path_this_scan}/Output")
    except:
        seq.msg(f"No previous output to delete at {path_this_scan}/Output")
    
    # Prepare output arrays
    th    = [ [] for i in range(NChannels) ]
    rates = [ [] for i in range(NChannels) ]

    # Set system up for scan
    tmp_ethresh = [0] * NChannels
    m.Set_eth(seq,tmp_ethresh)
    m.Mutrig_TorE_ASIC_configure(seq)

    # Generate threshold list without offset variation
    th_list = list(range(start_threshold, stop_threshold + 1, step_threshold))
    n_steps = len(th_list)
    
    # Scan Threshold (only changing base threshold, keeping individual offsets fixed)
    for thr_iteration, current_tthreshold in enumerate(th_list):
        # Calculate actual thresholds including individual channel offsets
        actual_thresholds = []
        for ch in range(NChannels):
            actual_th_midas = 63- current_tthreshold 
            actual_th = current_tthreshold + channel_offsets[ch] * 64
            actual_thresholds.append(actual_th)
        
        seq.msg(f"Setting T-threshold to {actual_th_midas} ({actual_thresholds[:min(16, NChannels)]}...)")
        
        # Set base T-threshold (same for all channels)
        seq.odb_set(m.Get_channel_odb_path("tthresh"), [actual_th_midas] * NChannels)
        
        # Configure all asics
        m.Configure_all_asics(seq)

        # Wait for settings to take effect
        time.sleep(wait_time)

        # Readout rates
        path_rate = f"{cfg.path_variables}/TDCR"
        current_rate = seq.odb_get(path_rate);
        
        # Store output
        seq.odb_set(f"{path_this_scan}/Output/thresh{thr_iteration}", actual_thresholds)
        seq.odb_set(f"{path_this_scan}/Output/rate{thr_iteration}", current_rate)
        
        # Store output as python array, to return later, in the form of th[channel][th_iteration]
        for i in range(len(current_rate)):
            th[i].append(actual_thresholds[i])  # Store actual threshold including channel offset
            rates[i].append(current_rate[i])

    # Restore previous values
    m.Restore_Settings(seq, original_settings)

    return th, rates, original_settings;

# Write data to json
def write_json(path, th,rates, original_settings):
    with open(path, 'w') as json_file:
        json.dump(fp = json_file, obj = {
            'th':th,
            'rates':rates,
            'temperatures':temperatures,
            'settings':original_settings})


# Readout e-threshold scan results

# Read in Data from json
def read_json(path, **kwargs):
    if os.path.isfile(path) and os.access(path, os.R_OK):
        # Set the path for the output:
        with open(path) as json_file:
            data = json.load(json_file)
            # read json based on how it was written in write_json        
            return data['th'], data['rates'], data['temperatures'], data['settings']
    return None

# Read in Data from json
def read_odb(seq, **kwargs):
    data = seq.odb_get(f"{path_this_scan}/Output")
    scan_th = {}
    scan_r = {}
    rate = []*255
    thresh = []*255
    for it in range(255):
        try:
            rate[it] = data[f"rate{it}"]
            thresh[it] = data[f"thresh{it}"]
        except:
            break
    #transpose the data to have per channel arrays
    for channel in range(len(rate[0])):
        scan_th[channel] = [thresh[it][channel] for it in range(len(thresh))]
        scan_r[channel]  = [rate[it][channel] for it in range(len(rate))]

    return scan_th, scan_r, None

# Create configuration database from threshold scan results (for module DB saved as effective threshold)
# Parameters:
# tthresh : list or np.array of T-Thresholds per channel (as effective threshold)
# Optional Parameters:
# path : specify output path and filename (default: tth_calib_DB_DD-MM-YYYY_HH-MM-SS.json)
def write_config_db(tthresh, **kwargs):
    now = datetime.now()
    # Format the string
    if "path" in kwargs:
        output_path = kwargs.get("path")
    else:
        output_path = now.strftime("tth_calib_DB_%d-%m-%Y_%H-%M-%S.json")
        print("No valid filename specified, setting it to", output_path)
        
    output = {"/ODB path": f"{cfg.path_asicsettings}/Channels","tthresh": [int(x) for x in np.array(tthresh).astype(int)]}

    try:    
        print("Saving the configuration into a file: ", output_path)
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    except:
        output_path = now.strftime("tth_calib_DB_%d-%m-%Y_%H-%M-%S.json")
        print("-- File Path not found, saving to", output_path, "--")
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    return output

# Create configuration database from threshold scan results (for ODB, as array of tth and tth_offset)
# Parameters:
# tthresh : list or np.array of T-Thresholds per channel 
# tthresh_offset : list or np.array of T-Threshold offsets per channel 
# Optional Parameters:
# path : specify output path and filename (default: tth_calib_ODB_DD-MM-YYYY_HH-MM-SS.json)
def write_config_odb(tthresh, tth_offsets, **kwargs):
    now = datetime.now()
    # Format the string
    if "path" in kwargs:
        output_path = kwargs.get("path")
    else:
        output_path = now.strftime("tth_calib_ODB_%d-%m-%Y_%H-%M-%S.json")
        print("No valid filename specified, setting it to", output_path)
        
    output = {"/ODB path": f"{cfg.path_asicsettings}/Channels","tthresh": [int(x) for x in np.array(tthresh).astype(int)]}
    offsets = {'tthresh_offset' : [int(x) for x in np.array(tth_offsets).astype(int)]}
    output.update(offsets)

    try:    
        print("Saving the configuration into a file: ", output_path)
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    except:
        output_path = now.strftime("tth_calib_ODB_%d-%m-%Y_%H-%M-%S.json")
        print("-- File Path not found, saving to", output_path, "--")
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    return output
