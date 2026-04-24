# `B047` wave bundle

- **bucket:** `BASIC`
- **profile:** `B047_lane1_only`
- **same-axis VCD:** `sim/B047.vcd`
- **shared-axis HTML:** `packet_analyzer/index.html`
- **bundled SVD:** `opq.svd`
- **sim args:** `+SWB_PROFILE_NAME=B047_lane1_only +SWB_FRAMES=3 +SWB_FRAME_SLOT_CYCLES=4096 +SWB_CASE_SEED=4242 +SWB_SAT0=0.20 +SWB_SAT1=0.40 +SWB_SAT2=0.60 +SWB_SAT3=0.80 +SWB_FEB_ENABLE_MASK=2 +SWB_LANE0_SKEW_CYC=0 +SWB_LANE1_SKEW_CYC=0 +SWB_LANE2_SKEW_CYC=0 +SWB_LANE3_SKEW_CYC=0`
- **frame cadence:** `SWB_FRAME_SLOT_CYCLES=4096` is the physical `N_SHD=128` SOP spacing at `250 MHz`; smaller values are visualization-only compression.
- **timestamp contract:** frame-header `ts[47:0]` is the time-slice origin in `8 ns` units, starts at `0`, advances by `0x0800` per frame at `N_SHD=128` (`0x1000` at `N_SHD=256`), keeps the lower slice bits zero, and `debug1` is the later live dispatch timestamp rather than a copy of the frame origin.

## Captured summary

- **start:** `# Start time: 09:03:16 on Apr 24,2026`
- **case:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_basic_test.sv(171) @ 70000: uvm_test_top [CASE] Basic case: frames=3 sat=[0.20 0.40 0.60 0.80] mask=0x2 hit_mode=poisson raw_total_hits=607 padding_hits_added=1 total_hits=608 expected_words=152 use_merge=1 dma_half_full_pct=0 case_seed=4242 lane_skew0=[0,0,0,0] lane_skew_max=0 lane_skew_mode=  fixed`
- **opq:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(673) @ 55614000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] opq expected=608 actual=608 ghosts=0 missing=0`
- **dma:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(673) @ 55614000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] dma expected=608 actual=608 ghosts=0 missing=0`
- **dma_summary:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(821) @ 55614000: uvm_test_top.env.scoreboard [DMA_SUMMARY] Compared 152 payload words, ignored 128 trailing padding words, ingress_hits=2844 opq_hits=608 dma_hits=608 parse_errors=0`
- **pass:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(874) @ 55614000: uvm_test_top.env.scoreboard [SWB_CHECK_PASS] profile=B047_lane1_only case_seed=4242 payload_words=152 padding_words=128 ingress_hits=2844 opq_hits=608 dma_hits=608`
- **end:** `# End time: 09:03:19 on Apr 24,2026, Elapsed time: 0:00:03`

## Notes

- The recorded VCD keeps `feb_if0..3`, `opq_if`, `dma_if`, and `ctrl_if` on the same clock/time axis.
- `bundle.json` names those interface roles explicitly so downstream tools can identify ingress, merged OPQ egress, DMA, and control signals without guessing from the raw VCD.
- When present, `opq.svd` is the register-map snapshot that belongs to the same evidence bundle.
- `packet_analyzer/` is the local shared-axis WaveDrom report generated from `tb_int/`. It is the human-readable ingress/egress/DMA correlation view for the exact same capture.

## Serve

`python3 /home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/serve_packet_analyzer.py --dir tb_int/wave_reports/BASIC/B047/packet_analyzer --port 8765`
