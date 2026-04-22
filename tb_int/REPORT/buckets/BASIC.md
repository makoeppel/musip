# `REPORT/buckets/BASIC.md` — ordered-merge trace

> **Audience:** chief architect. This page is the per-bucket audit trail required by `~/.codex/skills/dv-workflow/SKILL.md` §Coverage rule 9. Every row below is one case, in the canonical case-id order declared in [`../../DV_BASIC.md`](../../DV_BASIC.md). Rows follow the skill's strict column contract. This file is generated — hand edits are overwritten.

- **bucket:** `BASIC` — [`../../DV_BASIC.md`](../../DV_BASIC.md)
- **range:** `B001` .. `B129` — **129 cases**
- **default method:** `d` (directed (1 txn / case))
- **execution mode:** `isolated`
- **status:** ⚠️ partial — promoted spot-check evidence exists for `B046`, but UCDB save/merge is not yet wired into the promoted build. Coverage columns remain placeholders until `dv_report_gen.py` renders actual UCDB output. See [`../../DV_REPORT.md`](../../DV_REPORT.md) §Remaining work.

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
  case_id                = planned canonical id from DV_BASIC.md
  type (d/r)             = d = directed (1 deterministic txn), r = randomised (N txn)
  coverage_by_this_case  = ordered incremental code-coverage gain added by this case vs. the previously merged baseline for this bucket's ordered merge; explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`
  executed random txn    = observed txn count (r); `0` for d
  coverage_incr_per_txn  = per-transaction incremental gain, same vector layout (mirrors coverage_by_this_case for d)
-->

| status | case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|:---:|---|:---:|---|---:|---|
| ❓ | [B001](../cases/B001.md) | d | pending | 0 | pending |
| ❓ | [B002](../cases/B002.md) | d | pending | 0 | pending |
| ❓ | [B003](../cases/B003.md) | d | pending | 0 | pending |
| ❓ | [B004](../cases/B004.md) | d | pending | 0 | pending |
| ❓ | [B005](../cases/B005.md) | d | pending | 0 | pending |
| ❓ | [B006](../cases/B006.md) | d | pending | 0 | pending |
| ❓ | [B007](../cases/B007.md) | d | pending | 0 | pending |
| ❓ | [B008](../cases/B008.md) | d | pending | 0 | pending |
| ❓ | [B009](../cases/B009.md) | d | pending | 0 | pending |
| ❓ | [B010](../cases/B010.md) | d | pending | 0 | pending |
| ❓ | [B011](../cases/B011.md) | d | pending | 0 | pending |
| ❓ | [B012](../cases/B012.md) | d | pending | 0 | pending |
| ❓ | [B013](../cases/B013.md) | d | pending | 0 | pending |
| ❓ | [B014](../cases/B014.md) | d | pending | 0 | pending |
| ❓ | [B015](../cases/B015.md) | d | pending | 0 | pending |
| ❓ | [B016](../cases/B016.md) | d | pending | 0 | pending |
| ❓ | [B017](../cases/B017.md) | d | pending | 0 | pending |
| ❓ | [B018](../cases/B018.md) | d | pending | 0 | pending |
| ❓ | [B019](../cases/B019.md) | d | pending | 0 | pending |
| ❓ | [B020](../cases/B020.md) | d | pending | 0 | pending |
| ❓ | [B021](../cases/B021.md) | d | pending | 0 | pending |
| ❓ | [B022](../cases/B022.md) | d | pending | 0 | pending |
| ❓ | [B023](../cases/B023.md) | d | pending | 0 | pending |
| ❓ | [B024](../cases/B024.md) | d | pending | 0 | pending |
| ❓ | [B025](../cases/B025.md) | d | pending | 0 | pending |
| ❓ | [B026](../cases/B026.md) | d | pending | 0 | pending |
| ❓ | [B027](../cases/B027.md) | d | pending | 0 | pending |
| ❓ | [B028](../cases/B028.md) | d | pending | 0 | pending |
| ❓ | [B029](../cases/B029.md) | d | pending | 0 | pending |
| ❓ | [B030](../cases/B030.md) | d | pending | 0 | pending |
| ❓ | [B031](../cases/B031.md) | d | pending | 0 | pending |
| ❓ | [B032](../cases/B032.md) | d | pending | 0 | pending |
| ❓ | [B033](../cases/B033.md) | d | pending | 0 | pending |
| ❓ | [B034](../cases/B034.md) | d | pending | 0 | pending |
| ❓ | [B035](../cases/B035.md) | d | pending | 0 | pending |
| ❓ | [B036](../cases/B036.md) | d | pending | 0 | pending |
| ❓ | [B037](../cases/B037.md) | d | pending | 0 | pending |
| ❓ | [B038](../cases/B038.md) | d | pending | 0 | pending |
| ❓ | [B039](../cases/B039.md) | d | pending | 0 | pending |
| ❓ | [B040](../cases/B040.md) | d | pending | 0 | pending |
| ❓ | [B041](../cases/B041.md) | d | pending | 0 | pending |
| ❓ | [B042](../cases/B042.md) | d | pending | 0 | pending |
| ❓ | [B043](../cases/B043.md) | d | pending | 0 | pending |
| ❓ | [B044](../cases/B044.md) | d | pending | 0 | pending |
| ❓ | [B045](../cases/B045.md) | d | pending | 0 | pending |
| ✅ | [B046](../cases/B046.md) | d | pending | 0 | pending |
| ❓ | [B047](../cases/B047.md) | d | pending | 0 | pending |
| ❓ | [B048](../cases/B048.md) | d | pending | 0 | pending |
| ❓ | [B049](../cases/B049.md) | d | pending | 0 | pending |
| ❓ | [B050](../cases/B050.md) | d | pending | 0 | pending |
| ❓ | [B051](../cases/B051.md) | d | pending | 0 | pending |
| ❓ | [B052](../cases/B052.md) | d | pending | 0 | pending |
| ❓ | [B053](../cases/B053.md) | d | pending | 0 | pending |
| ❓ | [B054](../cases/B054.md) | d | pending | 0 | pending |
| ❓ | [B055](../cases/B055.md) | d | pending | 0 | pending |
| ❓ | [B056](../cases/B056.md) | d | pending | 0 | pending |
| ❓ | [B057](../cases/B057.md) | d | pending | 0 | pending |
| ❓ | [B058](../cases/B058.md) | d | pending | 0 | pending |
| ❓ | [B059](../cases/B059.md) | d | pending | 0 | pending |
| ❓ | [B060](../cases/B060.md) | d | pending | 0 | pending |
| ❓ | [B061](../cases/B061.md) | d | pending | 0 | pending |
| ❓ | [B062](../cases/B062.md) | d | pending | 0 | pending |
| ❓ | [B063](../cases/B063.md) | d | pending | 0 | pending |
| ❓ | [B064](../cases/B064.md) | d | pending | 0 | pending |
| ❓ | [B065](../cases/B065.md) | d | pending | 0 | pending |
| ❓ | [B066](../cases/B066.md) | d | pending | 0 | pending |
| ❓ | [B067](../cases/B067.md) | d | pending | 0 | pending |
| ❓ | [B068](../cases/B068.md) | d | pending | 0 | pending |
| ❓ | [B069](../cases/B069.md) | d | pending | 0 | pending |
| ❓ | [B070](../cases/B070.md) | d | pending | 0 | pending |
| ❓ | [B071](../cases/B071.md) | d | pending | 0 | pending |
| ❓ | [B072](../cases/B072.md) | d | pending | 0 | pending |
| ❓ | [B073](../cases/B073.md) | d | pending | 0 | pending |
| ❓ | [B074](../cases/B074.md) | d | pending | 0 | pending |
| ❓ | [B075](../cases/B075.md) | d | pending | 0 | pending |
| ❓ | [B076](../cases/B076.md) | d | pending | 0 | pending |
| ❓ | [B077](../cases/B077.md) | d | pending | 0 | pending |
| ❓ | [B078](../cases/B078.md) | d | pending | 0 | pending |
| ❓ | [B079](../cases/B079.md) | d | pending | 0 | pending |
| ❓ | [B080](../cases/B080.md) | d | pending | 0 | pending |
| ❓ | [B081](../cases/B081.md) | d | pending | 0 | pending |
| ❓ | [B082](../cases/B082.md) | d | pending | 0 | pending |
| ❓ | [B083](../cases/B083.md) | d | pending | 0 | pending |
| ❓ | [B084](../cases/B084.md) | d | pending | 0 | pending |
| ❓ | [B085](../cases/B085.md) | d | pending | 0 | pending |
| ❓ | [B086](../cases/B086.md) | d | pending | 0 | pending |
| ❓ | [B087](../cases/B087.md) | d | pending | 0 | pending |
| ❓ | [B088](../cases/B088.md) | d | pending | 0 | pending |
| ❓ | [B089](../cases/B089.md) | d | pending | 0 | pending |
| ❓ | [B090](../cases/B090.md) | d | pending | 0 | pending |
| ❓ | [B091](../cases/B091.md) | d | pending | 0 | pending |
| ❓ | [B092](../cases/B092.md) | d | pending | 0 | pending |
| ❓ | [B093](../cases/B093.md) | d | pending | 0 | pending |
| ❓ | [B094](../cases/B094.md) | d | pending | 0 | pending |
| ❓ | [B095](../cases/B095.md) | d | pending | 0 | pending |
| ❓ | [B096](../cases/B096.md) | d | pending | 0 | pending |
| ❓ | [B097](../cases/B097.md) | d | pending | 0 | pending |
| ❓ | [B098](../cases/B098.md) | d | pending | 0 | pending |
| ❓ | [B099](../cases/B099.md) | d | pending | 0 | pending |
| ❓ | [B100](../cases/B100.md) | d | pending | 0 | pending |
| ❓ | [B101](../cases/B101.md) | d | pending | 0 | pending |
| ❓ | [B102](../cases/B102.md) | d | pending | 0 | pending |
| ❓ | [B103](../cases/B103.md) | d | pending | 0 | pending |
| ❓ | [B104](../cases/B104.md) | d | pending | 0 | pending |
| ❓ | [B105](../cases/B105.md) | d | pending | 0 | pending |
| ❓ | [B106](../cases/B106.md) | d | pending | 0 | pending |
| ❓ | [B107](../cases/B107.md) | d | pending | 0 | pending |
| ❓ | [B108](../cases/B108.md) | d | pending | 0 | pending |
| ❓ | [B109](../cases/B109.md) | d | pending | 0 | pending |
| ❓ | [B110](../cases/B110.md) | d | pending | 0 | pending |
| ❓ | [B111](../cases/B111.md) | d | pending | 0 | pending |
| ❓ | [B112](../cases/B112.md) | d | pending | 0 | pending |
| ❓ | [B113](../cases/B113.md) | d | pending | 0 | pending |
| ❓ | [B114](../cases/B114.md) | d | pending | 0 | pending |
| ❓ | [B115](../cases/B115.md) | d | pending | 0 | pending |
| ❓ | [B116](../cases/B116.md) | d | pending | 0 | pending |
| ❓ | [B117](../cases/B117.md) | d | pending | 0 | pending |
| ❓ | [B118](../cases/B118.md) | d | pending | 0 | pending |
| ❓ | [B119](../cases/B119.md) | d | pending | 0 | pending |
| ❓ | [B120](../cases/B120.md) | d | pending | 0 | pending |
| ❓ | [B121](../cases/B121.md) | d | pending | 0 | pending |
| ❓ | [B122](../cases/B122.md) | d | pending | 0 | pending |
| ❓ | [B123](../cases/B123.md) | d | pending | 0 | pending |
| ❓ | [B124](../cases/B124.md) | d | pending | 0 | pending |
| ❓ | [B125](../cases/B125.md) | d | pending | 0 | pending |
| ❓ | [B126](../cases/B126.md) | d | pending | 0 | pending |
| ❓ | [B127](../cases/B127.md) | d | pending | 0 | pending |
| ❓ | [B128](../cases/B128.md) | d | pending | 0 | pending |
| ❓ | [B129](../cases/B129.md) | d | pending | 0 | pending |

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
| ❓ | B001 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B002 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B003 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B004 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B005 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B006 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B007 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B008 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B009 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B010 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B011 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B012 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B013 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B014 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B015 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B016 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B017 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B018 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B019 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B020 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B021 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B022 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B023 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B024 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B025 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B026 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B027 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B028 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B029 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B030 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B031 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B032 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B033 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B034 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B035 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B036 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B037 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B038 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B039 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B040 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B041 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B042 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B043 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B044 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B045 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | B046 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B047 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B048 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B049 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B050 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B051 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B052 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B053 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B054 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B055 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B056 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B057 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B058 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B059 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B060 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B061 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B062 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B063 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B064 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B065 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B066 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B067 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B068 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B069 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B070 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B071 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B072 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B073 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B074 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B075 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B076 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B077 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B078 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B079 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B080 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B081 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B082 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B083 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B084 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B085 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B086 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B087 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B088 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B089 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B090 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B091 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B092 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B093 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B094 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B095 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B096 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B097 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B098 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B099 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B100 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B101 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B102 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B103 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B104 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B105 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B106 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B107 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B108 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B109 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B110 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B111 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B112 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B113 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B114 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B115 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B116 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B117 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B118 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B119 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B120 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B121 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B122 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B123 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B124 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B125 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B126 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B127 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B128 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | B129 | pending | pending | pending | pending | pending | pending | pending |

## Bucket-level checks

- Row count above matches planned catalog size (`129`).
- Case-id ordering matches the canonical order in [`../../DV_BASIC.md`](../../DV_BASIC.md).
- `bucket_frame` continuous-frame baseline for this bucket: [`CROSS-001`](../cross/CROSS-001.md).
- Bug regression anchors touching this bucket: [`../../BUG_HISTORY.md`](../../BUG_HISTORY.md).
