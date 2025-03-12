#!/usr/bin/env nextflow

/*
========================================================================================
    HELP
========================================================================================
*/

def printHelp() {
    NextflowTool.help_message("${workflow.ProjectDir}/schema.json", 
                              ["${workflow.ProjectDir}/assorted-sub-workflows/mixed_input/schema.json",
                               "${workflow.ProjectDir}/assorted-sub-workflows/irods_extractor/schema.json"],
    params.monochrome_logs, log)
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

def logo = NextflowTool.logo(workflow, params.monochrome_logs)

log.info logo

NextflowTool.commandLineParams(workflow.commandLine, log, params.monochrome_logs)

workflow {
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
