#!/usr/bin/env python3
import sys
import textwrap

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <min_len> <input_fasta>", file=sys.stderr)
        sys.exit(1)

    min_len = int(sys.argv[1])
    input_fasta = sys.argv[2]
    contigs = {}
    tmp_contig = ""
    good = True
    name = ""

    with open(input_fasta, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            if line.startswith(">"):
                if tmp_contig and good:
                    contigs[name] = tmp_contig
                tmp_contig = ""

                parts = line[1:].split()
                length = int(parts[3].split("=")[1])
                coverage = parts[2].split("=")[1]
                good = length >= min_len
                name = f">{parts[0]}_length_{length}_cov_{coverage}"
            else:
                tmp_contig += line

    # Don't forget the last contig
    if tmp_contig and good:
        contigs[name] = tmp_contig

    # Sort and print
    for header in sorted(contigs, key=lambda k: len(contigs[k]), reverse=True):
        print(header)
        print(textwrap.fill(contigs[header], width=100, break_on_hyphens=False))

if __name__ == "__main__":
    main()
