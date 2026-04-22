# `P041` wave bundle

- **bucket:** `PROF`
- **profile:** `P041_dma_half_full_75`
- **same-axis VCD:** `sim/P041.vcd`
- **sim args:** `+SWB_PROFILE_NAME=P041_dma_half_full_75 +SWB_FRAMES=2 +SWB_CASE_SEED=5151 +SWB_SAT0=0.20 +SWB_SAT1=0.20 +SWB_SAT2=0.20 +SWB_SAT3=0.20 +SWB_DMA_HALF_FULL_PCT=75`

## Captured summary

- **start:** `# Start time: 19:37:59 on Apr 22,2026`
- **case:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_basic_test.sv(163) @ 66000: uvm_test_top [CASE] Basic case: frames=2 sat=[0.20 0.20 0.20 0.20] mask=0xf hit_mode=poisson raw_total_hits=1638 padding_hits_added=2 total_hits=1640 expected_words=410 use_merge=1 dma_half_full_pct=75 case_seed=5151`
- **opq:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(590) @ 51498000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] opq expected=1640 actual=1640 ghosts=0 missing=0`
- **dma:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(590) @ 51498000: uvm_test_top.env.scoreboard [HIT_STAGE_SUMMARY] dma expected=1640 actual=1640 ghosts=0 missing=0`
- **dma_summary:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(734) @ 51498000: uvm_test_top.env.scoreboard [DMA_SUMMARY] Compared 410 payload words, ignored 128 trailing padding words, ingress_hits=1640 opq_hits=1640 dma_hits=1640 parse_errors=0`
- **pass:** `# UVM_INFO /home/yifeng/packages/musip_2604/tb_int/cases/basic/uvm/sv/swb_scoreboard.sv(783) @ 51498000: uvm_test_top.env.scoreboard [SWB_CHECK_PASS] profile=P041_dma_half_full_75 case_seed=5151 payload_words=410 padding_words=128 ingress_hits=1640 opq_hits=1640 dma_hits=1640`
- **end:** `# End time: 19:38:06 on Apr 22,2026, Elapsed time: 0:00:07`

## Notes

- The recorded VCD keeps `feb_if0..3`, `opq_if`, `dma_if`, and `ctrl_if` on the same clock/time axis.
- The packet analyzer bundle decodes ingress packets from the same VCD; use GTKWave or Questa on the VCD when you want to correlate those ingress packets against `opq_if` and `dma_if` cycle-by-cycle.

## Serve

`python3 external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/serve_packet_analyzer.py --dir tb_int/wave_reports/PROF/P041/packet_analyzer --port 8765`
