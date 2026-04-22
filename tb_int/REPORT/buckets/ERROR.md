# `REPORT/buckets/ERROR.md` — ordered-merge trace

> **Audience:** chief architect. This page is the per-bucket audit trail required by `~/.codex/skills/dv-workflow/SKILL.md` §Coverage rule 9. Every row below is one case, in the canonical case-id order declared in [`../../DV_ERROR.md`](../../DV_ERROR.md). Rows follow the skill's strict column contract. This file is generated — hand edits are overwritten.

- **bucket:** `ERROR` — [`../../DV_ERROR.md`](../../DV_ERROR.md)
- **range:** `X001` .. `X129` — **129 cases**
- **default method:** `d` (directed (1 txn / case))
- **execution mode:** `isolated`
- **status:** ❓ pending — UCDB save/merge not yet wired into the promoted build; per-case rows are placeholders until `dv_report_gen.py` renders actual UCDB output. See [`../../DV_REPORT.md`](../../DV_REPORT.md) §Remaining work.

## Merged totals (this bucket)

<!-- columns:
  status      = bucket-level emoji per skill legend
  metric      = coverage category from skill §Coverage rule 6
  merged_pct  = union UCDB across all evidenced cases in this bucket
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

## Per-case rows (strict 5-column contract)

<!-- columns (strict, per skill §Coverage rule 3):
  status                 = case-level emoji per skill legend
  case_id                = planned canonical id from DV_ERROR.md
  type (d/r)             = d = directed (1 deterministic txn), r = randomised (N txn)
  coverage_by_this_case  = ordered incremental code-coverage gain added by this case vs. the previously merged baseline for this bucket's ordered merge; explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`
  executed random txn    = observed txn count (r); `0` for d
  coverage_incr_per_txn  = per-transaction incremental gain, same vector layout (mirrors coverage_by_this_case for d)
-->

| status | case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|:---:|---|:---:|---|---:|---|
| ❓ | [X001](../cases/X001.md) | d | pending | 0 | pending |
| ❓ | [X002](../cases/X002.md) | d | pending | 0 | pending |
| ❓ | [X003](../cases/X003.md) | d | pending | 0 | pending |
| ❓ | [X004](../cases/X004.md) | d | pending | 0 | pending |
| ❓ | [X005](../cases/X005.md) | d | pending | 0 | pending |
| ❓ | [X006](../cases/X006.md) | d | pending | 0 | pending |
| ❓ | [X007](../cases/X007.md) | d | pending | 0 | pending |
| ❓ | [X008](../cases/X008.md) | d | pending | 0 | pending |
| ❓ | [X009](../cases/X009.md) | d | pending | 0 | pending |
| ❓ | [X010](../cases/X010.md) | d | pending | 0 | pending |
| ❓ | [X011](../cases/X011.md) | d | pending | 0 | pending |
| ❓ | [X012](../cases/X012.md) | d | pending | 0 | pending |
| ❓ | [X013](../cases/X013.md) | d | pending | 0 | pending |
| ❓ | [X014](../cases/X014.md) | d | pending | 0 | pending |
| ❓ | [X015](../cases/X015.md) | d | pending | 0 | pending |
| ❓ | [X016](../cases/X016.md) | d | pending | 0 | pending |
| ❓ | [X017](../cases/X017.md) | d | pending | 0 | pending |
| ❓ | [X018](../cases/X018.md) | d | pending | 0 | pending |
| ❓ | [X019](../cases/X019.md) | d | pending | 0 | pending |
| ❓ | [X020](../cases/X020.md) | d | pending | 0 | pending |
| ❓ | [X021](../cases/X021.md) | d | pending | 0 | pending |
| ❓ | [X022](../cases/X022.md) | d | pending | 0 | pending |
| ❓ | [X023](../cases/X023.md) | d | pending | 0 | pending |
| ❓ | [X024](../cases/X024.md) | d | pending | 0 | pending |
| ❓ | [X025](../cases/X025.md) | d | pending | 0 | pending |
| ❓ | [X026](../cases/X026.md) | d | pending | 0 | pending |
| ❓ | [X027](../cases/X027.md) | d | pending | 0 | pending |
| ❓ | [X028](../cases/X028.md) | d | pending | 0 | pending |
| ❓ | [X029](../cases/X029.md) | d | pending | 0 | pending |
| ❓ | [X030](../cases/X030.md) | d | pending | 0 | pending |
| ❓ | [X031](../cases/X031.md) | d | pending | 0 | pending |
| ❓ | [X032](../cases/X032.md) | d | pending | 0 | pending |
| ❓ | [X033](../cases/X033.md) | d | pending | 0 | pending |
| ❓ | [X034](../cases/X034.md) | d | pending | 0 | pending |
| ❓ | [X035](../cases/X035.md) | d | pending | 0 | pending |
| ❓ | [X036](../cases/X036.md) | d | pending | 0 | pending |
| ❓ | [X037](../cases/X037.md) | d | pending | 0 | pending |
| ❓ | [X038](../cases/X038.md) | d | pending | 0 | pending |
| ❓ | [X039](../cases/X039.md) | d | pending | 0 | pending |
| ❓ | [X040](../cases/X040.md) | d | pending | 0 | pending |
| ❓ | [X041](../cases/X041.md) | d | pending | 0 | pending |
| ❓ | [X042](../cases/X042.md) | d | pending | 0 | pending |
| ❓ | [X043](../cases/X043.md) | d | pending | 0 | pending |
| ❓ | [X044](../cases/X044.md) | d | pending | 0 | pending |
| ❓ | [X045](../cases/X045.md) | d | pending | 0 | pending |
| ❓ | [X046](../cases/X046.md) | d | pending | 0 | pending |
| ❓ | [X047](../cases/X047.md) | d | pending | 0 | pending |
| ❓ | [X048](../cases/X048.md) | d | pending | 0 | pending |
| ❓ | [X049](../cases/X049.md) | d | pending | 0 | pending |
| ❓ | [X050](../cases/X050.md) | d | pending | 0 | pending |
| ❓ | [X051](../cases/X051.md) | d | pending | 0 | pending |
| ❓ | [X052](../cases/X052.md) | d | pending | 0 | pending |
| ❓ | [X053](../cases/X053.md) | d | pending | 0 | pending |
| ❓ | [X054](../cases/X054.md) | d | pending | 0 | pending |
| ❓ | [X055](../cases/X055.md) | d | pending | 0 | pending |
| ❓ | [X056](../cases/X056.md) | d | pending | 0 | pending |
| ❓ | [X057](../cases/X057.md) | d | pending | 0 | pending |
| ❓ | [X058](../cases/X058.md) | d | pending | 0 | pending |
| ❓ | [X059](../cases/X059.md) | d | pending | 0 | pending |
| ❓ | [X060](../cases/X060.md) | d | pending | 0 | pending |
| ❓ | [X061](../cases/X061.md) | d | pending | 0 | pending |
| ❓ | [X062](../cases/X062.md) | d | pending | 0 | pending |
| ❓ | [X063](../cases/X063.md) | d | pending | 0 | pending |
| ❓ | [X064](../cases/X064.md) | d | pending | 0 | pending |
| ❓ | [X065](../cases/X065.md) | d | pending | 0 | pending |
| ❓ | [X066](../cases/X066.md) | d | pending | 0 | pending |
| ❓ | [X067](../cases/X067.md) | d | pending | 0 | pending |
| ❓ | [X068](../cases/X068.md) | d | pending | 0 | pending |
| ❓ | [X069](../cases/X069.md) | d | pending | 0 | pending |
| ❓ | [X070](../cases/X070.md) | d | pending | 0 | pending |
| ❓ | [X071](../cases/X071.md) | d | pending | 0 | pending |
| ❓ | [X072](../cases/X072.md) | d | pending | 0 | pending |
| ❓ | [X073](../cases/X073.md) | d | pending | 0 | pending |
| ❓ | [X074](../cases/X074.md) | d | pending | 0 | pending |
| ❓ | [X075](../cases/X075.md) | d | pending | 0 | pending |
| ❓ | [X076](../cases/X076.md) | d | pending | 0 | pending |
| ❓ | [X077](../cases/X077.md) | d | pending | 0 | pending |
| ❓ | [X078](../cases/X078.md) | d | pending | 0 | pending |
| ❓ | [X079](../cases/X079.md) | d | pending | 0 | pending |
| ❓ | [X080](../cases/X080.md) | d | pending | 0 | pending |
| ❓ | [X081](../cases/X081.md) | d | pending | 0 | pending |
| ❓ | [X082](../cases/X082.md) | d | pending | 0 | pending |
| ❓ | [X083](../cases/X083.md) | d | pending | 0 | pending |
| ❓ | [X084](../cases/X084.md) | d | pending | 0 | pending |
| ❓ | [X085](../cases/X085.md) | d | pending | 0 | pending |
| ❓ | [X086](../cases/X086.md) | d | pending | 0 | pending |
| ❓ | [X087](../cases/X087.md) | d | pending | 0 | pending |
| ❓ | [X088](../cases/X088.md) | d | pending | 0 | pending |
| ❓ | [X089](../cases/X089.md) | d | pending | 0 | pending |
| ❓ | [X090](../cases/X090.md) | d | pending | 0 | pending |
| ❓ | [X091](../cases/X091.md) | d | pending | 0 | pending |
| ❓ | [X092](../cases/X092.md) | d | pending | 0 | pending |
| ❓ | [X093](../cases/X093.md) | d | pending | 0 | pending |
| ❓ | [X094](../cases/X094.md) | d | pending | 0 | pending |
| ❓ | [X095](../cases/X095.md) | d | pending | 0 | pending |
| ❓ | [X096](../cases/X096.md) | d | pending | 0 | pending |
| ❓ | [X097](../cases/X097.md) | d | pending | 0 | pending |
| ❓ | [X098](../cases/X098.md) | d | pending | 0 | pending |
| ❓ | [X099](../cases/X099.md) | d | pending | 0 | pending |
| ❓ | [X100](../cases/X100.md) | d | pending | 0 | pending |
| ❓ | [X101](../cases/X101.md) | d | pending | 0 | pending |
| ❓ | [X102](../cases/X102.md) | d | pending | 0 | pending |
| ❓ | [X103](../cases/X103.md) | d | pending | 0 | pending |
| ❓ | [X104](../cases/X104.md) | d | pending | 0 | pending |
| ❓ | [X105](../cases/X105.md) | d | pending | 0 | pending |
| ❓ | [X106](../cases/X106.md) | d | pending | 0 | pending |
| ❓ | [X107](../cases/X107.md) | d | pending | 0 | pending |
| ❓ | [X108](../cases/X108.md) | d | pending | 0 | pending |
| ❓ | [X109](../cases/X109.md) | d | pending | 0 | pending |
| ❓ | [X110](../cases/X110.md) | d | pending | 0 | pending |
| ❓ | [X111](../cases/X111.md) | d | pending | 0 | pending |
| ❓ | [X112](../cases/X112.md) | d | pending | 0 | pending |
| ❓ | [X113](../cases/X113.md) | d | pending | 0 | pending |
| ❓ | [X114](../cases/X114.md) | d | pending | 0 | pending |
| ❓ | [X115](../cases/X115.md) | d | pending | 0 | pending |
| ❓ | [X116](../cases/X116.md) | d | pending | 0 | pending |
| ❓ | [X117](../cases/X117.md) | d | pending | 0 | pending |
| ❓ | [X118](../cases/X118.md) | d | pending | 0 | pending |
| ❓ | [X119](../cases/X119.md) | d | pending | 0 | pending |
| ❓ | [X120](../cases/X120.md) | d | pending | 0 | pending |
| ❓ | [X121](../cases/X121.md) | d | pending | 0 | pending |
| ❓ | [X122](../cases/X122.md) | d | pending | 0 | pending |
| ❓ | [X123](../cases/X123.md) | d | pending | 0 | pending |
| ❓ | [X124](../cases/X124.md) | d | pending | 0 | pending |
| ❓ | [X125](../cases/X125.md) | d | pending | 0 | pending |
| ❓ | [X126](../cases/X126.md) | d | pending | 0 | pending |
| ❓ | [X127](../cases/X127.md) | d | pending | 0 | pending |
| ❓ | [X128](../cases/X128.md) | d | pending | 0 | pending |
| ❓ | [X129](../cases/X129.md) | d | pending | 0 | pending |

## Ordered merged-total trace (after each case added)

<!-- Per skill §Coverage rule 9, the ordered merged-total trace must follow the per-case rows so every per-case delta is auditable against the running bucket baseline.

columns:
  status            = bucket-running emoji after this case joined the merge
  after_case_id     = case that was most recently added to the ordered merge
  merged_stmt       = bucket merged statement %  after this case
  merged_branch     = bucket merged branch %     after this case
  merged_cond       = bucket merged condition %  after this case
  merged_expr       = bucket merged expression % after this case
  merged_fsm_state  = bucket merged FSM state %  after this case
  merged_fsm_trans  = bucket merged FSM trans %  after this case
  merged_toggle     = bucket merged toggle %     after this case
-->

| status | after_case_id | merged_stmt | merged_branch | merged_cond | merged_expr | merged_fsm_state | merged_fsm_trans | merged_toggle |
|:---:|---|---:|---:|---:|---:|---:|---:|---:|
| ❓ | X001 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X002 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X003 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X004 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X005 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X006 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X007 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X008 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X009 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X010 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X011 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X012 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X013 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X014 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X015 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X016 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X017 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X018 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X019 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X020 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X021 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X022 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X023 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X024 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X025 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X026 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X027 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X028 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X029 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X030 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X031 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X032 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X033 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X034 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X035 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X036 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X037 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X038 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X039 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X040 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X041 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X042 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X043 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X044 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X045 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X046 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X047 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X048 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X049 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X050 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X051 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X052 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X053 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X054 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X055 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X056 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X057 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X058 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X059 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X060 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X061 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X062 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X063 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X064 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X065 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X066 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X067 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X068 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X069 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X070 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X071 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X072 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X073 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X074 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X075 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X076 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X077 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X078 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X079 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X080 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X081 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X082 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X083 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X084 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X085 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X086 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X087 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X088 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X089 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X090 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X091 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X092 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X093 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X094 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X095 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X096 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X097 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X098 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X099 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X100 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X101 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X102 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X103 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X104 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X105 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X106 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X107 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X108 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X109 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X110 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X111 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X112 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X113 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X114 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X115 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X116 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X117 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X118 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X119 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X120 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X121 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X122 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X123 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X124 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X125 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X126 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X127 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X128 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | X129 | pending | pending | pending | pending | pending | pending | pending |

## Bucket-level checks

- Row count above matches planned catalog size (`129`).
- Case-id ordering matches the canonical order in [`../../DV_ERROR.md`](../../DV_ERROR.md).
- `bucket_frame` continuous-frame baseline for this bucket: [`CROSS-004`](../cross/CROSS-004.md).
- Bug regression anchors touching this bucket: [`../../BUG_HISTORY.md`](../../BUG_HISTORY.md).
