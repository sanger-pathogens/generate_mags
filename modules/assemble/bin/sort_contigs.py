#!/usr/bin/env python3
import sys
import textwrap
import argparse

def parse_fasta(filepath):
    """Parses a FASTA file and returns a dict of {header: sequence}."""
    contigs = {}
    name = ""
    seq = []

    with open(filepath, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if name:
                    contigs[name] = ''.join(seq)
                name = line
                seq = []
            else:
                seq.append(line)
        if name:
            contigs[name] = ''.join(seq)

    return contigs

def combine_fastas(fasta_files, min_contig=0):
    """Combines multiple FASTA files, filters by min_contig."""
    combined = {}
    for file in fasta_files:
        contigs = parse_fasta(file)
        for header, seq in contigs.items():
            if len(seq) >= min_contig:
                combined[header] = seq
    return combined

def print_sorted_contigs(contigs, line_width=100):
    """Prints contigs sorted by length, formatted."""
    for header in sorted(contigs, key=lambda k: len(contigs[k]), reverse=True):
        print(header)
        print(textwrap.fill(contigs[header], width=line_width, break_on_hyphens=False))

def main():
    parser = argparse.ArgumentParser(description="Combine and sort contigs from multiple FASTA files.")
    parser.add_argument("fastas", nargs="+", help="Input FASTA files")
    parser.add_argument("--min_contig", type=int, default=0, help="Minimum contig length to include (default: 0)")

    args = parser.parse_args()
    combined_contigs = combine_fastas(args.fastas, min_contig=args.min_contig)
    
    if not combined_contigs:
        print(f"No contigs passed the length filter (min_contig = {args.min_contig}).", file=sys.stderr)
        sys.exit(1)

    print_sorted_contigs(combined_contigs)

if __name__ == "__main__":
    main()
