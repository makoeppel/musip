# `B047_lane1_only` wave bundle

- **profile:** `B047_lane1_only`
- **same-axis VCD:** `sim/B047_lane1_only.vcd`
- **sim args:** `+SWB_PROFILE_NAME=B047_lane1_only +SWB_FRAMES=2 +SWB_CASE_SEED=4242 +SWB_SAT0=0.20 +SWB_SAT1=0.40 +SWB_SAT2=0.60 +SWB_SAT3=0.80 +SWB_FEB_ENABLE_MASK=2`

## Captured summary

- **start:** `# Start time: 19:37:32 on Apr 22,2026`
- **case:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_basic_test.sv(163) @ 66000: uvm_test_top [CASE] Basic case: frames=2 sat=[0.20 0.40 0.60 0.80] mask=0x2 hit_mode=poisson raw_total_hits=843 padding_hits_added=1 total_hits=844 expected_words=211 use_merge=1 dma_half_full_pct=0 case_seed=4242`
- **opq:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(590) @ 48590000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] opq expected=844 actual=844 ghosts=0 missing=0`
- **dma:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(590) @ 48590000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] dma expected=844 actual=844 ghosts=0 missing=0`
- **dma_summary:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(734) @ 48590000: uvm_test_top.env.scoreboard [DMA_SUMMARY] Compared 211 payload words, ignored 128 trailing padding words, ingress_hits=3810 opq_hits=844 dma_hits=844 parse_errors=0`
- **pass:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(783) @ 48590000: uvm_test_top.env.scoreboard [SWB_CHECK_PASS] profile=B047_lane1_only case_seed=4242 payload_words=211 padding_words=128 ingress_hits=3810 opq_hits=844 dma_hits=844`
- **end:** `# End time: 19:37:34 on Apr 22,2026, Elapsed time: 0:00:02`

## Notes

- The recorded VCD keeps `feb_if0..3`, `opq_if`, `dma_if`, and `ctrl_if` on the same clock/time axis.
- The packet analyzer bundle decodes ingress packets from the same VCD; use GTKWave or Questa on the VCD when you want to correlate those ingress packets against `opq_if` and `dma_if` cycle-by-cycle.

## Serve

`python3 external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/serve_packet_analyzer.py --dir tb_int/wave_reports/B047_lane1_only/packet_analyzer --port 8765`

