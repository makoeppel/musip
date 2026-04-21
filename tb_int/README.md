# `tb_int`

Integration-facing simulation workspace for the OPQ/SWB bring-up.

- `cases/` holds directed case buckets and future replay domains.
- `cases/basic/` is the first constrained-random MuPix ingress case.
- `cases/basic/uvm/` contains the mixed-language UVM harness that drives `swb_block`.

Use this order:

1. `make ip-init`
   Use this once after clone or whenever the OPQ snapshot or submodules need refreshing.
2. `make ip-tlm-basic-smoke`
   Use this first when you want the smallest deterministic replay bundle.
3. `make ip-plain-basic-2env-smoke`
   Use this next to run the split DPI seam with explicit ingress and egress boundary checking.
4. `make ip-lint-rtl`
   Use this before compile. It strict-checks the clean maintained files and hygiene-checks the legacy or imported RTL.
5. `make ip-tlm-basic`
   Use this to generate the larger Poisson replay bundle for the default basic case.
6. `make ip-plain-basic`
   Use this to run the quartus-system-style plain replay bench on the current host.
7. `make ip-plain-basic-2env`
   Use this to run the split 2-env DPI workaround harness on the current host.
8. `make ip-compile-basic`
   Use this to make sure the mixed-language UVM harness still compiles.
10. `make ip-uvm-basic`
   Use this after the full Mentor verification runtime is available.
11. `make ip-formal-boundary`
   Use this to run the OPQ seam packet-contract formal scaffold.

What each make target means:

- `make ip-init`: initialize submodules and refresh the OPQ snapshot.
- `make ip-sync-opq`: refresh only the copied OPQ RTL snapshot.
- `make ip-svd`: regenerate the OPQ memory-map SVD under `build/ip/`.
- `make ip-check-license`: check whether the ETH Siemens/Mentor features are reachable.
- `make ip-lint-rtl`: strict-check maintained bridge/wrapper RTL and hygiene-check touched legacy or imported RTL.
- `make ip-compile-plain`: compile the plain mixed-language replay bench.
- `make ip-compile-plain-2env`: compile the split 2-env DPI workaround harness.
- `make ip-compile-basic`: compile the mixed-language UVM harness only.
- `make ip-tlm-basic`: generate the simulatorless basic case and export replay files.
- `make ip-tlm-basic-smoke`: generate the directed smoke replay bundle under `ref/out_smoke`.
- `make ip-plain-basic`: run the plain mixed-language replay bench.
- `make ip-plain-basic-smoke`: run the plain mixed-language directed smoke bench.
- `make ip-plain-basic-2env`: run the split 2-env DPI workaround harness.
- `make ip-plain-basic-2env-smoke`: run the split 2-env directed smoke harness.
- `make ip-uvm-basic`: run the real RTL/UVM case.
- `make ip-formal-boundary`: run the OPQ seam packet-contract formal scaffold.
- `make ip-e2e`: alias for `ip-uvm-basic`.
- `make ip-e2e-ref`: alias for `ip-tlm-basic`.
- `make ip-e2e-plain`: alias for `ip-plain-basic`.
- `make ip-e2e-plain-2env`: alias for `ip-plain-basic-2env`.
- `make ip-clean`: remove both UVM scratch data and fallback replay output.
