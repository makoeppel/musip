#!/usr/bin/env -S python3
import argparse
import sys
sys.path.append("../../")

import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.tth_selection as tth_ana
import mutrig.tthreshold_scan as tth_scan
import mutrig.Mutrig_basic_functions as m
import midas.client as client

# Standalone / Tests main routine
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Select and export T-threshold settings from a scan."
    )
    parser.add_argument("filename", help="Input T-threshold scan JSON file")
    parser.add_argument(
        "-o",
        "--output",
        metavar="FILENAME",
        help="Output ODB configuration JSON file (default: INPUT.calib.json)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Upload the selected threshold configuration to ODB",
    )
    args = parser.parse_args()

    filename_output = args.output or args.filename + ".calib.json"
    tths_arr, offsets_arr, bad_channels, channels_details = tth_ana.select_rate(
        args.filename, constrate_value=1e4, ratecut=1e3, skip=4
    )
    config = tth_scan.assemble_config(tths_arr, offsets_arr, path=filename_output)

    if args.apply:
        seq = client.MidasClient("MutrigTuning")
        for key,val in config.items():
            print(f"Updating ODB: {cfg.path_asicsettings}/Channels/{key}")
            seq.odb_set(f"{cfg.path_asicsettings}/Channels/{key}",val)
        
        m.Configure_all_asics(seq)
