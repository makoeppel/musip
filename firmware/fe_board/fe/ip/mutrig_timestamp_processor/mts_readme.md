# MuTRiG Timestamp Processor IP

## Parameters

| Parameter | Default | Range | Description |
| --- | ---: | --- | --- |
| `BANK` | `UP` | `UP` or integration-defined bank string | Bank label. `UP` emits ASIC IDs 0..3; `DW`/`DOWN` emits ASIC IDs 4..7. |
| `ENABLED_CHANNEL_LO` | `0` | `0..15` | First enabled MuTRiG channel. |
| `ENABLED_CHANNEL_HI` | `3` | `0..15` | Last enabled MuTRiG channel. Must be greater than or equal to `ENABLED_CHANNEL_LO`. |
| `PADDING_EOP_WAIT_CYCLE` | `512` | `0..4096` | Termination drain grace window in clock cycles. |
| `LPM_DIV_PIPELINE` | `4` | `0..16` | Divider pipeline depth. Must match the RTL divider latency. |
| `MUTRIG_BUFFER_EXPECTED_LATENCY_8N` | `2000` | `0..65535` | Expected MuTRiG buffering latency in 8 ns ticks. Also the reset value of the latency CSR. |
| `MUTRIG_OVERFLOW_LOOKBACK_8N` | `2000` | `0..6553` | Post-wrap epoch-disambiguation window in 8 ns ticks. |
| `DEBUG` | `1` | `0..4` | Compatibility parameter. The compact Phase I RTL ties the debug streams low. |
| `DV_COUNTER_SEED_ENABLE` | `0` | `0/1` | DV-only total-hit counter seed enable. Keep `0` for synthesis. |
| `FRAME_CORRPT_BIT_LOC` | `2` | `0..31` | Hidden error-bit mapping parameter. |
| `CRCERR_BIT_LOC` | `1` | `0..31` | Hidden error-bit mapping parameter. |
| `HITERR_BIT_LOC` | `0` | `0..31` | Hidden error-bit mapping parameter. |
| `IP_UID` | `0x4D545350` | signed 31-bit | IP identity value, default ASCII `MTSP`. |
| `INSTANCE_ID` | `0` | signed 31-bit | Integration-specific instance identifier. |
| `VERSION_MAJOR` | `26` | `0..255` | Packaged version major. Locked by elaboration. |
| `VERSION_MINOR` | `4` | `0..255` | Packaged version minor. Locked by elaboration. |
| `VERSION_PATCH` | `1` | `0..15` | Packaged version patch. Locked by elaboration. |
| `BUILD` | `529` | `0..4095` | Packaged build field. Locked by elaboration. |
| `VERSION_DATE` | `20260601` | signed 31-bit | Packaged version date. Locked by elaboration. |
| `GIT_STAMP_OVERRIDE` | `false` | boolean | Allows manual `VERSION_GIT` entry when set. |
| `VERSION_GIT` | package-time git hash | signed 31-bit | Git stamp parameter. Enabled only when override is set. |

## Ports

All interfaces are associated with `clock_interface` and `reset_interface`.

| Interface | Type | Direction | Ports | Notes |
| --- | --- | --- | --- | --- |
| `clock_interface` | clock | sink | `i_clk` | Main IP clock. |
| `reset_interface` | reset | sink | `i_rst` | Synchronous deassert reset. |
| `csr` | Avalon-MM | slave | `avs_csr_readdata[31:0]`, `avs_csr_read`, `avs_csr_address[2:0]`, `avs_csr_waitrequest`, `avs_csr_write`, `avs_csr_writedata[31:0]` | Local word-addressed CSR aperture. |
| `run_ctrl` | Avalon-ST | sink | `asi_ctrl_data[8:0]`, `asi_ctrl_valid` | One-hot run command stream. |
| `hit_type0_in` | Avalon-ST | sink | `asi_hit_type0_channel[5:0]`, `asi_hit_type0_startofpacket`, `asi_hit_type0_endofpacket`, `asi_hit_type0_endofrun`, `asi_hit_type0_error[2:0]`, `asi_hit_type0_data[44:0]`, `asi_hit_type0_valid` | Input MuTRiG hit stream. |
| `hit_type1_out` | Avalon-ST | source | `aso_hit_type1_data[38:0]`, `aso_hit_type1_valid`, `aso_hit_type1_ready`, `aso_hit_type1_channel[3:0]`, `aso_hit_type1_endofpacket`, `aso_hit_type1_startofpacket`, `aso_hit_type1_empty`, `aso_hit_type1_error` | Output Type1 hit stream. `ready` is present for compatibility; current RTL does not stall on it. |
| `hit_type1_extended_0` | Avalon-ST | source | `aso_hit_type1_extended_0_data[86:0]`, `aso_hit_type1_extended_0_valid` | Compatibility port. Data and valid are tied low in the compact Phase I RTL. |
| `hit_type1_extended_1` | Avalon-ST | source | `aso_hit_type1_extended_1_data[86:0]`, `aso_hit_type1_extended_1_valid` | Compatibility port. Data and valid are tied low in the compact Phase I RTL. |
| `hit_type1_ts` | conduit | source | `coe_hit_type1_ts[47:0]` | Compatibility port tied low in the compact Phase I RTL. |
| `hit_arrival_gts` | conduit | source | `coe_hit_arrival_gts_8n[47:0]` | Compatibility port tied low in the compact Phase I RTL. |
| `debug_ts` | Avalon-ST | source | `aso_debug_ts_valid`, `aso_debug_ts_data[15:0]` | Compatibility debug port tied low. |
| `debug_burst` | Avalon-ST | source | `aso_debug_burst_valid`, `aso_debug_burst_data[15:0]` | Compatibility debug port tied low. |
| `ts_delta` | Avalon-ST | source | `aso_ts_delta_valid`, `aso_ts_delta_data[15:0]` | Compatibility debug port tied low. |
| `debug_status` | conduit | source | `coe_debug_status_data[31:0]` | Compatibility debug port tied low. |
| `hit_type0_sidecar` | conduit | sink | `coe_hit_type0_sidecar_data[63:0]`, `coe_hit_type0_sidecar_valid` | Compatibility input, ignored by the compact Phase I RTL. |
| `hit_type1_sidecar` | conduit | source | `coe_hit_type1_sidecar_data[63:0]`, `coe_hit_type1_sidecar_valid` | Compatibility output tied low. |

## Input And Output Data Formats

### Run Control Input

`asi_ctrl_data[8:0]` carries one-hot run-state commands from the run-control
network. The MTS RTL recognizes the project run states such as `RUN_PREPARE`,
`SYNC`, `RUNNING`, and `TERMINATING`.

### Hit Type0 Input

`asi_hit_type0_data[44:0]`:

| Bits | Field |
| --- | --- |
| `[44:41]` | ASIC |
| `[40:36]` | channel |
| `[35:21]` | T coarse counter |
| `[20:16]` | T fine |
| `[15:1]` | E coarse counter |
| `[0]` | E flag |

Sidebands:

| Signal | Description |
| --- | --- |
| `asi_hit_type0_channel[5:0]` | Input stream channel. |
| `asi_hit_type0_startofpacket` | MuTRiG frame start. |
| `asi_hit_type0_endofpacket` | MuTRiG frame end. |
| `asi_hit_type0_endofrun` | Last packet marker for run termination. |
| `asi_hit_type0_error[2:0]` | Input error bits; bit locations are parameterized. |
| `asi_hit_type0_valid` | Input beat valid. |

### Hit Type1 Output

`aso_hit_type1_data[38:0]`:

| Bits | Field |
| --- | --- |
| `[38:35]` | ASIC |
| `[34:30]` | channel |
| `[29:17]` | T timestamp in 8 ns ticks |
| `[16:14]` | T 1.6 ns remainder |
| `[13:9]` | T fine |
| `[8:0]` | E-T / TOT field in 1.6 ns units |

Sidebands:

| Signal | Description |
| --- | --- |
| `aso_hit_type1_channel[3:0]` | Output stream channel. |
| `aso_hit_type1_startofpacket` | First accepted beat for an enabled channel in a run. |
| `aso_hit_type1_endofpacket` | Terminating boundary. |
| `aso_hit_type1_empty` | Asserted only for the dedicated terminate marker. |
| `aso_hit_type1_error` | Timestamp error sideband (`tserr`). |
| `aso_hit_type1_valid` | Output beat valid. |

### Compatibility Outputs

The extended Type1, timestamp-conduit, debug, and sidecar outputs are kept in
the port list for integration compatibility. The compact Phase I RTL drives
their data and valid signals low.

## CSR

### Local CSR Map

The packaged `csr` interface is word addressed.

| Word | Byte | Name | Access | Description |
| ---: | ---: | --- | --- | --- |
| `0x00` | `0x000` | `CONTROL_STATUS` | RW/RO | Mixed control and status word. |
| `0x01` | `0x004` | `DISCARD_HIT_CNT` | RO | Count of hits discarded by hit-error filtering or disallowed run state. |
| `0x02` | `0x008` | `EXPECTED_LATENCY` | RW | Expected MuTRiG buffering latency in 8 ns ticks. |
| `0x03` | `0x00C` | `TOTAL_HIT_CNT_HI` | RO | Upper 16 bits of the accepted-hit counter. Writable only when DV counter seeding is enabled. |
| `0x04` | `0x010` | `TOTAL_HIT_CNT_LO` | RO | Lower 32 bits of the accepted-hit counter. Writable only when DV counter seeding is enabled. |

`CONTROL_STATUS` fields:

| Bit(s) | Field | Access | Description |
| --- | --- | --- | --- |
| `[0]` | `go_or_running` | RW/RO | Write controls `go`; read mirrors whether the processor is currently `RUNNING`. |
| `[1]` | `force_stop` | RW | Manual stop gate on input acceptance. |
| `[2]` | `soft_reset` | RW | One-shot local reset request. |
| `[3]` | `bypass_lapse` | RW | Bypass MTS-to-GTS lapse correction. |
| `[4]` | `discard_hiterr` | RW | Drop `hit_type0` beats with the configured hit-error bit. Reset default is set. |
| `[5]` | `drop_delay_error` | RW | Drop `hit_type1` beats with timestamp-delay error. Reset default forwards them with error asserted. |
| `[6]` | `frame_aligned_arrival` | RW | Export frame-start GTS on the arrival conduit instead of per-hit arrival GTS. |
| `[29]` | `delay_ts_field_use_t` | RW | Use T timestamp for delay calculation when set; use E when clear. |
| `[30]` | `derive_tot` | RW | Enable long-hit E-T derivation. |
| others | reserved | - | Reserved or unused. |

### Mu3e CSR Adapter Map

`mu3e_mts_csr_adapter.vhd` exposes a 4-word bridge on the Mu3e register bus.
In `scifi_datapath.vhd`, the two MTS banks occupy a small local aperture in
the sorter SC branch: UP bank at offsets `0xF8..0xFB`, DOWN bank at
`0xFC..0xFF`.

| Word | Name | Access | Description |
| ---: | --- | --- | --- |
| `0x0` | `CONTROL_STATUS` | RW/RO | Write bit 0 starts one transaction, bit 1 selects write/read, bit 2 clears sticky done/overrun. Read bit 0 busy, bit 1 done, bit 2 overrun, bit 3 last command was write, bits `[10:8]` latched MTS CSR address. |
| `0x1` | `MTS_ADDRESS` | RW | MTS CSR address, bits `[2:0]`. |
| `0x2` | `WRITE_DATA` | RW | Write data for a bridged MTS CSR write. |
| `0x3` | `READ_DATA` | RO | Data returned by the last completed MTS CSR read. |
