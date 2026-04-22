# `tb_int/cases`

Case inventory for integration-level SWB verification.

If you are new here:

1. Start with `basic/`.
2. Run the replay/reference flow first, not the full SWB-integrated UVM flow.
3. Only move to the RTL/UVM run after the proper Mentor/Questa runtime is available.

- `basic/` is the first promoted case family.
- Future replay or capture-derived scenarios can live alongside it without changing the harness root.

Current direction:

- keep the first case focused on MuPix-format FEB ingress,
- keep the OPQ boundary explicitly checkable even though the fully integrated `swb_block` path is now green in this repo,
- compare the first `GET_N_DMA_WORDS` payload words and ignore the event-builder padding tail.
