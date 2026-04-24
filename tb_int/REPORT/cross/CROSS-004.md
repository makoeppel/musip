# `CROSS-004.md` — continuous-frame signoff run

- **run_id:** `CROSS-004`
- **mode:** `bucket_frame`
- **scope:** promoted ERROR anchors X111,X112,X116-X118,X120,X122-X124 in one no-restart frame
- **status:** `✅`

## Execution evidence

| field | value |
|---|---|
| build | `make ip-cross-baselines` |
| manifest | [`sim_runs/cross/manifests/CROSS-004.manifest`](../../sim_runs/cross/manifests/CROSS-004.manifest) |
| log | [`sim_runs/cross/logs/CROSS-004.log`](../../sim_runs/cross/logs/CROSS-004.log) |
| driver_log | [`sim_runs/cross/driver_logs/CROSS-004.driver.log`](../../sim_runs/cross/driver_logs/CROSS-004.driver.log) |
| ucdb | [`sim_runs/cross/coverage/CROSS-004.ucdb`](../../sim_runs/cross/coverage/CROSS-004.ucdb) |
| sim_time | `271.014 us` |
| segment_count | `9` |
| reset_count | `0` |
| segment_pass_count | `9` |
| check_pass_count | `9` |
| UVM errors / fatals | `0 / 0` |
| payload / padding words | `1116 / 640` |
| ingress / OPQ / DMA hits | `4464 / 4464 / 4464` |
| code coverage | `stmt=72.48, branch=64.94, cond=30.04, expr=45.26, fsm_state=75.76, fsm_trans=39.80, toggle=28.43` |
| functional cross pct | `41.46` |

## Segment manifest

| idx | case_id | bucket | replay_dir | mask | merge | dma_half_full_pct | seed | reset_before |
|---:|---|---|---|---:|---:|---:|---:|---:|
| 0 | `X111` | `ERROR` | [`sim_runs/cross/replay/X111`](../../sim_runs/cross/replay/X111) | `0xf` | `1` | `0` | `1066426748` | `0` |
| 1 | `X112` | `ERROR` | [`sim_runs/cross/replay/X112`](../../sim_runs/cross/replay/X112) | `0xf` | `1` | `0` | `0` | `0` |
| 2 | `X116` | `ERROR` | [`sim_runs/cross/replay/X116`](../../sim_runs/cross/replay/X116) | `0xf` | `1` | `0` | `12345` | `0` |
| 3 | `X117` | `ERROR` | [`sim_runs/cross/replay/X117`](../../sim_runs/cross/replay/X117) | `0xf` | `1` | `0` | `12345` | `0` |
| 4 | `X118` | `ERROR` | [`sim_runs/cross/replay/X118`](../../sim_runs/cross/replay/X118) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 5 | `X120` | `ERROR` | [`sim_runs/cross/replay/X120`](../../sim_runs/cross/replay/X120) | `0xf` | `1` | `0` | `1` | `0` |
| 6 | `X122` | `ERROR` | [`sim_runs/cross/replay/X122`](../../sim_runs/cross/replay/X122) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 7 | `X123` | `ERROR` | [`sim_runs/cross/replay/X123`](../../sim_runs/cross/replay/X123) | `0xf` | `1` | `0` | `1327604986` | `0` |
| 8 | `X124` | `ERROR` | [`sim_runs/cross/replay/X124`](../../sim_runs/cross/replay/X124) | `0xf` | `1` | `0` | `1327604986` | `0` |

## Notes

- bug-regression anchor shapes that are legal pass cases.
- This evidence is generated from `tb_int/sim_runs/cross/summary.json`; hand edits to this page are overwritten.
- The promoted baseline uses the legal anchor segment set currently implemented by the UVM segment-manifest runner. The broader 129-row cross catalog remains the planning space for future exact case-id expansion.
