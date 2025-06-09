#!/usr/bin/env python3
import sys

if len(sys.argv) < 3:
    print("Usage: rm_short_contigs.py <min_len> <filename>")
    sys.exit(1)

min_len = int(sys.argv[1])
filename = sys.argv[2]

with open(filename) as f:
    for line in f:
        if not line.startswith(">"):
            print(line.strip())
        else:
            try:
                value = int(line.split("_")[3])
            except (IndexError, ValueError):
                print(f"Warning: Couldn't parse integer from line: {line.strip()}", file=sys.stderr)
                continue

            if value < min_len:
                break
            else:
                print(line.strip())
