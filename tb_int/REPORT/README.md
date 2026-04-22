# `tb_int/REPORT/` — reviewer entry point

This is the generated evidence tree for the `tb_int` MuSiP SWB/OPQ integration DV per `~/.codex/skills/dv-workflow/SKILL.md` §Report Layout. The top-level dashboards in [`../DV_REPORT.md`](../DV_REPORT.md) and [`../DV_COV.md`](../DV_COV.md) roll up to the chief architect. Everything per-case, per-bucket, per-cross, and per-random-soak lives here.

> **Audience:** chief architect reviewing musip DV sign-off. You should not need to open RTL, UVM sources, or the generator to interpret any column name on a page under this tree. Every table is preceded by an HTML column legend.

## Navigation

| entry | purpose |
|---|---|
| [`buckets/BASIC.md`](buckets/BASIC.md) | ordered-merge trace for directed standard-traffic cases (`B001..B129`) |
| [`buckets/EDGE.md`](buckets/EDGE.md)   | ordered-merge trace for boundary / corner cases (`E001..E129`) |
| [`buckets/PROF.md`](buckets/PROF.md)   | ordered-merge trace for random / profile / soak cases (`P001..P129`) |
| [`buckets/ERROR.md`](buckets/ERROR.md) | ordered-merge trace for fault / illegal / recovery cases (`X001..X129`) |
| [`cases/TEMPLATE.md`](cases/TEMPLATE.md) | canonical per-case evidence schema (one `<case_id>.md` per case) |
| [`cross/README.md`](cross/README.md)     | continuous-frame signoff runs (`CROSS-001..CROSS-129`) including `bucket_frame` and `all_buckets_frame` baselines |
| [`txn_growth/README.md`](txn_growth/README.md) | checkpoint-UCDB coverage curves for random long-runs (pending emitter) |

## Case catalog pointers

| bucket | planning file | range | catalog size |
|---|---|---|---:|
| BASIC | [`../DV_BASIC.md`](../DV_BASIC.md) | `B001..B129` | 129 |
| EDGE  | [`../DV_EDGE.md`](../DV_EDGE.md)   | `E001..E129` | 129 |
| PROF  | [`../DV_PROF.md`](../DV_PROF.md)   | `P001..P129` | 129 |
| ERROR | [`../DV_ERROR.md`](../DV_ERROR.md) | `X001..X129` | 129 |
| CROSS | [`../DV_CROSS.md`](../DV_CROSS.md) | `CROSS-001..CROSS-129` | 129 |

The canonical stimulus field map for every case is declared once in [`../DV_BASIC.md`](../DV_BASIC.md#stimulus-field-map-per-frame-per-lane) and is derived from [`feb_frame_assembly.vhd`](../../external/mu3e-ip-cores/feb_frame_assembly/feb_frame_assembly.vhd) plus Mu3eSpecBook §5.2.6.

## Status emoji legend

<!-- Fixed five-symbol palette from dv-workflow skill §Status Emoji Convention.
     One emoji per row, always leftmost. No new symbols may be invented. -->

| emoji | meaning |
|:---:|---|
| ✅ | passing / closed / at-or-above target |
| ⚠️  | partial / below target / known-limited |
| ❌ | failed / regression / missing required evidence |
| ❓ | pending / not-yet-available |
| ℹ️  | informational footnote |

## Current posture

<!-- columns:
  area     = dimension of the report tree
  state    = emoji snapshot
  note     = one-sentence evidence or gap summary
-->

| area | state | note |
|---|:---:|---|
| per-case pages under `cases/`           | ⚠️ | promoted spot-check evidence exists for 5 / 516 cases (`B046`, `E025`, `E026`, `E027`, `P040`); generator-backed full rendering still pending |
| per-bucket ordered-merge traces         | ⚠️ | skeleton rows remain for coverage, but promoted spot-check rows are now linked to real case pages |
| continuous-frame cross signoff (`cross/`) | ❓ | `CROSS-001..005` baselines mapped in [`../DV_REPORT.json`](../DV_REPORT.json), full `cross/<run_id>.md` rendering pending |
| random-soak txn_growth curves           | ❓ | UVM checkpoint emitter not yet wired (skill §Checkpoint UCDBs) — `txn_growth/README.md` carries the explicit placeholder |
| integration toolchain pass/fail gates   | ✅ | see [`../DV_REPORT.md`](../DV_REPORT.md#health) and [`../DV_REPORT.json`](../DV_REPORT.json) `summary` |
| bug ledger                              | ℹ️  | live at [`../BUG_HISTORY.md`](../BUG_HISTORY.md) (`BUG-001-H..BUG-010-R`) |

## Generator

This tree is produced by:

```bash
python3 ~/.codex/skills/dv-workflow/scripts/dv_report_gen.py --tb tb_int
```

- reads [`../DV_REPORT.json`](../DV_REPORT.json) as the single source of truth
- overwrites previously generated pages idempotently
- never touches `DV_*.md` plan files, RTL, or UVM source
- exits non-zero if the JSON is missing, malformed, or inconsistent with the planned bucket ranges

Hand edits under this tree are overwritten on the next run — fix the generator or the JSON, not the output.

## Links out

- [`../DV_REPORT.md`](../DV_REPORT.md) — top-level dashboard
- [`../DV_COV.md`](../DV_COV.md) — coverage dashboard and per-harness merged totals
- [`../DV_REPORT.json`](../DV_REPORT.json) — machine-readable source
- [`../BUG_HISTORY.md`](../BUG_HISTORY.md) — bug ledger
- [`../DV_INT_PLAN.md`](../DV_INT_PLAN.md) — locked DV plan and signoff boundary
- [`../DV_INT_HARNESS.md`](../DV_INT_HARNESS.md) — harness topology, monitors, plusargs
