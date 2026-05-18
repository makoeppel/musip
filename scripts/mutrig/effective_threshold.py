import numpy as np
from typing import Tuple
from scipy.signal import correlate#, correlation_lags
from scipy.ndimage import shift as nd_shift
from scipy.signal import savgol_filter


class signal_alignment:
    
    def __init__(self):
        pass

    def smooth_curve(self,rate:np.ndarray,window_size:int=11,poly_order:int=5)->np.ndarray:
        '''
        Smoothing of input array using the Savitzky-Golay filter.
        Inputs:
                rate: np.ndarray
                    array of count rate from T-Threshold scan
                window_size: int
                    number of points used for each smoothing point
                poly_order: int
                    highest order of polynomial used for interpolation
                
                CAUTION: 
                    window_size must be greater than poly_order
        Returns:
                rate_smoothed: np.ndarray
                    smoothed input array using a Savitzky-Golay filter
        '''
        rate_smoothed = savgol_filter(rate,window_size,poly_order)
        return rate_smoothed

    def mask_features(self,rate_low:np.ndarray,rate_high:np.ndarray,p_cut:float=0.9,normalise:bool=False)->Tuple[np.ndarray,np.ndarray]:
        '''
        Mask features which are not present in both input arrays.
        Inputs: 
                rate_low: np.ndarray
                    count rate in lower offset
                rate_high: np.ndarray
                    count rate in higher offset
                p_cut: float
                    value between 0 and 1 used to vary window size of arrays
                normalise: bool
                    normalises both arrays to the maximum of rate_high
        Returns: 
                rate_low: np.ndarray
                    masked (and possibly normalised) count rate in lower offset
                rate_high: np.ndarray
                    masked (and possibly normalised) count rate in higher offset
        '''
        rate_low = np.copy(rate_low)
        rate_high = np.copy(rate_high)

        # Find maximum in higher offset array
        max_high = np.max(rate_high)

        if normalise:
            rate_low_norm = rate_low/max_high
            rate_high_norm = rate_high/max_high
            rate_low_norm[rate_low_norm > p_cut] = 0
            rate_high_norm[rate_high_norm > p_cut] = 0
            return rate_low_norm,rate_high_norm
        else:
            # Mask features of lower offset array that are not present in the higher offset array
            rate_low[(rate_low > p_cut*max_high)] = 0
            rate_high[(rate_high > p_cut*max_high)] = 0
            return rate_low, rate_high
    
    '''
    def determine_shift_correlation(self,rate_low,rate_high,p:float,debug=False):
        rate_low_cut, rate_high_cut = self.mask_features(rate_low, rate_high,p_cut=p,normalise=True)
        mask = self.find_overlap(rate_low_cut)
        rate_low_masked = rate_low_cut[mask]
        rate_high_masked = rate_high_cut[mask]
        correlation = correlate(rate_low_masked, rate_high_masked, mode="full")
        lags = correlation_lags(rate_low_masked.size, rate_high_masked.size, mode="full")
        print(correlation)
        opt_shift = np.argmax(correlation)
        if debug:
            print(f'The optimal shift is {opt_shift:.2f}!')
        return opt_shift
    '''
    
    def find_overlap(self, rate_low: np.ndarray) -> list:
        mask = np.nonzero(rate_low)
        return mask
    
    def calculate_cost(self,rate_low:np.ndarray,rate_high_shifted:np.ndarray,rate_low_err:np.ndarray,rate_high_err:np.ndarray)->float:
        '''
        Inputs:
                rate_low: np.ndarray
                    NumPy array of count rate in lower offset
                rate_low_err: np.ndarray
                    NumPy array containing the uncertainty for each data point in the lower offset, default is square root of counts
                rate_high_shifted: np.ndarray
                    NumPy array of count rate in higher offset
                rate_high_err: np.ndarray
                    NumPy array containing the uncertainty for each data point in the higher offset, default is square root of counts
        Returns:
                cost: float 
                    value used for characterising the alignment of the array in the lower offset and the shifted higher offset (lower is better)
        '''
        cost = np.nanmean((rate_low-rate_high_shifted)**2/np.sqrt(rate_low_err**2+rate_high_err**2))
        return cost
    
    def determine_optimal_shift(self,rate_low: np.ndarray, rate_high: np.ndarray, p: float = 0.9, step: float = 1, smooth: bool = False, norm:bool = False, debug:bool = False) -> Tuple[float, list]:
        '''
        Inputs:
            test: np.ndarray
            rate_high: np.ndarray
            p: float
            step: float
            smooth: bool

        Returns:
            opt_shift: float
            cost_total: np.ndarray
        '''
        n = len(rate_high)

        if smooth:
            rate_low = self.smooth_curve(rate_low)
            rate_high = self.smooth_curve(rate_high)

        # Set features of the lower array, which are not present in the higher array, to zero
        rate_low_cut, rate_high_cut = self.mask_features(rate_low, rate_high, p, normalise=norm)
        mask = self.find_overlap(rate_low_cut)
        
        rate_low_masked = rate_low_cut[mask]
        rate_low_masked_err = np.sqrt(rate_low_masked)
        shifts = np.arange(0, n, step)  # fractional shifts are possible
        cost_total = []
        for shift in shifts:
            # Fractional shift without wrap-around
            arr_shifted = nd_shift(rate_high_cut,-shift,cval=0)
            rate_high_masked = arr_shifted[mask]
            rate_high_masked_err = np.sqrt(rate_high_masked)

            if np.all(rate_high_masked == 0) or np.all(rate_low_masked == 0):
                cost_total.append(np.inf)
                continue
            else:
                cost_tmp = self.calculate_cost(rate_low_masked, rate_high_masked, rate_low_masked_err, rate_high_masked_err)
                cost_total.append(cost_tmp)
        if np.all(cost_total==np.inf):
            print('No optimal shift can be determined since for the given cut percentage no overlap is found!')
        # Determine optimal shift from minimisation of the cost function
        opt_index = np.argmin(cost_total)
        opt_shift = shifts[opt_index]
        if cost_total[opt_shift]==np.inf:
            opt_shift=-1
        if debug:
            print(f'The optimal shift is {opt_shift:.2f} with an MSE of {cost_total[opt_index]}!')
        return opt_shift, np.asarray(cost_total)
      
    def optimal_shift_vectorized(self,rate_low: np.ndarray, rate_high: np.ndarray, p: float = 0.9, step: float = 1, smooth: bool = False, norm:bool = False, debug:bool = False, channels=None) -> list:
        if(np.shape(rate_low) != np.shape(rate_high)):
            raise Exception("Shape of T threshold scans dont match, cant find alignment")
        nch = np.shape(rate_low)[0]
        if channels is not None:
            if max(channels) >= nch:
                print("Specified Channels go higher than the number of scans, omitting")
                chs = range(nch)
            chs = channels
        else:
            chs = range(nch)
        print(nch)
        opt_shifts = []
        for i in chs:
            shift, cost = self.determine_optimal_shift(rate_low[i], rate_high[i], p=p, step=step, smooth=smooth, norm=norm, debug=debug)  
            opt_shifts.append(shift)
        return opt_shifts
