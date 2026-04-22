# DV_PROF.md — tb_int (MuSiP SWB/OPQ integration)

**Companion:** [`DV_INT_PLAN.md`](DV_INT_PLAN.md) · [`DV_INT_HARNESS.md`](DV_INT_HARNESS.md) · [`DV_BASIC.md`](DV_BASIC.md) · [`DV_COV.md`](DV_COV.md) · [`DV_REPORT.md`](DV_REPORT.md) · [`BUG_HISTORY.md`](BUG_HISTORY.md)
**Canonical ID range:** `P001`–`P129`
**Intent:** randomized, profile, soak, and throughput-oriented scenarios that stress the SWB+OPQ integration beyond what the directed BASIC and EDGE buckets cover. Each case is anchored on a specific randomization axis (lane saturation, frame length, lane skew, backpressure, `i_get_n_words`, seed) so merged coverage closes without duplication.
**Stimulus source:** same FEB `aso_hit_type3` grammar; profile cases parametrize (a) per-lane Poisson saturation `λ` driving subheader occupancy, (b) per-lane frame counts, (c) per-lane skew in cycles, (d) sink backpressure distribution, (e) `i_get_n_words` event-builder grouping, (f) LCG seed.

## Method / implementation legend

- **method** — `D` = directed (fixed stimulus) · `R` = randomized (per-seed)
- **implementation** — `live UVM` · `live plain` · `live 2env` · `planned` · `planned (variant-only)`
- **checkpoint UCDB** — log-spaced save cadence `1, 2, 4, 8, 16, … ≤ total_frames` under [`REPORT/txn_growth/`](REPORT/txn_growth/). Applies to `checkpoint_soak` and seeded long runs.

## Randomization axes (for randomized cases)

Each `R` case names the axes it varies. The axis table is shared with [`DV_CROSS.md`](DV_CROSS.md) so merged UCDBs align.

| axis | values | notes |
|---|---|---|
| `seed` | 32-bit LCG seed | drives all other axes for the run |
| `sat_per_lane` | `{0.00, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50}` | per-lane Poisson subheader saturation |
| `frames_per_run` | `{1, 2, 4, 8, 16, 32, 128, 1024}` | number of back-to-back frames per lane |
| `lane_skew_cyc` | `{0, 1, 16, 64, 256, 1024, 4096}` | inter-lane SOP skew in cycles |
| `dma_ready_p` | `{1.0, 0.95, 0.90, 0.80, 0.70, 0.50, 0.25}` | sink backpressure Bernoulli rate |
| `i_get_n_words` | `{1, 4, 16, 64, 128, 256, 512}` | event-builder grouping size |
| `feb_type` | `{0x3A (MuPix default), 0x3B, 0x30}` | feb_type[5:0] routing cover |

## Catalog

<!-- columns:
  case_id / method / implementation / scenario / primary checks / stage
-->

| case_id | method | implementation | scenario | primary checks | stage |
|---|---|---|---|---|---|
| P001 | D | live UVM | `make ip-uvm-longrun` default wrapper: 128 runs, per-lane `0.0..0.5` grid step `0.1`, seed `260421` | `pass_count=128 fail_count=0`; summary at `cases/basic/uvm/report/longrun/summary.json`; zero ghost/missing hits across all 128 runs | all |
| P002 | D | live UVM | historical 256-run rerun archive: seed `260422`, same `0.0..0.5` grid, output `cases/basic/uvm/report/longrun_ext_260422_fixed/` | `pass_count=256 fail_count=0`; former zero-payload corner closes cleanly | all |
| P003 | R | live UVM | single-lane saturation sweep `λ ∈ {0.0, 0.1, 0.2, 0.3, 0.4, 0.5}`, 1 frame per run, lane 0 only | payload_words grows monotonically with λ; zero ghost/missing hits at each λ | I/O/D |
| P004 | R | live UVM | single-lane saturation sweep on lane 1 only (same λ grid) | same contract with lane 1 routing; per-hit feb_id propagation | I/O/D |
| P005 | R | live UVM | single-lane saturation sweep on lane 2 only | same | I/O/D |
| P006 | R | live UVM | single-lane saturation sweep on lane 3 only | same | I/O/D |
| P007 | R | live UVM | symmetric 4-lane saturation `λ=0.1` on all lanes, 32 frames per run, 8 runs | total hits ≈ `4 * λ * N_SHD * MAX_HITS * frames`; DMA `abs_ts` sort monotone across frame boundary | all |
| P008 | R | live UVM | symmetric 4-lane saturation `λ=0.2`, 32 frames, 8 runs | same | all |
| P009 | R | live UVM | symmetric 4-lane saturation `λ=0.3`, 32 frames, 8 runs | same | all |
| P010 | R | live UVM | symmetric 4-lane saturation `λ=0.4`, 32 frames, 8 runs | same | all |
| P011 | R | live UVM | symmetric 4-lane saturation `λ=0.5`, 32 frames, 8 runs | maximum default-grid saturation; stress page allocator | all |
| P012 | R | live UVM | asymmetric 4-lane `(0.5, 0.0, 0.5, 0.0)` (alternating), 16 frames | lanes 1 and 3 emit all-zero-hit subheaders; lanes 0 and 2 carry full traffic; mux does not starve | all |
| P013 | R | live UVM | asymmetric `(0.4, 0.3, 0.2, 0.1)` (descending), 16 frames | per-lane rate ordering preserved; DMA hit distribution reflects per-lane rates | all |
| P014 | R | live UVM | asymmetric `(0.1, 0.2, 0.3, 0.4)` (ascending), 16 frames | mirror of P013; lane 3 dominates | all |
| P015 | R | live UVM | asymmetric `(0.5, 0.5, 0.0, 0.0)` (half-silent), 16 frames | lanes 2 and 3 silent; arbitration retires lanes 0/1 without starvation | I/M/O |
| P016 | R | live UVM | asymmetric `(0.0, 0.0, 0.5, 0.5)` (mirror of P015) | same with lanes 0/1 silent | I/M/O |
| P017 | R | live UVM | one hot lane `(0.5, 0.0, 0.0, 0.0)`, 32 frames | lane 0 single-stream throughput baseline | I/M/O |
| P018 | R | live UVM | one hot lane `(0.0, 0.0, 0.0, 0.5)` | lane 3 single-stream baseline | I/M/O |
| P019 | R | live UVM | dense short frames: `λ=0.5`, `N_SHD=1` effective (only 1 subheader per frame), 128 frames | OPQ page cycles 128 times; no page leak; `pkg_cnt` advances to 128 | I/O |
| P020 | R | live UVM | sparse long frames: `λ=0.05`, `N_SHD` full, 4 frames | ~95% of subheaders are zero-hit; OPQ skips efficiently; DMA payload is small | I/O/D |
| P021 | R | live UVM | 2-frame run with per-frame seed drift: `seed = base + frame_idx * 17` | seed change between frames does not corrupt per-hit trace; hits per frame meet per-lane expectation | I/O |
| P022 | R | live UVM | 8-frame saturation campaign `λ=0.25`, seed `260421`, lane skew 0 | baseline 8-frame payload; checkpoint UCDB at frame 1, 2, 4, 8 | all + ckp |
| P023 | R | live UVM | 16-frame saturation `λ=0.25` | checkpoint UCDBs at 1, 2, 4, 8, 16 | all + ckp |
| P024 | R | live UVM | 32-frame saturation `λ=0.25` | checkpoints 1, 2, 4, 8, 16, 32 | all + ckp |
| P025 | R | live UVM | 128-frame saturation `λ=0.25` | checkpoints 1, 2, 4, 8, 16, 32, 64, 128 | all + ckp |
| P026 | R | live UVM | 1024-frame soak `λ=0.25`, seed `260421` | checkpoints up to 1024; coverage growth curve logged in `REPORT/txn_growth/P026.md` | all + ckp |
| P027 | R | live UVM | 1024-frame soak `λ=0.50` (stress) | peak saturation soak; checkpoints same cadence; coverage closure target | all + ckp |
| P028 | R | live UVM | 1024-frame soak `λ=0.05` (low-rate) | sparse soak; padding and `o_done` stress-tested under many empty subheaders | all + ckp |
| P029 | R | live UVM | 10000-frame soak `λ=0.25`, checkpoint UCDBs at `1,2,4,…,8192` | wall-clock long run; `gts_8n` exercises high bits; counter wrap corners | all + ckp |
| P030 | R | live UVM | 10000-frame soak `λ=0.50` | peak stress; checkpoint sequence `1,2,4,…,8192` | all + ckp |
| P031 | R | live UVM | per-lane seed decorrelation: each lane uses `seed + lane_id * 31` | lane-to-lane randomness independent; per-hit trace shows no correlation spikes | I |
| P032 | R | live UVM | per-frame seed decorrelation: each frame uses `seed + frame_idx * 37` | frame-to-frame traffic shape varies; OPQ does not cache frame shape | I/M |
| P033 | R | live UVM | lane-skew sweep `lane_skew_cyc ∈ {0,1,16,64,256,1024,4096}`, `λ=0.25` | DMA sort across lane skew is correct; OPQ allocator scales | I/M/O |
| P034 | R | live UVM | lane-skew sweep with asymmetric saturation `(0.5,0.4,0.3,0.2)` | lane-skew × saturation cross; no starvation | all |
| P035 | R | live UVM | rare-frame profile: only 1 in 10 subheaders has any hits, `N_SHD` max | OPQ scans `N_SHD` subheaders with ~90% zero hits; `o_done` still asserts after padding | I/O/D/E |
| P036 | R | planned | dense-frame profile: every active subheader has exactly MAX_HITS hits with lane count / frame count bounded so total event hits stay `<= OPQ_N_HIT` | peak legal OPQ throughput within the configured hit budget; all-lane overflow variants are tracked separately and are not promoted on the default build | I/O/D |
| P037 | R | live UVM | mixed profile: 50% of frames dense, 50% rare, interleaved | per-frame profile switching stress | I/O |
| P038 | R | live UVM | sink backpressure profile `dma_ready_p=0.95` (light) on `λ=0.25` 32-frame run | mild backpressure absorbed; no dropped hits | D/E |
| P039 | R | live UVM | `dma_ready_p=0.80` (moderate) | absorbed; slight `o_done` delay | D/E |
| P040 | R | live UVM | `dma_ready_p=0.50` (heavy) | event builder stalls repeatedly; all hits eventually retire | D/E |
| P041 | R | live UVM | `dma_ready_p=0.25` (extreme) | long stalls; `o_done` delayed by many cycles; no deadlock | D/E |
| P042 | R | live UVM | bursty backpressure: `dma_ready=0` for 64 cyc every 256 cyc | burst-pattern stall absorbed; scoreboard verifies no re-ordering | D/E |
| P043 | R | live UVM | `dma_ready=0` for one very long stall (8192 cyc) then free | pipeline recovers; OPQ pages preserved; DMA resumes | O/D/E |
| P044 | R | live UVM | `i_get_n_words=1` throughout `λ=0.25` 32-frame run | every DMA beat is its own event; `o_endofevent` pulses every beat | D/E |
| P045 | R | live UVM | `i_get_n_words=4` (one MAX_HITS group per event) | event boundary aligns with subheader | D/E |
| P046 | R | live UVM | `i_get_n_words=16` | larger events; padding after each; `o_done` less frequent but each carries full padding | D/E |
| P047 | R | live UVM | `i_get_n_words=64` | one event per frame on typical `λ` | D/E |
| P048 | R | live UVM | `i_get_n_words=256` (large) | multi-frame aggregation before `o_endofevent`; padding appears after aggregate | D/E |
| P049 | R | live UVM | `i_get_n_words=512` | even larger aggregation; stress on internal counters | D/E |
| P050 | R | live UVM | `i_get_n_words` changes mid-run (1 → 4 → 16 → 64) | event boundaries adjust; no residual leakage between old and new grouping | D/E |
| P051 | R | live UVM | seed sweep P022 replayed with 4 orthogonal seeds `{0x01,0x02,0x03,0x04}` | per-seed UCDBs merge; coverage grows monotonically with seed count | all + ckp |
| P052 | R | live UVM | seed sweep P023 replayed with 4 orthogonal seeds | same | all + ckp |
| P053 | R | live UVM | seed sweep P024 replayed with 4 orthogonal seeds | same | all + ckp |
| P054 | R | live UVM | seed sweep P025 replayed with 4 orthogonal seeds | same | all + ckp |
| P055 | R | live UVM | seed sweep P026 replayed with 4 orthogonal seeds `{0x11,0x12,0x13,0x14}` | 4 × 1024-frame soaks; merged checkpoint UCDBs | all + ckp |
| P056 | R | live UVM | seed sweep P027 (`λ=0.50`) replayed with 4 orthogonal seeds | stress merge | all + ckp |
| P057 | R | live UVM | seed sweep P028 (`λ=0.05`) replayed with 4 orthogonal seeds | low-rate merge | all + ckp |
| P058 | R | live UVM | seed sweep P029 (10000-frame `λ=0.25`) with 2 orthogonal seeds | long-horizon merge | all + ckp |
| P059 | R | live UVM | seed sweep P030 (10000-frame `λ=0.50`) with 2 orthogonal seeds | peak long-horizon merge | all + ckp |
| P060 | R | live UVM | symmetric 4-lane `λ=0.50` 128-frame burst starting from `gts_8n` near 2^47 (close to rollover) | `gts_8n[47:16]` rollover stressed under load | I/M/O |
| P061 | R | live UVM | 128-frame burst starting near `pkg_cnt = 0xFF80` (close to 16-bit rollover) | header1 low word rolls mid-run; OPQ does not fault | I/M |
| P062 | R | live UVM | 128 frames with `pkg_cnt` explicitly held constant (debug0 resends same frame_id) | debug0 `pkg_cnt` field repeats; scoreboard records the repeat without incorrectly dedupe | I/M |
| P063 | R | live UVM | 128 frames with `debug0.hit_cnt` always zero (debug bug simulation) | real hit count at OPQ differs from debug0; scoreboard records only real hits | I/O/D |
| P064 | R | live UVM | 128 frames with `debug0.subheader_cnt` always max (overcount simulation) | OPQ reads real subheader count from stream; debug mismatch logged | I/O |
| P065 | R | live UVM | saturation sweep stress: `λ` rises from 0.0 to 0.5 linearly across 64 frames | slow-ramp stress; OPQ page allocator tracks rising fill | I/O |
| P066 | R | live UVM | saturation sweep stress: `λ` drops from 0.5 to 0.0 linearly across 64 frames | falling ramp; `o_done` per frame scales down | I/O/E |
| P067 | R | live UVM | saturation oscillation: `λ` toggles 0.5 / 0.0 every 4 frames across 128 frames | frame-shape discontinuity; no page leak | I/O |
| P068 | R | live UVM | saturation noise: `λ` drawn uniformly from `[0.0,0.5]` per frame over 128 frames | broadest saturation coverage | I/O + ckp |
| P069 | R | live UVM | saturation asymmetry: lane 0 always `0.5`, lanes 1-3 always `0.0` across 1024 frames | lane 0 hot-thread soak; lanes 1-3 starvation-free | I/M/O + ckp |
| P070 | R | live UVM | saturation asymmetry: lane 0 always `0.0`, lanes 1-3 always `0.5` | mirror of P069 | I/M/O + ckp |
| P071 | R | live UVM | MAX_HITS=4 default, per-subheader hit count drawn uniformly from `{0,1,2,3,4}` | full hit-count distribution covered | I/O/D |
| P072 | R | live UVM | per-subheader `shd_ts` drawn uniformly from `{0x00,…,0xFF}` (full 8-bit range) | `shd_ts` toggle coverage maxed | I/O |
| P073 | R | live UVM | hit field `Row[8:0]` drawn uniformly from `[0,0x1FF]`, other fields fixed | `Row` toggle coverage maxed | I/D |
| P074 | R | live UVM | hit field `Col[6:0]` drawn uniformly from `[0,0x7F]` | `Col` toggle coverage maxed | I/D |
| P075 | R | live UVM | hit field `TS1[10:0]` drawn uniformly from `[0,0x7FF]` | `TS1` toggle coverage maxed | I/D |
| P076 | R | live UVM | hit field `TS2[4:0]` drawn uniformly from `[0,0x1F]` | `TS2` toggle coverage maxed | I/D |
| P077 | R | live UVM | combined hit-field uniform random: all fields drawn independently | hit word toggle coverage maxed | I/D |
| P078 | R | live UVM | `feb_id` drawn uniformly from `[0,0xFFFF]` across 128 frames | preamble `feb_id` toggle coverage maxed; per-hit DMA `feb_id` propagation | I/O/D |
| P079 | R | live UVM | `feb_type[5:0]` cycles through `{0x3A,0x3B,0x30}` across frames | non-MuPix tags exercised; routing cover | I/M |
| P080 | R | live UVM | soak with lane-skew rotation: every 256 frames, skew pattern rotates | long-horizon lane-skew toggle | I/M + ckp |
| P081 | R | live UVM | plain harness profile: `make ip-plain-basic` with `USE_MERGE=1`, full replay | `expected_hits=3800 actual_hits=3800`, `order_exact=0` acceptable | I/D |
| P082 | R | live plain | plain harness with explicit `USE_MERGE=0` variant on smoke replay | bypass path hit contract still closes | D (variant) |
| P083 | R | live plain | plain harness 128-frame synthesized replay bundle | payload size scales linearly; `order_exact` allowed to be 0 | D |
| P084 | R | live plain | plain harness with long idle gaps between frames (4096 cyc) | frame boundaries tolerated; no harness timeout | I |
| P085 | R | live 2env | `make ip-plain-basic-2env` full replay with DPI seam enabled | `DMA_SUMMARY` closes; OPQ boundary audit reports zero ghost | I/O/D |
| P086 | R | live 2env | 2env 128-frame run with `λ=0.25` | seam DPI forwards all OPQ beats; scoreboard count matches | I/O/D |
| P087 | R | live 2env | 2env with explicit seam reference (read from `ref/` output) | pure file-based replay; scoreboard compares DPI output to reference | O |
| P088 | R | live 2env | 2env sparse `λ=0.05` soak over 256 frames | zero-payload padding stress; seam does not time out | D/E |
| P089 | R | live 2env | 2env dense `λ=0.50` soak over 256 frames | peak seam throughput; scoreboard does not drop | D/E + ckp |
| P090 | R | live 2env | 2env long-horizon 1024-frame soak with lane skew 64 | seam synchronization verified across long horizon | I/O + ckp |
| P091 | R | live UVM | checkpoint UCDB cadence `1,2,4,…,4096` on 4096-frame run, `λ=0.30` | coverage growth curve published in `REPORT/txn_growth/P091.md` | all + ckp |
| P092 | R | live UVM | checkpoint UCDB cadence same on 4096-frame, `λ=0.10` | low-rate coverage growth | all + ckp |
| P093 | R | live UVM | checkpoint UCDB cadence `1,2,4,…,2048` on 2048-frame mixed-λ run | mixed-shape coverage growth | all + ckp |
| P094 | R | live UVM | coverage closure run: 128-frame, seed `0x260421`, per-lane `0.1/0.2/0.3/0.4` | per-bucket coverage vectors published in DV_COV | all |
| P095 | R | live UVM | coverage closure run: 256-frame, seed `0x260422`, per-lane `0.1/0.2/0.3/0.4` | full randomized grid; no ghost/missing hits | all |
| P096 | R | live UVM | coverage closure run: 512-frame, per-lane `0.05` (sparse) | sparse-frame coverage drive | I/O + ckp |
| P097 | R | live UVM | coverage closure run: 512-frame, per-lane `0.50` (dense) | dense-frame coverage drive | I/O + ckp |
| P098 | R | live UVM | 4-lane symmetric `λ=0.25` run with hit-trace export `+SWB_HIT_TRACE_PREFIX=<abs>` | per-hit ingress/OPQ/DMA ledgers written; row count sanity checked | I/O/D |
| P099 | R | live UVM | profile run with `+SWB_FRAMES=8 +SWB_CASE_SEED=0x1234` | 8-frame trace with explicit seed capture | I/O/D |
| P100 | R | live UVM | profile run with `+SWB_FRAMES=64 +SWB_CASE_SEED=0x5678` | 64-frame trace with explicit seed capture | I/O/D + ckp |
| P101 | R | live UVM | profile soak with event builder `i_get_n_words` swept every 128 frames | event-builder config change mid-run exercised | D/E + ckp |
| P102 | R | live UVM | profile soak with lane mask swept every 128 frames | lane enable/disable mid-run; scoreboard verifies no stale hits | I/M + ckp |
| P103 | R | live UVM | profile soak with `feb_type` swept every 128 frames | type routing change mid-run | I/M |
| P104 | R | live UVM | mixed random shape campaign: 128 runs, random axis draw per run, seed `0x104` | full axis coverage; `ip-uvm-longrun`-style wrapper | all + ckp |
| P105 | R | live UVM | mixed random shape campaign: 256 runs, seed `0x105` | double-depth axis coverage | all + ckp |
| P106 | R | live UVM | mixed random shape campaign: 512 runs, seed `0x106` | 4× baseline depth; stress scheduler | all + ckp |
| P107 | R | live UVM | longhaul soak 10000 frames, seed `0x107`, λ=0.50, lane skew 64, dma_ready_p=0.90 | ≥2^33 clock cycles of activity; counter-wrap watch | all + ckp |
| P108 | R | live UVM | longhaul soak 50000 frames, seed `0x108`, λ=0.25 | 5× longer; ckp cadence `1,2,4,…,32768` | all + ckp |
| P109 | R | live UVM | longhaul soak 100000 frames, seed `0x109`, λ=0.30, dma_ready_p=0.80 | largest soak; runtime > 1 h expected; ckp cadence `1,2,4,…,65536` | all + ckp |
| P110 | R | live UVM | post-P109 coverage review run (non-soak) replay with saved seed | coverage vectors match P109 checkpoints | all |
| P111 | R | live plain | plain harness 100000-frame replay soak (no scoreboard hit tracing) | runtime wall-clock benchmark; `order_exact=0` acceptable; `actual_hits` matches replay | D |
| P112 | R | live 2env | 2env 10000-frame soak with seam DPI | seam DPI stable under long runs | I/O |
| P113 | R | live UVM | variant `SWB_USE_MERGE=0` long run (4096 frames, λ=0.25) | merge path bypass still closes; different code path exercised | D/E (variant) |
| P114 | R | live UVM | variant `SWB_N_LANES=2` long run (4096 frames, λ=0.25) on 2-lane replay | reduced lane count stable long-horizon | all (variant) |
| P115 | R | live UVM | variant `SWB_N_LANES=8` long run (4096 frames, λ=0.25) on 8-lane replay | extended lane count stable long-horizon | all (variant) |
| P116 | R | live UVM | variant `SWB_N_SUBHEADERS=64` long run (4096 frames, `N_SHD=64`) | smaller page size; OPQ allocator stable | I/O (variant) |
| P117 | R | live UVM | variant `SWB_N_SUBHEADERS=256` long run (4096 frames, `N_SHD=256`) | larger page (current replay default); OPQ stable | I/O (variant) |
| P118 | R | live UVM | variant `SWB_MAX_HITS_PER_SUBHEADER=8` long run | wider subheader; OPQ MAX_HITS scaling | I/O (variant) |
| P119 | R | live UVM | variant `USE_BIT_MERGER=1, USE_BIT_STREAM=0` long run | alternative merge internal selected; contract unchanged | M/O (variant) |
| P120 | R | live UVM | variant `USE_BIT_STREAM=1, USE_BIT_GENERIC=0` long run | alternative merge internal selected | M/O (variant) |
| P121 | R | live UVM | variant `USE_BIT_GENERIC=1` long run | generic merge internal selected | M/O (variant) |
| P122 | R | live UVM | combined variant: `SWB_N_SUBHEADERS=256, MAX_HITS=8` long run on dense shape | highest per-lane hit density; peak OPQ stress | I/O (variant) |
| P123 | R | live UVM | profile with alternating `feb_type` per lane across 256 frames | `feb_type`-per-lane routing stability | I/M |
| P124 | R | live UVM | profile with `feb_id` drawn from a 256-entry pool per lane | `feb_id` routing stress; OPQ tag table coverage | I/O |
| P125 | R | live UVM | profile replaying the 64-frame trace exported from P100 | reproducible replay; scoreboard matches saved trace | I/O/D |
| P126 | R | live UVM | replay with recorded seed from P095 and explicit `SWB_HIT_TRACE_PREFIX` | per-hit trace byte-matches the P095 original | I/O/D |
| P127 | R | live UVM | replay with recorded seed from P107 — verify pass holds | long-soak reproducibility | all |
| P128 | R | live UVM | profile campaign covering the Mu3eSpecBook 5.2.6 hit field space uniformly (Latin hypercube sample over `{Row, Col, TS1, TS2}`) | Latin-hypercube ensures field-grid coverage in fewer runs | I/D |
| P129 | R | live UVM | prof-bucket regression smoke: P001, P011, P026, P044, P085, P091, P107 chained in `bucket_frame` mode | all seven anchor cases close without harness reset between them | all |

## Execution modes

- **isolated** — per-case `make ip-uvm-basic` or `make ip-plain-basic-2env` with explicit plusargs; UCDB saved under `REPORT/cases/P0xx.md` evidence.
- **bucket_frame** — sweep `P001..P129` in order (see [`DV_CROSS.md`](DV_CROSS.md) §6.1).
- **checkpoint_soak** — for `R` cases marked `+ckp` above, run under `python3 tb_int/cases/basic/uvm/run_longrun.py --runs <N> --campaign-seed <seed> --checkpoints 1,2,4,...,N --out-dir report/txn_growth/<case_id>`.

## Regenerate

```
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb tb_int
```
