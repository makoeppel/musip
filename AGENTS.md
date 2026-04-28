# Agent Notes

- `/home/yifeng/packages/musip_2604/external/mu3e-ip-cores` is a pull-only consumer snapshot. Do not implement fixes there in-place.
- If a consumer under `external/mu3e-ip-cores` needs a fix, make the change in the source repo under `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores` or the relevant nested repo there.
- For source-repo fixes, prefer a separate guest worktree, make commits there, then sync or pull the result back into this consumer workspace.
- When resyncing this workspace, overwrite only from the upstream source repo. Do not treat `external/` as the source of truth.
- For OPQ or other `mu3e-ip-cores` IP fixes found during musip integration, first validate and push from `/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores` (or the relevant nested source repo). Then update musip only by pulling/syncing that upstream result into `external/mu3e-ip-cores`; never push from the musip mirror.
- Use Nios II/e (`cpu impl Tiny`) for the A10 board firmware. The ETH build server does not have a Nios II/f license; selecting `Fast` can generate `top_time_limited.sof`.
- If a `top_time_limited.sof` must be used for temporary board debug, keep the `quartus_pgm` time-limited IP evaluation prompt alive in a persistent session. Quitting or killing that programmer session can invalidate the loaded design.
