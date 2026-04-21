# `tb_int`

Integration-facing simulation workspace for the OPQ/SWB bring-up.

- `cases/` holds directed case buckets and future replay domains.
- `cases/basic/` is the first constrained-random MuPix ingress case.
- `cases/basic/uvm/` contains the mixed-language UVM harness that drives `swb_block`.

Use this order:

1. `make ip-init`
   Use this once after clone or whenever the OPQ snapshot or submodules need refreshing.
2. `make ip-check-license`
   Use this to confirm the ETH floating features are visible.
3. `make ip-tlm-basic`
   Use this first on the current host. It does not need the blocked `vsim` runtime and creates replay files.
4. `make ip-compile-basic`
   Use this to make sure the mixed-language harness still compiles.
5. `make ip-uvm-basic`
   Only use this after you have a full Mentor/Questa runtime. On the current host it will stop early with an explanation.

What each make target means:

- `make ip-init`: initialize submodules and refresh the OPQ snapshot.
- `make ip-sync-opq`: refresh only the copied OPQ RTL snapshot.
- `make ip-svd`: regenerate the OPQ memory-map SVD under `build/ip/`.
- `make ip-check-license`: check whether the ETH Siemens/Mentor features are reachable.
- `make ip-compile-basic`: compile the mixed-language UVM harness only.
- `make ip-tlm-basic`: generate the simulatorless basic case and export replay files.
- `make ip-uvm-basic`: run the real RTL/UVM case.
- `make ip-e2e`: alias for `ip-uvm-basic`.
- `make ip-e2e-ref`: alias for `ip-tlm-basic`.
- `make ip-clean`: remove both UVM scratch data and fallback replay output.
