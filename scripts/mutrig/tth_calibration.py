"""
threshold_calibration.py
=========================

Utilities for rate-vs-threshold scans made of several "sections" that were
each recorded at a different coarse DAC setting ("offset"), with the raw
threshold code given as

    th = block_size * offset + tth        (tth in [0, block_size))

Because the physical (continuous) threshold does not necessarily advance by
exactly `block_size` codes for every increment of `offset` (DAC non-
linearity, deliberately overlapping scans, etc.), stitching the sections
into one physically-meaningful axis requires calibrating a `scale` such
that

    th_continuous_raw = offset * scale + tth

`scale` is found empirically: for every pair of neighbouring offset
sections, the tail of one rate curve is compared against the head of the
next over a range of candidate shifts, and the shift that gives the best
statistical match (lowest reduced chi-square, using Poisson counting
errors sigma_rate = sqrt(rate)) is taken as the true overlap width. Doing
this over many channels and taking the median makes the result robust
against channels with little or no signal.

On top of that, a **zero-point** calibration is applied: each channel's
rate curve rises out of the noise floor at some threshold ("turn-on"
point). That point is found per channel (again using the Poisson errors
to define a statistically significant rise above baseline) and the
median over channels gives a global `zero_offset`, which is subtracted so
that th_continuous = 0 sits at the point where the data just starts to
rise:

    th_continuous = offset * scale + tth - zero_offset

Public functions
-----------------
plot_channel(data, filenames, channel, ...)          -- plotting
find_rise_edge(th_continuous, rate, rate_err, ...)    -- turn-on point of one curve
calibrate_channel(th, rates, block_size)              -- single channel calibration
calibrate_channels(data, channels, ...)               -- multi-channel calibration
save_calibration(calibration, path)                   -- write JSON
load_calibration(path)                                -- read JSON
th_to_continuous(th, calibration, channel=None)        -- th   -> th_continuous
apply_calibration(dataset, calibration, channels=None) -- apply to a full dataset
continuous_to_th(th_continuous, calibration, channel)   -- th_continuous -> (offset, tth, th)
"""

from __future__ import annotations

import json
import numpy as np
import matplotlib.pyplot as plt


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def _poisson_sigma(rate):
    """
    Default statistical uncertainty on a rate/count value:
    sigma_rate = sqrt(rate), floored at sqrt(1) so that zero-count bins
    don't get an (unphysical) zero uncertainty / infinite weight.
    """
    rate = np.asarray(rate, dtype=float)
    return np.sqrt(np.maximum(rate, 1.0))


# ---------------------------------------------------------------------------
# 1) Plotting a single channel
# ---------------------------------------------------------------------------
def plot_channel(data, filenames, channel, ax=None, use_continuous=False,
                  calibration=None, logy=True, **plot_kwargs):
    """
    Plot rate vs. threshold for ONE channel, overlaying every dataset in
    `data` (mirrors the loop given in the prompt, just restricted to one
    channel and pulled out into a reusable function).

    Parameters
    ----------
    data : list[dict]
        Each dict must have 'th' and 'rates' indexable by `channel`, i.e.
        dataset['th'][channel] / dataset['rates'][channel] -> 1D array-like.
    filenames : list[str]
        Label per dataset, same order as `data`.
    channel : int
        Channel index to plot.
    ax : matplotlib.axes.Axes, optional
        Draws into this axis if given, otherwise creates a new figure.
    use_continuous : bool, default False
        If True, plot against th_continuous (needs `calibration`, and
        includes the zero-point shift) instead of the raw 'th' values.
    calibration : dict, optional
        Required when use_continuous=True. As returned by
        calibrate_channels()/load_calibration().
    logy : bool, default True
        Use a log scale on the rate axis (typical for these scans, which
        span many orders of magnitude).
    **plot_kwargs :
        Forwarded to ax.plot (e.g. marker='.', lw=1).

    Returns
    -------
    matplotlib.axes.Axes
    """
    if ax is None:
        _, ax = plt.subplots(figsize=(8, 5))

    xlabel = 'th'
    for i, dataset in enumerate(data):
        th = np.asarray(dataset['th'][channel])
        rates = np.asarray(dataset['rates'][channel])

        if use_continuous:
            if calibration is None:
                raise ValueError("calibration must be given when use_continuous=True")
            th_plot = th_to_continuous(th, calibration, channel=channel)
            xlabel = 'th_continuous'
        else:
            th_plot = th

        label = filenames[i] if i < len(filenames) else f'dataset {i}'
        ax.plot(th_plot, rates, label=f'{label} - Channel {channel}', **plot_kwargs)

    ax.set_xlabel(xlabel)
    ax.set_ylabel('rate')
    if logy:
        ax.set_yscale('log')
    ax.set_title(f'Channel {channel}')
    ax.legend(fontsize=8)
    return ax


# ---------------------------------------------------------------------------
# 2) Calibration core -- scale (section stitching)
# ---------------------------------------------------------------------------
def _split_sections(th, block_size):
    """offset = th // block_size ; tth = th % block_size."""
    th = np.asarray(th)
    offset = th // block_size
    tth = th % block_size
    return offset, tth


def _weighted_shift(ref, tgt, max_shift, ref_err=None, tgt_err=None):
    """
    Find the integer shift s (|s| <= max_shift) that best aligns `tgt`
    with `ref` in their overlap region, using a variance-weighted
    correlation in log-space that accounts for the Poisson counting
    fluctuations sigma_rate = sqrt(rate) of each point.

    Rationale: these rate curves span many decades, so shape matching is
    done in log1p(rate) space (as in the un-weighted version). A given
    absolute counting uncertainty sigma_rate translates to a log-space
    uncertainty of sigma_log = sigma_rate / (1 + rate) (error
    propagation through log1p). Points with a large sigma_log -- i.e.
    statistically insignificant / very noisy points, dominantly at very
    low counts -- get a small weight 1/sigma_log^2 and therefore cannot
    spuriously pull the alignment, while well-measured points drive the
    match.

    For a trial shift s, the weighted Pearson correlation between
    log1p(ref[i]) and log1p(tgt[i-s]) is computed over the overlap range,
    with weight w_i = 1 / (sigma_log_ref[i]^2 + sigma_log_tgt[i-s]^2).
    The shift with the highest weighted correlation is returned.

    Parameters
    ----------
    ref, tgt : array-like
        Rate values of the two sections to align.
    max_shift : int
    ref_err, tgt_err : array-like, optional
        Per-point 1-sigma uncertainties on ref/tgt (in rate units).
        Defaults to sqrt(rate) (floored at 1 count) if not given.

    Returns
    -------
    best_shift : int
    best_score : float in [-1, 1]
        Weighted correlation coefficient at the best shift (higher is
        a better match); used the same way a plain correlation
        coefficient would be, e.g. thresholded via `min_score`.
    weighted_chi2 : float
        Weighted mean squared residual at the best shift, for
        diagnostics (not used for the shift search itself).
    """
    ref = np.asarray(ref, dtype=float)
    tgt = np.asarray(tgt, dtype=float)
    ref_err = _poisson_sigma(ref) if ref_err is None else np.asarray(ref_err, dtype=float)
    tgt_err = _poisson_sigma(tgt) if tgt_err is None else np.asarray(tgt_err, dtype=float)

    log_ref = np.log1p(ref)
    log_tgt = np.log1p(tgt)
    sig_log_ref = ref_err / (1.0 + ref)
    sig_log_tgt = tgt_err / (1.0 + tgt)

    n = len(ref)
    best_shift, best_score, best_chi2 = 0, -np.inf, np.inf

    for s in range(-max_shift, max_shift + 1):
        if s >= 0:
            a, wa = log_ref[s:], sig_log_ref[s:]
            b, wb = log_tgt[: n - s], sig_log_tgt[: n - s]
        else:
            a, wa = log_ref[: n + s], sig_log_ref[: n + s]
            b, wb = log_tgt[-s:], sig_log_tgt[-s:]

        if len(a) < 4:
            continue

        var = wa ** 2 + wb ** 2
        var = np.where(var <= 0, np.nan, var)
        w = 1.0 / var
        w = np.nan_to_num(w, nan=0.0, posinf=0.0)
        wsum = w.sum()
        if wsum <= 0:
            continue

        mean_a = np.average(a, weights=w)
        mean_b = np.average(b, weights=w)
        da, db = a - mean_a, b - mean_b
        var_a = np.average(da ** 2, weights=w)
        var_b = np.average(db ** 2, weights=w)
        if var_a <= 0 or var_b <= 0:
            continue

        cov = np.average(da * db, weights=w)
        score = cov / np.sqrt(var_a * var_b)
        chi2 = np.average(da ** 2 + db ** 2, weights=w)  # diagnostic only
        #print(f"shift {s}: score={score:.3f}, chi2={chi2:.3f}")
        if score > best_score:
            best_score, best_shift, best_chi2 = score, s, chi2

    if not np.isfinite(best_score):
        return 0, 0.0, np.inf

    return best_shift, float(best_score), float(best_chi2)


# ---------------------------------------------------------------------------
# 2b) Zero-point calibration -- find where the data starts to rise
# ---------------------------------------------------------------------------
def find_rise_edge(th, rate, rate_err=None, n_sigma=5.0, baseline_n=5):
    """
    Find the threshold value at which a rate curve rises out of the noise
    floor ("turn-on" point), using the Poisson counting uncertainty
    sigma_rate = sqrt(rate) to define what counts as a statistically
    significant rise.

    Method
    ------
    1. Estimate a baseline level & its uncertainty from the first
       `baseline_n` points (assumed to be below threshold, i.e. no
       signal yet).
    2. Define a decision level = baseline + n_sigma * sigma, where sigma
       combines the baseline uncertainty and the point-by-point Poisson
       uncertainty.
    3. Scan from low to high threshold for the first point that crosses
       this level, then linearly interpolate between that point and the
       previous one to get a sub-bin-precision crossing threshold.

    Parameters
    ----------
    th, rate : array-like
        Threshold axis (any monotonic units -- raw th or th_continuous)
        and matching rate values for ONE channel/curve. Need not be
        pre-sorted; they are sorted internally by `th`.
    rate_err : array-like, optional
        1-sigma uncertainty per point. Defaults to sqrt(rate) (floored at
        1 count).
    n_sigma : float, default 5.0
        How many standard deviations above baseline counts as "starting
        to rise".
    baseline_n : int, default 5
        Number of leading (lowest-threshold) points used to estimate the
        baseline.

    Returns
    -------
    float or None
        The threshold value where the curve crosses the decision level,
        or None if no such crossing is found (e.g. curve never rises).
    """
    th = np.asarray(th, dtype=float)
    rate = np.asarray(rate, dtype=float)
    order = np.argsort(th)
    th, rate = th[order], rate[order]

    if rate_err is None:
        rate_err = _poisson_sigma(rate)
    else:
        rate_err = np.asarray(rate_err, dtype=float)[order]

    if len(rate) < baseline_n + 1:
        return None

    baseline = float(np.median(rate[:baseline_n]))
    baseline_sigma = float(np.median(rate_err[:baseline_n]))
    level = baseline + n_sigma * max(baseline_sigma, 1.0)

    above = np.where(rate[baseline_n:] >= level)[0]
    if len(above) == 0:
        return None
    i = baseline_n + int(above[0])

    th0, th1 = th[i - 1], th[i]
    r0, r1 = rate[i - 1], rate[i]
    if r1 == r0:
        return float(th1)

    frac = (level - r0) / (r1 - r0)
    frac = min(max(frac, 0.0), 1.0)
    return float(th0 + frac * (th1 - th0))


# ---------------------------------------------------------------------------
# 3) Per-channel / multi-channel calibration
# ---------------------------------------------------------------------------
def calibrate_channel(th, rates, block_size=64, max_shift=None,
                       rate_err=None, n_sigma_rise=5.0, baseline_n=5,
                       skip_first=0):
    """
    Determine, for ONE channel:
      - the true 'scale' (continuous-threshold units per offset step),
        found by chi-square-matching the overlap of consecutive offset
        sections (using Poisson errors sigma_rate = sqrt(rate)),
      - the 'rise_edge' (turn-on threshold), found in the resulting
        scale-only continuous axis (offset*scale + tth), i.e. before any
        zero-point shift is applied.

    Parameters
    ----------
    th, rates : array-like
        Raw threshold codes and matching rates for one channel, e.g.
        dataset['th'][channel] / dataset['rates'][channel].
    block_size : int, default 64
        Nominal section width (matches "th = 64*offset + tth").
    max_shift : int, optional
        Search window for the alignment shift; default block_size // 2.
    rate_err : array-like, optional
        1-sigma uncertainty per rate point, same length/order as `rates`.
        Defaults to sqrt(rate) (floored at 1 count) wherever needed.
    n_sigma_rise, baseline_n :
        Passed through to find_rise_edge().
    skip_first : int, default 0
        Number of leading datapoints to omit from the calibration.

    Returns
    -------
    dict:
        scale        : float, best-fit continuous units per offset step
        shifts       : list[int], per-boundary shift (n_offsets - 1 entries)
        scores       : list[float], quality score (0,1] for each shift
        reduced_chi2 : list[float], reduced chi-square for each shift
        n_offsets    : int, number of offset sections detected
        block_size   : int, as given
        rise_edge    : float or None, turn-on point in scale-only
                       continuous units (offset*scale + tth)
    """
    th = np.asarray(th)
    rates = np.asarray(rates, dtype=float)
    if rate_err is not None:
        rate_err = np.asarray(rate_err, dtype=float)

    if (not isinstance(skip_first, (int, np.integer))
            or isinstance(skip_first, (bool, np.bool_)) or skip_first < 0):
        raise ValueError("skip_first must be a non-negative integer")
    if skip_first >= len(th) and skip_first:
        raise ValueError("skip_first must be smaller than the number of datapoints")

    if skip_first:
        th = th[skip_first:]
        rates = rates[skip_first:]
        if rate_err is not None:
            rate_err = rate_err[skip_first:]

    offset, tth = _split_sections(th, block_size)
    n_offsets = int(offset.max()) + 1 if len(offset) else 0
    if max_shift is None:
        max_shift = block_size // 2

    shifts, scores, chi2s = [], [], []
    for o in range(n_offsets - 1):
        mask_a, mask_b = offset == o, offset == o + 1
        sec_a, sec_b = rates[mask_a], rates[mask_b]
        err_a = rate_err[mask_a] if rate_err is not None else None
        err_b = rate_err[mask_b] if rate_err is not None else None

        L = min(len(sec_a), len(sec_b), block_size)
        if L < 4:
            continue
        sec_a, sec_b = sec_a[:L], sec_b[:L]
        if err_a is not None:
            err_a = err_a[:L]
        if err_b is not None:
            err_b = err_b[:L]

        shift, score, chi2 = _weighted_shift(sec_a, sec_b, max_shift, err_a, err_b)
        shifts.append(shift)
        scores.append(score)
        chi2s.append(chi2)

    scale = float(np.median(shifts)) if shifts else 0.0

    th_continuous_raw = offset * scale + tth
    rise_edge = find_rise_edge(th_continuous_raw, rates, rate_err=rate_err,
                                n_sigma=n_sigma_rise, baseline_n=baseline_n)
    print(f"Channel calib: scale={scale} offs={rise_edge}")

    return {
        'scale': scale,
        'shifts': shifts,
        'scores': scores,
        'reduced_chi2': chi2s,
        'n_offsets': n_offsets,
        'block_size': block_size,
        'rise_edge': rise_edge,
    }


def calibrate_channels(data, channels, dataset_index=0, block_size=64,
                        max_shift=None, min_score=0.3,
                        n_sigma_rise=5.0, baseline_n=5, rate_err=None,
                        skip_first=0):
    """
    Run calibrate_channel() for several channels (from one dataset) and
    combine the results into a single, more robust calibration, including
    both the section-stitching `scale` and the turn-on `zero_offset`.

    Parameters
    ----------
    data : list[dict]
        As in plot_channel().
    channels : iterable[int]
        Channels to use for the fit (results are stored per-channel too).
    dataset_index : int, default 0
        Which dataset in `data` to calibrate from.
    block_size : int, default 64
    max_shift : int, optional
    min_score : float, default 0.3
        Per-boundary shifts with quality score below this are discarded
        before aggregating the global scale (keeps flat / noisy channels
        from biasing the fit). score = 1/(1+reduced_chi2), so 0.3
        corresponds to reduced_chi2 <~ 2.3.
    n_sigma_rise : float, default 5.0
        Passed to find_rise_edge() for each channel's turn-on point.
    baseline_n : int, default 5
        Passed to find_rise_edge().
    rate_err : dict[int -> array-like], optional
        Per-channel 1-sigma uncertainties on the rate values (same shape
        as data[dataset_index]['rates'][ch]). Defaults to sqrt(rate) for
        every channel if not given.
    skip_first : int, default 0
        Number of leading datapoints to omit from each channel's calibration.

    Returns
    -------
    calibration : dict
        block_size   : int
        scale        : float, global (aggregated) scale
        scale_std    : float, spread of per-channel scale estimates
        zero_offset  : float, global (aggregated) turn-on point, in the
                       scale-only continuous axis -- this is subtracted
                       in th_to_continuous() so th_continuous=0 sits at
                       the point where the data starts to rise
        zero_offset_std : float, spread of per-channel rise edges
        per_channel  : {channel: <calibrate_channel() result>}
    """
    per_channel = {}
    good_scales = []
    good_rise_edges = []

    for ch in channels:
        th = data[dataset_index]['th'][ch]
        rates = data[dataset_index]['rates'][ch]
        ch_rate_err = rate_err[ch] if (rate_err is not None and ch in rate_err) else None

        result = calibrate_channel(th, rates, block_size=block_size,
                                    max_shift=max_shift, rate_err=ch_rate_err,
                                    n_sigma_rise=n_sigma_rise, baseline_n=baseline_n,
                                    skip_first=skip_first)
        per_channel[ch] = result

        good_shift_scores = [(s, sc) for s, sc in zip(result['shifts'], result['scores'])
                              if sc >= min_score]
        channel_is_good = bool(good_shift_scores)
        if channel_is_good:
            good = [s for s, sc in good_shift_scores]
            good_scales.append(np.median(good))

        if channel_is_good and result['rise_edge'] is not None:
            good_rise_edges.append(result['rise_edge'])

    if good_scales:
        global_scale = float(np.median(good_scales))
        scale_std = float(np.std(good_scales))
    else:
        global_scale = float(block_size)
        scale_std = 0.0

    if good_rise_edges:
        zero_offset = float(np.median(good_rise_edges))
        zero_offset_std = float(np.std(good_rise_edges))
    else:
        zero_offset = 0.0
        zero_offset_std = 0.0

    return {
        'block_size': block_size,
        'scale': global_scale,
        'scale_std': scale_std,
        'zero_offset': zero_offset,
        'zero_offset_std': zero_offset_std,
        'per_channel': per_channel,
    }


# ---------------------------------------------------------------------------
# 4) Save / load
# ---------------------------------------------------------------------------
def save_calibration(calibration, path):
    """Write a calibration dict (from calibrate_channels) to a JSON file."""
    serializable = {
        'block_size': calibration['block_size'],
        'scale': calibration['scale'],
        'scale_std': calibration.get('scale_std', 0.0),
        'zero_offset': calibration.get('zero_offset', 0.0),
        'zero_offset_std': calibration.get('zero_offset_std', 0.0),
        'per_channel': {
            str(ch): {
                'scale': v['scale'],
                'shifts': v['shifts'],
                'scores': v['scores'],
                'reduced_chi2': v.get('reduced_chi2', []),
                'n_offsets': v['n_offsets'],
                'block_size': v['block_size'],
                'rise_edge': v.get('rise_edge', None),
            }
            for ch, v in calibration.get('per_channel', {}).items()
        },
    }
    with open(path, 'w') as f:
        json.dump(serializable, f, indent=2)


def load_calibration(path):
    """Load a calibration dict previously written by save_calibration()."""
    with open(path) as f:
        raw = json.load(f)
    raw['per_channel'] = {int(k): v for k, v in raw.get('per_channel', {}).items()}
    raw.setdefault('zero_offset', 0.0)
    raw.setdefault('zero_offset_std', 0.0)
    return raw


# ---------------------------------------------------------------------------
# 5) Apply calibration
# ---------------------------------------------------------------------------
def _channel_params(calibration, channel):
    """Look up (scale, zero_offset) for `channel`, falling back to global."""
    per_channel = calibration.get('per_channel', {})
    if channel is not None and channel in per_channel:
        entry = per_channel[channel]
        scale = entry['scale']
        zero_offset = entry.get('rise_edge')
        if zero_offset is None:
            zero_offset = calibration.get('zero_offset', 0.0)
    else:
        scale = calibration['scale']
        zero_offset = calibration.get('zero_offset', 0.0)
    return scale, zero_offset


def th_to_continuous(th, calibration, channel=None):
    """
    Map raw threshold code(s) th -> th_continuous, including the
    zero-point shift:

        th_continuous = offset*scale + tth - zero_offset

    Parameters
    ----------
    th : scalar or array-like
    calibration : dict
        As returned by calibrate_channels()/load_calibration().
    channel : int, optional
        Uses this channel's own fitted scale and rise_edge (turn-on
        point) if present in calibration['per_channel']; otherwise falls
        back to the global calibration['scale'] / ['zero_offset'].

    Returns
    -------
    float or np.ndarray (same shape as th)
    """
    block_size = calibration['block_size']
    scale, zero_offset = _channel_params(calibration, channel)

    th = np.asarray(th)
    offset = th // block_size
    tth = th % block_size
    return offset * scale + tth - zero_offset


def apply_calibration(dataset, calibration, channels=None):
    """
    Apply a calibration to a whole dataset (one entry of `data`), returning
    a NEW dataset with an added 'th_continuous' entry (same
    dict-of-channel-arrays layout as 'th').

    Parameters
    ----------
    dataset : dict
        dataset['th'][channel] -> array-like (dict- or list-indexable).
    calibration : dict
    channels : iterable[int], optional
        Defaults to every channel present in dataset['th'].

    Returns
    -------
    dict
        Shallow copy of `dataset` plus 'th_continuous'.
    """
    if channels is None:
        channels = (dataset['th'].keys() if isinstance(dataset['th'], dict)
                    else range(len(dataset['th'])))

    th_continuous = {}
    for ch in channels:
        th_continuous[ch] = th_to_continuous(dataset['th'][ch], calibration,
                                              channel=ch).tolist()

    new_dataset = dict(dataset)
    new_dataset['th_continuous'] = th_continuous
    return new_dataset


# ---------------------------------------------------------------------------
# 6) Inverse mapping
# ---------------------------------------------------------------------------
def continuous_to_th(th_continuous, calibration, channel=None):
    """
    Recover (offset, tth) -- and the original raw code th -- from a
    continuous threshold value.

        raw_continuous = th_continuous + zero_offset   (undo zero shift)
        offset = floor(raw_continuous / scale)
        tth    = raw_continuous - offset*scale        (should be in [0, block_size))
        th     = block_size*offset + round(tth)

    Parameters
    ----------
    th_continuous : scalar or array-like
    calibration : dict
    channel : int, optional
        Same semantics as th_to_continuous().

    Returns
    -------
    offset, tth, th : arrays (or scalars) of the same shape as th_continuous
        offset, th are integers; tth is the (float) fine threshold.
    """
    block_size = calibration['block_size']
    scale, zero_offset = _channel_params(calibration, channel)

    th_continuous = np.asarray(th_continuous, dtype=float)
    raw_continuous = th_continuous + zero_offset
    offset = np.floor(raw_continuous / scale).astype(int)
    tth = raw_continuous - offset * scale
    th = (block_size * offset + np.round(tth)).astype(int)

    scalar_in = np.isscalar(th_continuous) or (hasattr(th_continuous, 'ndim')
                                                 and th_continuous.ndim == 0)
    if scalar_in:
        return int(offset), float(tth), int(th)
    return offset, tth, th
