# `REPORT/buckets/PROF.md` — ordered-merge trace

> **Audience:** chief architect. This page is the per-bucket audit trail required by `~/.codex/skills/dv-workflow/SKILL.md` §Coverage rule 9. Every row below is one case, in the canonical case-id order declared in [`../../DV_PROF.md`](../../DV_PROF.md). Rows follow the skill's strict column contract. This file is generated — hand edits are overwritten.

- **bucket:** `PROF` — [`../../DV_PROF.md`](../../DV_PROF.md)
- **range:** `P001` .. `P129` — **129 cases**
- **default method:** `d` (directed (1 txn / case))
- **execution mode:** `isolated`
- **status:** ⚠️ partial — promoted isolated evidence exists for `6` of `129` cases; coverage columns remain placeholders until ordered UCDB save/merge is promoted

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
  case_id                = planned canonical id from DV_PROF.md
  type (d/r)             = d = directed (1 deterministic txn), r = randomised (N txn)
  coverage_by_this_case  = ordered incremental code-coverage gain added by this case vs. the previously merged baseline for this bucket's ordered merge; explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`
  executed random txn    = observed txn count (r); `0` for d
  coverage_incr_per_txn  = per-transaction incremental gain, same vector layout (mirrors coverage_by_this_case for d)
-->

| status | case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|:---:|---|:---:|---|---:|---|
| ✅ | [P001](../cases/P001.md) | d | pending | 0 | pending |
| ✅ | [P002](../cases/P002.md) | d | pending | 0 | pending |
| ❓ | [P003](../cases/P003.md) | r | pending | pending | pending |
| ❓ | [P004](../cases/P004.md) | r | pending | pending | pending |
| ❓ | [P005](../cases/P005.md) | r | pending | pending | pending |
| ❓ | [P006](../cases/P006.md) | r | pending | pending | pending |
| ❓ | [P007](../cases/P007.md) | r | pending | pending | pending |
| ❓ | [P008](../cases/P008.md) | r | pending | pending | pending |
| ❓ | [P009](../cases/P009.md) | r | pending | pending | pending |
| ❓ | [P010](../cases/P010.md) | r | pending | pending | pending |
| ❓ | [P011](../cases/P011.md) | r | pending | pending | pending |
| ❓ | [P012](../cases/P012.md) | r | pending | pending | pending |
| ❓ | [P013](../cases/P013.md) | r | pending | pending | pending |
| ❓ | [P014](../cases/P014.md) | r | pending | pending | pending |
| ❓ | [P015](../cases/P015.md) | r | pending | pending | pending |
| ❓ | [P016](../cases/P016.md) | r | pending | pending | pending |
| ❓ | [P017](../cases/P017.md) | r | pending | pending | pending |
| ❓ | [P018](../cases/P018.md) | r | pending | pending | pending |
| ❓ | [P019](../cases/P019.md) | r | pending | pending | pending |
| ❓ | [P020](../cases/P020.md) | r | pending | pending | pending |
| ❓ | [P021](../cases/P021.md) | r | pending | pending | pending |
| ❓ | [P022](../cases/P022.md) | r | pending | pending | pending |
| ❓ | [P023](../cases/P023.md) | r | pending | pending | pending |
| ❓ | [P024](../cases/P024.md) | r | pending | pending | pending |
| ❓ | [P025](../cases/P025.md) | r | pending | pending | pending |
| ❓ | [P026](../cases/P026.md) | r | pending | pending | pending |
| ❓ | [P027](../cases/P027.md) | r | pending | pending | pending |
| ❓ | [P028](../cases/P028.md) | r | pending | pending | pending |
| ❓ | [P029](../cases/P029.md) | r | pending | pending | pending |
| ❓ | [P030](../cases/P030.md) | r | pending | pending | pending |
| ❓ | [P031](../cases/P031.md) | r | pending | pending | pending |
| ❓ | [P032](../cases/P032.md) | r | pending | pending | pending |
| ❓ | [P033](../cases/P033.md) | r | pending | pending | pending |
| ❓ | [P034](../cases/P034.md) | r | pending | pending | pending |
| ❓ | [P035](../cases/P035.md) | r | pending | pending | pending |
| ❓ | [P036](../cases/P036.md) | r | pending | pending | pending |
| ❓ | [P037](../cases/P037.md) | r | pending | pending | pending |
| ❓ | [P038](../cases/P038.md) | r | pending | pending | pending |
| ❓ | [P039](../cases/P039.md) | r | pending | pending | pending |
| ✅ | [P040](../cases/P040.md) | r | pending | 1 | pending |
| ✅ | [P041](../cases/P041.md) | r | pending | 1 | pending |
| ❓ | [P042](../cases/P042.md) | r | pending | pending | pending |
| ❓ | [P043](../cases/P043.md) | r | pending | pending | pending |
| ❓ | [P044](../cases/P044.md) | r | pending | pending | pending |
| ❓ | [P045](../cases/P045.md) | r | pending | pending | pending |
| ❓ | [P046](../cases/P046.md) | r | pending | pending | pending |
| ❓ | [P047](../cases/P047.md) | r | pending | pending | pending |
| ❓ | [P048](../cases/P048.md) | r | pending | pending | pending |
| ❓ | [P049](../cases/P049.md) | r | pending | pending | pending |
| ❓ | [P050](../cases/P050.md) | r | pending | pending | pending |
| ❓ | [P051](../cases/P051.md) | r | pending | pending | pending |
| ❓ | [P052](../cases/P052.md) | r | pending | pending | pending |
| ❓ | [P053](../cases/P053.md) | r | pending | pending | pending |
| ❓ | [P054](../cases/P054.md) | r | pending | pending | pending |
| ❓ | [P055](../cases/P055.md) | r | pending | pending | pending |
| ❓ | [P056](../cases/P056.md) | r | pending | pending | pending |
| ❓ | [P057](../cases/P057.md) | r | pending | pending | pending |
| ❓ | [P058](../cases/P058.md) | r | pending | pending | pending |
| ❓ | [P059](../cases/P059.md) | r | pending | pending | pending |
| ❓ | [P060](../cases/P060.md) | r | pending | pending | pending |
| ❓ | [P061](../cases/P061.md) | r | pending | pending | pending |
| ❓ | [P062](../cases/P062.md) | r | pending | pending | pending |
| ❓ | [P063](../cases/P063.md) | r | pending | pending | pending |
| ❓ | [P064](../cases/P064.md) | r | pending | pending | pending |
| ❓ | [P065](../cases/P065.md) | r | pending | pending | pending |
| ❓ | [P066](../cases/P066.md) | r | pending | pending | pending |
| ❓ | [P067](../cases/P067.md) | r | pending | pending | pending |
| ❓ | [P068](../cases/P068.md) | r | pending | pending | pending |
| ❓ | [P069](../cases/P069.md) | r | pending | pending | pending |
| ❓ | [P070](../cases/P070.md) | r | pending | pending | pending |
| ❓ | [P071](../cases/P071.md) | r | pending | pending | pending |
| ❓ | [P072](../cases/P072.md) | r | pending | pending | pending |
| ❓ | [P073](../cases/P073.md) | r | pending | pending | pending |
| ❓ | [P074](../cases/P074.md) | r | pending | pending | pending |
| ❓ | [P075](../cases/P075.md) | r | pending | pending | pending |
| ❓ | [P076](../cases/P076.md) | r | pending | pending | pending |
| ❓ | [P077](../cases/P077.md) | r | pending | pending | pending |
| ❓ | [P078](../cases/P078.md) | r | pending | pending | pending |
| ❓ | [P079](../cases/P079.md) | r | pending | pending | pending |
| ❓ | [P080](../cases/P080.md) | r | pending | pending | pending |
| ❓ | [P081](../cases/P081.md) | r | pending | pending | pending |
| ❓ | [P082](../cases/P082.md) | r | pending | pending | pending |
| ❓ | [P083](../cases/P083.md) | r | pending | pending | pending |
| ❓ | [P084](../cases/P084.md) | r | pending | pending | pending |
| ❓ | [P085](../cases/P085.md) | r | pending | pending | pending |
| ❓ | [P086](../cases/P086.md) | r | pending | pending | pending |
| ❓ | [P087](../cases/P087.md) | r | pending | pending | pending |
| ❓ | [P088](../cases/P088.md) | r | pending | pending | pending |
| ❓ | [P089](../cases/P089.md) | r | pending | pending | pending |
| ❓ | [P090](../cases/P090.md) | r | pending | pending | pending |
| ❓ | [P091](../cases/P091.md) | r | pending | pending | pending |
| ❓ | [P092](../cases/P092.md) | r | pending | pending | pending |
| ❓ | [P093](../cases/P093.md) | r | pending | pending | pending |
| ❓ | [P094](../cases/P094.md) | r | pending | pending | pending |
| ❓ | [P095](../cases/P095.md) | r | pending | pending | pending |
| ❓ | [P096](../cases/P096.md) | r | pending | pending | pending |
| ❓ | [P097](../cases/P097.md) | r | pending | pending | pending |
| ❓ | [P098](../cases/P098.md) | r | pending | pending | pending |
| ❓ | [P099](../cases/P099.md) | r | pending | pending | pending |
| ❓ | [P100](../cases/P100.md) | r | pending | pending | pending |
| ❓ | [P101](../cases/P101.md) | r | pending | pending | pending |
| ❓ | [P102](../cases/P102.md) | r | pending | pending | pending |
| ❓ | [P103](../cases/P103.md) | r | pending | pending | pending |
| ❓ | [P104](../cases/P104.md) | r | pending | pending | pending |
| ❓ | [P105](../cases/P105.md) | r | pending | pending | pending |
| ❓ | [P106](../cases/P106.md) | r | pending | pending | pending |
| ❓ | [P107](../cases/P107.md) | r | pending | pending | pending |
| ❓ | [P108](../cases/P108.md) | r | pending | pending | pending |
| ❓ | [P109](../cases/P109.md) | r | pending | pending | pending |
| ❓ | [P110](../cases/P110.md) | r | pending | pending | pending |
| ❓ | [P111](../cases/P111.md) | r | pending | pending | pending |
| ❓ | [P112](../cases/P112.md) | r | pending | pending | pending |
| ❓ | [P113](../cases/P113.md) | r | pending | pending | pending |
| ❓ | [P114](../cases/P114.md) | r | pending | pending | pending |
| ❓ | [P115](../cases/P115.md) | r | pending | pending | pending |
| ❓ | [P116](../cases/P116.md) | r | pending | pending | pending |
| ❓ | [P117](../cases/P117.md) | r | pending | pending | pending |
| ❓ | [P118](../cases/P118.md) | r | pending | pending | pending |
| ❓ | [P119](../cases/P119.md) | r | pending | pending | pending |
| ❓ | [P120](../cases/P120.md) | r | pending | pending | pending |
| ❓ | [P121](../cases/P121.md) | r | pending | pending | pending |
| ❓ | [P122](../cases/P122.md) | r | pending | pending | pending |
| ✅ | [P123](../cases/P123.md) | r | pending | 16 | pending |
| ✅ | [P124](../cases/P124.md) | r | pending | 16 | pending |
| ❓ | [P125](../cases/P125.md) | r | pending | pending | pending |
| ❓ | [P126](../cases/P126.md) | r | pending | pending | pending |
| ❓ | [P127](../cases/P127.md) | r | pending | pending | pending |
| ❓ | [P128](../cases/P128.md) | r | pending | pending | pending |
| ❓ | [P129](../cases/P129.md) | r | pending | pending | pending |

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
| ✅ | P001 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | P002 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P003 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P004 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P005 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P006 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P007 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P008 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P009 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P010 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P011 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P012 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P013 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P014 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P015 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P016 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P017 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P018 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P019 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P020 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P021 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P022 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P023 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P024 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P025 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P026 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P027 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P028 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P029 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P030 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P031 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P032 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P033 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P034 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P035 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P036 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P037 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P038 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P039 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | P040 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | P041 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P042 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P043 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P044 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P045 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P046 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P047 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P048 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P049 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P050 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P051 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P052 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P053 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P054 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P055 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P056 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P057 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P058 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P059 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P060 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P061 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P062 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P063 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P064 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P065 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P066 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P067 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P068 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P069 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P070 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P071 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P072 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P073 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P074 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P075 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P076 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P077 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P078 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P079 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P080 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P081 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P082 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P083 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P084 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P085 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P086 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P087 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P088 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P089 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P090 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P091 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P092 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P093 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P094 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P095 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P096 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P097 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P098 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P099 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P100 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P101 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P102 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P103 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P104 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P105 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P106 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P107 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P108 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P109 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P110 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P111 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P112 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P113 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P114 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P115 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P116 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P117 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P118 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P119 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P120 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P121 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P122 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | P123 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | P124 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P125 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P126 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P127 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P128 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | P129 | pending | pending | pending | pending | pending | pending | pending |
