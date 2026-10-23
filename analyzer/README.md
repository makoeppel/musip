# Analyzer
`quadana` processes MIDAS files with the analyzer modules in this directory.
`AnaFillHits` (Module) creates the flow-event hit vector consumed by the other modules.

## Hit tree writer

`AnaHitTree` writes a ROOT tree named `hits` to the per-run analyzer output file
`outputNNNNN.root`. It writes one tree entry per processed flow event.

The writer is disabled by default. Enable it with the `hitTree` configuration
section:

```json
{
    "hitTree": {
        "enabled": true,
        "write_mutrighits": true,
        "write_pixelhits": true
    }
}
```

For offline analysis, pass the configuration after `--`:

```sh
quadana online/run00067.mid.lz4 -- --config analyzer/config_treewrite.json
```

The `write_mutrighits` and `write_pixelhits` options control whether the
corresponding vectors are populated. All branches are created when the tree is
created, so disabling a group leaves its branches present but empty.

## Tree format

Each branch is a `std::vector`. Values at the same index within one group
correspond to the same hit. A tree entry can contain an empty vector when the
event has no hits of that type.

| Branch | Element type | Meaning |
| --- | --- | --- |
| `mutrig_channel` | `uint32_t` | Global MuTRIG channel number |
| `mutrig_tot` | `uint16_t` | MuTRIG ToT / energy value |
| `mutrig_time` | `double` | MuTRIG hit time in ns |
| `mutrig_timestamp` | `uint64_t` | MuTRIG timestamp in 50 ps bins |
| `pixel_chipid` | `uint32_t` | MuPix chip ID |
| `pixel_col` | `uint8_t` | MuPix column |
| `pixel_row` | `uint8_t` | MuPix row |
| `pixel_tot` | `uint8_t` | MuPix ToT |
| `pixel_time` | `uint64_t` | MuPix time in ns |
| `pixel_timestamp` | `uint64_t` | MuPix timestamp in 8 ns units |
