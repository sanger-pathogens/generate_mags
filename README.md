# Metagenomic assembly nextflow pipeline

## Usage

```
Usage:
    nextflow run main.nf

Options:
    --manifest_of_reads / --manifest    Manifest containing paths to fastq files with headers ID,R1,R2. (mandatory)
    --skip_qc                           Skip metawrap qc step. [default: false] (optional)
    --keep_allbins                      Keep allbins option for bin refinement.. [default: false] (optional)
    --keep_assembly                     Don't cleanup assembly files. [default: false] (optional)
    --keep_binning                      Don't cleanup binning files. [default: false] (optional)
    --keep_bin_refinement               Don't cleanup bin refinement files. [default: false] (optional)
    --keep_reassembly                   Don't cleanup reassembly files. [default: false] (optional)
    --keep_metawrap_qc                  Don't cleanup metawrap qc files. [default: false] (optional)
    --skip_reassembly                   Skip reassembly step. [default: false] (optional)
    --fastspades                        Use fastspades assembly option. [default: false] (optional)
    --help                              Print this help message. (optional)
```

## Generating manifests

### On Wellcome Sanger Institute "farm" HPC

It is recommended to use the dedicated the farm module `manifest_generator`:

```
module load manifest_generator
generate_manifest.py -h # for script usage
```

Alternatively, you can use the scripts bundled with this repository (deprecated).

If your data is stored in the PaM informatics pipeline system, you can use the following method:

```
./generate_manifest_from_lanes.sh -l <lanes_file>
```

For more information, run:

```
./generate_manifest_from_lanes.sh -h
```

If your data is not stored in the PaM informatics pipeline system, use the following method:

### Step 1:

Obtain fastq paths:

```
ls -d -1 <path>/*.fastq.gz > fastq_paths.txt
```

### Step 2:

Generate manifest:

```
./generate_manifest.sh fastq_paths.txt
```

This will output the manifest to `manifest.csv` which can be fed into the nextflow pipeline

## Dependencies

This pipeline relies on the Nextflow and Singularity.

On the Sanger farm, these software dependencies can be accessed through loading the following modules:

```
nextflow/24.10.4
ISG/singularity/3.11.4
```
