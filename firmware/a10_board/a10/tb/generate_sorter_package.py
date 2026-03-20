# Generate VHDL with:
# - Variable per-link package target length L ~ Beta(1,2) scaled to [512, 2048],
#   so E[L] = 1024. Padding with 0x000000BC if shorter; allow longer if needed.
# - K identification vector per link/package: '1' when lower byte is in {0xBC, 0x9C, 0x7F}
#   (header=...BC, filler=...BC, trailer=...9C, subheader=...7F).
# - Subheader low byte kept at 0x7F.
#
# Output: /mnt/data/hit_stream_pkg_varlen.vhd

from dataclasses import dataclass
from typing import List, Iterable, Callable, Optional, Dict, Tuple
import random
from pathlib import Path

HEADER_WORD  = 0xE80000BC
TRAILER_WORD = 0x0000009C
FILLER_WORD  = 0x000000BC
SUBHDR_KBYTE = 0xF7

MIN_LEN = 512
MAX_LEN = 2048

def poisson_knuth(lmbda: float) -> int:
    if lmbda <= 0:
        return 0
    L = pow(2.718281828459045, -lmbda)
    k = 0
    p = 1.0
    while p > L:
        k += 1
        p *= random.random()
    return k - 1

def beta_1_2() -> float:
    """Sample Beta(1,2) without numpy. Mean=1/3; support [0,1].
    Inverse CDF: x = 1 - sqrt(1-u), u~U(0,1).
    """
    u = random.random()
    return 1.0 - (1.0 - u) ** 0.5

def draw_target_len() -> int:
    x = beta_1_2()  # in [0,1], mean 1/3
    length = int(round(MIN_LEN + (MAX_LEN - MIN_LEN) * x))
    return max(MIN_LEN, min(MAX_LEN, length))

@dataclass
class HitFields:
    link_id: int
    subctr: int
    hit_index: int
    ts_byte: int  # 0..255

def default_hit_encoder(h: HitFields) -> int:
    word = ((h.link_id & 0xF) << 28) | ((h.subctr & 0x7F) << 21) | ((h.hit_index & 0x1FF) << 12)
    word |= (random.randrange(0, 256) << 4) & 0xFF0
    word |= (h.ts_byte & 0xF)
    return word

class PacketStreamGenerator:
    def __init__(
        self,
        num_links: int = 8,
        hit_rates_per_link: Optional[List[float]] = None,
        rng_seed: Optional[int] = None,
        hit_encoder: Callable[[HitFields], int] = default_hit_encoder,
        subheader_k: int = SUBHDR_KBYTE,
    ) -> None:
        assert 1 <= num_links <= 8, "num_links must be in 1..8"
        self.num_links = num_links
        if hit_rates_per_link is None:
            hit_rates_per_link = [0.5] * num_links
        else:
            assert len(hit_rates_per_link) == num_links, "hit_rates_per_link length must equal num_links"
        self.hit_rates = hit_rates_per_link
        self.hit_encoder = hit_encoder
        self.subheader_k = subheader_k & 0xFF
        if rng_seed is not None:
            random.seed(rng_seed)

    def _encode_subheader(self, subctr: int) -> int:
        return ((subctr & 0x7F) << 24) | self.subheader_k

    def _encode_T0_T1(self, ts48: int) -> Tuple[int, int]:
        T0 = ts48 & 0xFFFFFFFF
        T1 = (ts48 >> 32) & 0xFFFF
        return T0, T1

    def make_package(self, ts48: int) -> Dict[int, Tuple[List[int], List[int]]]:
        """Return per-link data: words list and parallel K-vector list of 0/1 ints."""
        links: Dict[int, Tuple[List[int], List[int]]] = {}
        for link_id in range(self.num_links):
            words: List[int] = []
            kvec:  List[int] = []  # 1 if K in low byte (0xBC,0x9C,0x7F), else 0

            # Header
            words.append(HEADER_WORD)
            kvec.append(1)  # header lower byte is 0xBC

            # T0, T1, D0, D1
            T0, T1 = self._encode_T0_T1(ts48)
            D0, D1 = 0xD0D0D0D0, 0xD1D1D1D1
            words.extend([T0, T1, D0, D1])
            kvec.extend([0, 0, 0, 0])

            # Subheaders 0..127 and hits
            for subctr in range(128):
                sub_w = self._encode_subheader(subctr)
                words.append(sub_w)
                # subheader low byte is 0x7F -> mark as K
                kvec.append(1)

                n_hits = poisson_knuth(self.hit_rates[link_id])
                for hit_idx in range(n_hits):
                    ts_byte = 0 if subctr == 127 else random.randrange(1, 256)
                    h = HitFields(link_id=link_id, subctr=subctr, hit_index=hit_idx, ts_byte=ts_byte)
                    hit_w = self.hit_encoder(h)
                    words.append(hit_w)
                    # assume payload hits are data (not K)
                    kvec.append(0)

            # Trailer
            words.append(TRAILER_WORD)
            # trailer low byte is 0x9C -> mark as K
            kvec.append(1)

            # Pad to per-link target length if shorter
            target_len = draw_target_len()
            if len(words) < target_len:
                pad_needed = target_len - len(words)
                words.extend([FILLER_WORD] * pad_needed)
                kvec.extend([1] * pad_needed)  # filler is 0x..BC => K

            # Mask and store
            words = [w & 0xFFFFFFFF for w in words]
            links[link_id] = (words, kvec)
        return links

    def stream(self, num_packages: int, start_ts48: int = 0, ts_step: int = 1024):
        list_of_packages = []
        ts = start_ts48 & ((1 << 48) - 1)
        for _ in range(num_packages):
            list_of_packages.append(self.make_package(ts))
            ts = (ts + ts_step) & ((1 << 48) - 1)
        return list_of_packages

# --- Configure and generate ---
gen = PacketStreamGenerator(
    num_links=8,
    hit_rates_per_link=[20, 15, 5, 6, 9, 30, 20, 5],
    rng_seed=42,
    subheader_k=SUBHDR_KBYTE,  # keep 0x7F
)

packages = gen.stream(num_packages=4, start_ts48=0x0, ts_step=1024)

# --- Emit VHDL package ---
def vhdl_word_list(words: List[int]) -> str:
    items = [f'x"{w:08X}"' for w in words]
    lines = []
    line = []
    char_count = 0
    for it in items:
        if char_count + len(it) + 2 > 100:
            lines.append(", ".join(line))
            line = [it]
            char_count = len(it)
        else:
            line.append(it)
            char_count += len(it) + 2
    if line:
        lines.append(", ".join(line))
    return "(\n        " + ",\n        ".join(lines) + "\n    )"

def vhdl_kvec_list(kvec: List[int]) -> str:
    # as string of '0'/'1' in std_logic_vector aggregate
    items = [f"'{int(b)}'" for b in kvec]
    lines = []
    line = []
    char_count = 0
    for it in items:
        if char_count + len(it) + 2 > 100:
            lines.append(", ".join(line))
            line = [it]
            char_count = len(it)
        else:
            line.append(it)
            char_count += len(it) + 2
    if line:
        lines.append(", ".join(line))
    return "(\n        " + ",\n        ".join(lines) + "\n    )"

pkg_lines = []
pkg_lines.append("-- Auto-generated hit stream data with variable package length in [512,2048]")
pkg_lines.append("-- Mean target length per link ~= 1024 via Beta(1,2) length sampler.")
pkg_lines.append("library ieee;")
pkg_lines.append("use ieee.std_logic_1164.all;")
pkg_lines.append("")
pkg_lines.append("package hit_stream_pkg is")
pkg_lines.append("  subtype word32_t is std_logic_vector(31 downto 0);")
pkg_lines.append("  type word32_vec_t is array (natural range <>) of word32_t;")
pkg_lines.append("  type slv_vec_t   is array (natural range <>) of std_logic_vector;")
pkg_lines.append("")

for p_idx, link_map in enumerate(packages):
    for link_id, (words, kvec) in link_map.items():
        name = f"LINK{link_id}_PKG{p_idx}"
        pkg_lines.append(f"  constant {name}_LEN : natural := {len(words)};")
        pkg_lines.append(f"  constant {name}_WORDS : word32_vec_t(0 to {len(words)-1}) := {vhdl_word_list(words)};")
        pkg_lines.append(f"  constant {name}_K    : std_logic_vector(0 to {len(kvec)-1}) := {vhdl_kvec_list(kvec)};")
        pkg_lines.append("")

pkg_lines.append(f"  constant NUM_LINKS : natural := {gen.num_links};")
pkg_lines.append(f"  constant NUM_PACKAGES : natural := {len(packages)};")
pkg_lines.append(f"  constant PKG_LEN_MIN : natural := {MIN_LEN};")
pkg_lines.append(f"  constant PKG_LEN_MAX : natural := {MAX_LEN};")
pkg_lines.append("end package;")
pkg_lines.append("")
pkg_lines.append("package body hit_stream_pkg is")
pkg_lines.append("end package body;")

vhdl_text = "\n".join(pkg_lines)

out_path = Path("hit_stream_pkg_varlen.vhd")
out_path.write_text(vhdl_text)

# Also compute some stats to show the chosen lengths per link/package
lengths = { (p_idx, link_id): len(words) for p_idx, link_map in enumerate(packages) for link_id, (words, kvec) in link_map.items() }

print(len(vhdl_text.splitlines()), str(out_path), lengths)
