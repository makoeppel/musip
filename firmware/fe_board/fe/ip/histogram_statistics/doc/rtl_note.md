# Histogram Statistics V2 RTL Timing Note

## Sign-off target

- Integration: SciFi Phase I, one HIST instance observing all eight post-MTS ASIC lanes.
- Device: Intel Arria V `5AGXBA7D4F31C5`.
- Nominal clock: 125 MHz (`8.000 ns`).
- Standalone sign-off clock: 137.5 MHz (`7.273 ns`, 1.1 times nominal).
- Quartus: 18.1 Standard, Standard Fit effort, seed 1, multi-corner timing.
- Profile: `N_PORTS=8`, `COAL_QUEUE_DEPTH=8`, `COAL_CAM_PIPELINE_MODE="AUTO"`, signed delay default, 256 bins.

## Pre-fit model

The dominant logic is expected to be the eight parallel full-width signed
sample/range/binning lanes followed by the counted eight-input coalescer.  At
queue depth eight, AUTO selects the unpipelined small-CAM profile.  The likely
critical cone is therefore a bin-tag comparison or counted commit path inside
the live-cell queue, rather than either of the two ping-pong histogram RAMs.
The pending-hit accounting feedback is the secondary candidate because it
combines per-lane accepted and drained kick counts.

The expected footprint, based on the same RTL snapshot's preceding standalone
closure, is approximately 11,930 ALMs, 5,650 registers, two block RAMs, and no
DSPs.  A materially larger result would indicate that the full-width delay
mapping or CAM storage was replicated unexpectedly.

## Measured result

The exact Phase-I HIST SHA-256
`2891b95a1bcfbe5e9d0541b6c1e337da697758cde491181b5eb370dbcefad332`
passes the seed-1 standalone compile at `7.273 ns`. All setup and hold TNS
values are `0.000 ns`.

| Corner | Setup slack | Hold slack | Minimum-pulse-width slack |
|---|---:|---:|---:|
| Slow 1100 mV, 85 C | `+0.252 ns` | `+0.249 ns` | `+2.697 ns` |
| Slow 1100 mV, 0 C | `+0.264 ns` | `+0.235 ns` | `+2.665 ns` |
| Fast 1100 mV, 85 C | `+2.729 ns` | `+0.160 ns` | `+2.847 ns` |
| Fast 1100 mV, 0 C | `+3.251 ns` | `+0.146 ns` | `+2.838 ns` |

The slow-85 C critical setup path is now `cfg_interval_cfg[17]` to a
`pingpong_sram.bank_*_valid` bit, with `6.933 ns` data delay and `+0.252 ns`
slack. The prior failing dynamic filter cone was cut into three measured
segments: sample-to-extracted-field `+0.974 ns`, sample-to-update-key
`+0.666 ns`, and registered filter-compare-to-write-request `+1.716 ns`.
The counted coalescer remains close behind but positive; its first path in the
slow-85 worst-20 report has `+0.289 ns` slack.

| Resource | Fitted use |
|---|---:|
| ALMs | `11,713 / 91,680 (13%)` |
| Registers | `6,321` |
| Block-memory bits | `16,384` |
| RAM blocks | `2` |
| DSP blocks | `0` |

Immutable evidence is under
`/data3/yifeng/hist_standalone_signoff_20260714_125105/`, especially the fit
and timing summaries, the four `setup_*_worst_paths.rpt` plus four
`hold_*_worst_paths.rpt` reports, and the three focused retime-boundary reports.
The SOF SHA-256 is
`24426f500811c0dd8191319ddd90b2bb5c79b96f3dedfa7328a8a76b17810117`.

## Locked-hash full-board fit

The exact final Phase-I source snapshot also completes the full FEB compile in
`24m31s` with `0 errors / 241 warnings`, Standard Fit seed 1.  Fitted use is
`38,191 / 91,680 ALMs (42%)`, `57,382` registers, `6,328 LABs (69%)`,
`10,252,892 / 13,987,840` block-memory bits (73%), `1,280 / 1,366` RAM blocks
(94%), `44,160` MLAB bits, and zero DSP blocks.  The output SOF SHA-256 is
`446934d47628480aa7f298f0998cb1f2c02cdb720d0be7c0bf9751534e57c600`.

| Full-board corner | Global setup WNS/TNS | Global hold WNS/TNS |
|---|---:|---:|
| Slow 1100 mV, 85 C | `-0.082 / -0.410 ns` | `+0.245 / 0 ns` |
| Slow 1100 mV, 0 C | `+0.227 / 0 ns` | `+0.194 / 0 ns` |
| Fast 1100 mV, 85 C | `+1.835 / 0 ns` | `+0.115 / 0 ns` |
| Fast 1100 mV, 0 C | `+2.061 / 0 ns` | `+0.101 / 0 ns` |

The only setup residual is on the unrelated
`transceiver_pll_clock[0]` domain.  The SciFi/HIST
`lvds_firefly_clk` domain closes at slow-85 with `+0.437 ns` setup slack,
zero TNS, and 134.7 MHz reported Fmax.  The slow-85 scoped post-fit checks have
zero violations and zero TNS: HIST setup/hold `+0.631/+0.245 ns`, adapter
minimum to/from setup/hold `+1.434/+0.259 ns`, filter `+0.631/+0.245 ns`,
coalescer `+0.714/+0.252 ns`, and SC CDC `+1.424/+0.251 ns`.

The board result is therefore not presented as globally timing-clean or fully
constrained.  In particular, TimeQuest reports incomplete setup/hold
constraints and Quartus warns that the SciFi LVDS receiver PLL reset ports are
not properly connected.  That PLL warning matters to latency diagnosis: an
on-board negative physics-hit lifetime is evidence of upstream epoch,
timestamp, or clock-lock failure, not a valid alternate phase coordinate.  The
signed value remains visible in the diagnostic histogram and must be corrected
at its source rather than clamped or folded.

Immutable full-board evidence is under
`/data3/yifeng/phase1_hist_final_compile_20260714_130114/`; the explicit
slow-85 scoped report is `evidence/report_hist_scoped_r3_slow85.log`.
