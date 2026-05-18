import sys
sys.path.append("../../../python/")
import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables
import mutrig.tthreshold_scan as tscan
import mutrig.Mutrig_basic_functions as m
import midas.client as client
import signal
import sys
import os


# Sequencer callbacks
def define_params(seq):
    seq.register_param("start_threshold", "Start t-threshold", 0);
    seq.register_param("stop_threshold", "Stop t-threshold", 255);
    seq.register_param("step_threshold", "Step t-threshold", 1);
    seq.register_param("wait_time", "Wait time (s)", 1);


def sequence(seq):
    start_threshold = seq.get_param("start_threshold");
    stop_threshold  = seq.get_param("stop_threshold");
    step_threshold  = seq.get_param("step_threshold");
    wait_time        = seq.get_param("wait_time");
    scan(seq,start_threshold, stop_threshold, step_threshold, wait_time)

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
    global seq;
    seq = client.MidasClient("MutrigTuning")

    # register handler for common termination signals
    signal.signal(signal.SIGINT, _interrupt_handler)
    signal.signal(signal.SIGTERM, _interrupt_handler)

    th,r,temperatures,settings = tscan.scan(seq,start_threshold=0, stop_threshold=63, step_threshold=1, wait_time=3, start_offset=0, stop_offset=2)
    filename = f'tthreshold_scan.json'
    seq.msg("Scan complete. Writing output to "+filename)
    tscan.write_json(filename,th,r,temperatures,settings);

