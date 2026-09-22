# Reading the SciFi histogram: address map for MIDAS and NIOS

This is the fe_scifi integration address map for `histogram_statistics_v2`.
For what the IP itself does, see `README.md` and `doc/rtl_note.md`.

## Where the mailbox sits

The histogram runs in the 125 MHz datapath domain. The legacy Mu3e slow
control tree cannot carry `waitrequest` or `readdatavalid`, so the leaf is
fixed-latency and every variable-latency operation is executed through a
one-command mailbox (`mu3e_hist_avmm_cdc_adapter`).

Slow control path:

```
sc_rx (from SWB)  ─┐
                   ├─► sc_ram ─► e_lvl0_sc_node ─► slave0 (subdetector)
NIOS avm_sc       ─┘                                  │
                                                      ▼
                                        scifi_path e_lvl1_sc_node
                                                      │ slave0 (catch-all)
                                                      ▼
                                        scifi_path e_lvl2_sc_node
                                                      │ slave1  0x02000..0x02003
                                                      ▼
                                        mu3e_hist_avmm_cdc_adapter
                                                      │
                                    ┌─────────────────┴─────────────────┐
                                    ▼                                   ▼
                            avm_csr (32 words)                avm_hist_bin (256 words)
```

All addresses below are **32-bit slow-control word addresses**, not byte
addresses. Only these four words are directly visible; CSR and bin access
is indirect through them.

| Word | SC addr | Name | Description |
|---:|---:|---|---|
| 0 | `0x02000` | `CONTROL_STATUS` | Write bit 0 `START`, bit 1 `WRITE`, bit 2 `CLEAR`. Read bit 0 busy, bit 1 done, bit 2 overrun, bit 3 last operation was write, bit 4 timeout, bits 6:5 Avalon response, bits 16:8 target echo. |
| 1 | `0x02001` | `TARGET_ADDRESS` | Low 9 bits. CSR target `0x000..0x01f`, or frozen-bin target `0x100..0x1ff`. |
| 2 | `0x02002` | `WRITE_DATA` | Staged CSR write data. |
| 3 | `0x02003` | `READ_DATA` | Data from a completed indirect read. |

## Reading from MIDAS

Use the existing `FEBSlowcontrolInterface` against the `mappedFEB` selected
from the SciFi FEB list. Do not hardcode a data-link number.

```cpp
constexpr uint32_t HIST_STATUS = 0x02000;
constexpr uint32_t HIST_TARGET = 0x02001;
constexpr uint32_t HIST_WDATA  = 0x02002;
constexpr uint32_t HIST_RDATA  = 0x02003;
constexpr uint32_t HIST_START  = 1u;
constexpr uint32_t HIST_WRITE  = 2u;
constexpr uint32_t HIST_CLEAR  = 4u;

feb_sc.FEB_read (feb, HIST_STATUS, value);
feb_sc.FEB_write(feb, HIST_TARGET, target);
```

Indirect read sequence:

1. Read `0x02000`; refuse to start if busy is one.
2. Write `CLEAR` to `0x02000`, then verify busy/done/overrun/timeout and the
   Avalon response are clear. The previous-operation bit may remain set.
3. Write the target to `0x02001` and read it back.
4. Write `START` to `0x02000`.
5. Poll until `busy=0` and `done=1`. Require no overrun or timeout, response
   `00`, read-operation bit 3 clear, and the exact target echo in bits 16:8.
6. Read the result from `0x02003`.

A CSR write is the same, but stage and verify both `0x02001` and `0x02002`,
start with `START | WRITE`, and require bit 3 set on completion.

Verify `UID` (`target 0x000`) reads `0x48495354` (ASCII `HIST`) before
trusting anything else.

## Reading from NIOS

**The same word addresses work from NIOS.** `sc_ram` is an arbiter, not an
address split: the SWB link port (`i_ram_*`) and the NIOS Avalon port
(`i_avs_*`) both drive one shared `o_reg_*` master into the same tree, so
NIOS sees an identical map.

```cpp
#include "sc_ram.h"
volatile sc_ram_t* ram = (sc_ram_t*)AVM_SC_BASE;

// same four words as MIDAS
alt_u32 status = ram->data[0x02000];
ram->data[0x02001] = target;
ram->data[0x02000] = 1;              // START
while (ram->data[0x02000] & 1) { }   // busy
alt_u32 value = ram->data[0x02003];
```

`ram->data[]` spans word addresses `0x0000..0xFEFF`, so `0x2000..0x2003` is
inside it. The top 256 words are the `regs` block and are unrelated.

Poll with a bounded budget rather than the unbounded loop above, and apply
the same status checks listed for MIDAS.

## One owner at a time

`sc_ram` arbitrates per access, and `FEBSlowcontrolInterface` serializes each
outer packet. Neither protects a **multi-packet mailbox sequence**. A second
client interleaving between step 3 and step 5 replaces the staged target or
data and corrupts the result.

Use exactly one logical mailbox owner. In particular do not run the
command-line helper, or a NIOS routine, while MIDAS owns the mailbox.

## Indirect targets

| Target | Name | Description |
|---:|---|---|
| `0x000` | `UID` | Read-only `0x48495354`. Verify first. |
| `0x001` | `META` | Version/date/instance metadata. |
| `0x002` | `CONTROL` | Apply, mode, signedness, equality filter, source, error status. |
| `0x003` | `LEFT_BOUND` | Signed lower edge of bin 0. |
| `0x004` | `RIGHT_BOUND` | Exclusive right edge, derived as `LEFT + 256*WIDTH`. |
| `0x005` | `BIN_WIDTH` | Low 16 bits, in 125 MHz ticks. Use a nonzero power of two. |
| `0x006` | `KEY_LOC` | `{filter_hi, filter_lo, update_hi, update_lo}`, one byte each. |
| `0x007` | `KEY_VALUE` | Filter key in bits 31:16, update key in bits 15:0. |
| `0x008` | `UNDERFLOW_COUNT` | Current-window keys below `LEFT_BOUND`. |
| `0x009` | `OVERFLOW_COUNT` | Current-window keys at or above `RIGHT_BOUND`. |
| `0x00a` | `INTERVAL_CFG` | Automatic bank-swap period in clocks. Zero disables. |
| `0x00b` | `BANK_STATUS` | Bit 0 active write bank, bit 1 flushing, bits 15:8 flush address. |
| `0x00c` | `PORT_STATUS` | Bits 7:0 FIFO-empty flags, bits 23:16 maximum FIFO level. |
| `0x00d` | `TOTAL_HITS` | Current-window raw accepted samples before filtering. |
| `0x00e` | `DROPPED_HITS` | Current-window loss from a full post-binner FIFO. |
| `0x00f` | `COAL_STATUS` | Coalescer occupancy. Upper half is pressure, not drops. |
| `0x010` | `SCRATCH` | Read/write scratch. |
| `0x011` | `LAST_INTERVAL_TOTAL_HITS` | Latched at the last bank swap. |
| `0x012` | `LAST_INTERVAL_DROPPED_HITS` | Latched at the last bank swap. |
| `0x100 + bin` | `FROZEN_BIN[bin]` | Bin contents of the bank not being filled, `bin` 0..255. |

Writing zero to any bin target is a **global histogram clear**, not a
single-bin clear. Do not expose a general bin-write function.

## Modes

`CONTROL` bits: 0 apply strobe, 1 apply pending, 3:2 input port (use zero),
7:4 mode (`0` rate, `1` delay), 8 update-key representation (`1` unsigned for
rate, `0` signed for delay), 12 equality filter enable, 13 reject when one /
accept-only when zero, 17:16 source (**use `3`** for the eight post-MTS Type1
lanes), 24 configuration error, 31:28 error reason.

- **Delay** bins the signed 48-bit lifetime `arrival48 - true_hit_timestamp48`.
  One tick is 8 ns. Default preset covers `[-1000, 3096)` with 16-tick
  (128 ns) bins.
- **Rate** has 256 stable bins; bin `32*ASIC + channel`, ASIC `0..7`,
  channel `0..31`.

A negative delay is not an alternate frame phase. It means the upstream
timestamp, epoch, PLL or run synchronization is wrong. Keep negative bins
visible and fix the upstream cause.

Write CSR 3, 5, 6, 7 and 10 first, then CSR 2 last with its apply bit. Poll
CSR 2 until bit 1 clears, require bit 24 clear, and verify CSR 4. Apply while
stopped with the source quiet.

| Preset | CSR3 | CSR5 | CSR6 | CSR7 | CSR10 | CSR2 apply | CSR2 stable |
|---|---:|---:|---:|---:|---:|---:|---:|
| Delay, reject channel 31 | `0xfffffc18` | `0x10` | `0x221e251e` | `0x001f0000` | `0` | `0x00033011` | `0x00033010` |
| Delay, no filter | `0xfffffc18` | `0x10` | `0x2623251e` | `0` | `0` | `0x00030011` | `0x00030010` |
| Rate, no filter | `0` | `1` | `0x221e251e` | `0` | `0` | `0x00030101` | `0x00030100` |
| Rate, reject channel `C` | `0` | `1` | `0x221e251e` | `(C & 31) << 16` | `0` | `0x00033101` | `0x00033100` |
| Rate, reject ASIC `A` | `0` | `1` | `0x2623251e` | `(A & 7) << 16` | `0` | `0x00033101` | `0x00033100` |

The equality filter has one comparator. It can reject or accept one channel,
one ASIC, or one exact ASIC/channel coordinate. It is not a bitmap.

## Coherent snapshot

With `INTERVAL_CFG=0`, configure while stopped, run `PREP -> SYNC ->
RUNNING`, enable the source only after RUNNING, disable it, then enter
`TERMINATING`. The datapath holds RUNNING toward the histogram until the
observed plane has been quiet, then releases one forced bank swap.

Then: wait for CSR11 bit 1 to clear, save the active-bank bit 0, read targets
`0x100..0x1ff`, read CSR11 again, and publish only if bit 1 is still clear and
the active-bank bit did not change. Read CSR17/18 and publish atomically.

A genuinely zero-hit run does not force a new bank swap. Report `no new
snapshot` rather than relabelling the previous frozen bank as a fresh empty
run.

For rolling windows set `INTERVAL_CFG=N` clocks (ten seconds is
`1250000000`). Choose an interval strictly longer than the worst full-dump
time; the one-bit bank identity aliases if the reader is too slow. Discard and
restart a scan if flushing starts or the bank changes mid-scan.

`sum(frozen bins)` need not equal CSR17: CSR17 counts raw pre-filter input,
while equality rejects and delay under/overflow are not `DROPPED_HITS`.

## Known limitation on this branch

There is no epoch-reset owner here, so hits crossing a SYNC epoch boundary
can land in a wrong delay bin until the counters resettle. Rate mode is
unaffected.
