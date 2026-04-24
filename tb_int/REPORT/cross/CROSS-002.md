# `CROSS-002.md` — continuous-frame signoff run

- **run_id:** `CROSS-002`
- **mode:** `bucket_frame`
- **scope:** promoted EDGE anchors E025-E027 in one no-restart frame
- **status:** `✅`

## Execution evidence

| field | value |
|---|---|
| build | `make ip-cross-baselines` |
| manifest | [`sim_runs/cross/manifests/CROSS-002.manifest`](../../sim_runs/cross/manifests/CROSS-002.manifest) |
| log | [`sim_runs/cross/logs/CROSS-002.log`](../../sim_runs/cross/logs/CROSS-002.log) |
| driver_log | [`sim_runs/cross/driver_logs/CROSS-002.driver.log`](../../sim_runs/cross/driver_logs/CROSS-002.driver.log) |
| ucdb | [`sim_runs/cross/coverage/CROSS-002.ucdb`](../../sim_runs/cross/coverage/CROSS-002.ucdb) |
| sim_time | `75.670 us` |
| segment_count | `3` |
| reset_count | `0` |
| segment_pass_count | `3` |
| check_pass_count | `3` |
| UVM errors / fatals | `0 / 0` |
| payload / padding words | `256 / 256` |
| ingress / OPQ / DMA hits | `2560 / 1024 / 1024` |
| code coverage | `stmt=72.63, branch=64.94, cond=29.52, expr=45.69, fsm_state=75.76, fsm_trans=39.80, toggle=22.04` |
| functional cross pct | `39.88` |

## Segment manifest

| idx | case_id | bucket | replay_dir | mask | merge | dma_half_full_pct | seed | reset_before |
|---:|---|---|---|---:|---:|---:|---:|---:|
| 0 | `E025` | `EDGE` | [`sim_runs/cross/replay/E025`](../../sim_runs/cross/replay/E025) | `0xf` | `1` | `0` | `111` | `0` |
| 1 | `E026` | `EDGE` | [`sim_runs/cross/replay/E026`](../../sim_runs/cross/replay/E026) | `0xf` | `1` | `0` | `112` | `0` |
| 2 | `E027` | `EDGE` | [`sim_runs/cross/replay/E027`](../../sim_runs/cross/replay/E027) | `0x1` | `1` | `0` | `113` | `0` |

## Notes

- zero/single/MAX_HITS subheader anchors.
- This evidence is generated from `tb_int/sim_runs/cross/summary.json`; hand edits to this page are overwritten.
- The promoted baseline uses the legal anchor segment set currently implemented by the UVM segment-manifest runner. The broader 129-row cross catalog remains the planning space for future exact case-id expansion.
