#!/usr/bin/env nextflow

include { validate_parameters } from './modules/helper_functions.nf'
include { METAWRAP_QC } from './subworkflows/metawrap_qc.nf'
include { ASSEMBLY; BINNING; BIN_REFINEMENT; REASSEMBLE_BINS } from './modules/metawrap.nf'
include { CLEANUP_ASSEMBLY; CLEANUP_BINNING; CLEANUP_BIN_REFINEMENT; CLEANUP_REFINEMENT_REASSEMBLY;
          CLEANUP_TRIMMED_FASTQ_FILES } from './modules/cleanup/cleanup.nf'

// helper functions
def printHelp() {
    log.info """
    Usage:
        nextflow run .

    Options:
        --manifest                   Manifest containing paths to fastq files (mandatory)
        --skip_qc                    skip metawrap qc step - default false (optional)
        --keep_allbins               keep allbins option for bin refinement - default false (optional)
        --keep_assembly              don't cleanup assembly files - default false (optional)
        --keep_binning               don't cleanup binning files - default false (optional)
        --keep_bin_refinement        don't cleanup bin refinement files - default false (optional)
        --keep_reassembly            don't cleanup reassembly files - default false (optional)
        --keep_metawrap_qc           don't cleanup metawrap qc files - default false (optional)
        --skip_reassembly            skip reassembly step - default false (optional)
        --fastspades                 use fastspades assembly option - default false (optional)
        --help                       print this help message (optional)
    """.stripIndent()
}

if (params.help) {
    printHelp()
    exit 0
}

validate_parameters()

workflow {
    manifest_ch = Channel.fromPath(params.manifest, checkIfExists: true)
    fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')
            .map{ row -> tuple(row.sample_id, file(row.first_read), file(row.second_read)) }

    if (params.skip_qc) {
        ASSEMBLY(fastq_path_ch)
    }
    else {
        METAWRAP_QC(fastq_path_ch)
        ASSEMBLY(METAWRAP_QC.out.filtered_reads)
    }
    BINNING(ASSEMBLY.out.fastq_path_ch, ASSEMBLY.out.assembly_ch)
    if (params.skip_reassembly) {
        BIN_REFINEMENT(BINNING.out.binning_ch, BINNING.out.fastq_path_ch)
    }
    else {
        BIN_REFINEMENT(BINNING.out.binning_ch, BINNING.out.fastq_path_ch)
        REASSEMBLE_BINS(BIN_REFINEMENT.out.bin_refinement_ch, BIN_REFINEMENT.out.fastq_path_ch)
    }

    // cleanup
    if (!params.keep_metawrap_qc && !params.skip_qc) {
        if (params.skip_reassembly){
            CLEANUP_TRIMMED_FASTQ_FILES(BIN_REFINEMENT.out.fastq_path_ch)
        }
        else {
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
