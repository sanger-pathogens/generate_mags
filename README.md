# Metagenomic assembly nextflow pipeline

## Usage
```
Usage:
    nextflow run main.nf

Options:
    --manifest                   Manifest containing paths to fastq files with headers ID,R1,R2. (mandatory)
    --skip_qc                    Skip metawrap qc step. [default: false] (optional)
    --keep_allbins               Keep all bins from bin refinement, instead of best one only. [default: false] (optional)
    --keep_assembly              Save initial SPAdes assembly files. [default: false] (optional)
    --keep_binning               Save first-pass binning files. [default: false] (optional)
    --cleanup_assembly           Cleanup assembly files from work/ subfolders. [default: true] (optional)
    --cleanup_binning            Cleanup binning files from work/ subfolders. [default: true] (optional)
    --cleanup_bin_refinement     Cleanup bin refinement files from work/ subfolders. [default: true] (optional)
    --cleanup_reassembly         Cleanup reassembly files from work/ subfolders. [default: true] (optional)
    --cleanup_metawrap_qc        Cleanupp metawrap qc files from work/ subfolders. [default: true] (optional)
    --skip_reassembly            Skip reassembly step. [default: false] (optional)
    --fastspades                 Use fastspades assembly option. [default: false] (optional)
    --help                       Print this help message. (optional)
```

## Generating manifests

If your data is stored in the PaM informatics pipeline system, you can use the following method:

`./generate_manifest_from_lanes.sh -l <lanes_file>`

For more information, run:
`./generate_manifest_from_lanes.sh -h`

If your data is not stored in the PaM informatics pipeline system, use the following method:
### Step 1:
Obtain fastq paths:
`ls -d -1 <path>/*.fastq.gz > fastq_paths.txt`
### Step 2:
Generate manifest:
`./generate_manifest.sh fastq_paths.txt`

This will output the manifest to `manifest.csv` which can be fed into the nextflow pipeline

## Dependencies
This pipeline relies on the following modules:
```
ISG/singularity/3.6.4
nextflow/22.10.6-5843
```