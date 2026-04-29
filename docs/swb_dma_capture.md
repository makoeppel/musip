# SWB DMA Capture Runbook

This runbook is for correlating live SWB DMA payloads with SignalTap captures
after the FEB/SC setup has already been proven. It does not replace the OPQ/SWB
simulation signoff under `tb_int/`; it gives a bounded hardware evidence path.

## Boundaries

- Use `/dev/mudaq0`. Do not switch to UIO/VFIO for this flow when the next
  step expects the MUDAQ kernel driver.
- Serialize JTAG and PCIe work. Wait for `quartus_pgm`, `quartus_stp`, and
  System Console transactions to exit before probing `/dev/mudaq0`.
- Keep DMA snapshot reads bounded. Full 32 MB buffer dumps are slow, noisy, and
  make hardware evidence harder to review.
- `swb_dma_snapshot` is read-only: it does not reset FPGA logic, arm DMA, alter
  run-control state, or write readout masks.

## Build

```bash
cmake --build build --target swb_dma_snapshot
```

The executable is generated at `build/tools/swb_dma_snapshot`.

## Minimal Snapshot

After an explicit setup command has produced DMA data, capture the status
registers and a 256-word window centered on the last end-of-event pointer:

```bash
build/tools/swb_dma_snapshot \
  --words 256 \
  --around eoe \
  --out reports/swb_dma_snapshot_$(date +%Y%m%d_%H%M%S).txt
```

Use CSV when the next step is script comparison:

```bash
build/tools/swb_dma_snapshot \
  --format csv \
  --words 1024 \
  --around write \
  --out reports/swb_dma_snapshot_$(date +%Y%m%d_%H%M%S).csv
```

The header records the DMA ring size, capture start word, last written word,
last end-of-event block, next word after the end-of-event block, global
timestamp, readout masks, DMA enable register, event-build status, event-build
counters, DMA status, DMA address registers, and link-lock registers.

## SignalTap Correlation

Use the same transaction boundary in SignalTap and in the host snapshot:

1. Program the image and verify that the `.stp` matches the programmed revision.
2. Arm SignalTap on the SWB event-builder/DMA handshake, typically:
   `o_dma_wren`, `o_dma_data`, `o_endofevent`, DMA enable, DMA status, and the
   selected readout-state/mask registers.
3. Run the explicit traffic setup or run-control command.
4. Wait for SignalTap acquisition to complete.
5. Run `swb_dma_snapshot --around eoe --words <N>`.
6. Compare SignalTap's final `o_dma_data` beats against the snapshot words near
   `last_endofevent_next_word`.

Stop immediately if a host MMIO probe clears PCIe MEM decode, the BARs vanish,
or config reads return all `0xff`. Recover with the documented SWB reprogram
and MUDAQ rescan path before any further MMIO.

## Known Failure Meaning

- `EVENT_BUILD_STATUS_REGISTER_R bit 0 = 0` after the expected run window means
  the DMA event builder did not finish; do not interpret the buffer as complete
  event evidence.
- `EVENT_BUILD_SKIP_EVENT_DMA_R != 0` means accepted input exceeded the DMA
  event-builder path or event grammar was rejected.
- `last_written_word` moving while SignalTap is idle means another readout path
  is still armed. Stop it explicitly before taking evidence.
- A zero or stale DMA window with nonzero event counters points at host DMA
  mapping, kernel driver, or endpoint recovery, not OPQ packet correctness.
