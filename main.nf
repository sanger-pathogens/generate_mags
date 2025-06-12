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
include { ASSEMBLY; 
          BINNING;
          BIN_REFINEMENT;
          REASSEMBLE_BINS                } from './modules/metawrap.nf'
include { CLEANUP_ASSEMBLY; 
          CLEANUP_BINNING; 
          CLEANUP_BIN_REFINEMENT; 
          CLEANUP_REFINEMENT_REASSEMBLY;
          CLEANUP_TRIMMED_FASTQ_FILES    } from './modules/cleanup/cleanup.nf'

//
// SUBWORKFLOWS
//

include { MIXED_INPUT                    } from './assorted-sub-workflows/mixed_input/mixed_input.nf'
include { METAWRAP_QC                    } from './subworkflows/metawrap_qc.nf'
include { REMOVE_HUMAN                   } from './subworkflows/human_read_removal.nf'
include { METAWRAP_ASSEMBLE              } from './subworkflows/metawrap_assembly.nf'
include { METAWRAP_BINNING               } from './subworkflows/metawrap_binning.nf'
include { METAWRAP_BIN_REFINEMENT        } from './subworkflows/metawrap_bin_refinement.nf'

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
    | set{reads_ch}
    
    switch (params.qc) {
        case "scrubber":
        REMOVE_HUMAN(reads_ch)
        | set { ready_reads }

        break
    
    case "metawrap":
        METAWRAP_QC(reads_ch)
        | set { ready_reads }

        break

    case "skip":
        reads_ch
        | set { ready_reads }

        break
    
    default:
        log.error("input --qc: ${params.qc} was not one of scrubber|metawrap|skip")

    }

    if (params.split_process) {
        METAWRAP_ASSEMBLE(ready_reads)
        | set { contigs }

        METAWRAP_BINNING(contigs, ready_reads)
        | set { bins }

        METAWRAP_BIN_REFINEMENT(bins, ready_reads)

    } else {
        //legacy
        ASSEMBLY(ready_reads)

        ASSEMBLY.out.assembly_ch
        | set { contigs }

        BINNING(contigs, ready_reads)

        BIN_REFINEMENT(BINNING.out.binning_ch, BINNING.out.fastq_path_ch)

        if (!params.skip_reassembly) {
            REASSEMBLE_BINS(BIN_REFINEMENT.out.bin_refinement_ch, BIN_REFINEMENT.out.fastq_path_ch)
        }

        // cleanup
        if (params.cleanup_metawrap_qc && !params.qc == "skip") {
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
}
