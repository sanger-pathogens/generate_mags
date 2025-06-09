process SEQKIT {
    tag "${meta.ID}"
    label "cpu_4"
    label "mem_8"
    label "time_30m"

    container  'quay.io/biocontainers/seqkit:2.10.0--h9ee0642_0'

    publishDir mode: 'copy', path: "${params.outdir}/gunc/"

    input:
    tuple val(meta), path(fastas)

    output:
    tuple val(meta), emit: results

    script:
    """
    seqkit seq ${meta.ID}.fasta -m 1000 > ${meta.ID}_cleaned.fa.gz
    """
}