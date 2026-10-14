import argparse
import sys
sys.path.append("../../")

import mutrig.base_variables as cfg
import mutrig.mutrigTB_variables

import mutrig.eth_selection as eth_ana
import mutrig.ethreshold_scan as eth_scan
import mutrig.Mutrig_basic_functions as m
import midas.client as client

# Standalone / Tests main routine
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Select and export E-threshold settings from a scan."
    )
    parser.add_argument("filename", help="Input E-threshold scan JSON file")
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
    data = eth_ana.read_data(args.filename)
    eths_arr, bad_channels, channels_details = eth_ana.select_rate(
        data, constrate_value=1e0, ratecut=10, skip=4
    )
    config = eth_scan.assemble_config(
        eths_arr, data["settings"], path=filename_output
    )

    if args.apply:
        seq = client.MidasClient("MutrigTuning")
        for key,val in config.items():
            print(f"Updating ODB: {cfg.path_asicsettings}/Channels/{key}")
            seq.odb_set(f"{cfg.path_asicsettings}/Channels/{key}",val)
        
        m.Configure_all_asics(seq)
