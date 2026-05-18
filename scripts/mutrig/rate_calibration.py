import sys
sys.path.append("../../python/")
from datetime import datetime
import numpy as np
import re
import json
import mutrig.base_variables as cfg

import mutrig.effective_threshold as efftth
import mutrig.Mutrig_basic_functions as m

# defined values for the cuts:
ratecut = 100
rangecutx = 5e1
rangecuty = 15

def find_max_value_limit(selected_list,limit_value,offset_value):
    max_value_index = 0
    max_value = 0
    if(limit_value > len(selected_list)):
        print("limit value is larger than size of the list!")
        return
    for i in range(limit_value):
        index = i + offset_value*limit_value
        if(selected_list[index] > max_value):
            max_value = selected_list[index]
            max_value_index = index
    return max_value_index
    
def cut_rate(rates, dim_tth, offset, rate_cut):
    low_rate_channels = []
    for i in range(len(rates)):
        index_max = find_max_value_limit(rates[i],dim_tth,offset)
        if(rates[i][index_max] < rate_cut):
            low_rate_channels.append(i)    
    return low_rate_channels

def cut_range(rates, dim_tth, offset, thresh, interv):
    # discriminating, for which settings the scan lies above thresh
    # if those numbers arent contained in an interval of size interv, throw them out
    #print("cut_range called")
    print("Range Cut function uses --Xlim:   ",  "{:<12}".format(thresh), ", --Ylim:      ", "{:<12}".format(interv))
    if(dim_tth > len(rates)):
        print("limit value of dim_tth is larger than size of the rates array!")
        return
    rates_current = [ [] for i in range(len(rates)) ] # restructure the rates array to be for one offset
    badch_range = np.array([])
    contained = np.array([])
    for i in range(len(rates)):
        for j in range(dim_tth):
            index = j + offset*dim_tth
            rates_current[i].append(rates[i][index])
    
    channels= np.arange(0, len(rates_current), 1)
    data = np.array(rates_current)[channels.astype(int)]

    for i in range(len(rates_current)):
        if sum(data[i]) == 0:
            continue;
        indices = np.argwhere(data[i] > thresh)[:, 0]
        longest_streak = 0
        current_streak = 1
        # Iterate through the sorted array
        for j in range(1, len(indices)):
            # Check if the current element is consecutive to the previous element
            if indices[j] != indices[j - 1]:  # Skip duplicates
                if indices[j] == indices[j - 1] + 1:
                    current_streak += 1
                else:
                    longest_streak = max(longest_streak, current_streak)
                    current_streak = 1
    
        # Return the longest sequence length
        streak = max(longest_streak, current_streak)
        contained = np.append(contained, streak)
        if streak < interv:
            badch_range = np.append(badch_range, channels[i])

    return badch_range.astype(int)
    
#TODO: move to tth calibration
def read_tthscan(filename):
    # read out the scan file to determine the dimensions:
    with open(filename) as json_file:
        module_data = json.load(json_file)
        tths = module_data[f'th']
        rates = module_data[f'rates']
        # try to determine what were the dimensions for tth and offset
        counter_tth = 0
        start_tth = 0
        if(tths[0][0] != 0):
            start_tth = tths[0][0]
        for i in range(len(tths[0])):
            if(tths[0][i]<64):
                counter_tth = counter_tth + 1;
        counter_off = (len(tths[0]) - counter_tth)/counter_tth;
        print("The range for tth is: (", start_tth,",",counter_tth-1,"), for offset: ( 0,",int(counter_off),")")
    return start_tth, counter_tth, int(counter_off)
    
def read_tth_calib_odb(filename):
    with open(filename) as json_file:
        module_data = json.load(json_file)
        # read json based on how it was written in write_config_odb       
    tths_calib = module_data[f'tthresh']
    tths_offsets = module_data[f'tthresh_offset']
    tths = []    
    for i in range(416):
        tths.append(63 - tths_calib[i])
    return tths, tths_offsets
    
def select_tth(filename,constrate,constrate_value,high_to_low,debug):
    if constrate == True: 
        tths_arr, offsets_arr, bad_channels, channels_details = select_tth_const(filename,constrate_value,high_to_low,debug)
    else:
        select_tth_dyn(filename)
        
    return tths_arr, offsets_arr, bad_channels, channels_details

def select_tth_const(filename,constrate_value,high_to_low = False, debug = False):
    print("Selecting TTH based on constant target rate of ",constrate_value," Hz")
    start_tth, dim_tth, dim_off = read_tthscan(filename)
    print("Dimension for tth and offset are: ", dim_tth, dim_off,"; start of tth: ", start_tth)
    with open(filename) as json_file:
        module_data = json.load(json_file)
        tths = module_data[f'th']
        rates = module_data[f'rates']
    print("Number of channels: ",len(tths)) 
    tths_arr = np.zeros(len(tths))
    off_arr = np.zeros(len(tths))
    bad_channels = []
    good_channels = []
    low_rate_channels = []
    channels_details = [ [] for i in range(len(rates)) ]
    
    for off in range(dim_off + 1):
        print("Starting analysis of T-offset ",off)
        low_rate_channels = cut_rate(rates, dim_tth, off, ratecut)
        range_channels = cut_range(rates, dim_tth, off,rangecutx, rangecuty)        
        for i in range(len(tths)):
            # skip channel if it's already determined as "good":
            if i in good_channels:
                #print("Channel ",i," is already good")
                continue
            chosen_threshold_value = -1
            index_max = find_max_value_limit(rates[i],dim_tth,off)
            if i in low_rate_channels:
                if i not in bad_channels:
                    bad_channels.append(i)
                chosen_threshold_value = 0
                tths_arr[i] = chosen_threshold_value
                channels_details[i].append("bad")
                channels_details[i].append("ratecut")
                continue
            if i in range_channels:
                if i not in bad_channels:
                    bad_channels.append(i)
                chosen_threshold_value = 0
                tths_arr[i] = chosen_threshold_value
                channels_details[i].append("bad")
                channels_details[i].append("rangecut")
                continue
            if high_to_low == False:
                chosen_rate_value = 0
                for j in range(dim_tth):
                    index_tth = (dim_tth + off*dim_tth) - 1 - j
                    if (rates[i][index_tth] < constrate_value and rates[i][index_tth] > chosen_rate_value):
                        if (index_tth < index_max + 2): # don't look further than the max rate of the scan
                            break
                        chosen_rate_value = rates[i][index_tth]
                        chosen_threshold_value = (63 + off*dim_tth) - tths[i][index_tth] # these values are reversed! -> for config need to write them as 63-tth!
                if (chosen_threshold_value == -1):
                    if i not in bad_channels:
                        bad_channels.append(i)
                    chosen_threshold_value = 0
                    channels_details[i].append("bad")
                    channels_details[i].append("selection")
                else:
                    good_channels.append(i)
                    channels_details[i].append("good")
                    if i in bad_channels:
                        if debug:
                            print("This channel (",i,") is in bad channels list, removing it")
                        bad_channels.remove(i)
                tths_arr[i] = chosen_threshold_value
                off_arr[i] = off
            else:
                chosen_rate_value = rates[i][index_max]
                for j in range(dim_tth):
                    index_tth = j + off*dim_tth
                    if (index_tth > index_max + 2 and rates[i][index_tth] < constrate_value and rates[i][index_tth] < chosen_rate_value):
                        chosen_rate_value = rates[i][index_tth]
                        chosen_threshold_value = (63 + off*dim_tth) - tths[i][index_tth] # these values are reversed! -> for config need to write them as 63-tth!
                        break
                if (chosen_threshold_value == -1):
                    if i not in bad_channels:
                        bad_channels.append(i)
                    chosen_threshold_value = 0
                    channels_details[i].append("bad")
                    channels_details[i].append("selection")
                else:
                    good_channels.append(i)
                    channels_details[i].append("good")
                    if i in bad_channels:
                        if debug:
                            print("This channel (",i,") is in bad channels list, removing it")
                        bad_channels.remove(i)
                tths_arr[i] = chosen_threshold_value
                off_arr[i] = off
                
    np.sort(good_channels)    
    np.sort(bad_channels)    
    if debug:
        print("good channels: ",good_channels)
        print("bad channels: ",bad_channels)
    
    counter_bad_channels_mod0 = 0
    counter_good_channels_mod0 = 0
    for i in range(len(bad_channels)):
        if(bad_channels[i] < 416):
            counter_bad_channels_mod0 = counter_bad_channels_mod0 + 1
    for i in range(len(good_channels)):
        if(good_channels[i] < 416):
            counter_good_channels_mod0 = counter_good_channels_mod0 + 1
    print("amount of bad channels in mod0: ",counter_bad_channels_mod0)
    print("amount of good channels in mod0: ",counter_good_channels_mod0)
    
    if tths_arr.max() > 63:
        print("Some TTH was found bigger than 63!")
    if off_arr.max() > dim_off:
        print("Some TTH offset was found bigger than the measured dimension of the offsets!")

    if debug:
        print(np.array2string(tths_arr, threshold = np.inf))

    return tths_arr, off_arr, bad_channels, channels_details
    
def select_tth_dyn(filename):
    print("Selecting TTH based on dynamic algorithm")

def select_eth(filename,constrate_value,led,high_to_low,debug):
    if led == True: 
        eths_arr = select_eth_led(filename,constrate_value,debug)
    else:
        eths_arr = select_eth_const(filename,constrate_value,high_to_low,debug)
        
    return eths_arr

def select_eth_const(filename,constrate_value,high_to_low = False,debug = False):
    print("Selecting ETH based on constant target rate of ",constrate_value," Hz")
    with open(filename) as json_file:
        module_data = json.load(json_file)
        eths = module_data[f'th']
        rates = module_data[f'rates']
    # Find the thresholds based on const target rate
    bad_channels = []
    good_channels = []
    eths_arr = np.zeros(len(eths))
    dim_eth = len(eths[0])
    for i in range(len(eths)):
        index_max = find_max_value_limit(rates[i],dim_eth,0)
        if high_to_low == False:
            chosen_rate_value = 0
            chosen_threshold_value = -1
            for j in range(dim_eth):
                index_tth = dim_eth - 1 - j
                if (rates[i][index_tth] < constrate_value and rates[i][index_tth] > chosen_rate_value):
                    if (index_tth < index_max + 2): # don't look further than the max rate of the scan
                        break
                    chosen_rate_value = rates[i][index_tth]
                    chosen_threshold_value = dim_eth - 1 - eths[i][index_tth] # these values are reversed! -> for config need to write them as 63-tth!
            if (chosen_threshold_value == -1):
                if i not in bad_channels:
                    bad_channels.append(i)
                chosen_threshold_value = 0
            else:
                good_channels.append(i)
                if i in bad_channels:
                    if debug:
                        print("This channel (",i,") is in bad channels list, removing it")
                    bad_channels.remove(i)
            eths_arr[i] = chosen_threshold_value
        else:
            chosen_rate_value = rates[i][index_max]
            chosen_threshold_value = -1
            for j in range(dim_tth):
                index_tth = j
                if (index_tth > index_max + 2 and rates[i][index_tth] < constrate_value and rates[i][index_tth] < chosen_rate_value):
                    chosen_rate_value = rates[i][index_tth]
                    chosen_threshold_value = dim_eth - 1 - tths[i][index_tth] # these values are reversed! -> for config need to write them as 63-tth!
                    break
            if (chosen_threshold_value == -1):
                if i not in bad_channels:
                    bad_channels.append(i)
                chosen_threshold_value = 0
            else:
                good_channels.append(i)
                if i in bad_channels:
                    if debug:
                        print("This channel (",i,") is in bad channels list, removing it")
                    bad_channels.remove(i)
            eths_arr[i] = chosen_threshold_value

    counter_bad_channels_mod0 = 0
    counter_good_channels_mod0 = 0
    for i in range(len(bad_channels)):
        if(bad_channels[i] < 416):
            counter_bad_channels_mod0 = counter_bad_channels_mod0 + 1
    for i in range(len(good_channels)):
        if(good_channels[i] < 416):
            counter_good_channels_mod0 = counter_good_channels_mod0 + 1
    print("amount of bad channels in mod0: ",counter_bad_channels_mod0)
    print("amount of good channels in mod0: ",counter_good_channels_mod0)

    if debug:
        print(np.array2string(eths_arr, threshold = np.inf))
    return eths_arr

def select_eth_led(filename,constrate_value,debug = False):
    print("Selecting ETH from scan with LED with rate of ",constrate_value," Hz")
    with open(filename) as json_file:
        module_data = json.load(json_file)
    eths = module_data[f'th']
    rates = module_data[f'rates']
    bad_channels = []
    good_channels = []
    eths_arr = np.zeros(len(eths))
    dim_eth = len(eths[0])
    if debug:
        print("dim_eth: ",dim_eth)
    
    constrate_value_adjusted = constrate_value - 0.1*constrate_value
    
    for i in range(len(eths)):
        chosen_rate_value = 0
        chosen_threshold_value = -1
        for j in range(dim_eth):
            index_eth = dim_eth - 1 - j
            if (rates[i][index_eth] > constrate_value_adjusted and chosen_threshold_value == -1): # first one to cross the rate border
                chosen_rate_value = rates[i][index_eth]
                chosen_threshold_value = dim_eth - 1 - eths[i][index_eth] # these values are reversed! -> for config need to write them as 63-tth!
        if (chosen_threshold_value == -1):
            if i not in bad_channels:
                bad_channels.append(i)
            chosen_threshold_value = 0
        else:
            good_channels.append(i)
            if i in bad_channels:
                if debug:
                    print("This channel (",i,") is in bad channels list, removing it")
                bad_channels.remove(i)
        eths_arr[i] = chosen_threshold_value

    counter_bad_channels_mod0 = 0
    counter_good_channels_mod0 = 0
    for i in range(len(bad_channels)):
        if(bad_channels[i] < 416):
            counter_bad_channels_mod0 = counter_bad_channels_mod0 + 1
    for i in range(len(good_channels)):
        if(good_channels[i] < 416):
            counter_good_channels_mod0 = counter_good_channels_mod0 + 1
    print("amount of bad channels in mod0: ",counter_bad_channels_mod0)
    print("amount of good channels in mod0: ",counter_good_channels_mod0)
            
    if debug:
        print(np.array2string(eths_arr, threshold = np.inf))
    return eths_arr

# Add this to rate_calibration.py

def select_eth_zero(filename, debug=False):
    """
    Select ETH based on first non-zero rate when scanning from high to low physical threshold.
    
    For each channel, when going from highest threshold down:
    - Find the first point where rate becomes non-zero (>0)
    - Take the threshold value BEFORE that point (the last zero-rate threshold)
    
    Args:
        filename: path to the JSON file with e-threshold scan data
        debug: if True, print debug information
    
    Returns:
        eths_arr: array of e-threshold values for each channel
    """
    print("Selecting ETH based on first non-zero rate (scanning from high to low)")
    
    with open(filename) as json_file:
        module_data = json.load(json_file)
        thresholds = module_data['th']  # Note: in e-threshold scan, this is named 'th' in the JSON
        rates = module_data['rates']
        settings = module_data['settings']
    
    n_channels = len(thresholds)
    n_points = len(thresholds[0])
    
    eths_arr = np.zeros(n_channels)
    bad_channels = []
    good_channels = []
    
    for ch in range(n_channels):
        chosen_threshold = -1
        
        # Scan from highest threshold down (index 0 is lowest threshold? need to check)
        # Based on the scan code: threshold increases with iteration, so index 0 = start_threshold
        # We want to go from highest (last index) to lowest (first index)
        for i in range(n_points-1, -1, -1):
            if rates[ch][i] > 1:  # Found first non-zero rate
                if i > 1:  # Take the threshold before this point
                    chosen_threshold = thresholds[ch][i+2]
                else:
                    # If first point is already non-zero, take that threshold
                    chosen_threshold = thresholds[ch][i]
                break
        
        if chosen_threshold == -1:
            # No non-zero rate found in entire scan
            if ch not in bad_channels:
                bad_channels.append(ch)
            chosen_threshold = 0
            if debug:
                print(f"Channel {ch}: No non-zero rate found")
        else:
            good_channels.append(ch)
            if debug:
                print(f"Channel {ch}: First non-zero at {thresholds[ch][i]} Hz (threshold={chosen_threshold})")
        if chosen_threshold ==0:
            chosen_threshold = 255
        eths_arr[ch] = 255-chosen_threshold # convert to MIDAS threshold
    
    # Statistics
    print(f"Channels with valid threshold: {len(good_channels)}")
    print(f"Bad channels (no non-zero rate): {len(bad_channels)}")
    
    if debug and bad_channels:
        print(f"Bad channels: {bad_channels}")
    
    return eths_arr

# Append effective threshold calculation here using read in methods from this script
def align_flat_offsets(filename, channels=None):
    aligner = efftth.signal_alignment();
    start_tth, dim_tth, dim_off = read_tthscan(filename)
    with open(filename) as json_file:
        module_data = json.load(json_file)
        tths  = module_data[f'th']
        rates = module_data[f'rates']
  
    #Take number of channels from 'rates' shape
    nch = np.shape(rates)[0]
    rates_per_offset = np.reshape(np.array(rates), (nch, dim_off+1, dim_tth))
    rates_per_offset = np.swapaxes(rates_per_offset, 0, 1)
    
    #Calculate offset factors and output array of dim nch
    print("Calling vectorized function here")
    alpha = [aligner.optimal_shift_vectorized(rates_per_offset[dim_off-i-1], rates_per_offset[dim_off-i], smooth = False, p = 0.9, step = 1, norm = False, channels=channels, debug=True) for i in range(dim_off)]
    return alpha

def tth_to_efftth(filename, channels=None):
    tths_arr, offsets_arr, bad_channels, channels_details = select_tth(filename,constrate=True,constrate_value=10000,high_to_low = False)
    alpha = align_flat_offsets(filename, channels=channels) 
    if channels is not None:
        print("using channels array")
    else:
        channels = range(len(tths_arr))
    print("Conversion factors have shape", np.shape(np.array(alpha).T), "tth have", np.shape(tths_arr), "tthoff have", np.shape(offsets_arr))
    #debugging
    #for i in channels:
    #    x = np.array(alpha).T[i][:int(offsets_arr[i])]
    #    print(x, np.shape(x))
    return [tths_arr[i] + np.sum(np.array(alpha).T[i][:int(offsets_arr[i])]) for i in channels]

    # output: 
    # conversion factor
    # effective threshold
# Standalone / Tests main routine
if __name__ == "__main__":
    
    filename = "./ttheshold_scan15122025-HV56.0-module7-flippedTTH.json"
        
    #tths_arr, offsets_arr, bad_channels, channels_details = select_tth(filename,constrate=True,constrate_value=10000,high_to_low = False)
    
