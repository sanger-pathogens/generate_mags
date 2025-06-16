process CHECKM {
    tag "${meta.ID}"
    label "cpu_4"
    label "mem_8"
    label "time_30m"

    container 'quay.io/biocontainers/checkm-genome:1.2.4--pyhdfd78af_0'

    publishDir mode: 'copy', path: "${params.outdir}/checkm2/", pattern: "${meta.ID}_${bin_name}_checkm2_report.tsv"

    input:
    tuple val(meta), val(bin_name), path(fastas)

    output:
    tuple val(meta), val(bin_name), path(fastas), path(report_txt), emit: results

    script:
    report_txt = "${meta.ID}/storage/bin_stats_ext.tsv"
    """
    mkdir tmp
    checkm lineage_wf -x fasta ${fastas} ${meta.ID} -t ${task.cpus} --tmpdir tmp --pplacer_threads ${task.cpus}

    
    """
}

process SUMMARISE_CHECKM {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    publishDir mode: 'copy', path: "${params.outdir}/${meta.ID}/checkm1/", pattern: "${meta.ID}_${bin_name}checkm_summary.tsv"

    container 'quay.io/sangerpathogens/python-curl:3.11'

    input:
    tuple val(meta), val(bin_name), path(fastas), path(report)

    output:
    tuple val(meta), path(fastas), path(summary), emit: merged_bins

    script:
    command = "${projectDir}/modules/bin_refinement/bin/summarise_checkm.py"
    summary = "${meta.ID}_${bin_name}checkm_summary.tsv"
    """
    ${command} ${report} ${bin_name} > ${summary}
    """    
}