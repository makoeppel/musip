# `CROSS-001.md` — continuous-frame signoff run

- **run_id:** `CROSS-001`
- **mode:** `bucket_frame`
- **scope:** promoted BASIC anchors B001,B002,B046-B049 in one no-restart frame
- **status:** `✅`

## Execution evidence

| field | value |
|---|---|
| build | `make ip-cross-baselines` |
| manifest | [`sim_runs/cross/manifests/CROSS-001.manifest`](../../sim_runs/cross/manifests/CROSS-001.manifest) |
| log | [`sim_runs/cross/logs/CROSS-001.log`](../../sim_runs/cross/logs/CROSS-001.log) |
| driver_log | [`sim_runs/cross/driver_logs/CROSS-001.driver.log`](../../sim_runs/cross/driver_logs/CROSS-001.driver.log) |
| ucdb | [`sim_runs/cross/coverage/CROSS-001.ucdb`](../../sim_runs/cross/coverage/CROSS-001.ucdb) |
| sim_time | `206.938 us` |
| segment_count | `6` |
| reset_count | `0` |
| segment_pass_count | `6` |
| check_pass_count | `6` |
| UVM errors / fatals | `0 / 0` |
| payload / padding words | `962 / 768` |
| ingress / OPQ / DMA hits | `9605 / 3848 / 3848` |
| code coverage | `stmt=72.84, branch=65.68, cond=33.37, expr=46.12, fsm_state=75.76, fsm_trans=39.80, toggle=27.68` |
| functional cross pct | `36.88` |

## Segment manifest

| idx | case_id | bucket | replay_dir | mask | merge | dma_half_full_pct | seed | reset_before |
|---:|---|---|---|---:|---:|---:|---:|---:|
| 0 | `B001` | `BASIC` | [`sim_runs/cross/replay/B001`](../../sim_runs/cross/replay/B001) | `0xf` | `1` | `0` | `0` | `0` |
| 1 | `B002` | `BASIC` | [`sim_runs/cross/replay/B002`](../../sim_runs/cross/replay/B002) | `0xf` | `1` | `0` | `1` | `0` |
| 2 | `B046` | `BASIC` | [`sim_runs/cross/replay/B046`](../../sim_runs/cross/replay/B046) | `0x1` | `1` | `0` | `4242` | `0` |
| 3 | `B047` | `BASIC` | [`sim_runs/cross/replay/B047`](../../sim_runs/cross/replay/B047) | `0x2` | `1` | `0` | `4242` | `0` |
| 4 | `B048` | `BASIC` | [`sim_runs/cross/replay/B048`](../../sim_runs/cross/replay/B048) | `0x4` | `1` | `0` | `4242` | `0` |
| 5 | `B049` | `BASIC` | [`sim_runs/cross/replay/B049`](../../sim_runs/cross/replay/B049) | `0x8` | `1` | `0` | `4242` | `0` |

## Notes

- BASIC smoke/full replay plus active-lane mask anchors.
- This evidence is generated from `tb_int/sim_runs/cross/summary.json`; hand edits to this page are overwritten.
- The promoted baseline uses the legal anchor segment set currently implemented by the UVM segment-manifest runner. The broader 129-row cross catalog remains the planning space for future exact case-id expansion.
