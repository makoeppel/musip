# `tb_int/cases/cross/ghdl`

Lightweight GHDL cross-run waveform fixture for the MuSiP SWB/OPQ integration.

This bench is a deterministic debug waveform generator, not the signoff DUT. It mirrors the promoted `CROSS-005` flow shape by walking the BASIC, EDGE, PROF, and ERROR anchor cases in one no-restart run with reset delimiters between buckets. The generated GTKWave save file follows the SignalTap/GTK reporting convention: clock/reset first, then RX ingress, OPQ join/reorder, DMA egress, and scoreboard signals.

Targets:

```bash
make ip-ghdl-cross-objects
make ip-ghdl-cross-run
make ip-ghdl-cross-gtkw
make ip-ghdl-cross-checkpoints
make ip-ghdl-cross-view
```

Defaults are tuned for an O(1s)-class local GHDL run on a normal workstation:

```bash
make ip-ghdl-cross-run GHDL_CASE_CYCLES=8192 GHDL_WAVE_FORMAT=vcd
```

Outputs are generated under `report/` and intentionally ignored:

- `report/tb_swb_cross_ghdl.vcd`
- `report/tb_swb_cross_ghdl.gtkw`
- `report/tb_swb_cross_ghdl.log`
- `report/tb_swb_cross_ghdl_checkpoints.md`
- `report/*_filter.txt`

Current local validation:

- `make ip-ghdl-cross-run` passes the 22-case sequence: BASIC `B001`, `B002`, `B046..B049`; EDGE `E025..E027`; PROF `P040`, `P041`, `P123`, `P124`; ERROR `X111`, `X112`, `X116..X118`, `X120`, `X122..X124`.
- `make ip-ghdl-cross-checkpoints` checks 13 named checkpoints and 41 signal expectations across case starts, DMA backpressure, partial-join body hold/release, error anchors, and final scoreboard state.
- GTKWave visual inspection on April 28, 2026 opened the generated `.gtkw` and checked 10 focused points: `B001`, `B046`, `E025`, `P040` start, `P040` DMA backpressure, `P123` body hold, `P123` release, `X111`, `X118`, and `CROSS_DONE`. The groups render as clock/reset -> case delimiters -> RX ingress -> OPQ join/reorder -> DMA egress -> scoreboard diagnostics, with no ghost or missing counts and final scoreboard pass asserted.
