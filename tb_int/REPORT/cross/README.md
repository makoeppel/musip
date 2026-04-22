# `REPORT/cross/` — continuous-frame signoff runs

> **Audience:** chief architect. This page indexes every `bucket_frame`, `all_buckets_frame`, and long-run cross signoff baseline named in [`../../DV_CROSS.md`](../../DV_CROSS.md). One file per run under `cross/<run_id>.md` carries its code coverage, functional cross %, per-txn growth curve, and counter-check summary per skill §Report Layout rule 5.

- **range:** `CROSS-001` .. `CROSS-129` — **129 runs**
- **status:** ❓ pending — per-run detail pages are now emitted as explicit placeholders, but UCDB save/merge is still not wired into the promoted build. Promoted signoff runs that have already passed the integration gate are linked in [`../../DV_REPORT.md`](../../DV_REPORT.md) §Validation matrix and in [`../../DV_REPORT.json`](../../DV_REPORT.json) `cross_baselines[]`.

## Mandatory baselines (skill §Plan-Writing Rules rule 8)

<!-- columns:
  status       = run-level emoji per skill legend
  run_id       = canonical CROSS id
  mode         = execution mode: bucket_frame, all_buckets_frame, anchored_hybrid, seed_sweep, checkpoint_soak
  bucket/scope = buckets exercised; case-id order within each
  case_count   = number of cases executed in the continuous frame
  evidence     = pointer to the per-run evidence page once emitted
-->

| status | run_id | mode | bucket / scope | case_count | evidence |
|:---:|---|---|---|---:|---|
| ❓ | [CROSS-001](CROSS-001.md) | bucket_frame      | BASIC (`B001..B129`) | 129 | pending |
| ❓ | [CROSS-002](CROSS-002.md) | bucket_frame      | EDGE  (`E001..E129`) | 129 | pending |
| ❓ | [CROSS-003](CROSS-003.md) | bucket_frame      | PROF  (`P001..P129`) | 129 | pending |
| ❓ | [CROSS-004](CROSS-004.md) | bucket_frame      | ERROR (`X001..X129`) | 129 | pending |
| ❓ | [CROSS-005](CROSS-005.md) | all_buckets_frame | BASIC → EDGE → PROF → ERROR (`516` cases total) | 516 | pending |

## Full run ladder (CROSS-001 .. CROSS-129)

<!-- columns:
  status       = per-run health emoji
  run_id       = canonical CROSS id
  cluster      = DV_CROSS.md §6 cluster: bucket baselines, GOOD-ERROR-GOOD hybrids, arbitration/skew, interleaving, seed sweep, bug-seeded soak, variant builds, coverage closure, checkpoint UCDB soak
  notes        = free-form pointer back to DV_CROSS.md row
-->

| status | run_id | cluster | notes |
|:---:|---|---|---|
| ❓ | [CROSS-001](CROSS-001.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-002](CROSS-002.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-003](CROSS-003.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-004](CROSS-004.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-005](CROSS-005.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-006](CROSS-006.md) | bucket_baselines | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-007](CROSS-007.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-008](CROSS-008.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-009](CROSS-009.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-010](CROSS-010.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-011](CROSS-011.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-012](CROSS-012.md) | good_error_good | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-013](CROSS-013.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-014](CROSS-014.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-015](CROSS-015.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-016](CROSS-016.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-017](CROSS-017.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-018](CROSS-018.md) | arbitration_skew | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-019](CROSS-019.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-020](CROSS-020.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-021](CROSS-021.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-022](CROSS-022.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-023](CROSS-023.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-024](CROSS-024.md) | interleaving | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-025](CROSS-025.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-026](CROSS-026.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-027](CROSS-027.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-028](CROSS-028.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-029](CROSS-029.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-030](CROSS-030.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-031](CROSS-031.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-032](CROSS-032.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-033](CROSS-033.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-034](CROSS-034.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-035](CROSS-035.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-036](CROSS-036.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-037](CROSS-037.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-038](CROSS-038.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-039](CROSS-039.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-040](CROSS-040.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-041](CROSS-041.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-042](CROSS-042.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-043](CROSS-043.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-044](CROSS-044.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-045](CROSS-045.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-046](CROSS-046.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-047](CROSS-047.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-048](CROSS-048.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-049](CROSS-049.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-050](CROSS-050.md) | seed_sweep | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-051](CROSS-051.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-052](CROSS-052.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-053](CROSS-053.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-054](CROSS-054.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-055](CROSS-055.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-056](CROSS-056.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-057](CROSS-057.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-058](CROSS-058.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-059](CROSS-059.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-060](CROSS-060.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-061](CROSS-061.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-062](CROSS-062.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-063](CROSS-063.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-064](CROSS-064.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-065](CROSS-065.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-066](CROSS-066.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-067](CROSS-067.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-068](CROSS-068.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-069](CROSS-069.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-070](CROSS-070.md) | bug_seeded_soak | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-071](CROSS-071.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-072](CROSS-072.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-073](CROSS-073.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-074](CROSS-074.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-075](CROSS-075.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-076](CROSS-076.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-077](CROSS-077.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-078](CROSS-078.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-079](CROSS-079.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-080](CROSS-080.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-081](CROSS-081.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-082](CROSS-082.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-083](CROSS-083.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-084](CROSS-084.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-085](CROSS-085.md) | variant_builds | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-086](CROSS-086.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-087](CROSS-087.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-088](CROSS-088.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-089](CROSS-089.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-090](CROSS-090.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-091](CROSS-091.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-092](CROSS-092.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-093](CROSS-093.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-094](CROSS-094.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-095](CROSS-095.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-096](CROSS-096.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-097](CROSS-097.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-098](CROSS-098.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-099](CROSS-099.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-100](CROSS-100.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-101](CROSS-101.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-102](CROSS-102.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-103](CROSS-103.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-104](CROSS-104.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-105](CROSS-105.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-106](CROSS-106.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-107](CROSS-107.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-108](CROSS-108.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-109](CROSS-109.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-110](CROSS-110.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-111](CROSS-111.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-112](CROSS-112.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-113](CROSS-113.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-114](CROSS-114.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-115](CROSS-115.md) | coverage_closure | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-116](CROSS-116.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-117](CROSS-117.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-118](CROSS-118.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-119](CROSS-119.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-120](CROSS-120.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-121](CROSS-121.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-122](CROSS-122.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-123](CROSS-123.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-124](CROSS-124.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-125](CROSS-125.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-126](CROSS-126.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-127](CROSS-127.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-128](CROSS-128.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |
| ❓ | [CROSS-129](CROSS-129.md) | checkpoint_ucdb | see [`../../DV_CROSS.md`](../../DV_CROSS.md) |

## Per-run evidence contract (`cross/<run_id>.md`)

Each run page, once emitted, must carry:

1. Identifier, mode, and bucket/scope.
2. Invocation (make target, plusargs, seed, build variant).
3. Merged code coverage — explicit vector `stmt=.., branch=.., cond=.., expr=.., fsm_state=.., fsm_trans=.., toggle=..`.
4. Functional cross % against the relevant [`../../DV_CROSS.md`](../../DV_CROSS.md) §4 cross cluster.
5. Per-txn growth curve pointer into `../txn_growth/<case_id>.md` where applicable.
6. Counter-check summary: ingress / opq / dma hit counts, ghost / missing counts, payload / padding words, `dma_done` observation, `SWB_CHECK_PASS` presence.
7. Links to the WLF/GTKW artifacts and to the UCDB file on disk.

## Promoted baselines (from DV_REPORT.json `cross_baselines[]`)

<!-- These runs have already passed the integration gate and are currently the strongest empirical evidence. They will be captured under this cross/ tree once dv_report_gen.py is wired to emit per-run pages. -->

| status | run_id | build | case_count | evidence |
|:---:|---|---|---:|---|
| ✅ | `longrun_260421_default`    | `ip-compile-basic`      | 128 | [`../../cases/basic/uvm/report/longrun/summary.json`](../../cases/basic/uvm/report/longrun/summary.json) |
| ✅ | `plain_basic_smoke`         | `ip-compile-plain`      | 1 | [`../../cases/basic/ref/out_smoke/summary.json`](../../cases/basic/ref/out_smoke/summary.json) |
| ✅ | `plain_basic_full`          | `ip-compile-plain`      | 1 | [`../../cases/basic/ref/out/summary.json`](../../cases/basic/ref/out/summary.json) |
| ✅ | `plain_2env_full`           | `ip-compile-plain-2env` | 1 | [`../../cases/basic/plain_2env/report/run_plain_basic_2env.log`](../../cases/basic/plain_2env/report/run_plain_basic_2env.log) |
| ✅ | `formal_boundary`           | `ip-formal-boundary`    | n/a | [`../../cases/basic/plain_2env/formal/oss/swb_opq_boundary_contract/logfile.txt`](../../cases/basic/plain_2env/formal/oss/swb_opq_boundary_contract/logfile.txt) |

The stronger 256-run rerun remains available as historical archive evidence at [`../../cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json`](../../cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json), but it is not part of the promoted baseline set.

## Links out

- [`../README.md`](../README.md) — reviewer entry
- [`../../DV_CROSS.md`](../../DV_CROSS.md) — cross plan and cluster layout
- [`../../DV_COV.md`](../../DV_COV.md) — coverage dashboard
- [`../../DV_REPORT.json`](../../DV_REPORT.json) — machine-readable source
