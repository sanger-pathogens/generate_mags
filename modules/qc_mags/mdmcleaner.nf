process MDMCLEANER {
    tag "${meta.ID}"
    label "cpu_4"
    label "mem_8"
    label "time_30m"

    container  'quay.io/biocontainers/gunc:1.0.6--pyhdfd78af_0'

    publishDir mode: 'copy', path: "${params.outdir}/gunc/"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path(mdmcleaner_output) emit: results

    script:
    """
    mdmcleaner clean -i ${fasta} -o mdmcleaner_output -t ${task.cpus}
    """
}