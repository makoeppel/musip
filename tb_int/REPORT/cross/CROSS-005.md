# `CROSS-005.md` — continuous-frame signoff run

- **run_id:** `CROSS-005`
- **mode:** `all_buckets_frame`
- **scope:** promoted BASIC to EDGE to PROF to ERROR anchors with exactly one reset per bucket transition
- **status:** `✅`

## Execution evidence

| field | value |
|---|---|
| build | `make ip-cross-baselines` |
| manifest | [`sim_runs/cross/manifests/CROSS-005.manifest`](../../sim_runs/cross/manifests/CROSS-005.manifest) |
| log | [`sim_runs/cross/logs/CROSS-005.log`](../../sim_runs/cross/logs/CROSS-005.log) |
| driver_log | [`sim_runs/cross/driver_logs/CROSS-005.driver.log`](../../sim_runs/cross/driver_logs/CROSS-005.driver.log) |
| ucdb | [`sim_runs/cross/coverage/CROSS-005.ucdb`](../../sim_runs/cross/coverage/CROSS-005.ucdb) |
| sim_time | `1147.878 us` |
| segment_count | `22` |
| reset_count | `3` |
| segment_pass_count | `22` |
| check_pass_count | `22` |
| UVM errors / fatals | `0 / 0` |
| payload / padding words | `6855 / 2176` |
| ingress / OPQ / DMA hits | `34713 / 27420 / 27420` |
| code coverage | `stmt=72.86, branch=65.84, cond=34.20, expr=47.84, fsm_state=75.76, fsm_trans=43.28, toggle=31.69` |
| functional cross pct | `52.88` |

## Segment manifest

| idx | case_id | bucket | replay_dir | mask | merge | dma_half_full_pct | seed | reset_before |
|---:|---|---|---|---:|---:|---:|---:|---:|
| 0 | `B001` | `BASIC` | [`sim_runs/cross/replay/B001`](../../sim_runs/cross/replay/B001) | `0xf` | `1` | `0` | `0` | `0` |
| 1 | `B002` | `BASIC` | [`sim_runs/cross/replay/B002`](../../sim_runs/cross/replay/B002) | `0xf` | `1` | `0` | `1` | `0` |
| 2 | `B046` | `BASIC` | [`sim_runs/cross/replay/B046`](../../sim_runs/cross/replay/B046) | `0x1` | `1` | `0` | `4242` | `0` |
| 3 | `B047` | `BASIC` | [`sim_runs/cross/replay/B047`](../../sim_runs/cross/replay/B047) | `0x2` | `1` | `0` | `4242` | `0` |
| 4 | `B048` | `BASIC` | [`sim_runs/cross/replay/B048`](../../sim_runs/cross/replay/B048) | `0x4` | `1` | `0` | `4242` | `0` |
| 5 | `B049` | `BASIC` | [`sim_runs/cross/replay/B049`](../../sim_runs/cross/replay/B049) | `0x8` | `1` | `0` | `4242` | `0` |
| 6 | `E025` | `EDGE` | [`sim_runs/cross/replay/E025`](../../sim_runs/cross/replay/E025) | `0xf` | `1` | `0` | `111` | `1` |
| 7 | `E026` | `EDGE` | [`sim_runs/cross/replay/E026`](../../sim_runs/cross/replay/E026) | `0xf` | `1` | `0` | `112` | `0` |
| 8 | `E027` | `EDGE` | [`sim_runs/cross/replay/E027`](../../sim_runs/cross/replay/E027) | `0x1` | `1` | `0` | `113` | `0` |
| 9 | `P040` | `PROF` | [`sim_runs/cross/replay/P040`](../../sim_runs/cross/replay/P040) | `0xf` | `1` | `50` | `5151` | `1` |
| 10 | `P041` | `PROF` | [`sim_runs/cross/replay/P041`](../../sim_runs/cross/replay/P041) | `0xf` | `1` | `75` | `5151` | `0` |
| 11 | `P123` | `PROF` | [`sim_runs/cross/replay/P123`](../../sim_runs/cross/replay/P123) | `0xf` | `1` | `0` | `123` | `0` |
| 12 | `P124` | `PROF` | [`sim_runs/cross/replay/P124`](../../sim_runs/cross/replay/P124) | `0xf` | `1` | `0` | `124` | `0` |
| 13 | `X111` | `ERROR` | [`sim_runs/cross/replay/X111`](../../sim_runs/cross/replay/X111) | `0xf` | `1` | `0` | `1066426748` | `1` |
| 14 | `X112` | `ERROR` | [`sim_runs/cross/replay/X112`](../../sim_runs/cross/replay/X112) | `0xf` | `1` | `0` | `0` | `0` |
| 15 | `X116` | `ERROR` | [`sim_runs/cross/replay/X116`](../../sim_runs/cross/replay/X116) | `0xf` | `1` | `0` | `12345` | `0` |
| 16 | `X117` | `ERROR` | [`sim_runs/cross/replay/X117`](../../sim_runs/cross/replay/X117) | `0xf` | `1` | `0` | `12345` | `0` |
| 17 | `X118` | `ERROR` | [`sim_runs/cross/replay/X118`](../../sim_runs/cross/replay/X118) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 18 | `X120` | `ERROR` | [`sim_runs/cross/replay/X120`](../../sim_runs/cross/replay/X120) | `0xf` | `1` | `0` | `1` | `0` |
| 19 | `X122` | `ERROR` | [`sim_runs/cross/replay/X122`](../../sim_runs/cross/replay/X122) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 20 | `X123` | `ERROR` | [`sim_runs/cross/replay/X123`](../../sim_runs/cross/replay/X123) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 21 | `X124` | `ERROR` | [`sim_runs/cross/replay/X124`](../../sim_runs/cross/replay/X124) | `0xf` | `1` | `0` | `1327604986` | `0` |

## Notes

- Full promoted-anchor stack composition; reset before first EDGE, PROF, and ERROR segment only.
- This evidence is generated from `tb_int/sim_runs/cross/summary.json`; hand edits to this page are overwritten.
- The promoted baseline uses the legal anchor segment set currently implemented by the UVM segment-manifest runner. The broader 129-row cross catalog remains the planning space for future exact case-id expansion.
