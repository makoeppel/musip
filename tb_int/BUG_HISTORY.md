# BUG_HISTORY.md - tb_int DV bug ledger

Class legend:
- `R` = RTL / DUT bug
- `H` = harness / testcase / reporting bug

Severity legend:
- `soft error` = the bad packet/data flushes through the stream and does not leave the later datapath stuck
- `hard stuck error` = the bug poisons later packet handling and typically needs a functional reset / fresh restart to recover
- `non-datapath-refactor` = observability, reporting, harness, or naming/accounting consistency work with no direct packet-contract effect

Encounter sim-time legend:
- `min / p50 / max` = first encounter in simulation time under a still-traceable randomized long-run screen
- `n/a (...)` = directed-only, build-phase only, code-inspection only, reporting-only, or otherwise not honestly measurable in the current harness

Fix status detail contract for active entries and future updates:
- `state` = fixed / open / partial plus the current verification gate
- `mechanism` = how the implemented repair changes the RTL or harness behavior
- `before_fix_outcome` and `after_fix_outcome` = concise evidence showing what changed
- `potential_hazard` = whether the fix looks permanent or is still provisional / profile-limited
- `Claude Opus 4.7 xhigh review decision` = explicit review state; use `pending / not run` until that review has actually happened

Historical formal note:
- the current formal direction in this repo is the seam scaffold under `tb_int/cases/basic/plain_2env/formal/`; it is a property-level boundary check rather than a standalone full-formal signoff flow
- the promoted merge-enabled replay path now closes on the musip-regenerated authentic Qsys OPQ wrapper (`OPQ_SOURCE_MODE=upstream_qsys_generated`)
- the promoted merge-enabled path now also applies `feb_enable_mask` before the OPQ ingress bridge, so masked lanes no longer leak into the merged hit ledger
- the musip-local event-builder cleanup and the UCDB save/merge flow are now landed in this workspace
- the external upstream `signoff_4lane` audit item is kept in the ledger for reference but is out of scope for musip-local signoff here
- do not label a musip-local failure as a standalone OPQ / `packet_scheduler` bug unless it is independently reproduced in `mu3e-ip-cores/packet_scheduler`
- musip-only evidence stays in this ledger as a musip integration / wrapper / harness issue, even when the touched local snapshot lives under `firmware/a10_board/a10/merger/`
- if a future failure truly looks OPQ-internal, stop and report it explicitly before filing it against `packet_scheduler`

## Index

| bug_id | class | severity | encounter sim-time | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-001-H](#bug-001-h-default-non-replay-uvm-build-crashed-in-swb_case_builderbuild_basic_case) | H | non-datapath-refactor | `n/a (build-phase only)` | fixed | `make ip-uvm-basic` | `pending` | The default non-replay UVM path crashed in `swb_case_builder::build_basic_case` because the reverse padding loop underflowed its lane iterator. |
| [BUG-002-R](#bug-002-r-local-integrated-native-sv-merge-path-stalled-before-dma_done) | R | hard stuck error | `n/a (deprecated local owner only)` | waived | deprecated local-owner bring-up before `OPQ_SOURCE_MODE=upstream_qsys_generated` promotion | `n/a` | The deprecated musip-local standalone OPQ copy used to stall upstream of `dma_done`; this entry is waived because signoff now uses the authentic Qsys-generated OPQ wrapper instead. |
| [BUG-003-R](#bug-003-r-local-full-end-to-end-replay-diverged-from-the-expected-dma-ledger) | R | hard stuck error | `n/a (full replay exact repro)` | fixed | `make ip-plain-basic`, `make ip-uvm-basic` on the promoted Qsys-generated path | `pending` | The promoted authentic Qsys-generated OPQ wrapper used to drop hits because musip packaging fell back to upstream default lane/handle FIFO depths; the full end-to-end replay now closes. |
| [BUG-004-R](#bug-004-r-musip_event_builder-completion-contract-cleanup) | R | non-datapath-refactor | `n/a (contract cleanup with replay and coverage reruns)` | fixed | `firmware/a10_board/a10/swb/musip_event_builder.vhd` | `pending` | `musip_event_builder` now makes non-zero launch, last-payload retirement, one-word payload completion, and fixed padding behavior explicit. |
| [BUG-005-R](#bug-005-r-external-upstream-signoff_4lane-audit-still-shows-an-alignment-gap) | R | hard stuck error | `n/a (external audit only)` | open | `OPQ_SOURCE_MODE=signoff_4lane` audit runs | `n/a` | External upstream `signoff_4lane` alignment remains open, but it is not part of the musip-local blocker set in this repo. |
| [BUG-006-H](#bug-006-h-random-uvm-cases-were-not-exactly-reproducible-because-the-case-seed-was-not-captured) | H | non-datapath-refactor | `n/a (random-case reproducibility)` | fixed | `make ip-uvm-basic` randomized runs | `pending` | Random UVM cases were not exactly reproducible because the case-builder RNG state was implicit and not captured in the plan or logs. |
| [BUG-007-H](#bug-007-h-per-hit-trace-export-failed-when-the-report-directory-did-not-exist) | H | non-datapath-refactor | `n/a (trace export only)` | fixed | seeded UVM trace run with `+SWB_HIT_TRACE_PREFIX=.../report/...` | `pending` | Per-hit trace export failed because the UVM run target did not create the report directory before simulation. |
| [BUG-008-H](#bug-008-h-zero-payload-random-cases-falsely-failed-because-the-uvm-harness-always-required-dma_done-and-eoe) | H | non-datapath-refactor | `n/a (zero-payload random corner)` | fixed | extended long-run campaign run `246` with `sat=[0,0,0,0]` | `pending` | Zero-payload random cases falsely failed because the UVM harness always required `dma_done` and an end-of-event marker even when the current event-builder contract produced no DMA transaction. |
| [BUG-009-H](#bug-009-h-plain_2env-dma-scoreboarding-was-blind-to-ingress-hits-because-the-split-harness-only-wired-the-opq-boundary-scoreboard) | H | non-datapath-refactor | `n/a (split-harness replay audit)` | fixed | `make ip-plain-basic-2env-smoke` rerun during signoff refresh | `pending` | The split `plain_2env` harness only wired ingress replay into the OPQ boundary scoreboard, so the downstream DMA scoreboard saw real DMA hits without any expected-hit ledger. |
| [BUG-010-R](#bug-010-r-feb_enable_mask-did-not-gate-opq-ingress-so-masked-lanes-still-entered-the-merged-datapath) | R | soft error | `n/a (directed exact repro at 43.698 us)` | fixed | `make ip-uvm-basic` with `B046_lane0_only` | `pending` | `feb_enable_mask` did not gate the OPQ ingress bridge, so masked FEB lanes still entered the merged datapath and corrupted the per-hit expectation ledger. |

## 2026-04-21

### BUG-001-H: Default non-replay UVM build crashed in `swb_case_builder::build_basic_case`
- First seen in:
  - `make ip-uvm-basic`
- Symptom:
  - the default non-replay UVM run crashed before meaningful simulation with a bad handle / reference fatal in `swb_case_builder::build_basic_case`
- Root cause:
  - the reverse padding loop used an unsigned lane iterator
  - after lane `0` it underflowed and walked outside `frames_by_lane`
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `tb_int/cases/basic/uvm/sv/swb_types.sv` in the `swb_case_builder` class; this is the UVM basic-case generator that owned the broken reverse padding loop
  - mechanism: the reverse padding loop now uses signed reverse iterators and stops scanning when `extra_hits` reaches zero
  - before_fix_outcome: `make ip-uvm-basic` died in build phase before the run reached the real datapath behavior
  - after_fix_outcome: the default UVM run reaches the real datapath and now passes on the promoted local workspace snapshot
  - potential_hazard: low; this is a bounded harness-side iterator fix
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - this is a harness bug, not an RTL datapath defect
  - closing it was required before randomized UVM evidence could be trusted
- Commit:
  - `pending`

## 2026-04-22

### BUG-002-R: Local integrated native-SV merge path stalled before `dma_done`
- First seen in:
  - deprecated local-owner bring-up before the authentic Qsys wrapper was promoted
- Symptom:
  - the old standalone local OPQ copy stalled before `dma_done` and could miss every expected DMA hit in smoke replay
- Root cause:
  - the then-active owner was a deprecated local placeholder copy of OPQ rather than the authenticated Qsys-generated integration path now used for signoff
  - the current promoted musip owner is regenerated from `mu3e-ip-cores/packet_scheduler` through `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/`
- Fix status:
  - state: waived for current musip-local signoff because the deprecated local owner is no longer used
  - files/modules: owner selection is now anchored by `tb_int/cases/basic/opq_sources.mk` (`OPQ_SOURCE_MODE=upstream_qsys_generated`) together with the musip packaging sources `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/ordered_priority_queue_native_sv_fixed4_hw.tcl` and `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/opq_upstream_4lane.tcl`
  - mechanism: musip signoff now uses the regenerated authentic Qsys wrapper rather than the deprecated local OPQ placeholder files under `firmware/a10_board/a10/merger/`
  - before_fix_outcome: the deprecated local-owner smoke path could time out at `DMA done not observed before timeout` with `actual_words=0 actual_hits=0`
  - after_fix_outcome: the promoted authentic-wrapper path is the only signoff owner, and it closes smoke, full replay, default UVM, boundary replay, and the long-run screens
  - potential_hazard: low as long as the deprecated local owner is not re-promoted
  - attribution note: this waiver does not assert a standalone OPQ datapath bug. It records that the deprecated musip-local owner is out of scope now that the authentic Qsys-generated owner is the promoted path.
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - this entry is intentionally historical
  - current promoted evidence lives under the authentic-wrapper runs in `tb_int/cases/basic/plain/`, `tb_int/cases/basic/uvm/`, and `tb_int/cases/basic/plain_2env/`
- Commit:
  - `n/a`

### BUG-003-R: Local full end-to-end replay diverged from the expected DMA ledger
- First seen in:
  - `make ip-plain-basic`
  - `make ip-uvm-basic`
  - after the authentic Qsys-generated OPQ wrapper became the promoted owner
- Symptom:
  - the full replay case used to mismatch the expected DMA stream and could stall before `dma_done`
  - the deterministic exact repro closed short with `expected_hits=3800 actual_hits=3668`
  - the missing traffic concentrated on `lane3 frame1`, with `opq_missing_count=130` and `dma_missing_count=132`
- Root cause:
  - the musip-packaged authentic Qsys wrapper did not propagate `LANE_FIFO_DEPTH` or `HANDLE_FIFO_DEPTH` into the monolithic native-SV OPQ top, so the generated wrapper silently fell back to the upstream defaults instead of the fixed musip profile
  - on the failing replay this reduced the effective lane credit budget, exhausted `lane3` credit mid-frame, and dropped 130 hits from `frame1` even though ticket credit was still healthy
  - this was a musip-local packaging / wrapper bug; it was not promoted as a standalone OPQ-internal bug claim
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/ordered_priority_queue_native_sv_fixed4_hw.tcl` in the musip packaging transform now injects the fixed-profile `LANE_FIFO_DEPTH` and `HANDLE_FIFO_DEPTH` generics into the generated `ordered_priority_queue_dut_sv` wrapper; `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/opq_upstream_4lane.tcl` bumps the packaged instance version so Quartus/Qsys regenerates the wrapper; the generated module `firmware/a10_board/a10/merger/qsys/opq_upstream_4lane_native_sv/generated/ordered_priority_queue_native_sv_fixed4_26422504/synth/ordered_priority_queue_dut_sv.sv` now passes the intended fixed-profile depths into `ordered_priority_queue_monolithic_sv`
  - mechanism: the musip authentic-wrapper packaging now pins the intended `4-lane / 256-subheader / 2048-lane-fifo / 1024-ticket-fifo / 256-handle-fifo / 65536-page-ram` profile all the way into the monolithic SV top, so the wrapper can no longer fall back to the upstream default lane/handle FIFO depths
  - before_fix_outcome: full replay produced a short DMA ledger and timed out; the deterministic exact repro dropped 130 `lane3 frame1` hits and finished with `expected_hits=3800 actual_hits=3668`
  - after_fix_outcome: `make ip-plain-basic` now closes at `expected_words=950 actual_words=1078 expected_hits=3800 actual_hits=3800 actual_padding_words=128 order_exact=0`, and the default UVM run closes at `payload_words=951 padding_words=128 ingress_hits=3804 opq_hits=3804 dma_hits=3804`
  - potential_hazard: low to medium; the promoted authentic-wrapper closure is strong, but any direct upstream wrapper cleanup should still be tracked separately by the packet_scheduler owner
  - attribution note: this is recorded as a musip-local authentic-wrapper packaging defect, not as a standalone OPQ datapath bug. Any upstream OPQ attribution would still require an independent reproduction in `mu3e-ip-cores/packet_scheduler`.
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - promoted evidence:
    - exact failing repro before the fix: `plain_dma_check expected_hits=3800 actual_hits=3668`, plus UVM scoreboard `opq_missing_count=130` and `dma_missing_count=132`
    - plain full after the fix: `expected_words=950 actual_words=1078 expected_hits=3800 actual_hits=3800 actual_padding_words=128 order_exact=0`
    - default randomized UVM after the fix: `payload_words=951`, `padding_words=128`, `ingress_hits=3804`, `opq_hits=3804`, `dma_hits=3804`
    - seeded trace case remains clean at `payload=252`, `padding=128`, `ingress/opq/dma hits = 1008/1008/1008`
- Commit:
  - `pending`

### BUG-004-R: `musip_event_builder` completion contract cleanup
- First seen in:
  - `firmware/a10_board/a10/swb/musip_event_builder.vhd`
- Symptom:
  - `dma_done` behavior was easy to misread because completion depended on implicit local state transitions rather than an explicit non-zero launch and last-payload contract
  - the one-word payload corner was not retired explicitly, and the fixed padding phase was encoded as legacy local sequencing instead of a clearer payload-then-padding flow
- Root cause:
  - `dma_done` is really `musip_event_builder.o_done`, exposed through `EVENT_BUILD_STATUS_REGISTER_R`
  - the original state machine mixed launch qualification, payload retirement, and padding retirement into a legacy counter scheme that hid the one-word payload case and left the zero-word no-launch behavior implicit
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `firmware/a10_board/a10/swb/musip_event_builder.vhd`, entity `musip_event_builder`
  - mechanism: the event builder now uses explicit non-zero launch gating, separate payload and padding retire signals, a dedicated last-payload state, and a fixed `128`-word padding counter. One-word payloads now retire through the same explicit last-payload path as longer events, and zero-word requests remain a documented no-launch case.
  - before_fix_outcome: the completion contract was easy to misread, the one-word payload corner was not represented explicitly in the state machine, and padding retirement was encoded indirectly
  - after_fix_outcome: replay, UVM, and split-boundary reruns all preserve the expected `payload_words + 128 padding_words` accounting while the non-zero launch, last-payload `o_endofevent`, and sticky `o_done` behavior are now explicit in the RTL
  - potential_hazard: low; the cleanup is localized to musip-owned event-builder control logic and was rerun through the promoted replay and coverage flows
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - promoted reruns after the cleanup pass cleanly across:
    - `make ip-compile-plain`, `make ip-compile-basic`, `make ip-compile-plain-2env`
    - `make ip-cov-closure`
  - merged coverage artifacts now exist under `tb_int/sim_runs/coverage/`, and every promoted replay-bearing UCDB still reports `SWB_CHECK_PASS`
- Commit:
  - `pending`

### BUG-005-R: External upstream `signoff_4lane` audit still shows an alignment gap
- First seen in:
  - audit runs using `OPQ_SOURCE_MODE=signoff_4lane`
- Symptom:
  - the external upstream audit tree does not yet line up with the passing local musip snapshot
- Root cause:
  - open outside this repo's local blocker set
- Fix status:
  - state: open, external / out of musip scope
  - files/modules: no musip-local RTL module is being patched under this entry; this is an audit-only note for the external upstream `signoff_4lane` source set
  - mechanism: none in this repo for the current turn; other agents own that alignment work
  - before_fix_outcome: external audit tree diverges from the passing local owner
  - after_fix_outcome: none yet in this repo; this entry is retained for reference only
  - potential_hazard: low for local signoff, medium for external collateral if someone confuses the audit tree with the promoted local owner
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - this is not a musip-local blocker and is not part of the promoted validation gate in this workspace
- Commit:
  - `n/a`

### BUG-006-H: Random UVM cases were not exactly reproducible because the case seed was not captured
- First seen in:
  - `make ip-uvm-basic` randomized runs without replay
- Symptom:
  - a failing or interesting randomized case could not be rerun exactly from the logged rate overrides alone
- Root cause:
  - the case-builder sampled from implicit simulator process RNG state
  - the plan and log did not capture a dedicated per-case seed
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `tb_int/cases/basic/uvm/sv/swb_basic_test.sv` in class `swb_basic_test` for plusarg parsing and RNG seeding, `tb_int/cases/basic/uvm/sv/swb_types.sv` in classes `swb_case_plan` / `swb_case_builder` for recording the seed in the plan, and `tb_int/cases/basic/uvm/run_longrun.py` for carrying that seed into campaign summaries
  - mechanism: the UVM test now accepts `+SWB_CASE_SEED=<n>`, reseeds the case-builder process RNG explicitly, and records that seed in the case plan and run banner
  - before_fix_outcome: randomized case shape depended on implicit process RNG state and was not exactly reproducible
  - after_fix_outcome: randomized runs are exactly replayable, and the long-run driver records `case_seed` for every campaign row
  - potential_hazard: low; this is a harness-side determinism repair
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - this fix was required before the randomized campaigns could be treated as actionable signoff evidence
  - promoted evidence lives in `tb_int/cases/basic/uvm/report/longrun/summary.json`
  - stronger rerun evidence lives in `tb_int/cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json`
- Commit:
  - `pending`

### BUG-007-H: Per-hit trace export failed when the report directory did not exist
- First seen in:
  - seeded UVM trace run with `+SWB_HIT_TRACE_PREFIX=$(pwd)/tb_int/cases/basic/uvm/report/single_seed`
- Symptom:
  - the UVM run reached end of test but then reported file-open errors while trying to write the trace artifacts
- Root cause:
  - the `make run` target did not create `tb_int/cases/basic/uvm/report/` before simulation
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `tb_int/cases/basic/uvm/Makefile` in the `run` target now creates the report directory before simulation; the emitted trace files themselves come from `tb_int/cases/basic/uvm/sv/swb_scoreboard.sv` in class `swb_scoreboard`
  - mechanism: the UVM `run` target now creates the local report directory before invoking `vsim`
  - before_fix_outcome: trace export raised `UVM_ERROR`s for missing output paths even though the datapath itself closed
  - after_fix_outcome: the same seeded run passes cleanly and emits all expected trace files
  - potential_hazard: low; this is a bounded reporting-path fix
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - promoted evidence:
    - `single_seed_expected_hits.tsv`
    - `single_seed_ingress_hits.tsv`
    - `single_seed_opq_hits.tsv`
    - `single_seed_dma_hits.tsv`
    - `single_seed_summary.txt`
  - summary evidence: `scoreboard_pass=1`, `parse_errors=0`, `opq_ghost_count=0`, `opq_missing_count=0`, `dma_ghost_count=0`, `dma_missing_count=0`
- Commit:
  - `pending`

### BUG-008-H: Zero-payload random cases falsely failed because the UVM harness always required `dma_done` and EOE
- First seen in:
  - extended long-run campaign `python3 tb_int/cases/basic/uvm/run_longrun.py --runs 256 --campaign-seed 260422 --out-dir report/longrun_ext_260422`
  - failing row: `run_246`, `case_seed=1327604986`, `sat=[0.00 0.00 0.00 0.00]`
- Symptom:
  - the all-zero saturation random corner produced `total_hits=0` and `expected_words=0`, but the UVM run still timed out waiting for `dma_done`
  - the scoreboard then also raised `DMA_EOE` even though no payload words were expected or observed
- Root cause:
  - the current local `musip_event_builder` contract does not assert `o_done` or `o_endofevent` when `i_get_n_words=0`
  - the UVM harness assumed every legal case would eventually emit `dma_done` and EOE, so it falsely marked the zero-payload corner as a failure
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `tb_int/cases/basic/uvm/sv/swb_basic_test.sv` in class `swb_basic_test` now skips the `dma_done` timeout for zero-payload cases after a bounded settle window, and `tb_int/cases/basic/uvm/sv/swb_scoreboard.sv` in class `swb_scoreboard` only requires EOE when a non-zero payload was expected
  - mechanism: the UVM harness now treats `expected_word_count=0` as a legal zero-payload corner under the current event-builder contract while still rejecting any unexpected payload, ghost hit, or parser error
  - before_fix_outcome: `run_246` failed with `TIMEOUT`, `DMA_EOE`, `expected_payload_words=0`, `observed_payload_words=0`, and no actual hit mismatch
  - after_fix_outcome: the exact failing case now passes cleanly and emits `SWB_CHECK_PASS` with `payload_words=0`, `ingress_hits=0`, `opq_hits=0`, `dma_hits=0`
  - potential_hazard: low; this is a narrow harness-side contract alignment fix for the zero-payload corner, and it does not weaken any non-zero payload checks
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - first-fail evidence:
    - `tb_int/cases/basic/uvm/report/longrun_ext_260422/runs/run_246.log`
    - `tb_int/cases/basic/uvm/report/longrun_ext_260422/failures/run_246_summary.txt`
  - exact-fix evidence:
    - zero-payload rerun with trace prefix `tb_int/cases/basic/uvm/report/zero_payload_fix`
    - clean result: `SWB_CHECK_PASS`, `UVM_ERROR : 0`, `payload_words=0`, `ingress/opq/dma hits = 0/0/0`
    - extended rerun closure: `tb_int/cases/basic/uvm/report/longrun_ext_260422_fixed/summary.json` with `pass_count=256 fail_count=0`, including `run_246 case_seed=1327604986`
  - BUG-004-R now closes the underlying event-builder cleanup. This harness fix remains necessary because the legal zero-payload contract is still "no launch" rather than a synthetic empty DMA transaction.
- Commit:
  - `pending`

### BUG-009-H: `plain_2env` DMA scoreboarding was blind to ingress hits because the split harness only wired the OPQ boundary scoreboard
- First seen in:
  - `make ip-plain-basic-2env-smoke` rerun during the current signoff refresh
- Symptom:
  - the OPQ boundary scoreboard passed, but the downstream DMA scoreboard reported every real DMA hit as a ghost
  - smoke replay showed `dma expected=0 actual=8 ghosts=8`, even though the split harness was driving the correct replay bundle
- Root cause:
  - `swb_basic_2env_test` only connected the ingress monitors to `swb_opq_boundary_scoreboard`
  - the downstream shared `swb_scoreboard` therefore saw DMA words without any expected ingress-hit ledger
  - the split ingress monitors publish `swb_opq_beat`, while the downstream scoreboard expects `swb_stream_beat`, so the harness also needed a local type adapter instead of a raw direct connection
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `tb_int/cases/basic/plain_2env/sv/swb_2env_agents.sv` in class `swb_opq_ingress_monitor` now emits a parallel `swb_stream_beat` adapter feed, and `tb_int/cases/basic/plain_2env/sv/swb_2env_test.sv` in class `swb_basic_2env_test` now connects that adapter feed into `datapath_env.scoreboard`
  - mechanism: the split harness now fans the same ingress replay into both scoreboards, keeping the OPQ boundary checker on `swb_opq_beat` while giving the downstream DMA checker the `swb_stream_beat` objects it already understands
  - before_fix_outcome: `make ip-plain-basic-2env-smoke` raised `HIT_GHOST` errors because `dma_hits=8` arrived against `expected_hits=0`
  - after_fix_outcome: `make ip-plain-basic-2env-smoke` and `make ip-plain-basic-2env` both pass with `SWB_CHECK_PASS`, `ghosts=0`, and the expected `OPQ_BOUNDARY_SUMMARY`
  - potential_hazard: low; this is a local split-harness wiring and type-adapter repair with no effect on the real integrated datapath
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - smoke closure:
    - `DMA_SUMMARY`: `payload_words=2`, `ingress_hits=8`, `dma_hits=8`, `ghosts=0`
  - full replay closure:
    - `DMA_SUMMARY`: `payload_words=950`, `ingress_hits=3800`, `dma_hits=3800`, `ghosts=0`
  - the OPQ boundary audit remains a musip-local harness check, not a standalone OPQ attribution claim
- Commit:
  - `pending`

### BUG-010-R: `feb_enable_mask` did not gate OPQ ingress, so masked lanes still entered the merged datapath
- First seen in:
  - `make ip-uvm-basic SIM_ARGS='+SWB_PROFILE_NAME=B046_lane0_only +SWB_CASE_SEED=4242 +SWB_FEB_ENABLE_MASK=1 +SWB_SAT0=0.20 +SWB_SAT1=0.40 +SWB_SAT2=0.60 +SWB_SAT3=0.80'`
- Symptom:
  - the lane-mask directed case expected only lane0 hits to appear at OPQ and DMA, but masked lanes 1..3 still leaked into the merged path
  - the first failing repro reported `opq expected=368 actual=500 ghosts=450 missing=318` and `dma expected=368 actual=368 ghosts=330 missing=330`
- Root cause:
  - `swb_block` passed `rx_data_sim(3 downto 0)` directly into `ingress_egress_adaptor`
  - the `feb_enable_mask` / `SWB_GENERIC_MASK_REGISTER_W` was only applied later at `musip_mux_4_1`, so masked lanes were still visible to the OPQ ingress bridge
- Fix status:
  - state: fixed in working tree, not yet committed
  - files/modules: `firmware/a10_board/a10/swb/swb_block.vhd` in entity `swb_block`; this is the musip-owned SWB integration wrapper that now inserts a masked `rx_data_sim_opq` vector before `ingress_egress_adaptor`
  - mechanism: the first four FEB data lanes are now converted to `LINK32_IDLE` before the OPQ ingress bridge whenever the corresponding `feb_enable_mask` bit is deasserted
  - before_fix_outcome: the directed lane0-only case leaked masked-lane traffic into OPQ and then into the downstream DMA expectation ledger
  - after_fix_outcome: `B046_lane0_only` now passes with `opq expected=368 actual=368 ghosts=0 missing=0` and `dma expected=368 actual=368 ghosts=0 missing=0`
  - potential_hazard: low; the change is localized to musip-owned ingress masking ahead of the OPQ wrapper and does not modify the upstream OPQ IP
  - Claude Opus 4.7 xhigh review decision: pending / not run
- Runtime / coverage context:
  - passing evidence lives in `tb_int/cases/basic/uvm/report/B046_lane0_only.log`
  - this is a musip-local integration bug, not a standalone OPQ attribution claim
- Commit:
  - `pending`
