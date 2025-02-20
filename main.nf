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
        --keep_allbins               Keep allbins option for bin refinement.. [default: false] (optional)
        --keep_assembly              Don't cleanup assembly files. [default: false] (optional)
        --keep_binning               Don't cleanup binning files. [default: false] (optional)
        --keep_bin_refinement        Don't cleanup bin refinement files. [default: false] (optional)
        --keep_reassembly            Don't cleanup reassembly files. [default: false] (optional)
        --keep_metawrap_qc           Don't cleanup metawrap qc files. [default: false] (optional)
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
include { ASSEMBLY; BINNING; BIN_REFINEMENT; REASSEMBLE_BINS } from './modules/metawrap.nf'
include { CLEANUP_ASSEMBLY; CLEANUP_BINNING; CLEANUP_BIN_REFINEMENT; CLEANUP_REFINEMENT_REASSEMBLY;
          CLEANUP_TRIMMED_FASTQ_FILES } from './modules/cleanup/cleanup.nf'

include { MIXED_INPUT       } from './assorted-sub-workflows/mixed_input/mixed_input.nf' // Add a symlink to assorted sub workflows
//
// SUBWORKFLOWS
//
include { METAWRAP_QC } from './subworkflows/metawrap_qc.nf'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow {
    // manifest_ch = Channel.fromPath(params.manifest, checkIfExists: true)     # To delete
    // fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')     # To delete
    //         .map{ row -> tuple(row.ID, file(row.R1), file(row.R2)) }     # To delete

    MIXED_INPUT
    | map { meta, R1, R2 -> tuple(meta.ID, R1, R2)}
    | set{reads_ch}
    
    if (params.skip_qc) {
        ASSEMBLY(reads_ch)
    } else {
        METAWRAP_QC(reads_ch)
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
    if (!params.keep_metawrap_qc && !params.skip_qc) {
        if (params.skip_reassembly){
            CLEANUP_TRIMMED_FASTQ_FILES(BIN_REFINEMENT.out.fastq_path_ch)
        } else {
            CLEANUP_TRIMMED_FASTQ_FILES(REASSEMBLE_BINS.out.fastq_path_ch)
        }
    }

    if (!params.keep_assembly) {
        CLEANUP_ASSEMBLY(BINNING.out.assembly_ch)
    }

    if (!params.keep_binning) {
        CLEANUP_BINNING(BINNING.out.workdir, BIN_REFINEMENT.out.workdir)
    }

    if (!params.keep_bin_refinement && !params.keep_allbins && params.skip_reassembly) {
         CLEANUP_BIN_REFINEMENT(BIN_REFINEMENT.out.workdir)
    }

    if (!params.keep_reassembly && !params.skip_reassembly && !params.keep_allbins) {
        CLEANUP_REFINEMENT_REASSEMBLY(BIN_REFINEMENT.out.workdir, REASSEMBLE_BINS.out.workdir)
    }
}
