# `DV_SIGNOFF.md` — tb_int Base DV Signoff

**Date:** `2026-04-27`
**Scope:** MuSiP SWB/OPQ integration under `tb_int/`
**Wave evidence:** [`../wave/`](../wave/)
**Dashboard source:** [`../../doc/DV_REPORT.md`](../../doc/DV_REPORT.md)

## Functional Coverage

| bucket | planned | implemented / evidenced | missing | implemented anchors |
|---|---:|---:|---:|---|
| BASIC | 129 | 7 | 122 | `B046`, `B047`, `B048`, `B049`, `B101`, `B102`, `B103` |
| EDGE | 129 | 3 | 126 | `E025`, `E026`, `E027` |
| PROF | 129 | 6 | 123 | `P001`, `P002`, `P040`, `P041`, `P123`, `P124` |
| ERROR | 129 | 13 | 116 | `X111`, `X112`, `X113`, `X116`, `X117`, `X118`, `X119`, `X120`, `X121`, `X122`, `X123`, `X124`, `X125` |
| CROSS | 129 | 5 | 124 | `CROSS-001`..`CROSS-005` |

`P130` is implemented as a 65-frame waveform/analyzer trim stress case under [`../wave/PROF/P130/`](../wave/PROF/P130/). It is outside the current `P001..P129` planned catalog and is therefore not counted in the PROF planned-coverage row above.

## Missing Cases

- BASIC missing: all planned `B001..B129` except the seven anchors listed above.
- EDGE missing: all planned `E001..E129` except `E025..E027`.
- PROF missing: all planned `P001..P129` except `P001`, `P002`, `P040`, `P041`, `P123`, and `P124`.
- ERROR missing: all planned `X001..X129` except `X111`, `X112`, `X113`, and `X116..X125`.
- CROSS missing: `CROSS-006..CROSS-129`.

## Server

Start the checked-in waveform server from the repo root:

```bash
tb_int/report/script/start_wave_server.sh 8789
```
