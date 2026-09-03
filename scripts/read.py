#!/usr/bin/env python3
import argparse

def combine_files(file1, file2, outfile):
    CHUNK_SIZE = 256 * 256

    with open(file1, "rb") as f1, open(file2, "rb") as f2, open(outfile, "wb") as fout:
        while True:
            b1 = f1.read(CHUNK_SIZE)
            b2 = f2.read(CHUNK_SIZE)

            # End of both files
            if not b1 and not b2:
                break

            # If sizes differ, that's probably an error for this use case
            if len(b1) != len(b2):
                raise ValueError("Input files have different sizes!")

            out_chunk = bytearray(len(b1))

            for i, (x, y) in enumerate(zip(b1, b2)):

                if x == 0 or y == 0:
                    out_chunk[i] = 0
                elif x == 0x40:
                    out_chunk[i] = 0x47
                else:
                    out_chunk[i] = x

            fout.write(out_chunk)


def main():
    parser = argparse.ArgumentParser(
        description="Combine two binary mask files: output 0x47 where either input has 0x47 or 0x40."
    )
    parser.add_argument("file1", help="First input file")
    parser.add_argument("file2", help="Second input file")
    parser.add_argument("outfile", help="Output file")

    args = parser.parse_args()
    combine_files(args.file1, args.file2, args.outfile)


if __name__ == "__main__":
    main()
