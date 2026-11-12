#!/usr/bin/env -S python3
import sys
#sys.path.append("../../")
from datetime import datetime
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables
import mutrig.ethreshold_scan as escan
import mutrig.Mutrig_basic_functions as m
import midas.client as client
import signal
import sys
import os


import mutrig.mutrigTB_variables
cfg.polarity_inverted = False


# Sequencer callbacks
def define_params(seq):
    seq.register_param("start_threshold", "Start e-threshold", 0);
    seq.register_param("stop_threshold", "Stop e-threshold", 255);
    seq.register_param("step_threshold", "Step e::-threshold", 1);
    seq.register_param("wait_time", "Wait time (s)", 3);


def sequence(seq):
    seq.set_py_logger_to_midas(True)
    start_eth = seq.get_param("start_threshold");
    stop_eth  = seq.get_param("stop_threshold");
    step_eth  = seq.get_param("step_threshold");
    dt        = seq.get_param("wait_time");
    th,r,temperatures,settings = escan.scan(seq,
                                            start_threshold=start_eth, stop_threshold=stop_eth, step_threshold=step_eth,
                                            wait_time=dt)


    scan_path = "scripts/MutrigScripts/data/ethreshold_scans"
    current_date = datetime.now().strftime('%d-%m-%Y-%H:%M')
    filename = scan_path+"/eth_scan_"+str(current_date)+".json"

    seq.msg("Scan complete. Writing output to "+filename)
    escan.write_json(filename,th,r,temperatures,settings)

# Standalone / Tests
# Interrupt handler to restore settings
def _interrupt_handler(signum, frame):
    """Signal handler: restore original settings and exit."""
    try:
        if seq is not None and escan.original_settings:
            seq.msg(f"Interrupt ({signum}) received: restoring settings and exiting")
            print(f"Interrupt ({signum}) received: restoring settings and exiting")
            m.Restore_Settings(seq, escan.original_settings)
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

    th,r,temperatures,settings = escan.scan(seq,start_threshold=50, stop_threshold=130, step_threshold=1, wait_time=3)

    seq.msg("Scan complete. Writing output to "+filename)
    tscan.write_json(filename,th,r,temperatures,settings)