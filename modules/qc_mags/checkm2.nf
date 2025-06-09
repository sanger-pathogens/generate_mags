process CHECKM2 {
    tag "${meta.ID}"
    label "cpu_4"
    label "mem_8"
    label "time_30m"

    container  'quay.io/biocontainers/checkm2:1.0.2--pyh7cba7a3_0'

    publishDir mode: 'copy', path: "${params.outdir}/checkm2/"

    input:
    tuple val(meta), path(fastas)

    output:
    tuple val(meta), path(report_txt), path(diamond_results), emit: results

    script:
    report_txt = "${meta.ID}_${meta.method}_quality_report.tsv"
    diamond_results = "${meta.ID}_${meta.method}_diamond_results.tsv"
    """
    checkm2 predict --threads ${task.cpus} --input ${fastas} --output-directory checkm2 --database_path ${params.checkm2_db}

    # move the output file names to something slightly more descriptive including method

    mv checkm2/diamond_output/DIAMOND_RESULTS.tsv ${diamond_results}
    mv checkm2/quality_report.tsv ${report_txt}
    """
}