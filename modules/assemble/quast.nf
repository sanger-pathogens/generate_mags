process QUAST {
    tag "${meta.ID}"
    label "cpu_1"
    label "mem_250M"
    label "time_30m"

    container  'quay.io/biocontainers/quast:5.0.2--py36pl5321hcac48a8_7'

    publishDir mode: 'copy', pattern: "${report_txt}", path: "${params.outdir}/${meta.ID}/quast"

    input:
    tuple val(meta), path(consensus)

    output:
    tuple val(meta), path(report_txt), emit: quast_out

    script:
    output = "${meta.ID}_assembly_stats"
    report_path = "${output}/transposed_report.tsv"
    report_txt = "${output}/report.txt"
    """
    quast.py ${consensus} -o ${output} --no-html --no-plots
    """
}

process SUMMARY {
    label "cpu_1"
    label "mem_100M"
    label "time_30m"

    container  'quay.io/biocontainers/quast:5.0.2--py36pl5321hcac48a8_7'

    publishDir mode: 'copy', pattern: "${summary}", saveAs: { filename -> "summary_quast_report.tsv" }, path: {
        if ("${params.test}" == false ) "${params.outdir}/${workflow.runName}/"
        else "${params.outdir}/test/"
    }

    input:
    path('transposed_report???.tsv')

    output:
    path(summary), emit: summary_out

    script:
    summary = "quast_summary.tsv"
    """
    head -n 1 transposed_report001.tsv > ${summary} && tail -n +2 -q transposed_report*.tsv >> ${summary}
    """
}