# `tb_int/cases/basic/ref`

Simulatorless fallback for the basic SWB/OPQ bring-up case.

What it does:

- builds the same basic Poisson FEB traffic plan as the UVM case,
- serializes each FEB lane into MuSiP ingress words,
- reparses those lane streams as an independent TLM check,
- regenerates the expected 256-bit DMA payload words,
- exports replay artifacts for later UVM/RTL runs.

What it does not do:

- execute the mixed-language RTL,
- prove the OPQ RTL arbitration cycle by cycle,
- replace the real Questa UVM signoff run.

Primary target:

- `make -C tb_int/cases/basic/ref run`

Recommended use:

1. Run `make ip-tlm-basic` from the repo root.
2. Open `tb_int/cases/basic/ref/out/summary.json` to confirm hit count and expected word count.
3. Keep that `out/` directory. It is the replay bundle for a later `+SWB_REPLAY_DIR=...` UVM run once the proper Mentor runtime is installed.

Helpful overrides:

- `make -C tb_int/cases/basic/ref run SIM_ARGS='+SWB_FRAMES=1 +SWB_SAT0=0.10 +SWB_SAT1=0.20 +SWB_SAT2=0.30 +SWB_SAT3=0.40 +SWB_SEED=7'`
- `make -C tb_int/cases/basic/ref run OUT_DIR=$(pwd)/build/ip/basic_ref`

Outputs under `out/`:

- `summary.json` high-level case summary and artifact paths,
- `plan.json` frame/subheader/hit structure,
- `expected_dma_words.txt` normalized expected DMA payload words in a human-readable form,
- `expected_dma_words.mem` normalized expected DMA payload words in a UVM-friendly one-word-per-line format,
- `lane*_ingress.jsonl` serialized per-lane ingress traffic in a debug-friendly form,
- `lane*_ingress.mem` per-lane replay vectors in a UVM-friendly packed format,
- `uvm_replay_manifest.json` minimal manifest for the later replay run.

Replay file formats:

- `lane*_ingress.mem`: one 37-bit hex word per line, packed as `{valid[36], datak[35:32], data[31:0]}`
- `expected_dma_words.mem`: one normalized 256-bit DMA word per line
