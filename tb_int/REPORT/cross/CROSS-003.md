# `CROSS-003.md` — continuous-frame signoff run

- **run_id:** `CROSS-003`
- **mode:** `bucket_frame`
- **scope:** promoted PROF anchors P040,P041,P123,P124 in one no-restart frame
- **status:** `✅`

## Execution evidence

| field | value |
|---|---|
| build | `make ip-cross-baselines` |
| manifest | [`sim_runs/cross/manifests/CROSS-003.manifest`](../../sim_runs/cross/manifests/CROSS-003.manifest) |
| log | [`sim_runs/cross/logs/CROSS-003.log`](../../sim_runs/cross/logs/CROSS-003.log) |
| driver_log | [`sim_runs/cross/driver_logs/CROSS-003.driver.log`](../../sim_runs/cross/driver_logs/CROSS-003.driver.log) |
| ucdb | [`sim_runs/cross/coverage/CROSS-003.ucdb`](../../sim_runs/cross/coverage/CROSS-003.ucdb) |
| sim_time | `594.058 us` |
| segment_count | `4` |
| reset_count | `0` |
| segment_pass_count | `4` |
| check_pass_count | `4` |
| UVM errors / fatals | `0 / 0` |
| payload / padding words | `4521 / 512` |
| ingress / OPQ / DMA hits | `18084 / 18084 / 18084` |
| code coverage | `stmt=72.48, branch=64.99, cond=31.60, expr=46.98, fsm_state=75.76, fsm_trans=39.80, toggle=30.51` |
| functional cross pct | `31.46` |

## Segment manifest

| idx | case_id | bucket | replay_dir | mask | merge | dma_half_full_pct | seed | reset_before |
|---:|---|---|---|---:|---:|---:|---:|---:|
| 0 | `P040` | `PROF` | [`sim_runs/cross/replay/P040`](../../sim_runs/cross/replay/P040) | `0xf` | `1` | `50` | `5151` | `0` |
| 1 | `P041` | `PROF` | [`sim_runs/cross/replay/P041`](../../sim_runs/cross/replay/P041) | `0xf` | `1` | `75` | `5151` | `0` |
| 2 | `P123` | `PROF` | [`sim_runs/cross/replay/P123`](../../sim_runs/cross/replay/P123) | `0xf` | `1` | `0` | `123` | `0` |
| 3 | `P124` | `PROF` | [`sim_runs/cross/replay/P124`](../../sim_runs/cross/replay/P124) | `0xf` | `1` | `0` | `124` | `0` |

## Notes

- DMA backpressure plus fixed/varying skew anchors.
- This evidence is generated from `tb_int/sim_runs/cross/summary.json`; hand edits to this page are overwritten.
- The promoted baseline uses the legal anchor segment set currently implemented by the UVM segment-manifest runner. The broader 129-row cross catalog remains the planning space for future exact case-id expansion.
