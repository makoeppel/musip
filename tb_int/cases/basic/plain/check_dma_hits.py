#!/usr/bin/env python3
"""Semantic DMA checker for the plain SWB replay bench.

This compares expected and observed DMA payloads at the normalized 64-bit hit
level instead of the packed 256-bit word level, so corrected event-builder
repacking still validates as long as the same hits emerge with the same debug
timestamps.
"""

from __future__ import annotations

import argparse
import collections
from pathlib import Path


DMA_WORD_BITS = 256
HIT_WORD_BITS = 64
DMA_WORD_HEX = DMA_WORD_BITS // 4
DMA_PADDING_WORD = (1 << DMA_WORD_BITS) - 1
HIT_MASK = (1 << HIT_WORD_BITS) - 1
HIT_RSVD_MASK = ~(((1 << 5) - 1) << 58) & HIT_MASK


def read_hex_words(path: Path, width_hex: int) -> list[int]:
    words: list[int] = []
    with path.open("r", encoding="ascii") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            words.append(int(line, 16))
    return words


def normalize_hit(hit_word: int) -> int:
    return hit_word & HIT_RSVD_MASK


def split_payload_hits(words: list[int]) -> tuple[list[int], int]:
    hits: list[int] = []
    padding_words = 0
    for word in words:
        if word == DMA_PADDING_WORD:
            padding_words += 1
            continue
        for slot in range(4):
            hit_word = normalize_hit((word >> (slot * HIT_WORD_BITS)) & HIT_MASK)
            hits.append(hit_word)
    return hits, padding_words


def debug_ts_8ns(hit_word: int) -> int:
    return hit_word & ((1 << 37) - 1)


def hit_sig(hit_word: int) -> str:
    return (
        f"hit=0x{hit_word:016X} "
        f"ts8ns=0x{debug_ts_8ns(hit_word):010X} "
        f"payload_hi=0x{(hit_word >> 37) & 0x1FFFFF:06X}"
    )


def summarize_counter_delta(delta: collections.Counter[int], label: str) -> list[str]:
    lines: list[str] = []
    shown = 0
    for hit_word, count in sorted(delta.items()):
        if count <= 0:
            continue
        lines.append(f"{label}: count={count} {hit_sig(hit_word)}")
        shown += 1
        if shown >= 16:
            remaining = sum(delta.values()) - sum(value for _, value in delta.most_common(shown))
            if remaining > 0:
                lines.append(f"{label}: ... {remaining} additional unmatched hit(s)")
            break
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--expected", required=True, type=Path)
    parser.add_argument("--actual", required=True, type=Path)
    args = parser.parse_args()

    expected_words = read_hex_words(args.expected, DMA_WORD_HEX)
    actual_words = read_hex_words(args.actual, DMA_WORD_HEX)

    expected_hits, expected_padding = split_payload_hits(expected_words)
    actual_hits, actual_padding = split_payload_hits(actual_words)

    expected_counter = collections.Counter(expected_hits)
    actual_counter = collections.Counter(actual_hits)
    missing = expected_counter - actual_counter
    ghosts = actual_counter - expected_counter

    order_exact = expected_hits == actual_hits

    print(
        "plain_dma_check: "
        f"expected_words={len(expected_words)} actual_words={len(actual_words)} "
        f"expected_hits={len(expected_hits)} actual_hits={len(actual_hits)} "
        f"actual_padding_words={actual_padding} order_exact={int(order_exact)}"
    )

    if missing or ghosts:
        for line in summarize_counter_delta(missing, "missing"):
            print(f"plain_dma_check: {line}")
        for line in summarize_counter_delta(ghosts, "ghost"):
            print(f"plain_dma_check: {line}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
