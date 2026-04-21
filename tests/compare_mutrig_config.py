#!/usr/bin/env python3
import json
import argparse
from collections import OrderedDict


def load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def flatten_reference_json(ref):
    """
    Convert hierarchical MUTRIG JSON into a flat ordered list:
    [(name, bits, inverted), ...]
    """

    defaults = ref["defaults"]
    flat = []

    # Global section (once)
    for name, entry in defaults["Global"].items():
        flat.append((name, entry["bits"], entry["inverted"]))

    # Channels section (replicated for 32 channels)
    for ch in range(32):
        for name, entry in defaults["Channels"].items():
            flat.append((f"{name}_{ch}", entry["bits"], entry["inverted"]))

    # TDC section (once)
    for name, entry in defaults["TDCs"].items():
        flat.append((name, entry["bits"], entry["inverted"]))

    # Footer section
    footer = defaults["Footer"]
    for name, entry in footer.items():

        if name == "coin_mat":
            for item in entry:
                flat.append(
                    (
                        f"coin_mat_{item['channel']}",
                        item["bits"],
                        item["inverted"],
                    )
                )
        else:
            flat.append((name, entry["bits"], entry["inverted"]))

    return flat


def flatten_generated_json(gen):
    """
    Convert MapConfigFromDB JSON into:
    [(name, bits, inverted), ...]
    """
    flat = []
    for entry in gen:
        flat.append(
            (
                entry["name"],
                entry["nbits"],
                entry["bits_inverted"],
            )
        )
    return flat


def compare_sequences(seq_a, seq_b):
    mismatches = []

    max_len = max(len(seq_a), len(seq_b))

    for i in range(max_len):
        if i >= len(seq_a):
            mismatches.append(
                {"index": i, "error": "missing_in_generated", "expected": seq_b[i]}
            )
            continue

        if i >= len(seq_b):
            mismatches.append(
                {"index": i, "error": "extra_in_generated", "actual": seq_a[i]}
            )
            continue

        name_a, bits_a, inv_a = seq_a[i]
        name_b, bits_b, inv_b = seq_b[i]

        entry = {"index": i}

        if name_a != name_b:
            entry["name_mismatch"] = {"generated": name_a, "reference": name_b}

        if bits_a != bits_b:
            entry["bits_mismatch"] = {"generated": bits_a, "reference": bits_b}

        if inv_a != inv_b:
            entry["inversion_mismatch"] = {
                "generated": inv_a,
                "reference": inv_b,
            }

        if len(entry) > 1:
            mismatches.append(entry)

    return mismatches


def main():
    parser = argparse.ArgumentParser(
        description="Compare MUTRIG JSON config ordering, bit widths, and inversion flags."
    )
    parser.add_argument("generated_json")
    parser.add_argument("reference_json")
    parser.add_argument("--report-json", default=None)

    args = parser.parse_args()

    generated = load_json(args.generated_json)
    reference = load_json(args.reference_json)

    gen_flat = flatten_generated_json(generated)
    ref_flat = flatten_reference_json(reference)

    mismatches = compare_sequences(gen_flat, ref_flat)

    print(f"Generated entries: {len(gen_flat)}")
    print(f"Reference entries: {len(ref_flat)}")

    if not mismatches:
        print("✅ No mismatches found.")
    else:
        print(f"❌ Found {len(mismatches)} mismatches:\n")
        for m in mismatches[:20]:
            print(m)

    if args.report_json:
        with open(args.report_json, "w") as f:
            json.dump(mismatches, f, indent=2)
        print(f"\n📄 Full report written to {args.report_json}")


if __name__ == "__main__":
    main()