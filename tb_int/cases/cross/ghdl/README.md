# `tb_int/cases/cross/ghdl`

Lightweight GHDL cross-run waveform fixture for the MuSiP SWB/OPQ integration.

This bench is a deterministic debug waveform generator, not the signoff DUT. It emits a shorter packet-evidence run with five scenarios: BASIC merge (`B001`), runtime lane-mask change (`B046`), PROF skew/backpressure (`P123`), ERROR decode (`X111`), and CSR readback (`C001`). Each scenario shows at least three frames; frame headers are spaced by `0x800` ticks in the 8 ns timestamp domain, matching the UVM frame-step convention.

The packet grammar, timing guard, internal-dataflow display assumptions, and CSR-map assumptions are defined in [`CONTRACT.md`](CONTRACT.md). Treat that file as the local source of truth for whether a displayed signal is meaningful.

The generated GTKWave save file is organized for visual OPQ evidence: the scenario row translates `case_index` directly to `B001`, `B046`, `P123`, `X111`, and `C001`; packet evidence then flows through four ingress packet lanes, one OPQ egress packet lane, OPQ internal dataflow/fill-level signals, a DMA payload sample, diagnostics in appendix `A0`, CSR counter values in appendix `A1`, and CSR map/read-bus signals in appendix `A2`.

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
make ip-ghdl-cross-run GHDL_CASE_CYCLES=24576 GHDL_WAVE_FORMAT=vcd
```

Outputs are generated under `report/` and intentionally ignored:

- `report/tb_swb_cross_ghdl.vcd`
- `report/tb_swb_cross_ghdl.gtkw`
- `report/tb_swb_cross_ghdl_signal_guide.md`
- `report/tb_swb_cross_ghdl.log`
- `report/tb_swb_cross_ghdl_checkpoints.md`
- `report/*_filter.txt`

The generated signal guide is a Markdown companion to the GTKWave save file. It
describes each waveform group and every emitted row, including the controlled,
asserted, and inferred drop statistics in appendix `A1`.

Native-SV comparison flow:

```bash
python3 tb_int/scripts/export_wave_case_bundle.py \
  --case-id B001 \
  --profile-name B001_aligned_native_sv \
  --frames 3 \
  --seed 1 \
  --sat 0.20 0.40 0.60 0.80 \
  --feb-enable-mask 0xf \
  --frame-slot-cycles 4096 \
  --lane-skew-fixed 0,0,0,0 \
  --frame-start 0 \
  --frame-count 3 \
  --out-root tb_int/report/wave_native_compare \
  --opq-source-mode native_sv_signoff

make -C tb_int/cases/cross/ghdl run checkpoints \
  UVM_B001_VCD=$(pwd)/tb_int/report/wave_native_compare/BASIC/B001/sim/B001.vcd

python3 tb_int/scripts/compare_opq_wave_timing.py \
  --uvm-vcd tb_int/report/wave_native_compare/BASIC/B001/sim/B001.vcd \
  --ghdl-vcd tb_int/cases/cross/ghdl/report/tb_swb_cross_ghdl.vcd \
  --out tb_int/report/wave_native_compare/BASIC/B001/timing_compare.json
```

The `tb_int/report/wave_native_compare/` tree is generated evidence output and
is intentionally ignored by git. A fresh checkout can reproduce it by running
the three commands above in order.

When `UVM_B001_VCD` is set, the GHDL display for `B001` is not a synthetic OPQ model. It replays the native-SV UVM `feb_if0..3` ingress streams and `opq_if` egress stream extracted from the VCD, so the visual comparison is against the same native-SV packet timing.

Current local validation:

- `make ip-ghdl-cross-run` passes the five-scenario packet-evidence sequence: `B001`, `B046`, `P123`, `X111`, and `C001`.
- `make ip-ghdl-cross-checkpoints` checks 12 named checkpoints and 45 signal expectations across aligned BASIC lane preambles, OPQ egress-after-page-commit timing, UVM-spaced frame headers, runtime lane-mask updates, DMA backpressure, partial-join body hold, CSR reads, and final scoreboard state.
- The GTKWave view decodes each packet stream as raw `word[35:0]`, raw `data[31:0]`, decoded `datak[35:32]`, decoded packet kind, decoded header type, frame timestamp, header fields, timestamp/debug fields, collapsed subheader fields, and hit fields.
- The native-SV comparison above passes the timing and packet-integrity checks: all four BASIC lane SOPs are aligned for the first three frames, lane0 frame spacing is 4096 cycles, the first OPQ SOP is after the first ingress frame commit, all three OPQ SOP delays from lane0 SOP match between native-SV UVM and GHDL replay, and the parser verifies legal grammar, `0x800` frame timestamp steps, OPQ timestamp/count fields, and ingress-to-OPQ hit/subframe-hit multisets.
