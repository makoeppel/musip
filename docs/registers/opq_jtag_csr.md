# OPQ JTAG CSR make targets

This is the canonical runbook for the root-level OPQ CSR helpers that use the
Platform Designer JTAG Avalon master. Keep README files as short pointers to
this page instead of copying the command details into each README.

## Hardware path

- The musip-local OPQ Qsys wrapper lives under
  `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/`.
- The wrapper instantiates `csr_jtag_master` as an
  `altera_jtag_avalon_master` and connects `csr_jtag_master.master` to
  `opq_0.csr` at base address `0x0000`.
- `make ip-svd` regenerates the SVD at
  `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/opq_upstream_4lane.svd`.
- The root-level JTAG helpers call Intel System Console through
  `SYSTEM_CONSOLE`, which defaults to
  `/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console`.
- Live commands require hardware programmed with a bitstream that includes the
  current OPQ Qsys wrapper. Command logs are written under `build/ip/`.

## Target summary

| Target | Purpose |
|---|---|
| `make ip-svd` | regenerate the OPQ CSR SVD used by the JTAG helpers |
| `make ip-csr-lint` | check the upstream and musip-local OPQ packaging for the common UID/META CSR header contract |
| `make ip-opq-csr-probe` | check the compiled `.sopcinfo`, enumerate live System Console `master` services, claim the selected JTAG master when visible, and try a UID read |
| `make ip-opq-csr-dump` | regenerate the SVD, claim the selected JTAG master, and dump readable OPQ CSR registers with SVD field names |
| `make ip-opq-csr-write` | write one SVD-named CSR register, or one field through read-modify-write when `OPQ_CSR_FIELD` is set |
| `make ip-opq-csr-lane-mask` | write the full `LANE_MASK` CSR from `OPQ_LANE_MASK` |
| `make ip-opq-csr-mask-lane` | set one `LANE_MASK.MASK_LANE<n>` bit from `OPQ_LANE` |
| `make ip-opq-csr-unmask-lane` | clear one `LANE_MASK.MASK_LANE<n>` bit from `OPQ_LANE` |
| `make ip-opq-csr-monitor` | poll `STATUS.MASK_EFFECTIVE == 1` and log the samples |

## Common variables

| Variable | Used by | Meaning |
|---|---|---|
| `SYSTEM_CONSOLE=<path>` | all JTAG helpers | override the Intel System Console executable |
| `OPQ_CSR_MASTER=<pattern>` | all JTAG helpers | select a live System Console `master` service when more than one is visible |
| `OPQ_CSR_REGISTER=<name>` | `ip-opq-csr-write` | SVD register name to write; default is `LANE_MASK` |
| `OPQ_CSR_FIELD=<name>` | `ip-opq-csr-write` | optional SVD field name for read-modify-write |
| `OPQ_CSR_VALUE=<value>` | `ip-opq-csr-write` | register or field value to write |
| `OPQ_CSR_DRY_RUN=1` | write and lane-mask targets | parse the SVD and log the intended write without touching hardware |
| `OPQ_CSR_EXTRA='...'` | write and lane-mask targets | pass extra Tcl options such as `--force` or `--no-readback` |
| `OPQ_LANE=<n>` | lane bit targets | lane index for `ip-opq-csr-mask-lane` and `ip-opq-csr-unmask-lane` |
| `OPQ_LANE_MASK=<value>` | `ip-opq-csr-lane-mask` | complete value to write into `LANE_MASK` |

`OPQ_CSR_MASTER` is a case-insensitive substring pattern against the live
System Console service path. Without an override, the Tcl helper prefers service
paths containing `csr_jtag_master`, then `opq_upstream_4lane`, then
`jtag_master`; if only one `master` service is visible, it uses that service.

## Log files

The wrappers write clean text logs under `build/ip/`:

| Target | Log |
|---|---|
| `make ip-opq-csr-probe` | `build/ip/opq_jtag_probe.log` |
| `make ip-opq-csr-dump` | `build/ip/opq_jtag_dump.log` |
| `make ip-opq-csr-write` | `build/ip/opq_jtag_write.log` |
| `make ip-opq-csr-lane-mask` | `build/ip/opq_jtag_lane_mask.log` |
| `make ip-opq-csr-mask-lane OPQ_LANE=<n>` | `build/ip/opq_jtag_mask_lane<n>.log` |
| `make ip-opq-csr-unmask-lane OPQ_LANE=<n>` | `build/ip/opq_jtag_unmask_lane<n>.log` |
| `make ip-opq-csr-monitor` | `build/ip/opq_jtag_monitor.log` |

## Examples

Probe the compiled inventory and the live JTAG master service:

```bash
make ip-opq-csr-probe
```

Force a specific master service pattern when multiple masters are visible:

```bash
make ip-opq-csr-dump OPQ_CSR_MASTER='10AX115*csr_jtag_master'
```

Dry-run a full lane mask write:

```bash
make ip-opq-csr-lane-mask OPQ_LANE_MASK=0x3 OPQ_CSR_DRY_RUN=1
```

Mask and unmask one lane on live hardware:

```bash
make ip-opq-csr-mask-lane OPQ_LANE=2 OPQ_CSR_MASTER='10AX115*csr_jtag_master'
make ip-opq-csr-unmask-lane OPQ_LANE=2 OPQ_CSR_MASTER='10AX115*csr_jtag_master'
```

Write an arbitrary SVD register or field:

```bash
make ip-opq-csr-write OPQ_CSR_REGISTER=LANE_MASK OPQ_CSR_VALUE=0x5
make ip-opq-csr-write OPQ_CSR_REGISTER=LANE_MASK OPQ_CSR_FIELD=MASK_LANE1 OPQ_CSR_VALUE=1
```

Monitor the fixed mask-effective status trigger:

```bash
make ip-opq-csr-monitor OPQ_CSR_MASTER='10AX115*csr_jtag_master'
```
