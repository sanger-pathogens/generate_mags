#!/usr/bin/env python3

import sys
import gzip
import argparse
import logging

def open_fastq(filename):
    return gzip.open(filename, "rt") if filename.endswith(".gz") else open(filename, "r")

def strip_suffix(header):
    """Removes `.1` or `.2` at the end of the first word in the header."""
    parts = header.strip().split()
    id_part = parts[0].rsplit('.', 1)[0] if parts[0].endswith(('.1', '.2')) else parts[0]
    return ' '.join([id_part] + parts[1:])

def fix_headers(infile, outfile):
    with open_fastq(infile) as fin, open(outfile, "w") as fout:
        while True:
            lines = [fin.readline() for _ in range(4)]
            if not lines[0]:
                break  # EOF
            lines[0] = strip_suffix(lines[0]) + '\n'
            fout.writelines(lines)

def headers_match(file1, file2, max_reads=None):
    mismatch_count = 0
    with open_fastq(file1) as f1, open_fastq(file2) as f2:
        read_idx = 0
        while True:
            h1 = f1.readline()
            h2 = f2.readline()
            if not h1 or not h2:
                break  # EOF

            if read_idx % 4 == 0:
                id1 = strip_suffix(h1)
                id2 = strip_suffix(h2)
                if id1 != id2:
                    logging.warning(f"Mismatch at read {read_idx//4}: {h1.strip()} vs {h2.strip()}")
                    mismatch_count += 1
                    if mismatch_count >= 1:
                        return False
            else:
                f1.readline()
                f2.readline()
                f1.readline()
                f2.readline()
                f1.readline()
                f2.readline()
            read_idx += 1
            if max_reads and (read_idx // 4) >= max_reads:
                break
    return True

def main():
    parser = argparse.ArgumentParser(
        description="Validate and fix paired-end FASTQ headers by removing .1/.2 suffixes if needed."
    )
    parser.add_argument("reads1", help="FASTQ file for read 1 (can be .gz)")
    parser.add_argument("reads2", help="FASTQ file for read 2 (can be .gz)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("-o", "--output-prefix", default="fixed_", help="Prefix for fixed output files")

    args = parser.parse_args()
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO)

    r1_out = args.output_prefix + args.reads1.replace(".gz", "")
    r2_out = args.output_prefix + args.reads2.replace(".gz", "")

    logging.info("Checking header consistency...")
    if headers_match(args.reads1, args.reads2):
        logging.info("Headers match — no fix needed.")
    else:
        logging.info("Fixing headers...")
        fix_headers(args.reads1, r1_out)
        fix_headers(args.reads2, r2_out)
        logging.info(f"Fixed files written to: {r1_out} and {r2_out}")

if __name__ == "__main__":
    main()
