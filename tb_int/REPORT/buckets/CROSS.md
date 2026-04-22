# `REPORT/buckets/CROSS.md` — ordered-merge trace

> **Audience:** chief architect. This page is the per-bucket audit trail required by `~/.codex/skills/dv-workflow/SKILL.md` §Coverage rule 9 for the continuous-frame bucket. Every row below is one cross run, in the canonical run-id order declared in [`../../DV_CROSS.md`](../../DV_CROSS.md). Rows follow the skill's strict column contract. This file is generated — hand edits are overwritten.

- **bucket:** `CROSS` — [`../../DV_CROSS.md`](../../DV_CROSS.md)
- **range:** `CROSS-001` .. `CROSS-129` — **129 runs**
- **default method:** mixed — `bucket_frame` / `all_buckets_frame` / `anchored_hybrid` / `seed_sweep` / `checkpoint_soak`; each row is a continuous-frame run, so `d` or `r` applies per run per the planning row
- **execution mode:** `bucket_frame` / `all_buckets_frame` (no DUT restart between cases)
- **status:** ❓ pending — no CROSS run has produced merged-UCDB evidence yet. Per-run detail pages live under [`../cross/`](../cross/) as placeholders. See [`../../DV_REPORT.md`](../../DV_REPORT.md) §Remaining work.

## Merged totals (this bucket)

<!-- columns:
  status      = bucket-level emoji per skill legend
  metric      = coverage category from skill §Coverage rule 6
  merged_pct  = union UCDB across all evidenced cross runs in this bucket
  target      = per-skill category target
-->

| status | metric | merged_pct | target |
|:---:|---|---:|---:|
| ❓ | stmt      | pending | 95.0 |
| ❓ | branch    | pending | 90.0 |
| ❓ | cond      | pending | 85.0 |
| ❓ | expr      | pending | 85.0 |
| ❓ | fsm_state | pending | 95.0 |
| ❓ | fsm_trans | pending | 90.0 |
| ❓ | toggle    | pending | 80.0 |
| ❓ | functional (bucket crosspoints) | pending | 100.0 bins saturated |

## Per-run rows (strict 5-column contract)

<!-- columns (strict, per skill §Coverage rule 3; run-id replaces case-id for the CROSS bucket):
  status                 = run-level emoji per skill legend
  run_id                 = planned canonical CROSS id from DV_CROSS.md
  type (d/r)             = d = directed continuous frame (1 txn per embedded case), r = randomised continuous frame (N txn per embedded case)
  coverage_by_this_case  = ordered incremental code-coverage gain added by this run vs. the previously merged baseline for the CROSS ordered merge; explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`
  executed random txn    = observed total txn count across the continuous frame (0 if purely directed)
  coverage_incr_per_txn  = per-transaction incremental gain, same vector layout (mirrors coverage_by_this_case for purely directed runs)
-->

| status | run_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|:---:|---|:---:|---|---:|---|
| ❓ | [CROSS-001](../cross/CROSS-001.md) | d | pending | 0 | pending |
| ❓ | [CROSS-002](../cross/CROSS-002.md) | d | pending | 0 | pending |
| ❓ | [CROSS-003](../cross/CROSS-003.md) | d | pending | 0 | pending |
| ❓ | [CROSS-004](../cross/CROSS-004.md) | d | pending | 0 | pending |
| ❓ | [CROSS-005](../cross/CROSS-005.md) | d | pending | 0 | pending |
| ❓ | [CROSS-006](../cross/CROSS-006.md) | d | pending | 0 | pending |
| ❓ | [CROSS-007](../cross/CROSS-007.md) | d | pending | 0 | pending |
| ❓ | [CROSS-008](../cross/CROSS-008.md) | d | pending | 0 | pending |
| ❓ | [CROSS-009](../cross/CROSS-009.md) | d | pending | 0 | pending |
| ❓ | [CROSS-010](../cross/CROSS-010.md) | d | pending | 0 | pending |
| ❓ | [CROSS-011](../cross/CROSS-011.md) | d | pending | 0 | pending |
| ❓ | [CROSS-012](../cross/CROSS-012.md) | d | pending | 0 | pending |
| ❓ | [CROSS-013](../cross/CROSS-013.md) | d | pending | 0 | pending |
| ❓ | [CROSS-014](../cross/CROSS-014.md) | d | pending | 0 | pending |
| ❓ | [CROSS-015](../cross/CROSS-015.md) | d | pending | 0 | pending |
| ❓ | [CROSS-016](../cross/CROSS-016.md) | d | pending | 0 | pending |
| ❓ | [CROSS-017](../cross/CROSS-017.md) | d | pending | 0 | pending |
| ❓ | [CROSS-018](../cross/CROSS-018.md) | d | pending | 0 | pending |
| ❓ | [CROSS-019](../cross/CROSS-019.md) | r | pending | pending | pending |
| ❓ | [CROSS-020](../cross/CROSS-020.md) | r | pending | pending | pending |
| ❓ | [CROSS-021](../cross/CROSS-021.md) | r | pending | pending | pending |
| ❓ | [CROSS-022](../cross/CROSS-022.md) | r | pending | pending | pending |
| ❓ | [CROSS-023](../cross/CROSS-023.md) | r | pending | pending | pending |
| ❓ | [CROSS-024](../cross/CROSS-024.md) | r | pending | pending | pending |
| ❓ | [CROSS-025](../cross/CROSS-025.md) | r | pending | pending | pending |
| ❓ | [CROSS-026](../cross/CROSS-026.md) | r | pending | pending | pending |
| ❓ | [CROSS-027](../cross/CROSS-027.md) | r | pending | pending | pending |
| ❓ | [CROSS-028](../cross/CROSS-028.md) | r | pending | pending | pending |
| ❓ | [CROSS-029](../cross/CROSS-029.md) | r | pending | pending | pending |
| ❓ | [CROSS-030](../cross/CROSS-030.md) | r | pending | pending | pending |
| ❓ | [CROSS-031](../cross/CROSS-031.md) | r | pending | pending | pending |
| ❓ | [CROSS-032](../cross/CROSS-032.md) | r | pending | pending | pending |
| ❓ | [CROSS-033](../cross/CROSS-033.md) | r | pending | pending | pending |
| ❓ | [CROSS-034](../cross/CROSS-034.md) | r | pending | pending | pending |
| ❓ | [CROSS-035](../cross/CROSS-035.md) | r | pending | pending | pending |
| ❓ | [CROSS-036](../cross/CROSS-036.md) | r | pending | pending | pending |
| ❓ | [CROSS-037](../cross/CROSS-037.md) | r | pending | pending | pending |
| ❓ | [CROSS-038](../cross/CROSS-038.md) | r | pending | pending | pending |
| ❓ | [CROSS-039](../cross/CROSS-039.md) | r | pending | pending | pending |
| ❓ | [CROSS-040](../cross/CROSS-040.md) | r | pending | pending | pending |
| ❓ | [CROSS-041](../cross/CROSS-041.md) | r | pending | pending | pending |
| ❓ | [CROSS-042](../cross/CROSS-042.md) | r | pending | pending | pending |
| ❓ | [CROSS-043](../cross/CROSS-043.md) | r | pending | pending | pending |
| ❓ | [CROSS-044](../cross/CROSS-044.md) | r | pending | pending | pending |
| ❓ | [CROSS-045](../cross/CROSS-045.md) | r | pending | pending | pending |
| ❓ | [CROSS-046](../cross/CROSS-046.md) | r | pending | pending | pending |
| ❓ | [CROSS-047](../cross/CROSS-047.md) | r | pending | pending | pending |
| ❓ | [CROSS-048](../cross/CROSS-048.md) | r | pending | pending | pending |
| ❓ | [CROSS-049](../cross/CROSS-049.md) | r | pending | pending | pending |
| ❓ | [CROSS-050](../cross/CROSS-050.md) | r | pending | pending | pending |
| ❓ | [CROSS-051](../cross/CROSS-051.md) | r | pending | pending | pending |
| ❓ | [CROSS-052](../cross/CROSS-052.md) | r | pending | pending | pending |
| ❓ | [CROSS-053](../cross/CROSS-053.md) | r | pending | pending | pending |
| ❓ | [CROSS-054](../cross/CROSS-054.md) | r | pending | pending | pending |
| ❓ | [CROSS-055](../cross/CROSS-055.md) | r | pending | pending | pending |
| ❓ | [CROSS-056](../cross/CROSS-056.md) | r | pending | pending | pending |
| ❓ | [CROSS-057](../cross/CROSS-057.md) | r | pending | pending | pending |
| ❓ | [CROSS-058](../cross/CROSS-058.md) | r | pending | pending | pending |
| ❓ | [CROSS-059](../cross/CROSS-059.md) | r | pending | pending | pending |
| ❓ | [CROSS-060](../cross/CROSS-060.md) | r | pending | pending | pending |
| ❓ | [CROSS-061](../cross/CROSS-061.md) | r | pending | pending | pending |
| ❓ | [CROSS-062](../cross/CROSS-062.md) | r | pending | pending | pending |
| ❓ | [CROSS-063](../cross/CROSS-063.md) | r | pending | pending | pending |
| ❓ | [CROSS-064](../cross/CROSS-064.md) | r | pending | pending | pending |
| ❓ | [CROSS-065](../cross/CROSS-065.md) | r | pending | pending | pending |
| ❓ | [CROSS-066](../cross/CROSS-066.md) | r | pending | pending | pending |
| ❓ | [CROSS-067](../cross/CROSS-067.md) | r | pending | pending | pending |
| ❓ | [CROSS-068](../cross/CROSS-068.md) | r | pending | pending | pending |
| ❓ | [CROSS-069](../cross/CROSS-069.md) | r | pending | pending | pending |
| ❓ | [CROSS-070](../cross/CROSS-070.md) | r | pending | pending | pending |
| ❓ | [CROSS-071](../cross/CROSS-071.md) | d | pending | 0 | pending |
| ❓ | [CROSS-072](../cross/CROSS-072.md) | d | pending | 0 | pending |
| ❓ | [CROSS-073](../cross/CROSS-073.md) | d | pending | 0 | pending |
| ❓ | [CROSS-074](../cross/CROSS-074.md) | d | pending | 0 | pending |
| ❓ | [CROSS-075](../cross/CROSS-075.md) | d | pending | 0 | pending |
| ❓ | [CROSS-076](../cross/CROSS-076.md) | d | pending | 0 | pending |
| ❓ | [CROSS-077](../cross/CROSS-077.md) | d | pending | 0 | pending |
| ❓ | [CROSS-078](../cross/CROSS-078.md) | d | pending | 0 | pending |
| ❓ | [CROSS-079](../cross/CROSS-079.md) | d | pending | 0 | pending |
| ❓ | [CROSS-080](../cross/CROSS-080.md) | d | pending | 0 | pending |
| ❓ | [CROSS-081](../cross/CROSS-081.md) | d | pending | 0 | pending |
| ❓ | [CROSS-082](../cross/CROSS-082.md) | d | pending | 0 | pending |
| ❓ | [CROSS-083](../cross/CROSS-083.md) | d | pending | 0 | pending |
| ❓ | [CROSS-084](../cross/CROSS-084.md) | d | pending | 0 | pending |
| ❓ | [CROSS-085](../cross/CROSS-085.md) | d | pending | 0 | pending |
| ❓ | [CROSS-086](../cross/CROSS-086.md) | r | pending | pending | pending |
| ❓ | [CROSS-087](../cross/CROSS-087.md) | r | pending | pending | pending |
| ❓ | [CROSS-088](../cross/CROSS-088.md) | r | pending | pending | pending |
| ❓ | [CROSS-089](../cross/CROSS-089.md) | r | pending | pending | pending |
| ❓ | [CROSS-090](../cross/CROSS-090.md) | r | pending | pending | pending |
| ❓ | [CROSS-091](../cross/CROSS-091.md) | r | pending | pending | pending |
| ❓ | [CROSS-092](../cross/CROSS-092.md) | r | pending | pending | pending |
| ❓ | [CROSS-093](../cross/CROSS-093.md) | r | pending | pending | pending |
| ❓ | [CROSS-094](../cross/CROSS-094.md) | r | pending | pending | pending |
| ❓ | [CROSS-095](../cross/CROSS-095.md) | r | pending | pending | pending |
| ❓ | [CROSS-096](../cross/CROSS-096.md) | r | pending | pending | pending |
| ❓ | [CROSS-097](../cross/CROSS-097.md) | r | pending | pending | pending |
| ❓ | [CROSS-098](../cross/CROSS-098.md) | r | pending | pending | pending |
| ❓ | [CROSS-099](../cross/CROSS-099.md) | r | pending | pending | pending |
| ❓ | [CROSS-100](../cross/CROSS-100.md) | r | pending | pending | pending |
| ❓ | [CROSS-101](../cross/CROSS-101.md) | r | pending | pending | pending |
| ❓ | [CROSS-102](../cross/CROSS-102.md) | r | pending | pending | pending |
| ❓ | [CROSS-103](../cross/CROSS-103.md) | r | pending | pending | pending |
| ❓ | [CROSS-104](../cross/CROSS-104.md) | r | pending | pending | pending |
| ❓ | [CROSS-105](../cross/CROSS-105.md) | r | pending | pending | pending |
| ❓ | [CROSS-106](../cross/CROSS-106.md) | r | pending | pending | pending |
| ❓ | [CROSS-107](../cross/CROSS-107.md) | r | pending | pending | pending |
| ❓ | [CROSS-108](../cross/CROSS-108.md) | r | pending | pending | pending |
| ❓ | [CROSS-109](../cross/CROSS-109.md) | r | pending | pending | pending |
| ❓ | [CROSS-110](../cross/CROSS-110.md) | r | pending | pending | pending |
| ❓ | [CROSS-111](../cross/CROSS-111.md) | r | pending | pending | pending |
| ❓ | [CROSS-112](../cross/CROSS-112.md) | r | pending | pending | pending |
| ❓ | [CROSS-113](../cross/CROSS-113.md) | r | pending | pending | pending |
| ❓ | [CROSS-114](../cross/CROSS-114.md) | r | pending | pending | pending |
| ❓ | [CROSS-115](../cross/CROSS-115.md) | r | pending | pending | pending |
| ❓ | [CROSS-116](../cross/CROSS-116.md) | r | pending | pending | pending |
| ❓ | [CROSS-117](../cross/CROSS-117.md) | r | pending | pending | pending |
| ❓ | [CROSS-118](../cross/CROSS-118.md) | r | pending | pending | pending |
| ❓ | [CROSS-119](../cross/CROSS-119.md) | r | pending | pending | pending |
| ❓ | [CROSS-120](../cross/CROSS-120.md) | r | pending | pending | pending |
| ❓ | [CROSS-121](../cross/CROSS-121.md) | r | pending | pending | pending |
| ❓ | [CROSS-122](../cross/CROSS-122.md) | r | pending | pending | pending |
| ❓ | [CROSS-123](../cross/CROSS-123.md) | r | pending | pending | pending |
| ❓ | [CROSS-124](../cross/CROSS-124.md) | r | pending | pending | pending |
| ❓ | [CROSS-125](../cross/CROSS-125.md) | r | pending | pending | pending |
| ❓ | [CROSS-126](../cross/CROSS-126.md) | r | pending | pending | pending |
| ❓ | [CROSS-127](../cross/CROSS-127.md) | r | pending | pending | pending |
| ❓ | [CROSS-128](../cross/CROSS-128.md) | r | pending | pending | pending |
| ❓ | [CROSS-129](../cross/CROSS-129.md) | r | pending | pending | pending |

## Ordered merged-total trace (after each run added)

<!-- Per skill §Coverage rule 9, the ordered merged-total trace must follow the per-run rows so every per-run delta is auditable against the running bucket baseline.

columns:
  status            = bucket-running emoji after this run joined the merge
  after_run_id      = cross run that was most recently added to the ordered merge
  merged_stmt       = bucket merged statement %  after this run
  merged_branch     = bucket merged branch %     after this run
  merged_cond       = bucket merged condition %  after this run
  merged_expr       = bucket merged expression % after this run
  merged_fsm_state  = bucket merged FSM state %  after this run
  merged_fsm_trans  = bucket merged FSM trans %  after this run
  merged_toggle     = bucket merged toggle %     after this run
-->

| status | after_run_id | merged_stmt | merged_branch | merged_cond | merged_expr | merged_fsm_state | merged_fsm_trans | merged_toggle |
|:---:|---|---:|---:|---:|---:|---:|---:|---:|
| ❓ | CROSS-001 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-002 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-003 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-004 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-005 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-006 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-007 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-008 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-009 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-010 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-011 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-012 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-013 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-014 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-015 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-016 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-017 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-018 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-019 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-020 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-021 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-022 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-023 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-024 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-025 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-026 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-027 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-028 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-029 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-030 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-031 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-032 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-033 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-034 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-035 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-036 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-037 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-038 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-039 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-040 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-041 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-042 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-043 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-044 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-045 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-046 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-047 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-048 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-049 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-050 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-051 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-052 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-053 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-054 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-055 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-056 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-057 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-058 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-059 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-060 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-061 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-062 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-063 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-064 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-065 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-066 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-067 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-068 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-069 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-070 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-071 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-072 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-073 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-074 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-075 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-076 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-077 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-078 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-079 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-080 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-081 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-082 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-083 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-084 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-085 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-086 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-087 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-088 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-089 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-090 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-091 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-092 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-093 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-094 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-095 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-096 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-097 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-098 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-099 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-100 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-101 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-102 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-103 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-104 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-105 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-106 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-107 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-108 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-109 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-110 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-111 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-112 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-113 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-114 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-115 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-116 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-117 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-118 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-119 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-120 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-121 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-122 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-123 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-124 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-125 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-126 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-127 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-128 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | CROSS-129 | pending | pending | pending | pending | pending | pending | pending |

## Bucket-level checks

- Row count above matches planned catalog size (`129`).
- Run-id ordering matches the canonical `§6.1..§6.9` cluster layout in [`../../DV_CROSS.md`](../../DV_CROSS.md).
- Mandatory `bucket_frame` baselines: `CROSS-001` (BASIC), `CROSS-002` (EDGE), `CROSS-003` (PROF), `CROSS-004` (ERROR). `all_buckets_frame` baseline: `CROSS-005`.
- Per-run detail pages (one per CROSS id): [`../cross/`](../cross/).
- Bug regression anchors touching this bucket: [`../../BUG_HISTORY.md`](../../BUG_HISTORY.md).
