# `REPORT/buckets/EDGE.md` — ordered-merge trace

> **Audience:** chief architect. This page is the per-bucket audit trail required by `~/.codex/skills/dv-workflow/SKILL.md` §Coverage rule 9. Every row below is one case, in the canonical case-id order declared in [`../../DV_EDGE.md`](../../DV_EDGE.md). Rows follow the skill's strict column contract. This file is generated — hand edits are overwritten.

- **bucket:** `EDGE` — [`../../DV_EDGE.md`](../../DV_EDGE.md)
- **range:** `E001` .. `E129` — **129 cases**
- **default method:** `d` (directed (1 txn / case))
- **execution mode:** `isolated`
- **status:** ⚠️ partial — promoted spot-check evidence exists for `E025`, `E026`, and `E027`, but UCDB save/merge is not yet wired into the promoted build. Coverage columns remain placeholders until `dv_report_gen.py` renders actual UCDB output. See [`../../DV_REPORT.md`](../../DV_REPORT.md) §Remaining work.

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
  case_id                = planned canonical id from DV_EDGE.md
  type (d/r)             = d = directed (1 deterministic txn), r = randomised (N txn)
  coverage_by_this_case  = ordered incremental code-coverage gain added by this case vs. the previously merged baseline for this bucket's ordered merge; explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`
  executed random txn    = observed txn count (r); `0` for d
  coverage_incr_per_txn  = per-transaction incremental gain, same vector layout (mirrors coverage_by_this_case for d)
-->

| status | case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |
|:---:|---|:---:|---|---:|---|
| ❓ | [E001](../cases/E001.md) | d | pending | 0 | pending |
| ❓ | [E002](../cases/E002.md) | d | pending | 0 | pending |
| ❓ | [E003](../cases/E003.md) | d | pending | 0 | pending |
| ❓ | [E004](../cases/E004.md) | d | pending | 0 | pending |
| ❓ | [E005](../cases/E005.md) | d | pending | 0 | pending |
| ❓ | [E006](../cases/E006.md) | d | pending | 0 | pending |
| ❓ | [E007](../cases/E007.md) | d | pending | 0 | pending |
| ❓ | [E008](../cases/E008.md) | d | pending | 0 | pending |
| ❓ | [E009](../cases/E009.md) | d | pending | 0 | pending |
| ❓ | [E010](../cases/E010.md) | d | pending | 0 | pending |
| ❓ | [E011](../cases/E011.md) | d | pending | 0 | pending |
| ❓ | [E012](../cases/E012.md) | d | pending | 0 | pending |
| ❓ | [E013](../cases/E013.md) | d | pending | 0 | pending |
| ❓ | [E014](../cases/E014.md) | d | pending | 0 | pending |
| ❓ | [E015](../cases/E015.md) | d | pending | 0 | pending |
| ❓ | [E016](../cases/E016.md) | d | pending | 0 | pending |
| ❓ | [E017](../cases/E017.md) | d | pending | 0 | pending |
| ❓ | [E018](../cases/E018.md) | d | pending | 0 | pending |
| ❓ | [E019](../cases/E019.md) | d | pending | 0 | pending |
| ❓ | [E020](../cases/E020.md) | d | pending | 0 | pending |
| ❓ | [E021](../cases/E021.md) | d | pending | 0 | pending |
| ❓ | [E022](../cases/E022.md) | d | pending | 0 | pending |
| ❓ | [E023](../cases/E023.md) | d | pending | 0 | pending |
| ❓ | [E024](../cases/E024.md) | d | pending | 0 | pending |
| ✅ | [E025](../cases/E025.md) | d | pending | 0 | pending |
| ✅ | [E026](../cases/E026.md) | d | pending | 0 | pending |
| ✅ | [E027](../cases/E027.md) | d | pending | 0 | pending |
| ❓ | [E028](../cases/E028.md) | d | pending | 0 | pending |
| ❓ | [E029](../cases/E029.md) | d | pending | 0 | pending |
| ❓ | [E030](../cases/E030.md) | d | pending | 0 | pending |
| ❓ | [E031](../cases/E031.md) | d | pending | 0 | pending |
| ❓ | [E032](../cases/E032.md) | d | pending | 0 | pending |
| ❓ | [E033](../cases/E033.md) | d | pending | 0 | pending |
| ❓ | [E034](../cases/E034.md) | d | pending | 0 | pending |
| ❓ | [E035](../cases/E035.md) | d | pending | 0 | pending |
| ❓ | [E036](../cases/E036.md) | d | pending | 0 | pending |
| ❓ | [E037](../cases/E037.md) | d | pending | 0 | pending |
| ❓ | [E038](../cases/E038.md) | d | pending | 0 | pending |
| ❓ | [E039](../cases/E039.md) | d | pending | 0 | pending |
| ❓ | [E040](../cases/E040.md) | d | pending | 0 | pending |
| ❓ | [E041](../cases/E041.md) | d | pending | 0 | pending |
| ❓ | [E042](../cases/E042.md) | d | pending | 0 | pending |
| ❓ | [E043](../cases/E043.md) | d | pending | 0 | pending |
| ❓ | [E044](../cases/E044.md) | d | pending | 0 | pending |
| ❓ | [E045](../cases/E045.md) | d | pending | 0 | pending |
| ❓ | [E046](../cases/E046.md) | d | pending | 0 | pending |
| ❓ | [E047](../cases/E047.md) | d | pending | 0 | pending |
| ❓ | [E048](../cases/E048.md) | d | pending | 0 | pending |
| ❓ | [E049](../cases/E049.md) | d | pending | 0 | pending |
| ❓ | [E050](../cases/E050.md) | d | pending | 0 | pending |
| ❓ | [E051](../cases/E051.md) | d | pending | 0 | pending |
| ❓ | [E052](../cases/E052.md) | d | pending | 0 | pending |
| ❓ | [E053](../cases/E053.md) | d | pending | 0 | pending |
| ❓ | [E054](../cases/E054.md) | d | pending | 0 | pending |
| ❓ | [E055](../cases/E055.md) | d | pending | 0 | pending |
| ❓ | [E056](../cases/E056.md) | d | pending | 0 | pending |
| ❓ | [E057](../cases/E057.md) | d | pending | 0 | pending |
| ❓ | [E058](../cases/E058.md) | d | pending | 0 | pending |
| ❓ | [E059](../cases/E059.md) | d | pending | 0 | pending |
| ❓ | [E060](../cases/E060.md) | d | pending | 0 | pending |
| ❓ | [E061](../cases/E061.md) | d | pending | 0 | pending |
| ❓ | [E062](../cases/E062.md) | d | pending | 0 | pending |
| ❓ | [E063](../cases/E063.md) | d | pending | 0 | pending |
| ❓ | [E064](../cases/E064.md) | d | pending | 0 | pending |
| ❓ | [E065](../cases/E065.md) | d | pending | 0 | pending |
| ❓ | [E066](../cases/E066.md) | d | pending | 0 | pending |
| ❓ | [E067](../cases/E067.md) | d | pending | 0 | pending |
| ❓ | [E068](../cases/E068.md) | d | pending | 0 | pending |
| ❓ | [E069](../cases/E069.md) | d | pending | 0 | pending |
| ❓ | [E070](../cases/E070.md) | d | pending | 0 | pending |
| ❓ | [E071](../cases/E071.md) | d | pending | 0 | pending |
| ❓ | [E072](../cases/E072.md) | d | pending | 0 | pending |
| ❓ | [E073](../cases/E073.md) | d | pending | 0 | pending |
| ❓ | [E074](../cases/E074.md) | d | pending | 0 | pending |
| ❓ | [E075](../cases/E075.md) | d | pending | 0 | pending |
| ❓ | [E076](../cases/E076.md) | d | pending | 0 | pending |
| ❓ | [E077](../cases/E077.md) | d | pending | 0 | pending |
| ❓ | [E078](../cases/E078.md) | d | pending | 0 | pending |
| ❓ | [E079](../cases/E079.md) | d | pending | 0 | pending |
| ❓ | [E080](../cases/E080.md) | d | pending | 0 | pending |
| ❓ | [E081](../cases/E081.md) | d | pending | 0 | pending |
| ❓ | [E082](../cases/E082.md) | d | pending | 0 | pending |
| ❓ | [E083](../cases/E083.md) | d | pending | 0 | pending |
| ❓ | [E084](../cases/E084.md) | d | pending | 0 | pending |
| ❓ | [E085](../cases/E085.md) | d | pending | 0 | pending |
| ❓ | [E086](../cases/E086.md) | d | pending | 0 | pending |
| ❓ | [E087](../cases/E087.md) | d | pending | 0 | pending |
| ❓ | [E088](../cases/E088.md) | d | pending | 0 | pending |
| ❓ | [E089](../cases/E089.md) | d | pending | 0 | pending |
| ❓ | [E090](../cases/E090.md) | d | pending | 0 | pending |
| ❓ | [E091](../cases/E091.md) | d | pending | 0 | pending |
| ❓ | [E092](../cases/E092.md) | d | pending | 0 | pending |
| ❓ | [E093](../cases/E093.md) | d | pending | 0 | pending |
| ❓ | [E094](../cases/E094.md) | d | pending | 0 | pending |
| ❓ | [E095](../cases/E095.md) | d | pending | 0 | pending |
| ❓ | [E096](../cases/E096.md) | d | pending | 0 | pending |
| ❓ | [E097](../cases/E097.md) | d | pending | 0 | pending |
| ❓ | [E098](../cases/E098.md) | d | pending | 0 | pending |
| ❓ | [E099](../cases/E099.md) | d | pending | 0 | pending |
| ❓ | [E100](../cases/E100.md) | d | pending | 0 | pending |
| ❓ | [E101](../cases/E101.md) | d | pending | 0 | pending |
| ❓ | [E102](../cases/E102.md) | d | pending | 0 | pending |
| ❓ | [E103](../cases/E103.md) | d | pending | 0 | pending |
| ❓ | [E104](../cases/E104.md) | d | pending | 0 | pending |
| ❓ | [E105](../cases/E105.md) | d | pending | 0 | pending |
| ❓ | [E106](../cases/E106.md) | d | pending | 0 | pending |
| ❓ | [E107](../cases/E107.md) | d | pending | 0 | pending |
| ❓ | [E108](../cases/E108.md) | d | pending | 0 | pending |
| ❓ | [E109](../cases/E109.md) | d | pending | 0 | pending |
| ❓ | [E110](../cases/E110.md) | d | pending | 0 | pending |
| ❓ | [E111](../cases/E111.md) | d | pending | 0 | pending |
| ❓ | [E112](../cases/E112.md) | d | pending | 0 | pending |
| ❓ | [E113](../cases/E113.md) | d | pending | 0 | pending |
| ❓ | [E114](../cases/E114.md) | d | pending | 0 | pending |
| ❓ | [E115](../cases/E115.md) | d | pending | 0 | pending |
| ❓ | [E116](../cases/E116.md) | d | pending | 0 | pending |
| ❓ | [E117](../cases/E117.md) | d | pending | 0 | pending |
| ❓ | [E118](../cases/E118.md) | d | pending | 0 | pending |
| ❓ | [E119](../cases/E119.md) | d | pending | 0 | pending |
| ❓ | [E120](../cases/E120.md) | d | pending | 0 | pending |
| ❓ | [E121](../cases/E121.md) | d | pending | 0 | pending |
| ❓ | [E122](../cases/E122.md) | d | pending | 0 | pending |
| ❓ | [E123](../cases/E123.md) | d | pending | 0 | pending |
| ❓ | [E124](../cases/E124.md) | d | pending | 0 | pending |
| ❓ | [E125](../cases/E125.md) | d | pending | 0 | pending |
| ❓ | [E126](../cases/E126.md) | d | pending | 0 | pending |
| ❓ | [E127](../cases/E127.md) | d | pending | 0 | pending |
| ❓ | [E128](../cases/E128.md) | d | pending | 0 | pending |
| ❓ | [E129](../cases/E129.md) | d | pending | 0 | pending |

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
| ❓ | E001 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E002 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E003 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E004 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E005 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E006 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E007 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E008 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E009 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E010 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E011 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E012 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E013 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E014 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E015 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E016 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E017 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E018 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E019 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E020 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E021 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E022 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E023 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E024 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | E025 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | E026 | pending | pending | pending | pending | pending | pending | pending |
| ✅ | E027 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E028 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E029 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E030 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E031 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E032 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E033 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E034 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E035 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E036 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E037 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E038 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E039 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E040 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E041 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E042 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E043 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E044 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E045 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E046 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E047 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E048 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E049 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E050 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E051 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E052 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E053 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E054 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E055 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E056 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E057 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E058 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E059 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E060 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E061 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E062 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E063 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E064 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E065 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E066 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E067 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E068 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E069 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E070 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E071 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E072 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E073 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E074 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E075 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E076 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E077 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E078 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E079 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E080 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E081 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E082 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E083 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E084 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E085 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E086 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E087 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E088 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E089 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E090 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E091 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E092 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E093 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E094 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E095 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E096 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E097 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E098 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E099 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E100 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E101 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E102 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E103 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E104 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E105 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E106 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E107 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E108 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E109 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E110 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E111 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E112 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E113 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E114 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E115 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E116 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E117 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E118 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E119 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E120 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E121 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E122 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E123 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E124 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E125 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E126 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E127 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E128 | pending | pending | pending | pending | pending | pending | pending |
| ❓ | E129 | pending | pending | pending | pending | pending | pending | pending |

## Bucket-level checks

- Row count above matches planned catalog size (`129`).
- Case-id ordering matches the canonical order in [`../../DV_EDGE.md`](../../DV_EDGE.md).
- `bucket_frame` continuous-frame baseline for this bucket: [`CROSS-002`](../cross/CROSS-002.md).
- Bug regression anchors touching this bucket: [`../../BUG_HISTORY.md`](../../BUG_HISTORY.md).
