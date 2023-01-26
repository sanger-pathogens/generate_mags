#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { metawrap_qc } from './modules/metawrap_qc.nf'
include { cleanup_assembly; cleanup_binning; cleanup_bin_refinement; cleanup_refinement_reassembly;
          cleanup_trimmed_fastq_files } from './modules/cleanup.nf'

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
        -profile                     always use sanger_lsf when running on the farm (mandatory)
        --help                       print this help message (optional)
    """.stripIndent()
}

def validate_parameters () {
    if (!params.manifest) {
        log.error("Please specify a manifest using the --manifest option")
    }
}

process assembly {
    input:
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: fastq_path_ch
    path(assembly_file), emit: assembly_ch

    // dummy process for testing publishDir directives
    stub:
    assembly_file="final_assembly.fasta"
    """
    touch final_assembly.fasta
    """

    script:
    assembly_file="final_assembly.fasta"
    """
    cmd="metawrap assembly -1 $first_read -2 $second_read -o ."
    if $params.keep_assembly_files && $params.fastspades
    then
        cmd="\${cmd} --fastspades --keepfiles"
    elif $params.fastspades
    then
        cmd="\${cmd} --fastspades"
    elif $params.keep_assembly_files
    then
        cmd="\${cmd} --keepfiles"
    fi
    eval "\${cmd}"
    """
}

process binning {
    input:
    tuple val(sample_id), file(first_read), file(second_read)
    file(assembly_file)

    output:
    path "binning", emit: binning_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch
    path("${workdir}"), emit: workdir
    path("${assembly_file}"), emit: assembly_ch

    // dummy process for testing publishDir directives
    stub:
    workdir="binning_workdir.txt"
    assembly_file="final_assembly.fasta"
    """
    pwd > binning_workdir.txt
    mkdir -p binning
    mkdir -p binning/metabat2_bins
    mkdir -p binning/maxbin2_bins
    mkdir -p binning/concoct_bins
    touch binning/metabat2_bins/blah.fa
    touch binning/maxbin2_bins/blah.fa
    touch binning/concoct_bins/blah.fa
    """

    script:
    workdir="binning_workdir.txt"
    assembly_file="final_assembly.fasta"
    """
    pwd > binning_workdir.txt
    metawrap binning -a $assembly_file -o binning $first_read $second_read
    """
}

process bin_refinement {
    if (params.keep_allbins) { publishDir path: "${params.results_dir}", mode: 'copy', pattern: "*_bin_refinement_outdir" }
    if (params.skip_reassembly) { publishDir path: { "${params.results_dir}/${sample_id}_bin_refinement_outdir" }, mode: 'copy', pattern: '*.{fa,stats}' }
    input:
    path(binning_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path "${sample_id}_bin_refinement_outdir", emit: bin_refinement_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch
    path("${workdir}"), emit: workdir
    path("*.fa"), optional: true
    path("*.stats"), optional: true

    // dummy process for testing publishDir directives
    stub:
    workdir="bin_refinement_workdir.txt"
    """
    pwd > bin_refinement_workdir.txt
    mkdir -p ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/blah.fa
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/bleh.fa
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/blah.stats
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/bleh.stats

    # if we are publishing results, collect fasta and stats files whilst renaming
    if  $params.skip_reassembly
    then
       if [ "$params.keep_allbins" == "false" ]
       then
           shopt -s globstar
           for f in **/*.{fa,stats}
           do
              file_name=\$(basename \$f)
              mv \$f ${sample_id}"_"\${file_name}
           done
       fi
    fi
    """

    script:
    workdir="bin_refinement_workdir.txt"
    """
    pwd > bin_refinement_workdir.txt
    if $params.keep_allbins
    then
        metawrap bin_refinement --keep_allbins -o ${sample_id}_bin_refinement_outdir -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    else
        metawrap bin_refinement -o ${sample_id}_bin_refinement_outdir -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    fi
    if  $params.skip_reassembly
    then
       if [ "$params.keep_allbins" == "false" ]
       then
           shopt -s globstar
           for f in **/*.{fa,stats}
           do
              file_name=\$(basename \$f)
              mv \$f ${sample_id}"_"\${file_name}
           done
       fi
    fi
    """
}

process reassemble_bins {
    publishDir "${params.results_dir}/${sample_id}_reassemble_bins_outdir", mode: 'copy', overwrite: true, pattern: '*.{fa,stats}'
    input:
    path(bin_refinement_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path("*.fa")
    path("*.stats")
    path("${workdir}"), emit: workdir
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch

    // dummy process for testing publishDir directives
    stub:
    workdir="reassemble_bins_workdir.txt"
    """
    pwd > reassemble_bins_workdir.txt
    touch blah.fa
    touch bleh.fa
    touch blah.stats
    touch bleh.stats
    shopt -s globstar
    for f in **/*.{fa,stats}
    do
      file_name=\$(basename \$f)
      mv \$f ./${sample_id}_\${file_name}
    done
    """

    script:
    workdir="reassemble_bins_workdir.txt"
    """
    pwd > reassemble_bins_workdir.txt
    metawrap reassemble_bins -b ${bin_refinement_dir}/metawrap_50_5_bins/ -o ${sample_id}_reassemble_bins_outdir -1 $first_read -2 $second_read
    shopt -s globstar
    for f in **/*.{fa,stats}
    do
      file_name=\$(basename \$f)
      mv \$f ./${sample_id}_\${file_name}
    done
    """
}

workflow {
    if (params.help) {
        printHelp()
        exit 0
    }
    validate_parameters()
    manifest_ch = Channel.fromPath(params.manifest, checkIfExists: true)
    fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')
            .map{ row -> tuple(row.sample_id, file(row.first_read), file(row.second_read)) }
    if (params.skip_qc) {
        assembly(fastq_path_ch)
    }
    else {
        metawrap_qc(fastq_path_ch)
        assembly(metawrap_qc.out.trimmed_fastqs)
    }
    binning(assembly.out.fastq_path_ch, assembly.out.assembly_ch)
    if (params.skip_reassembly) {
        bin_refinement(binning.out.binning_ch, binning.out.fastq_path_ch)
    }
    else {
        bin_refinement(binning.out.binning_ch, binning.out.fastq_path_ch)
        reassemble_bins(bin_refinement.out.bin_refinement_ch, bin_refinement.out.fastq_path_ch)
    }
    // cleanup
    if (!params.keep_metawrap_qc && !params.skip_qc) {
        if (params.skip_reassembly){
            cleanup_trimmed_fastq_files(bin_refinement.out.fastq_path_ch)
        }
        else {
            cleanup_trimmed_fastq_files(reassemble_bins.out.fastq_path_ch)
        }
    }
    if (!params.keep_assembly) {
        cleanup_assembly(binning.out.assembly_ch)
    }
    if (!params.keep_binning) {
        cleanup_binning(binning.out.workdir, bin_refinement.out.workdir)
    }
    if (!params.keep_bin_refinement && !params.keep_allbins && params.skip_reassembly) {
         cleanup_bin_refinement(bin_refinement.out.workdir)
    }
    if (!params.keep_reassembly && !params.skip_reassembly && !params.keep_allbins) {
        cleanup_refinement_reassembly(bin_refinement.out.workdir, reassemble_bins.out.workdir)
    }
}
