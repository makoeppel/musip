#!/usr/bin/env -S python3
import sys
from datetime import datetime
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables
import mutrig.iv_scan as ivscan
import mutrig.Mutrig_basic_functions as m
import midas.client as client
import signal
import sys
import os


import mutrig.mutrigTB_variables
cfg.polarity_inverted = False


# Sequencer callbacks
def define_params(seq):
    seq.register_param("start_voltage", "Start voltage", 30)
    seq.register_param("stop_voltage", "Stop voltage", 45)
    seq.register_param("num_steps", "Number of steps", 30)
    seq.register_param("wait_time", "Wait time (s)", 1)

def sequence(seq):
    vstart = seq.get_param("start_voltage")
    vstop  = seq.get_param("stop_voltage")
    nsteps = seq.get_param("num_steps")
    dt     = seq.get_param("wait_time")
    
    names, V, I = ivscan.scan(seq,start_voltage=vstart, stop_voltage=vstop, num_steps=nsteps, wait_time=dt)

    scan_path = "scripts/MutrigScripts/data/iv_scans"
    current_date = datetime.now().strftime('%d-%m-%Y-%H:%M')
    filename = "iv_scan_"+str(current_date)+".json"
    filename_full = scan_path+"/"+filename
    seq.msg("Scan complete. Writing output to "+filename)
    ivscan.write_json(filename_full,names,V, I)
    filename = "iv_scan_"+str(current_date)+".pdf"
    filename_full = scan_path+"/"+filename
    ivscan.plot_iv(names, V, I, filename_full, filename)

# Standalone / Tests
# Interrupt handler to restore settings
def _interrupt_handler(signum, frame):
    """Signal handler: restore original settings and exit."""
    try:
        if seq is not None and ivscan.original_settings:
            seq.msg(f"Interrupt ({signum}) received: restoring settings and exiting")
            print(f"Interrupt ({signum}) received: restoring settings and exiting")
            ivscan.Restore_HV_Settings(seq, ivscan.original_settings)
        else:
            print(f"Interrupt ({signum}) received: no active scan or no saved settings to restore")
    except Exception as e:
        print(f"Error while restoring settings during interrupt: {e}")
    finally:
        sys.exit(1)


# Standalone / Tests main routine
if __name__ == "__main__":
    global seq
    seq = client.MidasClient("MutrigTuning")

    # register handler for common termination signals
    signal.signal(signal.SIGINT, _interrupt_handler)
    signal.signal(signal.SIGTERM, _interrupt_handler)
    cfg.Print()

    
    names, V, I = ivscan.scan(seq,start_voltage=30, stop_voltage=45, num_steps=30, wait_time=1)
    
    scan_path = "scripts/MutrigScripts/data/iv_scans"
    current_date = datetime.now().strftime('%d-%m-%Y-%H:%M')
    filename = "iv_scan_"+str(current_date)+".json"
    filename_full = scan_path+"/"+filename
    seq.msg("Scan complete. Writing output to "+filename)
    ivscan.write_json(filename_full,names,V, I)
    filename = "iv_scan_"+str(current_date)+".pdf"
    filename_full = scan_path+"/"+filename
    ivscan.plot_iv(names, V, I, filename_full, filename)

