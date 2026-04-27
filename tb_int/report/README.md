# `tb_int/report`

Checked-in DV evidence root for the MuSiP SWB/OPQ integration workspace.

## Layout

| path | owner |
|---|---|
| [`signoff/`](signoff/) | generated per-bucket, per-case, per-cross signoff evidence |
| [`signoff/DV_SIGNOFF.md`](signoff/DV_SIGNOFF.md) | implemented vs missing functional coverage summary |
| [`wave/`](wave/) | static waveform and packet-analyzer bundles |
| [`script/`](script/) | report-local helper scripts |

## Wave Server

Serve every checked-in analyzer bundle from the repo root:

```bash
tb_int/report/script/start_wave_server.sh 8789
```

The equivalent raw Python command is:

```bash
python3 -m http.server 8789 --bind 127.0.0.1 --directory tb_int/report/wave
```

Open `http://127.0.0.1:8789/` for the bundle index.
