"""
Noise Scan Python sequencer script for the Quads Setup.
"""
import time
import midas.client
import utils.helpers as helpers


def define_params(seq):
    # Define parameters that can be set through the ODB
    seq.register_param("max_hits",              "Maximum hits for tuning",  3)
    seq.register_param("run_time",              "Run time in seconds",      3)
    seq.register_param("start_threshold",       "Start threshold value",    130)
    seq.register_param("stop_threshold",        "Stop threshold value",     118)
    seq.register_param("step_threshold",        "Step threshold value",     1)
    seq.register_param("max_iterations",        "Maximum iteration",        10)
    seq.register_param("max_errorrate_retries", "Max errorrate retries",    5)
    seq.register_param("max_link_errors",       "Maximum link errors",      500)
    seq.register_param("reset_masks",           "Reset Mask",               1)
    seq.register_param("do_tuning",             "Also adjust TDACs",        0)


def sequence(seq):
    # Get parameters
    max_hits = seq.get_param("max_hits")
    run_time = seq.get_param("run_time")
    start_threshold = seq.get_param("start_threshold")
    stop_threshold = seq.get_param("stop_threshold")
    step_threshold = seq.get_param("step_threshold")
    max_iterations = seq.get_param("max_iterations")
    max_link_errors = seq.get_param("max_link_errors")
    do_tuning = seq.get_param("do_tuning")

    # Setup Minalyzer
    helpers.setup_minalyzer(seq, max_hits, max_link_errors, do_tuning)

    chips = helpers.get_chip_list(seq)

    thresholds = list(range(
        int(start_threshold),
        int(stop_threshold) - int(step_threshold),
        -int(step_threshold)
    ))

    seq.start_run()

    global_iteration = 0
    for idx, th in enumerate(thresholds):
        for iteration in range(1, max_iterations + 1):
            seq.msg(f"Running threshold {th} (iteration {iteration}/{max_iterations})")
            
            # Set Thresholds and Modes for all chips
            for chip in chips:
                # Set Thresholds
                helpers.set_chip_dac(seq, chip, "ThHigh", int(th))
                helpers.set_chip_dac(seq, chip, "ThLow", int(th - 1))

            # Configure Chips
            helpers.configure_chips(seq)

            # Configure TDACs
            helpers.configure_tdacs(seq)

            # Reset PLL
            helpers.reset_pll(seq, chips)

            helpers.feb_set_to_running(seq)

            # Run Minalyzer
            helpers.run_minalyzer(seq, global_iteration, run_time)

            # Parse information from Minalyzer output
            for chip in chips:
                mdata = seq.odb_get(f"{helpers.odb_path_minalyzer_output}{chip}")
                if mdata:
                    tot_noisy = mdata.get("tot_noisy", 0)
                    unmaskable = mdata.get("unmaskable", 0)
                    seq.msg(f"Chip {chip}: noisy={tot_noisy}, unmaskable={unmaskable}")
                else:
                    seq.msg(f"Chip {chip}: No tuning output found")

            global_iteration += 1


def at_exit(seq):
    """Cleanup function called when sequence exits"""
    seq.odb_set("/Sequencer/Command/Stop immediately", True)
    seq.stop_run()    

    print("Noise scan sequence cleanup")


if __name__ == "__main__":
    start_timer = time.time()
    client = midas.client.MidasClient("NoiseScanClient")
    print("Time taken: ", time.time()-start_timer)
