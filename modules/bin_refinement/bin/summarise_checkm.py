#!/usr/bin/env python3

import sys
import ast

# This script summarizes the statistics of each bin by parsing 
# the checkm_folder/storage/bin_stats_ext.tsv file of the CheckM output

def main():
    args = sys.argv
    if len(args) == 3:
        binner = args[2]
        print("bin\tcompleteness\tcontamination\tGC\tlineage\tN50\tsize\tbinner")
    elif len(args) == 4:
        source = {}
        with open(args[3], 'w') as f:
            for line in f:
                cut = line.strip().split("\t")
                source[cut[0]] = cut[7]
        print("bin\tcompleteness\tcontamination\tGC\tlineage\tN50\tsize\tbinner")
    else:
        print("bin\tcompleteness\tcontamination\tGC\tlineage\tN50\tsize")

    with open(args[1], 'r') as f:
        for line in f:
            name, data_str = line.strip().split("\t", 1)
            dic = ast.literal_eval(data_str)

            if "__" in dic.get("marker lineage", ""):
                dic["marker lineage"] = dic["marker lineage"].split("__")[1]

            output = [
                name,
                f'{dic.get("Completeness", 0):.2f}'[:5],
                f'{dic.get("Contamination", 0):.2f}'[:5],
                f'{dic.get("GC", 0):.2f}'[:5],
                dic.get("marker lineage", ""),
                str(dic.get("N50 (contigs)", "")),
                str(dic.get("Genome size", ""))
            ]

            if len(args) == 3:
                output.append(binner)
            elif len(args) == 4:
                output.append(source.get(name, "NA"))

            print("\t".join(output))

if __name__ == "__main__":
    main()
