process CONTIG_DEPTHS {
    label 'cpu_2'
    label 'mem_1'
    label 'time_30m'

    container 'quay.io/biocontainers/metabat2:2.18--h6f16272_0'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path(depth_text),  emit: depth

    script:
    depth_text = "${meta.ID}_depth.txt"
    """
    jgi_summarize_bam_contig_depths --outputDepth ${depth_text} ${bam}
    """
}

process METABAT1 {
    label 'cpu_2'
    label 'mem_10'
    label 'time_30m'

    container 'quay.io/biocontainers/metabat2:2.18--h6f16272_0'

    input:
    tuple val(meta), path(depth_text), path(assembly)

    output:
    tuple val(meta), path("${meta.ID}_bin"),  emit: depth

    script:
    """
    metabat1 -i ${assembly} \\
        -a ${depth_text} \\
        -o ${meta.ID}_bin \\
        -m ${params.min_contig} \\
        -t ${task.cpus} \\
        --unbinned
    """
}

process METABAT2 {
    label 'cpu_2'
    label 'mem_10'
    label 'time_30m'

    container 'quay.io/biocontainers/metabat2:2.18--h6f16272_0'

    input:
    tuple val(meta), path(depth_text), path(assembly)

    output:
    tuple val(meta), path("${meta.ID}_bin"),  emit: depth

    script:
    """
    metabat2 -i ${assembly} \\
        -a ${depth_text} \\
        -o ${meta.ID}_bin \\
        -m ${params.min_contig} \\
        -t ${task.cpus} \\
        --unbinned
    """
}