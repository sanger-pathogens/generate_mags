process GUNC {
    tag "${meta.ID}"
    label "cpu_4"
    label "mem_8"
    label "time_30m"

    container  'quay.io/biocontainers/gunc:1.0.6--pyhdfd78af_0'

    publishDir mode: 'copy', path: "${params.outdir}/gunc/"

    input:
    tuple val(meta), path(fastas)

    output:
    tuple val(meta), emit: results

    script:
    """
    gunc run -d ${fastas} -o gunc_outdir -t ${task.cpus}
    """
}