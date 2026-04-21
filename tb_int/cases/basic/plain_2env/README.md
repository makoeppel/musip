# `tb_int/cases/basic/plain_2env`

Two-env workaround harness for the SWB/OPQ integration.

This path splits the problem at the OPQ seam:

- the MuSiP post-OPQ datapath runs as VHDL-only RTL,
- the OPQ side is represented by a pin-matched DPI bridge,
- ingress stimulus and datapath checking live in separate UVM envs,
- the current backend is replay-backed from `../ref/out`.

Use this order:

1. Run `make ip-tlm-basic`
2. Run `make ip-compile-plain-2env`
3. Once a standard Mentor runtime exists, run `make ip-plain-basic-2env`

What the DPI backend does today:

- checks each ingress lane driver against `lane*_ingress.mem`,
- sources `opq_egress.mem` beat-by-beat into the VHDL-only datapath,
- keeps the OPQ pin contract explicit so a real standard-runtime backend can replace the replay backend later.

Useful overrides:

- `make run REPLAY_DIR=/absolute/path/to/tb_int/cases/basic/ref/out`
- `make run QUESTA_HOME=/path/to/full/questa`
