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

path_this_scan = f"/Tests/Mutrig/ethreshold_scan"
# module-level storage so an external interrupt handler can restore settings
_original_settings = {}

# Scan the e-threshold of the Mutrig chips
# Record rate per channel at each e-threshold setting
def scan(seq, start_threshold, stop_threshold, step_threshold, wait_time, do_start_run_on_step=False):
    '''
    Scan the e-threshold of the MuTrig chips and capture per-channel rates.

    This function performs an e-threshold sweep by writing the appropriate
    `ethresh` value for all channels and then reading the channel rates and
    temperature from the ODB after a settle period.

    Parameters
    ----------
    seq : midas.sequencer
        MIDAS sequencer object used to read/write the ODB and control runs.
    start_threshold : int
        Starting base threshold value (inclusive). The function converts this
        to the MIDAS register value as `255 - start_threshold`.
    stop_threshold : int
        Ending base threshold value (inclusive).
    step_threshold : int
        Increment step for the base threshold.
    wait_time : float
        Time in seconds to wait after applying a new threshold before reading
        rates and temperature.
    do_start_run_on_step : bool, optional
        If True, start and stop a MIDAS run at each step to collect hit data.
        If False, the scan only waits for the setting to settle.

    Returns
    -------
    tuple
        (th, rates, temperatures, original_settings)

        - th (list of lists): Per-channel threshold values recorded for each
          scan step. `th[channel][step]` is the base threshold used at that step.
        - rates (list of lists): Per-channel measured rates for each step.
        - temperatures (list): Temperature reading at each scan step.
        - original_settings (dict): Snapshot of ODB settings before the scan.
    '''
    cfg.check_defined()
    print(f"Config: {cfg.path_asicsettings}")

    #Assert valid parameters
    if start_threshold < 0 and stop_threshold < start_threshold:
        seq.msg("Error: start_threshold must be >= 0 and <= stop_threshold")
        return None


    n_steps = int(((stop_threshold - start_threshold) / step_threshold) +1)
    seq.msg(f"Mutrig E-Threshold scan: Scanning E-Threshold from {start_threshold} to {stop_threshold} in steps of {step_threshold} ({n_steps} steps)")
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
    m.Mutrig_TandE_ASIC_configure(seq)

    # Scan Threshold
    for thr_iteration in range(n_steps):
        current_threshold = start_threshold + step_threshold * thr_iteration
        current_ethreshold = 255 - current_threshold

        # Set e-threshold
        path_threshold = m.Get_channel_odb_path("ethresh")
        seq.msg(f"Setting E-threshold at {path_threshold} to {current_ethreshold}")
        seq.odb_set(path_threshold,  [current_ethreshold] * NChannels)
        
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

# Write data to json
def write_json(path, th, rates, temperatures, original_settings):
    '''
    Write e-threshold scan results to a JSON file.

    The JSON file contains the same structure returned by `scan()`.

    Parameters
    ----------
    path : str
        Output filename to write the JSON data to.
    th : list
        Per-channel threshold arrays.
    rates : list
        Per-channel rate arrays.
    temperatures : list
        Temperature values recorded at each scan step.
    original_settings : dict
        Snapshot of ODB settings saved before the scan.
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
    Read e-threshold scan results previously written by `write_json`.

    Parameters
    ----------
    path : str
        Path to the JSON file containing scan results.

    Returns
    -------
    tuple or None
        (th, rates, temperatures, settings) if the file exists and is readable,
        otherwise None.
    '''
    if os.path.isfile(path) and os.access(path, os.R_OK):
        with open(path) as json_file:
            data = json.load(json_file)
            return data['th'], data['rates'], data['temperatures'], data['settings']
    return None

# Read in Data from json
def read_odb(seq, **kwargs):
    '''
    Read e-threshold scan results from the ODB and transpose them per-channel.

    This function reads `rate<N>` and `thresh<N>` entries from the ODB output
    node and returns dictionaries keyed by channel index.

    Parameters
    ----------
    seq : midas.sequencer
        MIDAS sequencer object used to read the ODB.

    Returns
    -------
    tuple
        (scan_th, scan_r, None)

        - scan_th (dict): channel -> [thresholds per iteration]
        - scan_r (dict): channel -> [rates per iteration]
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
    #transpose the data to have per channel arrays
    for channel in range(len(rate[0])):
        scan_th[channel] = [thresh[it][channel] for it in range(len(thresh))]
        scan_r[channel]  = [rate[it][channel] for it in range(len(rate))]

    return scan_th, scan_r, None

# Create configuration database from threshold scan results (same for module DB and for ODB)
# Parameters:
# ethresh : list or np.array of E-Thresholds per channel
# Optional Parameters:
# path : specify output path and filename (default: eth_calib_DD-MM-YYYY_HH-MM-SS.json)
def write_config_odb(ethresh, settings, **kwargs):
    '''
    Create a JSON configuration file containing e-threshold and related channel settings.

    This writes an object suitable for importing into the MuTrig ODB, converting
    `ethresh` values to the actual register values expected by the hardware.

    Parameters
    ----------
    ethresh : list or np.array
        Per-channel base thresholds. Stored values are converted to actual
        e-threshold register values as `255 - x`.
    settings : dict
        Original ODB settings snapshot from `m.Store_Settings(seq)` or similar.
        Used to preserve `ebias`, `energy_c_en`, and `energy_r_en` values.
    path : str, optional
        Output filename to write. If omitted, a timestamped filename is used.

    Returns
    -------
    dict
        JSON object that was written to disk. Includes `/ODB path`, `ethresh`,
        `ebias`, `energy_c_en`, and `energy_r_en` fields.
    '''
    now = datetime.now()
    # Format the string
    if "path" in kwargs:
        output_path = kwargs.get("path")
    else:
        output_path = now.strftime("eth_calib_DB_%d-%m-%Y_%H-%M-%S.json")
        print("No valid filename specified, setting it to", output_path)
    
    # Add e-thresholds to output dict, converting from threshold to actual e-threshold value (255-x)
    output = {"/ODB path": f"{cfg.path_asicsettings}/Channels","ethresh": [int(255-x) for x in np.array(ethresh).astype(int)]}
    ebias = settings["Channels"]["ebias"]
    ebias_dict = {'ebias':ebias}
    energy_c_en = settings["Channels"]["energy_c_en"]
    energy_c_en_dict = {'energy_c_en':energy_c_en}
    energy_r_en = settings["Channels"]["energy_r_en"]
    energy_r_en_dict = {'energy_r_en':energy_r_en}
    output.update(ebias_dict)
    output.update(energy_c_en_dict)
    output.update(energy_r_en_dict)

    try:    
        print("Saving the configuration into a file: ", output_path)
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    except:
        output_path = now.strftime("eth_calib_DB_%d-%m-%Y_%H-%M-%S.json")
        print("-- File Path not found, saving to", output_path, "--")
        with open(output_path, 'w') as f_out:
            json.dump(output, f_out, indent=2)
        f_out.close()
    
    return output

