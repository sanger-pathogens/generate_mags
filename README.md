# generate_mags

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[[_TOC_]]

## Introduction

**generate_mags** is a nextflow pipeline that (unsurpisingly) generates MAGs (Metagenome-Assembled Genomes). It is based on `metawrap assembly` (https://github.com/bxlab/metaWRAP).

## Pipeline summary

There are 5 stages in this pipeline: QC, assembly, binning, bin refinement, and bin reassembly.

## Getting started

### Running on the farm (Sanger HPC clusters)

1. Load nextflow and singularity modules:

   ```bash
   module load nextflow ISG/singularity
   ```

2. Either:

   - Clone this repository using `git clone --recurse-submodules`  
     OR
   - Use ready-made module: `module load generate_mags`  
     :warning: If using the read-made module, replace `nextflow run main.nf` with `generate_mags` in all subsequent commands.

3. Start the pipeline  
   For example input, please see [Generating a manifest](#generating-a-manifest).

   Example:

   ```bash
   nextflow run main.nf --manifest ./test_data/inputs/test_manifest.csv --outdir my_output
   ```

   It is good practice to submit a dedicated job for the nextflow master process (use the `oversubscribed` queue):

   ```bash
   bsub -o output.o -e error.e -q oversubscribed -R "select[mem>4000] rusage[mem=4000]" -M4000 nextflow run . --manifest ./test_data/inputs/test_manifest.csv --outdir my_output
   ```

   See [usage](#usage) for all available pipeline options.

4. Once your run has finished, check output in the `outdir` and clean up any intermediate files. To do this (assuming no other pipelines are running from the current working directory) run:

   ```bash
   rm -rf work .nextflow*
   ```

> :warning:
> It is strongly recommended that you don't run more than 100 samples at a time through this pipeline to reduce vulnerabilities to transient errors - e.g. LSF and I/O errors.

### Other supported environments

Currently, you can also run this pipeline on a dedicated host machine containing docker (using `-profile docker`) or (`-profile singularity`). No other environments are natively supported at this time.

## Generating a manifest

This pipeline has several input parameters that allow read data to be retrieved locally, from the ENA, and from iRODS. Further detail can be found by using the pipeline `--help` parameter, or [here](./assorted-sub-workflows/README.md).

### Generating a manifest on the farm (Sanger HPC clusters)

It is recommended to use the dedicated the farm module `manifest_generator`:

```
module load manifest_generator
generate_manifest.py -h # for script usage
```

## Usage

```
Sequencing reads input parameters

There are two ways of providing input reads, which can be combined
      1) through direct input of compressed fastq sequence reads files. This kind of input is passed by specifying the paths to the
      read files via a manifest listing the pair of read files pertaining to a sample, one per row.

      --manifest_of_reads
            default: false
            Manifest containing per-sample paths to .fastq.gz files (optional)

      2) through specification of data to be downloaded from iRODS.
      The selected set of data files is defined by a combination of parameters: studyid, runid, laneid, plexid, target and type (these refer to specifics of the sequencing experiment and data to be retrieved).
      Each parameter restricts the set of data files that match and will be downloaded; when omitted, samples for all possible values of that parameter are retrieved.
      At least one of studyid or runid parameters must be specified. laneid/plexid/target/type are optional parameters that can be provided only in combination with studyid or runid;
      if these are specified without a studyid or runid, the request will be ignored (no iRODS data or metadata download) with a warning
      - this condition aims to avoid indiscriminate download of thousands of files across all possible runs.
      These parameters can be specified through the following command line options: --studyid, --runid, --laneid, --plexid, --target and --type.

      --studyid
            default: -1
            Sequencing Study ID
      --runid
            default: -1
            Sequencing Run ID
      --laneid
            default: -1
            Sequencing Lane ID
      --plexid
            default: -1
            Sequencing Plex ID
      --target
            default: 1
            Marker of key data product likely to be of interest to customer
      --type
            default: cram
            File type

Alternatively, the user can provide a CSV-format manifest listing a batch of such combinations.

      --manifest_of_lanes
            default: false
            Path to a manifest of search terms as specified above.
            At least one of studyid or runid fields, or another field that matches the list of iRODS metadata fields must be specified; other parameters are not mandatory and corresponding
            fields in the CSV manifest file can be left blank. laneid/plexid are only considered when provided alongside a studyid or runid. target/type are only considered in combination with studyid, runid, or other fields.

            Example of manifest 1:
                studyid,runid,laneid,plexid
                ,37822,2,354
                5970,37822,,332
                5970,37822,2,

            Example of manifest 2:
                sample_common_name,type,target
                Romboutsia lituseburensis,cram,1
                Romboutsia lituseburensis,cram,0
      --manifest_ena
            default: false
            Path to a manifest/file of ENA accessions (run, sample or study). Please also set the --accession_type to the appropriate accession type.
-----------------------------------------------------------------
 Aliased options
      --manifest
            default:
            Alias for --manifest_of_reads (optional)
-----------------------------------------------------------------
 Irods extractor processing options
      --cleanup_intermediate_files_irods_extractor
            default: false
            delete intermediate CRAM files downloaded from IRODS in work/ folder
      --preexisting_fastq_tag
            default: raw_fastq
            if the expected output fastq files exist in the folder named like this under the result folder for the sample e.g. in results/12345_1#67/raw_fastq/12345_1#67_1.fastq.gz,
            then skip download and any further processing for this sample.
      --split_sep_for_ID_from_fastq
            default: _1.fastq
            separator to recognise sample ID from preexisting file.
      --lane_plex_sep
            default: #
            separator to build sample ID from runid, laneid and plexid. Defaults to '#', which is the iRODS-native syntax.
      --save_method
            default: nested
            save output files in per sample folders (nested) or in one folder (flat)
      --irods_subset_to_skip
            default: phix
            skip data items for which metadata field 'subset' is set to this value
      --combine_same_id_crams
            default: false
            if retrieving read files representing subsets of the same source (files will share the same run, lane and plex IDs), should these files be combined into a 'total' subset i.e. reforming the source read file before subsetting by NPG processing.
      --large_data
            default: false
            If the data is very large instead start from the week queue with more memory (10GB)
      --read_type
            default: Illumina
            Platform the data you wish to receive was sequenced on Illumina|ont
-----------------------------------------------------------------
 General Options
      --manifest
            default:
            Manifest containing paths to fastq files with headers ID,R1,R2. (mandatory)

      --outdir
            default: ./results
            Directory to store pipeline output.

-----------------------------------------------------------------
 Quality Control Options
      --skip_qc
            default: false
            Skip metawrap QC step. (optional)

      --keep_metawrap_qc
            default: false
            Don't cleanup metawrap QC files. (optional)

-----------------------------------------------------------------
 Binning and Assembly Options
      --keep_allbins
            default: false
            Don't cleanup bin refinement files. (optional)

      --keep_assembly
            default: false
            Don't cleanup assembly files. (optional)

      --keep_binning
            default: false
            Don't cleanup binning files. (optional)

-----------------------------------------------------------------
 Reassembly Options
      --keep_reassembly
            default: false
            Don't cleanup reassembly files. (optional)

      --skip_reassembly
            default: false
            Skip reassembly step. (optional)

-----------------------------------------------------------------
 Additional Options
      --fastspades
            default: false
            Use fastspades assembly option. (optional)

      --help
            default: false
            Print this help message. (optional)

-----------------------------------------------------------------
```

## Output and intermediate file cleanup

By default, this pipeline will publish the results to a `results` folder, this can be changed using the `--outdir` argument. There are 5 stages in this pipeline: QC, assembly, binning, bin refinement, and bin reassembly and output folders are related to each of these.

:warning: By default, this pipeline will cleanup intermediate files to save disk space. This means that the `-resume` option will not work with this pipeline unless the cleanup processes are turned off. You must use some `--keep*` options to retain useful output!!

For instance, the output directory could look like:

```
example_generate_mags_output
├── <sample_id>_bin_refinement_outdir
│   ├── concoct_bins
│   │   ├── bin.0.fa
│   │   ├── bin.1.fa
│   │   ├── ...
│   │   └── bin.N.fa
│   ├── concoct_bins.contigs
│   ├── concoct_bins.stats
│   ├── maxbin2_bins
│   │   ├── bin.0.fa
│   │   ├── bin.1.fa
│   │   ├── ...
│   │   └── bin.N.fa
│   ├── maxbin2_bins.contigs
│   ├── maxbin2_bins.stats
│   ├── metabat2_bins
│   │   ├── bin.0.fa
│   │   ├── bin.1.fa
│   │   ├── ...
│   │   └── bin.N.fa
│   │   └── bin.unbinned.fa
│   ├── metabat2_bins.contigs
│   ├── metabat2_bins.stats
│   ├── metawrap_50_5_bins
│   │   ├── bin.0.fa
│   │   ├── bin.1.fa
│   │   ├── ...
│   │   └── bin.N.fa
│   ├── metawrap_50_5_bins.contigs
│   └── metawrap_50_5_bins.stats
├── <sample_id>_reassemble_bins_outdir
│   ├── <sample_id>_bin.1.<orig|strict|permissive>.fa
│   ├── <sample_id>_bin.2.<orig|strict|permissive>.fa
│   ├── ...
│   ├── <sample_id>_bin.N.<orig|strict|permissive>.fa
│   └── <sample_id>_reassembled_bins.stats
├── <sample_id>_saved_raw_assemblies
│   ├── <sample_id>_assembly_graph_with_scaffolds.gfa
│   ├── <sample_id>_megahit_final.contigs.fa
│   ├── <sample_id>_metaspades_contigs.fasta
│   └── <sample_id>_scaffolds.fasta
├── <sample_id>_saved_raw_bins
└── metawrap_qc
    ├── read_removal_statistics.csv
    ├── host_reads
    └── cleaned_reads
```

Output folders are described in the following table:
| folder | description |
| --------- | --------------------------------------------------------- |
| metawrap_qc | Contains host reads (fastq.gz) and cleaned/host-removed sample reads (fastq.gz), as well as `read_removal_statistics.csv` generated during the metawrap qc step (if `--keep_metawrap_qc` option is used) |
| <sample_id>\_saved_raw_assemblies | Contains raw assemblies (fasta) and assembly graph (gfa) generated during the assembly step (if `--keep_assembly` option is used) |
| <sample_id>\_bin_refinement_outdir | Contains all bin .fa, .stats and .contig files from the bin refinement step (if `--keep_allbins` option is used) |
| <sample_id>\_saved_raw_bins | Contains files generated during the binning step (if `--keep_binning` option is used) |
| <sample_id>\_reassemble_bins_outdir | Contains all bin assemblies (fasta) and stats files from the bin reassembly step (if `--keep_reassembly` option is used) |

## Further configuration

The easiest way to add or override pipeline-specific configuration is to create a custom nextflow config file and supply this to the pipeline using the `-c`  or `-config`  option. It is a good idea to take configuration from the pipeline repository as a starting point, then you can delete bits that you want to keep unchanged. For information on nextflow configuration and customisation, see https://www.nextflow.io/docs/latest/config.html.

A list of pipeline processes whose configuration (including resource requirements) can be customised with a nextflow configuration file if needed:
```
ASSEMBLY
BINNING
BIN_REFINEMENT
REASSEMBLE_BINS
CLEANUP_ASSEMBLY
CLEANUP_BINNING
CLEANUP_BIN_REFINEMENT
CLEANUP_REFINEMENT_REASSEMBLY
CLEANUP_TRIMMED_FASTQ_FILES
TRIMGALORE
BMTAGGER
FILTER_HOST_READS
GET_HOST_READS
GENERATE_STATS
COLLATE_STATS
```

## Credits

The pipeline uses a customised version of metaWRAP v1.3.2 (https://github.com/bxlab/metaWRAP) which is able to take in fastq.gz files. For further information see the MetaWRAP paper: [MetaWRAP - a flexible pipeline for genome-resolved metagenomic data analysis](https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-018-0541-1)

## Support

For further information or help, don't hesitate to get in touch via [pam-informatics@sanger.ac.uk](mailto:pam-informatics@sanger.ac.uk).
