#!/usr/bin/env -S python3
import sys
#sys.path.append("../../")
from datetime import datetime
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables
import mutrig.tthreshold_scan as tscan
import mutrig.Mutrig_basic_functions as m
import midas.client as client
import signal
import sys
import os


import mutrig.mutrigTB_variables
cfg.polarity_inverted = False


# Sequencer callbacks
def define_params(seq):
    seq.register_param("start_threshold", "Start t-threshold", 0);
    seq.register_param("stop_threshold", "Stop t-threshold", 63);
    seq.register_param("step_threshold", "Step t-threshold", 1);
    seq.register_param("start_offset", "Start t-offset", 0);
    seq.register_param("stop_offset", "Stop t-offset", 2);
    seq.register_param("wait_time", "Wait time (s)", 3);


def sequence(seq):
    seq.set_py_logger_to_midas(True)
    start_tth = seq.get_param("start_threshold");
    stop_tth  = seq.get_param("stop_threshold");
    step_tth  = seq.get_param("step_threshold");
    start_offs = seq.get_param("start_offset");
    stop_offs  = seq.get_param("stop_offset");
    dt        = seq.get_param("wait_time");

    th,r,temperatures,settings = tscan.scan(seq,
                                            start_threshold=start_tth, stop_threshold=stop_tth, step_threshold=step_tth, 
                                            start_offset=start_offs, stop_offset=stop_offs,
                                            wait_time=dt)


    scan_path = "scripts/MutrigScripts/data/tthreshold_scans"
    current_date = datetime.now().strftime('%d-%m-%Y-%H:%M')
    filename = scan_path+"/tth_scan_"+str(current_date)+".json"

    seq.msg("Scan complete. Writing output to "+filename)
    tscan.write_json(filename,th,r,temperatures,settings)

# Standalone / Tests
# Interrupt handler to restore settings
def _interrupt_handler(signum, frame):
    """Signal handler: restore original settings and exit."""
    try:
        if seq is not None and tscan.original_settings:
            seq.msg(f"Interrupt ({signum}) received: restoring settings and exiting")
            print(f"Interrupt ({signum}) received: restoring settings and exiting")
            m.Restore_Settings(seq, tscan.original_settings)
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

    #cfg.TEST_MODE = True
    cfg.Print()

    scan_path = "measurements/"
    filename = scan_path+"/tth_scan_"+str(current_date)+".json"

    th,r,temperatures,settings = tscan.scan(seq,start_threshold=0, stop_threshold=63, step_threshold=1, wait_time=3.0, start_offset=0, stop_offset=2)

    seq.msg("Scan complete. Writing output to "+filename)
    tscan.write_json(filename,th,r,temperatures,settings)
