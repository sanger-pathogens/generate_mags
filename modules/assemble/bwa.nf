process BWA {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/biocontainers/bwa:0.7.17--he4a0461_11'

    input:
    tuple val(meta), path(reads_1), path(reads_2), path(reference), path(bwa_index_files)

    output:
    tuple val(meta), path(sam),  emit: sam

    script:
    sam = "${meta.ID}_mapped.sam"
    """
    bwa mem -t ${task.cpus}  ${reference} ${reads_1} ${reads_2} > ${sam}
    """
}

process BWA_INDEX {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_250M'
    label 'time_30m'

    container 'quay.io/biocontainers/bwa:0.7.17--he4a0461_11'

    input:
    tuple val(meta), path(reference)

    output:
    tuple val(meta), path(reference), path("${reference}.*"),  emit: bwa_index

    script:
    """
    bwa index  ${reference}
    """
}