# `tb_int/cases/basic/plain_2env`

Two-env boundary harness for the SWB/OPQ integration.

This path splits the problem at the OPQ seam:

- the MuSiP post-OPQ datapath runs as VHDL-only RTL,
- the OPQ side is represented by a pin-matched DPI bridge,
- ingress stimulus and datapath checking live in separate UVM envs,
- the current backend is replay-backed from `../ref/out`.

Use this order:

1. Run `make ip-tlm-basic-smoke`
2. Run `make ip-check-license`
3. Run `make ip-plain-basic-2env-smoke`
4. Open `report/run_plain_basic_2env_smoke.log` and look for `OPQ_BOUNDARY_SUMMARY` and `DMA_SUMMARY`
5. Run `make ip-tlm-basic`
6. Run `make ip-plain-basic-2env`
7. Run `make ip-formal-boundary`

Runtime notes:

- the local Makefile defaults to `/data1/questaone_sim/questasim`,
- the run path uses the same full Questa runtime and ETH floating license setup as the UVM harness,
- the full replay run and the smoke run are both first-class options on the full Questa toolchain,
- this harness remains the promoted OPQ boundary audit owner even though the fully integrated SWB path is now green in the default UVM and plain benches.

What the DPI backend does today:

- checks each ingress lane driver against `lane*_ingress.mem`,
- sources `opq_egress.mem` beat-by-beat into the VHDL-only datapath,
- keeps the OPQ pin contract explicit so a real standard-runtime backend can replace the replay backend later.

What the UVM harness adds on top of that now:

- ingress monitors on all four FEB lanes,
- an explicit OPQ egress monitor,
- a parallel ingress-to-stream adapter feed into the downstream DMA scoreboard, so the split harness checks the same per-hit DMA contract as the integrated UVM path,
- a seam scoreboard that compares valid beats against `lane*_ingress.mem` and `opq_egress.mem`,
- packet-contract SVA checkers on every ingress lane plus the OPQ egress stream.

Useful overrides:

- `make run REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out`
- `make run-smoke SMOKE_REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out_smoke`
- `make run QUESTA_HOME=/data1/questaone_sim/questasim`
