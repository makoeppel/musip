# `wave_reports/` bundle guide

This directory holds checked-in waveform/analyzer bundles for promoted MuSiP DV cases.
Canonical case bundles are organized as `wave_reports/<bucket>/<case_id>/`:

- `BASIC/<case_id>/`
- `EDGE/<case_id>/`
- `PROF/<case_id>/`
- `ERROR/<case_id>/`
- `CROSS/<case_id>/`

Each promoted case bundle keeps one same-axis VCD that records:

- `tb_top.feb_if0..3`
- `tb_top.opq_if`
- `tb_top.dma_if`
- `tb_top.ctrl_if`
- `tb_top.clk`

That VCD is the correlation source of truth for ingress, merged OPQ egress, and DMA.
The bundled packet analyzer is an ingress-focused decode surface generated from the same VCD.

## Authored tools

- Authoritative packet-analyzer tool README:
  [`../../external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/README.md`](../../external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/README.md)
- Generator:
  [`../../external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/generate_musip_packet_analyzer.py`](../../external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/generate_musip_packet_analyzer.py)
- Local bundle exporter:
  [`../scripts/export_wave_case_bundle.py`](../scripts/export_wave_case_bundle.py)

## Current bundles

| bucket | case | intent | bundle |
|---|---|---|---|
| `BASIC` | `B047` | lane1-only merged-path closure | [`BASIC/B047/`](BASIC/B047/) |
| `BASIC` | `B048` | lane2-only merged-path closure | [`BASIC/B048/`](BASIC/B048/) |
| `BASIC` | `B049` | lane3-only merged-path closure | [`BASIC/B049/`](BASIC/B049/) |
| `PROF` | `P041` | `75%` DMA half-full backpressure | [`PROF/P041/`](PROF/P041/) |

Each case bundle contains:

- `sim/*.vcd`
- `sim/run_vcd.log`
- `ref/` ingress/reference artifacts
- `packet_analyzer/` static HTML bundle
- `bundle.json` summary metadata
- `README.md` case-local serve/correlation notes

## Serve

Serve any bundle's packet analyzer with:

```bash
python3 external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/serve_packet_analyzer.py \
  --dir tb_int/wave_reports/BASIC/B047/packet_analyzer \
  --port 8765
```

Optional visual-debug capture:

```bash
python3 external/mu3e-ip-cores/tools/packet_transaction_traffic_analyzer/scripts/run_packet_analyzer_visual_debug.py \
  --url http://127.0.0.1:8765/ \
  --out-dir tb_int/wave_reports/BASIC/B047/packet_analyzer/visual_debug
```

## Navigation help

- Use the lane selector to restrict the ingress view to one FEB lane at a time.
- Click a packet row to open the spec/details panes for that packet.
- Use the hex/bin toggle in the spec pane when checking field overlays.
- Use the low-level tracker pane when you need the original word sequence behind a decoded packet.
- Append `?debug=1` to the served URL if you need the analyzer's debug overlay.

## Correlation note

The packet analyzer decodes ingress packets only.
When you need OPQ and DMA correlation, open the case-local `sim/*.vcd` in GTKWave or Questa and inspect `feb_if*`, `opq_if`, and `dma_if` on the same timeline.
The masked-lane BASIC bundles intentionally keep all four ingress interfaces in the VCD even when only one lane survives the musip-local `feb_enable_mask`, so the pre-mask source traffic and the post-merge OPQ/DMA result stay visible in one recording.
