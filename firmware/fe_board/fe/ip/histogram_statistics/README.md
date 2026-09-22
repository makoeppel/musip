# Histogram Statistics Phase-I Snapshot

This directory vendors the exact `histogram_statistics_v2` RTL used by the
SciFi Phase-I integration. Quartus and the realistic UVM build consume these
local files; neither build requires a sibling `mu3e-ip-cores` checkout.

## Source

- Repository: `https://github.com/yifeng-ethz/histogram_statistics`
- Branch: `master`
- HEAD: `527444b39ab647f81c6fba9962c7baae6da0b0bd`
- Snapshot date: `2026-07-16`
- Snapshot kind: exact committed release bytes

The manifest below is byte-identical to the published commit. The local copy
keeps the Phase-I build independent of a sibling `mu3e-ip-cores` checkout.

## RTL Manifest

| File | SHA-256 |
|---|---|
| `histogram_statistics_v2_pkg.vhd` | `0ef02baad66cd40e0850bcc59a32503ceabe1cda29fffa69acf59568e721f55c` |
| `true_dual_port_ram_single_clock.vhd` | `21f2fba8a655a1c6008208bcecbd39b720d4257ac6b0df228997c9531cdfac73` |
| `hit_fifo.vhd` | `28ff9d9a5b7acc3ab4abfe29b915d3f94883e1dafa5a710c7e334e7c6cc3df4a` |
| `rr_arbiter.vhd` | `f10bafb6a6e1244ade50f68e9d298eb22c286ce5d237caa376158b9aba949e94` |
| `bin_divider.vhd` | `76758166cee8eaac2ddbd10ff70d3a656fcf98ed108bc8aefd061908ac9dbcc9` |
| `coalescing_queue.vhd` | `e6fe5fba15866cb6f2c3c3663fc6dd0035bd59b0dd3859eb847bd5881292736f` |
| `pingpong_sram.vhd` | `de0808f0faba7ac9bdd7c9130f7b38eb09ae2c72bf463dd8881ac123956e27b2` |
| `histogram_statistics_v2.vhd` | `2891b95a1bcfbe5e9d0541b6c1e337da697758cde491181b5eb370dbcefad332` |

`rr_arbiter.vhd` is retained for parity with the previously closed Quartus
QIP file list, although the current V2 implementation does not instantiate it.
The Platform Designer descriptor is not copied because Phase-I instantiates the
entity directly and the upstream descriptor has additional repository-relative
assets and preset dependencies.

## Phase-I presets

The upstream IP ships exactly two Platform Designer presets: `Delay (Default)`
and `Rate Cross-check`. This direct VHDL integration reproduces those two
functional profiles through generics plus runtime CSR writes. It deliberately
keeps `LOCK_KEY_RANGES=false` so either ASIC or channel rejection remains
runtime-selectable in both profiles:

| Preset | Power-on/runtime settings | Phase-I filter |
|---|---|---|
| Delay (Default) | mode `1`, source `3`, left `-1000`, width `16`, 256 bins (`[-1000,3096)`) | reject payload channel 31 with KEY_LOC filter `[34:30]`; the signed fill remains the complete MTS `latency48` |
| Rate Cross-check | mode `0`, source `3`, left `0`, width `1`, update key `[37:30]`, 256 bins | reject one programmable ASIC `[38:35]` or channel `[34:30]`; channel 31 is the normal metadata-reject setting |

The VHDL power-on configuration is Delay mode. The run-initialization CSR
sequence additionally programs the channel-31 metadata reject before physics
measurement; it does not alter, clamp, or fold any physics `latency48` value.
The realistic UVM drives both sequences through the production slow-control
mailbox and checks their readback before accepting histogram data.
