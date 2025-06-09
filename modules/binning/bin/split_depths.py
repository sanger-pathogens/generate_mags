import argparse
import logging
from pathlib import Path

def split_depth_file(master_depth_file: Path, output_file: Path):
    lines = master_depth_file.read_text().splitlines()
    header = lines[0].strip().split()
    data_lines = lines[1:]

    num_columns = len(header)
    logging.info(f"Header has {num_columns} columns. Splitting per-sample files")

    for i in range(4, num_columns + 1):
        with output_file.open("w") as f_out:
            for line in data_lines:
                if "totalAvgDepth" in line:
                    continue
                fields = line.strip().split("\t")
                if len(fields) < i:
                    logging.warning(f"Skipping line with insufficient columns: {line.strip()}")
                    continue
                f_out.write(f"{fields[0]}\t{fields[i - 1]}\n")

        with abund_list_file.open("a") as f_abund:
            f_abund.write(f"{output_file}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Split jgi_summarize_bam_contig_depths output for MaxBin2.")
    parser.add_argument("depth", required=True, help="Path to the depth file produced by jgi_summarize_bam_contig_depths")
    parser.add_argument("output", required=True, help="Path to emit final file to")

    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s"
    )

    if not Path(args.depth).is_file():
        logging.error(f"File not found: {args.depth}")
        exit(1)

    try:
        split_depth_file(args.depth)
    except Exception as e:
        logging.error(f"Failed to split depth file: {e}")
        exit(1)
