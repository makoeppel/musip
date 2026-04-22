# `REPORT/txn_growth/` — ⚠️ pending checkpoint UCDBs

> **Audience:** chief architect. This page is the explicit placeholder required by `~/.codex/skills/dv-workflow/SKILL.md` §Checkpoint UCDBs. Until the UVM side emits log-spaced checkpoint UCDBs for random long-runs, `dv_report_gen.py` emits this placeholder rather than fabricating curves.

- **status:** ⚠️ pending — the UVM emitter hook is not yet in place in `tb_int/cases/basic/uvm/sv/`. The skill-prescribed emitter shape is reproduced below so the hook can be dropped in without rearchitecting the harness.
- **scope:** every random / soak case under [`../../DV_PROF.md`](../../DV_PROF.md) whose `observed_txn > 1`.

## What this page will contain once the emitter is wired

One file per random / soak case, named `REPORT/txn_growth/<case_id>.md`. Each file will carry a real table:

<!-- columns (post-wiring):
  txn         = log-spaced transaction count at the snapshot: 1, 2, 4, 8, 16, 32, 64, ...
  stmt        = statement coverage at this snapshot
  branch      = branch coverage at this snapshot
  cond        = condition coverage at this snapshot
  expr        = expression coverage at this snapshot
  fsm_state   = FSM-state coverage at this snapshot
  fsm_trans   = FSM-transition coverage at this snapshot
  toggle      = toggle coverage at this snapshot
  ucdb_path   = path to the snapshot UCDB under `tb_int/cases/basic/uvm/cov_after/txn_growth/`
-->

| txn | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle | ucdb_path |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1      | pending | pending | pending | pending | pending | pending | pending | pending |
| 2      | pending | pending | pending | pending | pending | pending | pending | pending |
| 4      | pending | pending | pending | pending | pending | pending | pending | pending |
| 8      | pending | pending | pending | pending | pending | pending | pending | pending |
| 16     | pending | pending | pending | pending | pending | pending | pending | pending |
| 32     | pending | pending | pending | pending | pending | pending | pending | pending |
| 64     | pending | pending | pending | pending | pending | pending | pending | pending |
| 128    | pending | pending | pending | pending | pending | pending | pending | pending |
| ...    | ...     | ...     | ...     | ...     | ...     | ...     | ...     | ...     |

Each file will also carry a short analysis line identifying the saturation knee (the txn count at which the curve visibly flattens).

## Canonical UVM emitter pattern (skill §Checkpoint UCDBs)

```systemverilog
// in the test class, after each scoreboard-accepted transaction
local int unsigned next_checkpoint = 1;
local int unsigned txn_count       = 0;

task automatic on_txn_accepted();
  txn_count++;
  if (txn_count == next_checkpoint) begin
    string path = $sformatf("cov_after/txn_growth/%s_txn%0d_s%0d.ucdb",
                            get_type_name(), txn_count, seed);
    `uvm_info("COV", $sformatf("checkpoint UCDB -> %s", path), UVM_LOW)
    $system($sformatf("vcover save -onexit %s", path));
    next_checkpoint *= 2;
  end
endtask
```

- **cadence:** `1, 2, 4, 8, 16, …` — log-spaced by doubling.
- **naming:** `<case_id>_txn<N>_s<seed>.ucdb` under `tb_int/cases/basic/uvm/cov_after/txn_growth/`.
- **bound:** a 100 k-txn soak yields ~17 UCDBs, not 100 k.

## Aggregator contract

`dv_collect_evidence.py` (IP-local, typically under `tb_int/scripts/`) walks the snapshot dir, runs `vcover report` on each snapshot, and writes the series into [`../../DV_REPORT.json`](../../DV_REPORT.json) under `random_cases[i].txn_growth_curve` as a list of `{txn, coverage: {stmt, branch, cond, expr, fsm_state, fsm_trans, toggle}}` entries. `dv_report_gen.py` is strictly a renderer and does not invoke `vcover` itself.

## Candidate cases for first emission

<!-- columns:
  status   = per-case soak health emoji
  case_id  = random / soak case from DV_PROF.md
  target_N = planned final transaction count (from DV_PROF.md)
  note     = caveat or checkpoint-cadence observation, to be filled once the run lands
-->

| status | case_id | target_N | note |
|:---:|---|---:|---|
| ❓ | [P001](../cases/P001.md) | 128 | promoted 128-run screen (already passing; curve pending) |
| ❓ | [P002](../cases/P002.md) | 256 | historical 256-run rerun archive (already passing; curve pending) |
| ❓ | [P022](../cases/P022.md) | 8     | checkpoint UCDB soak anchor |
| ❓ | [P023](../cases/P023.md) | 16    | checkpoint UCDB soak anchor |
| ❓ | [P024](../cases/P024.md) | 32    | checkpoint UCDB soak anchor |
| ❓ | [P025](../cases/P025.md) | 128   | checkpoint UCDB soak anchor |
| ❓ | [P026](../cases/P026.md) | 1024  | checkpoint UCDB soak anchor |
| ❓ | [P027](../cases/P027.md) | 10000 | checkpoint UCDB soak anchor |
| ❓ | [P107](../cases/P107.md) | 10000 | longhaul soak |
| ❓ | [P108](../cases/P108.md) | 50000 | longhaul soak |
| ❓ | [P109](../cases/P109.md) | 100000 | longhaul soak |

## Links out

- [`../README.md`](../README.md) — reviewer entry
- [`../../DV_PROF.md`](../../DV_PROF.md) — planned random / soak catalog
- [`../../DV_REPORT.md`](../../DV_REPORT.md) — top-level dashboard
- [`../../DV_REPORT.json`](../../DV_REPORT.json) — machine-readable source (will carry `random_cases[].txn_growth_curve` once wired)
