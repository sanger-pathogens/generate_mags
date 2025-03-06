#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def printHelp() {
    log.info """
    Usage:
        nextflow run main.nf

    Options:
        --manifest                   Manifest containing paths to fastq files with headers ID,R1,R2. (mandatory)
        --outdir                     Directory to store pipeline output. [default: ./results] (optional)
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
    """.stripIndent()
}

if (params.help) {
    printHelp()
    exit 0
}

/*
========================================================================================
    IMPORT MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES
//
include { validate_parameters } from './modules/helper_functions.nf'
include { ASSEMBLY; BINNING; BIN_REFINEMENT; REASSEMBLE_BINS } from './modules/metawrap.nf'
include { CLEANUP_ASSEMBLY; CLEANUP_BINNING; CLEANUP_BIN_REFINEMENT; CLEANUP_REFINEMENT_REASSEMBLY;
          CLEANUP_TRIMMED_FASTQ_FILES } from './modules/cleanup/cleanup.nf'

//
// SUBWORKFLOWS
//
include { METAWRAP_QC } from './subworkflows/metawrap_qc.nf'

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

validate_parameters()

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    manifest_ch = Channel.fromPath(params.manifest, checkIfExists: true)
    fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')
            .map{ row -> tuple(row.ID, file(row.R1), file(row.R2)) }

    if (params.skip_qc) {
        ASSEMBLY(fastq_path_ch)
    } else {
        METAWRAP_QC(fastq_path_ch)
        ASSEMBLY(METAWRAP_QC.out.filtered_reads)
    }

    BINNING(ASSEMBLY.out.fastq_path_ch, ASSEMBLY.out.assembly_ch)
    
    if (params.skip_reassembly) {
        BIN_REFINEMENT(BINNING.out.binning_ch, BINNING.out.fastq_path_ch)
    } else {
        BIN_REFINEMENT(BINNING.out.binning_ch, BINNING.out.fastq_path_ch)
        REASSEMBLE_BINS(BIN_REFINEMENT.out.bin_refinement_ch, BIN_REFINEMENT.out.fastq_path_ch)
    }

    // cleanup
    if (params.cleanup_metawrap_qc && !params.skip_qc) {
        if (params.skip_reassembly){
            CLEANUP_TRIMMED_FASTQ_FILES(BIN_REFINEMENT.out.fastq_path_ch)
        } else {
            CLEANUP_TRIMMED_FASTQ_FILES(REASSEMBLE_BINS.out.fastq_path_ch)
        }
    }

    if (params.cleanup_assembly) {
        CLEANUP_ASSEMBLY(BINNING.out.assembly_ch)
    }

    if (params.cleanup_binning) {
        CLEANUP_BINNING(BINNING.out.workdir, BIN_REFINEMENT.out.workdir)
    }

    if (params.cleanup_bin_refinement) {
         CLEANUP_BIN_REFINEMENT(BIN_REFINEMENT.out.workdir, REASSEMBLE_BINS.out.workdir)
    }

    if (params.cleanup_reassembly && !params.skip_reassembly) {
        CLEANUP_REFINEMENT_REASSEMBLY(BIN_REFINEMENT.out.workdir, REASSEMBLE_BINS.out.workdir)
    }
}
