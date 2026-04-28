# `tb_int/cases/cross`

Continuous-frame signoff bucket.

Promoted evidence exists for `CROSS-001` through `CROSS-005`: per-bucket continuous frames for BASIC, EDGE, PROF, ERROR, and the all-buckets frame. Remaining `CROSS-006..CROSS-129` rows stay missing/pending evidence in this base signoff.

The [`ghdl/`](ghdl/) subfolder contains a lightweight all-bucket cross-run waveform fixture. It is not a replacement for the promoted UVM evidence; it is a fast, deterministic GTKWave/SignalTap-aligned debug view that exercises representative BASIC, EDGE, PROF, and ERROR anchor shapes with case-boundary delimiters.

Use the root make targets for that fixture:

```bash
make ip-ghdl-cross-objects
make ip-ghdl-cross-run
make ip-ghdl-cross-gtkw
make ip-ghdl-cross-checkpoints
make ip-ghdl-cross-view
```

Current GHDL fixture status: `make ip-ghdl-cross-run` passes the 22-anchor all-bucket sequence, and `make ip-ghdl-cross-checkpoints` checks 13 named checkpoints / 41 signal expectations. Generated VCD, log, GTKWave, screenshots, and filters stay under `ghdl/report/` and are ignored.
