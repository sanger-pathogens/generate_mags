#!/usr/bin/env python3

import pandas as pd
import argparse
import logging
import sys
from pathlib import Path

def setup_logging(log_file='qc_merge.log'):
    logging.basicConfig(
        filename=log_file,
        filemode='w',
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    logging.info("Logging initialized.")

def read_tsv(path, name):
    try:
        df = pd.read_csv(path, sep='\t')
        logging.info(f"{name} loaded successfully: {path}")
        return df
    except Exception as e:
        logging.error(f"Error reading {name} from {path}: {e}")
        sys.exit(f"Error reading {name}: {e}")

def process_checkm2(df, qc_stage):
    return df.rename(columns={
        'genome': 'genome_name_preqc',
        'checkm2_completeness': f'{qc_stage}_completeness',
        'checkm2_contamination': f'{qc_stage}_contamination'
    })[['genome_name_preqc', f'{qc_stage}_completeness', f'{qc_stage}_contamination']]

def process_gunc(df, qc_stage):
    return df.rename(columns={
        'genome': 'genome_name_preqc',
        'pass.GUNC': f'{qc_stage}_gunc_pass_or_fail'
    })[['genome_name_preqc', f'{qc_stage}_gunc_pass_or_fail']]

def process_mapping(df):
    expected_cols = ['genome_name_preqc', 'genome_name_postqc', 'mdm_cleaner_status', 'final_qc_status']
    for col in expected_cols:
        if col not in df.columns:
            logging.warning(f"Missing column in mapping file: {col}")
            df[col] = 'NA'
    return df[expected_cols]

def enrich_fields(df):
    df['sample_or_strain_name'] = df['genome_name_preqc'].apply(lambda x: x.split("_")[0])
    df['genome_status'] = df['genome_name_preqc'].apply(lambda x: "mag" if "MAG" in x.upper() else "isolate")
    df['genome_size'] = 'NA'         # Placeholder
    df['gtdbtk_taxonomy'] = 'NA'     # Placeholder
    df['contig_count'] = 'NA'        # Placeholder
    return df

def merge_all(mapping_df, pre_checkm2, pre_gunc, post_checkm2, post_gunc):
    df = mapping_df.copy()
    for other_df in [pre_checkm2, pre_gunc, post_checkm2, post_gunc]:
        df = df.merge(other_df, on='genome_name_preqc', how='left')
    df = enrich_fields(df)
    return df

def parse_args():
    parser = argparse.ArgumentParser(description="Merge GUNC, CheckM2 and post-QC metadata.")
    parser.add_argument('--pre_qc_checkm2', required=True, help='Path to pre-QC CheckM2 TSV')
    parser.add_argument('--pre_qc_gunc', required=True, help='Path to pre-QC GUNC TSV')
    parser.add_argument('--post_qc_checkm2', required=True, help='Path to post-QC CheckM2 TSV')
    parser.add_argument('--post_qc_gunc', required=True, help='Path to post-QC GUNC TSV')
    parser.add_argument('--postqc_mapping', required=True, help='Path to post-QC mapping TSV')
    parser.add_argument('--output', required=True, help='Output TSV path')
    return parser.parse_args()

def main():
    setup_logging()
    args = parse_args()

    pre_checkm2 = process_checkm2(read_tsv(args.pre_qc_checkm2, "Pre-QC CheckM2"), "preqc")
    pre_gunc = process_gunc(read_tsv(args.pre_qc_gunc, "Pre-QC GUNC"), "preqc")
    post_checkm2 = process_checkm2(read_tsv(args.post_qc_checkm2, "Post-QC CheckM2"), "postqc")
    post_gunc = process_gunc(read_tsv(args.post_qc_gunc, "Post-QC GUNC"), "postqc")
    mapping = process_mapping(read_tsv(args.postqc_mapping, "Post-QC Mapping"))

    merged = merge_all(mapping, pre_checkm2, pre_gunc, post_checkm2, post_gunc)

    output_cols = [
        'genome_name_preqc',
        'genome_name_postqc',
        'sample_or_strain_name',
        'genome_status',
        'genome_size',
        'gtdbtk_taxonomy',
        'contig_count',
        'final_qc_status',
        'preqc_completeness',
        'preqc_contamination',
        'preqc_gunc_pass_or_fail',
        'postqc_completeness',
        'postqc_contamination',
        'postqc_gunc_pass_or_fail',
        'mdm_cleaner_status'
    ]
    for col in output_cols:
        if col not in merged.columns:
            merged[col] = 'NA'

    merged[output_cols].to_csv(args.output, sep='\t', index=False)
    logging.info(f"Merged QC report written to: {args.output}")

if __name__ == '__main__':
    main()
