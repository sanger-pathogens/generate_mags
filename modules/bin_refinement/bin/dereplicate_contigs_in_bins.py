#!/usr/bin/env python3
import sys
import os

# Usage: ./script.py bins.stats binsFolder outFolder

# Load in bin completion and contamination scores
print("Loading in bin completion and contamination scores...")
bin_scores = {}
with open(sys.argv[1]) as f:
    for line in f:
        if "Completeness" in line:
            continue
        cut = line.strip().split("\t")
        score = float(cut[1]) - 5 * float(cut[2]) + 0.0000000001 * float(cut[5])
        bin_scores[cut[0]] = score

# Load in contigs in each bin
print("Loading in contigs in each bin...")
contig_mapping = {}
for bin_file in os.listdir(sys.argv[2]):
    bin_name = ".".join(bin_file.split("/")[-1].split(".")[:-1])
    with open(os.path.join(sys.argv[2], bin_file)) as f:
        for line in f:
            if not line.startswith(">"):
                continue
            contig = line[1:].strip()
            if contig not in contig_mapping:
                contig_mapping[contig] = bin_name
            else:
                if len(sys.argv) > 4 and sys.argv[4] == "remove":
                    contig_mapping[contig] = None
                elif bin_scores.get(bin_name, 0) > bin_scores.get(contig_mapping[contig], 0):
                    contig_mapping[contig] = bin_name

# Go over the bin files again and make a new dereplicated version of each bin file
print("Making a new dereplicated version of each bin file")
os.makedirs(sys.argv[3], exist_ok=True)

for bin_file in os.listdir(sys.argv[2]):
    bin_name = ".".join(bin_file.split("/")[-1].split(".")[:-1])
    input_path = os.path.join(sys.argv[2], bin_file)
    output_path = os.path.join(sys.argv[3], bin_file)
    
    with open(input_path) as infile, open(output_path, 'w') as out:
        at_least_one = False
        store = False
        for line in infile:
            if line.startswith(">"):
                contig = line[1:].strip()
                if contig_mapping.get(contig) == bin_name:
                    at_least_one = True
                    store = True
                else:
                    store = False
            if store:
                out.write(line)
    
    if not at_least_one:
        os.remove(output_path)
