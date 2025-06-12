#!/usr/bin/env python3
# Takes in the clustering_gt1000.csv file from CONCOCT binning, and splits the contigs into proper bins
# Usage:
# ./script clustering_gt1000.csv assembly_file.fa out_folder

import sys
import os

print("Loading in the bins that the contigs belong to...")
bins = {}
with open(sys.argv[1]) as bin_file:
    for line in bin_file:
        if line.startswith("contig_id"):
            continue
        bins[line.strip().split(",")[0].split(".")[0]] = line.strip().split(",")[1]

print("Going through the entire assembly and splitting contigs into their respective bin file...")
current_bin = ""
f = None
with open(sys.argv[2]) as assembly_file:
    for line in assembly_file:
        if line.startswith(">"):
            if f:
                f.close()
            contig = line[1:-1].split(".")[0].split()[0]
            line = line.rsplit()[0] + "\n"
            if contig in bins:
                current_bin = f"bin.{bins[contig]}.fa"
            else:
                current_bin = "unbinned.fa"
            f = open(os.path.join(sys.argv[3], current_bin), 'a')
        f.write(line)

if f:
    f.close()

print("Done!")
