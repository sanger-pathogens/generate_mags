#!/usr/bin/env python3

import os
import sys

import os
import sys

def split_contig_depth_file(master_depth_path, output_dir):
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    # Paths
    abund_list_path = os.path.join(output_dir, "mb2_abund_list.txt")

    # Clean old abundance list if it exists
    if os.path.exists(abund_list_path):
        os.remove(abund_list_path)

    with open(master_depth_path, 'r') as f:
        raw_lines = [line.strip() for line in f.readlines()]

    # Skip lines with 'totalAvgDepth'
    lines = [line for line in raw_lines if "totalAvgDepth" not in line]

    if not lines:
        print("No valid lines found in the input file.")
        return

    header = lines[0].split('\t')
    sample_names = header[3:]  # Sample names start from column 4 (index 3)

    # Write one file per sample
    for i, sample in enumerate(sample_names, start=3):
        sample_base = os.path.splitext(sample)[0]
        sample_file = os.path.join(output_dir, f"mb2_{sample_base}.txt")

        with open(sample_file, 'w') as out_f:
            for line in lines:
                cols = line.split('\t')
                if len(cols) > i:  # Avoid index errors
                    out_f.write(f"{cols[0]}\t{cols[i]}\n")

        # Add absolute path to abundance list
        with open(abund_list_path, 'a') as abund_f:
            abund_f.write(f"{os.path.abspath(sample_file)}\n")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python split_depths.py <path/to/mb2_master_depth.txt> <output_directory>")
        sys.exit(1)

    master_depth_file = sys.argv[1]
    output_dir = sys.argv[2]

    split_contig_depth_file(master_depth_file, output_dir)
