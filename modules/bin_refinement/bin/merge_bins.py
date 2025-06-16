#!/usr/bin/env python3

"""
This script extends consolidate_two_sets_of_bins.py in python3.

Key differences and improvements over the original version:

1. Multiple Bin Sets:
   - The original script was limited to comparing exactly two bin sets.
   - This version supports *N* input bin sets, enabling more flexible integration of results from multiple binning methods.

2. Added data structures:
   - Uses clearer, modular data structures (e.g., dictionaries and named mappings) for readability and extensibility.
   - Facilitates easier debugging and future development.

3. Contig Comparison the same:
   - Maintains the core logic of comparing bins based on contig-level overlap by name and length.
   - Still computes the percentage of overlap between bin pairs and uses a threshold (e.g., 80%) to determine correspondence.

4. Scalable Pairwise Matching:
   - Replaces the hardcoded bin1-vs-bin2 matching loop with a dynamic framework for comparing all bin pairs across all methods.
   - Ensures that bins are not reused once assigned, preventing ambiguous assignments.

5. Cleaner Output Management:
   - Handles renaming, selection, and output of bins and associated `.stats` files in a structured and consistent manner.

This script selects the best bins across all input sets based on overlap and quality scores (completion - 5 × contamination),
favoring higher-quality, non-redundant bins.

Sam
"""


import sys
import os
import argparse
import logging
from pathlib import Path
import itertools
import shutil

class BinInfo:
    """Class to hold dataset information and bin data."""
    
    def __init__(self, dataset_name: str, dataset_idx: int, bin_folder: str, stats_file: str, good_bins: set):
        self.dataset_name = dataset_name
        self.dataset_idx = dataset_idx
        self.bin_folder = bin_folder
        self.stats_file = stats_file
        self.good_bins = good_bins
        
        # Will be populated later
        self.bins_data = {}  # contig data: {bin_name: {contig_name: length}}
        self.stats = {}      # completion, contamination: {bin_name: (completion, contamination)}
        self.summaries = {}  # original summary lines: {bin_name: line}
        self.discard_stats = None
    
    def load_contig_data(self):
        """Load contig information from bin files."""
        logging.info(f"Loading contig data from {self.dataset_name}: {self.bin_folder}")
        
        for bin_file in self.good_bins:
            bin_path = os.path.join(self.bin_folder, bin_file)
            if not os.path.exists(bin_path):
                logging.warning(f"Bin file not found: {bin_path}")
                continue
                
            self.bins_data[bin_file] = {}
            contig_len = 0
            contig_name = ""
            
            try:
                with open(bin_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line.startswith('>'):
                            # Save previous contig if exists
                            if contig_name:
                                self.bins_data[bin_file][contig_name] = contig_len
                                contig_len = 0
                            contig_name = line[1:]
                        else:
                            contig_len += len(line)
                    
                    # Save last contig
                    if contig_name:
                        self.bins_data[bin_file][contig_name] = contig_len
                        
            except Exception as e:
                logging.error(f"Error reading bin file {bin_path}: {e}")
                continue
        
        logging.info(f"Loaded contig data for {len(self.bins_data)} bins from {self.dataset_name}")
    
    def load_stats_data(self):
        """Load completion and contamination stats from stats file."""
        logging.info(f"Loading stats for {self.dataset_name}: {self.stats_file}")
        
        try:
            with open(self.stats_file, 'r') as f:
                for line in f:
                    if "completeness" in line.lower():
                        self.summaries["header"] = line
                        continue
                    
                    parts = line.strip().split('\t')
                    if len(parts) < 3:
                        continue
                        
                    try:
                        bin_name = parts[0] + '.fasta'

                        if bin_name not in self.good_bins:
                            continue

                        completion = float(parts[1])
                        contamination = float(parts[2])
                        
                        self.stats[bin_name] = (completion, contamination)
                        self.summaries[bin_name] = line
                    except (ValueError, IndexError) as e:
                        logging.warning(f"Error parsing stats line: {line.strip()} - {e}")
                        
        except FileNotFoundError:
            logging.error(f"Stats file not found: {self.stats_file}")
            sys.exit(1)
    
    def get_bin_score(self, bin_name: str) -> float:
        """Calculate bin quality score for a specific bin."""
        if bin_name in self.stats:
            completion, contamination = self.stats[bin_name]
            return completion - contamination * 5
        return 0.0
    
    def get_bin_path(self, bin_name: str) -> str:
        """Get full path to a bin file."""
        return os.path.join(self.bin_folder, bin_name)
    
    def get_bin_stats(self, bin_name: str) -> tuple:
        """Get completion and contamination for a bin."""
        return self.stats.get(bin_name, (0.0, 0.0))
    
    def __str__(self):
        return f"BinInfo({self.dataset_name}: {len(self.good_bins)} bins)"
    
    def __repr__(self):
        return self.__str__()


def setup_logging(log_level: str = 'INFO', log_file: str = 'merge.log') -> None:
    """Setup logging configuration to write to a file."""
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S',
        filename=log_file,
        filemode='w'
    )

def clean_name(checkm2_file: str, ID: str) -> str:
    """Strips prefixes/suffixes from the stats file name (for nicer dataset names in log/class)."""
    if checkm2_file.startswith(f"{ID}_"):
        checkm2_file = checkm2_file[len(ID)+1:]
    if checkm2_file.endswith("_checkm2_report.tsv"):
        checkm2_file = checkm2_file[:-len("_checkm2_report.tsv")]
    return checkm2_file

def load_good_bins(stats_file: str, min_completion: float, max_contamination: float, dataset_name: str):
    """
    Load bins that meet quality criteria and track discarded bins.
    Returns:
        good_bins: set of bins to keep.
        discard_stats: dict of counts (total, good, discarded).
    """
    good_bins = set()
    total_bins = 0
    discarded_bins = []
    try:
        with open(stats_file, 'r') as f:
            for line in f:
                if "completeness" in line.lower():
                    continue
                
                parts = line.strip().split('\t')
                if len(parts) < 3:
                    continue
                
                total_bins += 1
                    
                try:
                    bin_name = parts[0]
                    completion = float(parts[1])
                    contamination = float(parts[2])
                    
                    if completion > min_completion and contamination < max_contamination:
                        good_bins.add(bin_name + '.fasta')
                    else:
                        discarded_bins.append({
                            'bin': bin_name,
                            'completion': completion,
                            'contamination': contamination,
                            'reason': f"completion={completion:.1f}% (min={min_completion}%), contamination={contamination:.1f}% (max={max_contamination}%)"
                        })
                except (ValueError, IndexError) as e:
                    logging.warning(f"Error parsing line in {stats_file}: {line.strip()} - {e}")
                    
    except FileNotFoundError:
        logging.error(f"Stats file not found: {stats_file}")
        sys.exit(1)
    
    discarded_count = len(discarded_bins)
    logging.info(f"Dataset {dataset_name}: {len(good_bins)} good bins, {discarded_count} discarded bins (out of {total_bins} total)")
    
    if discarded_count > 0:
        logging.debug(f"Dataset {dataset_name} - Discarded bins breakdown:")
        for bin_info in discarded_bins:
            logging.debug(f"  - {bin_info['bin']}: {bin_info['reason']}")
    
    return good_bins, {'total': total_bins, 'good': len(good_bins), 'discarded': discarded_count}

def calculate_overlap(bin1_contigs: dict, bin2_contigs: dict) -> float:
    """
        Calculates overlap ratio between two bins' contigs:
        Ratio is computed in both directions and the maximum is returned.
        If two bins share many contigs, their overlap will be high.
    """
    # Find matching contigs and their lengths
    match_1_length = sum(bin1_contigs[contig] for contig in bin1_contigs if contig in bin2_contigs)
    match_2_length = sum(bin2_contigs[contig] for contig in bin2_contigs if contig in bin1_contigs)
    
    # Calculate mismatches
    mismatch_1_length = sum(bin1_contigs[contig] for contig in bin1_contigs if contig not in bin2_contigs)
    mismatch_2_length = sum(bin2_contigs[contig] for contig in bin2_contigs if contig not in bin1_contigs)
    
    # Calculate ratios
    total_1 = match_1_length + mismatch_1_length
    total_2 = match_2_length + mismatch_2_length
    
    if total_1 == 0 or total_2 == 0:
        return 0.0
    
    ratio_1 = 100 * match_1_length / total_1
    ratio_2 = 100 * match_2_length / total_2
    
    return max(ratio_1, ratio_2)

def compare_all_bins(datasets: list) -> dict:
    """
        Compare all bins pairwise across all datasets using BinInfo objects.
        results in nested dict comparisons[(dataset1, bin1)][(dataset2, bin2)] = overlap
    """
    comparisons = {}
    
    # Create all pairwise comparisons between different datasets
    for i, dataset_i in enumerate(datasets):
        for j, dataset_j in enumerate(datasets):
            if i >= j:  # Only compare each pair once
                continue
                
            logging.info(f"Comparing bins between {dataset_i.dataset_name} and {dataset_j.dataset_name}")
            
            for bin_i in dataset_i.bins_data:
                bin_key_i = (dataset_i, bin_i)
                if bin_key_i not in comparisons:
                    comparisons[bin_key_i] = {}
                
                for bin_j in dataset_j.bins_data:
                    bin_key_j = (dataset_j, bin_j)
                    overlap = calculate_overlap(dataset_i.bins_data[bin_i], dataset_j.bins_data[bin_j])
                    comparisons[bin_key_i][bin_key_j] = overlap
                    
                    # Also store reverse comparison
                    if bin_key_j not in comparisons:
                        comparisons[bin_key_j] = {}
                    comparisons[bin_key_j][bin_key_i] = overlap
    
    return comparisons

def merge_bins(args) -> None:
    """Main function to merge the best bins using BinInfo objects."""
    if len(args.bin_folders) != len(args.stats_files):
        logging.error("Number of bin folders must match number of stats files")
        sys.exit(1)
    
    datasets = []
    all_discard_stats = []
    
    for i, (bin_folder, stats_file) in enumerate(zip(args.bin_folders, args.stats_files)):
        dataset_name = clean_name(stats_file, args.id) if args.id else f"dataset_{i+1}"
        
        logging.info(f"Processing {dataset_name}: {stats_file} - {bin_folder}")
        
        # Load good bins
        good_bins, discard_stats = load_good_bins(stats_file, args.min_completion, args.max_contamination, dataset_name)
        
        # Create dataset object
        dataset = BinInfo(
            dataset_name=dataset_name,
            dataset_idx=i,
            bin_folder=bin_folder,
            stats_file=stats_file,
            good_bins=good_bins
        )
        
        # Load all data
        dataset.load_contig_data()
        dataset.load_stats_data()
        
        datasets.append(dataset)
        all_discard_stats.append(discard_stats)
    
    total_discarded = sum(stats['discarded'] for stats in all_discard_stats)
    total_bins = sum(stats['total'] for stats in all_discard_stats)
    logging.info(f"DISCARD SUMMARY: {total_discarded} bins discarded out of {total_bins} total bins across all datasets\n{'-'*120}")
    
    logging.info("Performing pairwise comparisons between all datasets")
    comparisons = compare_all_bins(datasets)
    
    # Create output directory
    output_path = Path(args.output_folder)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Merge best bins
    logging.info("Merging best bins")
    new_summary_lines = []
    bin_counter = 1
    
    # add source to tsv
    if datasets and "header" in datasets[0].summaries:
        original_header = datasets[0].summaries["header"].strip()
        enhanced_header = original_header + "\tsource_dataset\tsource_bin\n"
        new_summary_lines.append(enhanced_header)
    
    # Process each bin and find its best version across all datasets
    selected_bins = set()
    
    for dataset in datasets:
        for bin_name in dataset.bins_data:
            bin_key = (dataset, bin_name)
            
            if bin_key in selected_bins:
                continue
            
            similar_bins = [bin_key]
            best_bin = bin_key
            best_score = dataset.get_bin_score(bin_name)
            
            # Check for overlapping bins in other datasets
            if bin_key in comparisons:
                for other_bin_key, overlap in comparisons[bin_key].items():
                    if overlap >= args.min_overlap:
                        other_dataset, other_bin_name = other_bin_key
                        other_score = other_dataset.get_bin_score(other_bin_name)
                        
                        if other_score > best_score:
                            best_bin = other_bin_key
                            best_score = other_score
                        
                        similar_bins.append(other_bin_key)
            
            # Mark all similar bins as processed
            for sim_bin in similar_bins:
                selected_bins.add(sim_bin)
            
            # Copy the best bin to output
            best_dataset, best_bin_name = best_bin
            source_path = best_dataset.get_bin_path(best_bin_name)
            dest_path = output_path / f"bin.{bin_counter}.fasta"
            
            shutil.copy2(source_path, dest_path)
            
            # Add to summary with source tracking
            if best_bin_name in best_dataset.summaries:
                original_line = best_dataset.summaries[best_bin_name]
                parts = original_line.strip().split('\t')
                
                # Create new line with source information
                source_bin = best_bin_name.replace('.fasta', '')
                new_line = f"bin.{bin_counter}\t" + "\t".join(parts[1:]) + f"\t{best_dataset.dataset_name}\t{source_bin}\n"
                new_summary_lines.append(new_line)
            
            logging.debug(f"Selected bin.{bin_counter}.fasta from {best_dataset.dataset_name}/{source_bin} (score: {best_score:.2f})")
            bin_counter += 1
    
    summary_path = output_path.with_suffix('.stats')
    try:
        with open(summary_path, 'w') as f:
            f.writelines(new_summary_lines)
        logging.info(f"Summary written to {summary_path}")
    except Exception as e:
        logging.error(f"Error writing summary file: {e}")
    
    total_bins_output = bin_counter - 1
    logging.info(f"Merged {total_bins_output} bins from {len(datasets)} datasets")
    logging.info(f"Output written to {output_path}")
    logging.info(f"Total bins processed: {total_bins}, discarded: {total_discarded}, merged: {total_bins_output}")
    
    # Print dataset summary
    logging.info("Dataset summary:")
    for dataset in datasets:
        logging.info(f"  {dataset.dataset_name}: {len(dataset.good_bins)} good bins from {dataset.bin_folder}")


def main():
    parser = argparse.ArgumentParser(
        description='Merge the best bins from multiple binning methods based on CheckM2 stats',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
            This script compares bins from multiple binning methods and selects the best version
            of each bin based on completion and contamination scores. Bins are matched based on
            contig overlap (default 80% minimum overlap).

            Example: ./merge_bins.py -b bin_folder1 bin_folder2 -s stats1.tsv stats2.tsv -o output_folder
        '''
    )
    parser.add_argument('-b', '--bin-folders', nargs='+', required=True, help='List of bin folders to compare')
    parser.add_argument('-s', '--stats-files', nargs='+', required=True, help='List of CheckM2 stats files corresponding to bin folders')
    parser.add_argument('-o', '--output-folder', required=True, help='Output folder for merged bins')
    parser.add_argument('-c', '--min-completion', type=float, default=70.0, help='Minimum completion percentage (default: 70.0)')
    parser.add_argument('-x', '--max-contamination', type=float, default=10.0, help='Maximum contamination percentage (default: 10.0)')
    parser.add_argument('-m', '--min-overlap', type=float, default=80.0, help='Minimum overlap percentage for bin matching (default: 80.0)')
    parser.add_argument('-i', '--id', type=str, help='ID to remove from stats TSV to name bins')
    parser.add_argument('-l', '--log', help='log file name')
    parser.add_argument('--log-level', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], default='INFO', help='Set logging level (default: INFO)')
    
    args = parser.parse_args()
    setup_logging(args.log_level, args.log)
    
    logging.info("Starting bin merging process")
    logging.info(f"Input datasets: {len(args.bin_folders)}")
    logging.info(f"Quality criteria: >{args.min_completion}% completion, <{args.max_contamination}% contamination")
    logging.info(f"Minimum overlap: {args.min_overlap}%")
    
    try:
        merge_bins(args)
        logging.info("Bin merging completed successfully")
    except Exception as e:
        logging.error(f"Error during processing: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()