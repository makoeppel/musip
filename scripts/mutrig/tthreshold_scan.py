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
def scan(seq, start_threshold, stop_threshold, step_threshold, wait_time, start_offset=0, stop_offset=0, do_start_run_on_step=False):
    '''
    Scan the T-threshold of the MuTrig chips and record per-channel rates.

    This function performs a T-threshold sweep and optionally varies the
    per-channel offset index. At each step it writes results to the ODB
    under `path_this_scan/Output` as `thresh<N>`, `rate<N>` and `temp<N>`.

    Parameters
    ----------
    seq : midas.sequencer
        MIDAS sequencer object used to read/write the ODB and control runs.
    start_threshold : int
        Base T-threshold start value (inclusive). Interpreted as the
        LSB/base threshold before offset is applied.
    stop_threshold : int
        Base T-threshold end value (inclusive).
    step_threshold : int
        Increment step for the base threshold.
    wait_time : float
        Seconds to wait after applying a setting before reading rates/temperature.
    start_offset : int, optional
        Offset index to start scanning (each offset = +64 on effective threshold).
        Default is 0. Only used when scanning offsets (see notes).
    stop_offset : int, optional
        Offset index to stop scanning (inclusive). Default is 0.
    do_start_run_on_step : bool, optional
        If True, start and stop a MIDAS run at each step to collect hit data.

    Returns
    -------
    tuple
        (th, rates, temperatures, original_settings)

        - th (list of lists): Per-channel threshold values. th[channel][step]
          contains the effective threshold used for that channel at that step
          (includes offset contribution where applicable).
        - rates (list of lists): Per-channel measured rates. rates[channel][step]
          contains the rate read from the ODB for that channel at that step.
        - temperatures (list): Temperature reading for each step (one value per
          iteration).
        - original_settings (dict): Snapshot of ODB settings taken before the scan
          which can be passed to `m.Restore_Settings` to revert the device.

    Notes
    -----
    - Effective thresholds are encoded as `base + offset*64`. The code
      calculates the MIDAS register `tthresh` as `63 - (effective % 64)` and
      writes the offset index into `tthresh_offset`.
    - Outputs are written into `path_this_scan/Output` and will overwrite any
      previous run of the same scan (the function attempts to delete that node).
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
    NChannels = len(original_settings['Channels']['ethresh'])
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
            run_number = seq.odb_get("/RunInfo/Run number")
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
        path_rate = f"{cfg.path_variables}/{cfg.bank_prefix}CR"
        current_rate = seq.odb_get(path_rate);
        #Readout Temperature
        path_temp = f"{cfg.path_variables}/{cfg.bank_prefix}TM"
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
    Scan T-thresholds while keeping current per-channel offsets fixed.

    This helper performs a threshold sweep using the current channel offsets
    stored in the ODB. It is equivalent to scanning only the base threshold
    value while preserving the `tthresh_offset` already configured per channel.

    Parameters
    ----------
    seq : midas.sequencer
        MIDAS sequencer object used to read/write the ODB.
    start_threshold : int
        Base T-threshold start value (inclusive).
    stop_threshold : int
        Base T-threshold end value (inclusive).
    step_threshold : int
        Increment step for the base threshold.
    wait_time : float
        Seconds to wait after applying a setting before reading rates.

    Returns
    -------
    tuple
        (th, rates, original_settings)

        - th (list of lists): Per-channel effective thresholds (base + offset*64)
          recorded for each scan step.
        - rates (list of lists): Per-channel measured rates for each step.
        - original_settings (dict): Snapshot of ODB settings taken before the scan.
    '''
    cfg.check_defined()

    #Assert valid parameters
    if start_threshold < 0 and stop_threshold < start_threshold:
        seq.msg("Error: start_threshold must be >= 0 and <= stop_threshold")
        return None

    # Store current values and get channel offsets
    global original_settings
    original_settings = m.Store_Settings(seq)
    NChannels = len(original_settings['Channels']['ethresh'])
    
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
        path_rate = f"{cfg.path_variables}/{cfg.bank_prefix}CR"
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
def write_json(path, th, rates, temperatures, original_settings):
    '''
    Write scan results to a JSON file.

    The JSON format written is a single object with keys: `th`, `rates`,
    `temperatures` and `settings` matching the in-memory structures returned
    by `scan()`.

    Parameters
    ----------
    path : str
        Output filename to write the JSON to.
    th : list
        Per-channel threshold lists.
    rates : list
        Per-channel rate lists.
    temperatures : list
        Temperature readings per step (may be None for some scans).
    original_settings : dict
        Settings snapshot saved before the scan.
    '''
    with open(path, 'w') as json_file:
        json.dump(fp=json_file, obj={
            'th': th,
            'rates': rates,
            'temperatures': temperatures,
            'settings': original_settings
        })


# Readout e-threshold scan results

# Read in Data from json
def read_json(path, **kwargs):
    '''
    Read scan results previously written by `write_json`.

    Parameters
    ----------
    path : str
        Path to the JSON file written by `write_json`.

    Returns
    -------
    tuple or None
        (th, rates, temperatures, settings) on success, or None if the file
        does not exist or is not readable.
    '''
    if os.path.isfile(path) and os.access(path, os.R_OK):
        with open(path) as json_file:
            data = json.load(json_file)
            return data['th'], data['rates'], data['temperatures'], data['settings']
    return None

# Read in Data from the ODB
def read_odb(seq, **kwargs):
    '''
    Read scan results from the ODB node `path_this_scan/Output` and return
    per-channel arrays.

    The function expects entries named `rate<N>` and `thresh<N>` for
    sequential iteration indices starting at 0. It transposes the stored
    iteration-oriented arrays into per-channel lists.

    Parameters
    ----------
    seq : midas.sequencer
        MIDAS sequencer object to read the ODB.

    Returns
    -------
    tuple
        (scan_th, scan_r, None)

        - scan_th (dict): Mapping channel -> [thresholds per iteration]
        - scan_r (dict): Mapping channel -> [rates per iteration]
        - Third return value is reserved for compatibility and always None.
    '''
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
    # transpose the data to have per channel arrays
    for channel in range(len(rate[0])):
        scan_th[channel] = [thresh[it][channel] for it in range(len(thresh))]
        scan_r[channel] = [rate[it][channel] for it in range(len(rate))]

    return scan_th, scan_r, None


# Create configuration database from threshold scan results (for ODB, as array of tth and tth_offset)
# Parameters:
# tthresh : list or np.array of T-Thresholds per channel 
# tthresh_offset : list or np.array of T-Threshold offsets per channel 
# Optional Parameters:
# path : specify output path and filename (default: tth_calib_ODB_DD-MM-YYYY_HH-MM-SS.json)
def write_config_odb(tthresh, tth_offsets=None, **kwargs):
    '''
    Create a JSON configuration file formatted for ODB import.

    The output contains both `tthresh` (effective thresholds) and
    `tthresh_offset` (per-channel offset indices) so it can be applied to
    the ODB directly.

    Parameters
    ----------
    tthresh : list or np.array
        Per-channel effective thresholds.
    tth_offsets : list or np.array
        Per-channel offset indices (integer indices, each representing
        an additional +64 multiplier for the effective threshold).
        If None, offsets will not be included in the output.
    path : str, optional
        If provided, use this filename. Otherwise a timestamped file
        `tth_calib_ODB_DD-MM-YYYY_HH-MM-SS.json` is used.

    Returns
    -------
    dict
        The JSON object that was written to disk (includes `tthresh` and
        `tthresh_offset`).
    '''
    now = datetime.now()
    # Format the string
    if "path" in kwargs:
        output_path = kwargs.get("path")
    else:
        output_path = now.strftime("tth_calib_ODB_%d-%m-%Y_%H-%M-%S.json")
        print("No valid filename specified, setting it to", output_path)
    outArray = [63 - x for x in np.array(tthresh).astype(np.uint32)]
    output = {"/ODB path": f"{cfg.path_asicsettings}/Channels", 
            "tthresh": [f"0x{x:02X}" for x in outArray]
    }
    if tth_offsets is not None:
        outArray = [63 - x for x in np.array(tth_offsets).astype(np.uint32)]
        offsets = {"tthresh_offset": [f"0x{x:02X}" for x in np.array(tth_offsets).astype(int)]}
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
