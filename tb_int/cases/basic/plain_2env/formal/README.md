# `tb_int/cases/basic/plain_2env/formal`

Formal-ready boundary contract scaffold for the split OPQ seam.

What this does today:

- treats the OPQ seam as a packet grammar boundary,
- proves that a small family of legal packet shapes satisfies the executable grammar model,
- covers a complete packet so the proof is not vacuous.

What this does not do yet:

- prove the real OPQ implementation,
- replace end-to-end replay or UVM checking,
- reason about the DPI bridge itself.

Use this order:

1. Run `make ip-formal-boundary`
2. Open `tb_int/cases/basic/plain_2env/formal/oss/swb_opq_boundary_contract/`
3. If the proof is green, treat it as a boundary-grammar sanity check, not signoff.
