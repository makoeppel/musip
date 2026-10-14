
import json

def select_rate(filename,constrate_value, ratecut, skip=0):
    print("Selecting TTH based on constant target rate of ",constrate_value," Hz")
    with open(filename) as json_file:
        module_data = json.load(json_file)
        tths = module_data[f'th']
        rates = module_data[f'rates']
    print("Number of channels: ",len(tths)) 
    bad_channels = []
    good_channels = []
    tths_arr = []
    offs_arr = []

    channels_details = [ [] for i in range(len(rates)) ]

    for channel, (tth, rate) in enumerate(zip(tths, rates)):
        if len(tth) != len(rate):
            raise ValueError(f"Channel {channel} has mismatched tth and rate lengths")
        # Split in groups per offset. This is needed because the scan in the next offset might start again at low rate,
        # needing to restart the search in each offset group
        offset_groups = {}
        for th_value, rate_value in zip(tth, rate):
            tth_val    = th_value % 64
            offset = int( (th_value-tth_val) / 64)
            offset_groups.setdefault(offset, []).append((tth_val, rate_value))

        passed_ratecut = False
        selected_th = None
        selected_offset = None
        for offset in sorted(offset_groups):
            offset_data = offset_groups[offset]
            ratecut_index = next(
                (i for i, (_, value) in enumerate(offset_data) if value >= ratecut and i > skip),
                None,
            )
            if ratecut_index is None:
                continue
            passed_ratecut = True

            #print(f"Search from {ratecut_index} : {offset_data[ratecut_index:]}")
            for th_value, rate_value in offset_data[ratecut_index:]:
                if rate_value < constrate_value:
                    selected_th = th_value%64
                    selected_offset = offset
                    break

            if selected_th is not None:
                break

        if selected_th is None:
            bad_channels.append(channel)
            channels_details[channel].append("bad")
            channels_details[channel].append(
                "ratecut" if not passed_ratecut else "no_threshold"
            )
            tths_arr.append(63)
            offs_arr.append(0)
            
        else:
            channels_details[channel].append("good")
            tths_arr.append(selected_th % 64)
            offs_arr.append(selected_offset)
            good_channels.append(channel)
        
        print(f"Channel {channel} -> Sel={selected_th} ({tths_arr[-1]},{offs_arr[-1]}) | {channels_details[channel]}")

    good_channels.sort()
    bad_channels.sort()
    print("good channels: ",good_channels)
    #print("bad channels: ",bad_channels)

    return tths_arr, offs_arr, bad_channels, channels_details
