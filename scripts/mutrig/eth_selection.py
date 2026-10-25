
import json

def read_data(filename):
    with open(filename) as json_file:
        return json.load(json_file)

def select_rate(data,constrate_value, ratecut, skip=0):
    print("Selecting TTH based on constant target rate of ",constrate_value," Hz")
    
    tths = data[f'th']
    rates = data[f'rates']
    print("Number of channels: ",len(tths)) 
    bad_channels = []
    good_channels = []
    tths_arr = []

    channels_details = [ [] for i in range(len(rates)) ]

    for channel, (tth, rate) in enumerate(zip(tths, rates)):
        if len(tth) != len(rate):
            raise ValueError(f"Channel {channel} has mismatched tth and rate lengths")
        if len(tth) == 0:
            tths_arr.append(255)
            continue
            #raise ValueError(f"Channel {channel} has zero tth and rate lengths")
        passed_ratecut = False
        ratecut_index = max(range(len(rate)), key=rate.__getitem__)
        if(rate[ratecut_index] > ratecut):
            passed_ratecut = True

        selected_th = None

        #print(f"Search from {ratecut_index} : {offset_data[ratecut_index:]}")
        for th_value, rate_value in zip(tth[ratecut_index:],rate[ratecut_index:]):
            if rate_value < constrate_value:
                selected_th = th_value
                break

        if (selected_th is None) or (not passed_ratecut):
            bad_channels.append(channel)
            channels_details[channel].append("bad")
            channels_details[channel].append(
                "ratecut" if not passed_ratecut else "no_threshold"
            )
            tths_arr.append(255)            
        else:
            channels_details[channel].append("good")
            tths_arr.append(selected_th)
            good_channels.append(channel)
        print(f"Channel {channel} -> Sel={selected_th} | {channels_details[channel]}")

    good_channels.sort()
    bad_channels.sort()
    print("good channels: ",good_channels)
    #print("bad channels: ",bad_channels)

    return tths_arr, bad_channels, channels_details

