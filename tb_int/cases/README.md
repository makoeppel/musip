# `tb_int/cases`

Case inventory for integration-level SWB verification.

If you are new here:

1. Start with `basic/`.
2. Run the replay/reference flow first, not the full SWB-integrated UVM flow.
3. Only move to the RTL/UVM run after the proper Mentor/Questa runtime is available.

- `basic/` owns smoke, lane-mask, active-lane, and randomized-screen anchors.
- `edge/` indexes boundary/corner cases implemented through the shared UVM/basic harness.
- `prof/` indexes profile, long-run, backpressure, skew, and analyzer-stress cases.
- `error/` indexes fault/recovery/regression anchors.
- `cross/` indexes continuous-frame signoff runs and the `cross/ghdl/` debug waveform fixture.

Current direction:

- keep the first case focused on MuPix-format FEB ingress,
- keep the OPQ boundary explicitly checkable even though the fully integrated `swb_block` path is now green in this repo,
- compare the first `GET_N_DMA_WORDS` payload words and ignore the event-builder padding tail.
- use `make ip-ghdl-cross-run` and `make ip-ghdl-cross-checkpoints` when you need a fast all-bucket waveform/debug pass before opening the heavier UVM evidence.

Functional coverage status and the implemented/missing list live in [`../report/signoff/DV_SIGNOFF.md`](../report/signoff/DV_SIGNOFF.md).
