process FIND_UNMAPPED_BWA {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_8'
    label 'time_1'

    container 'quay.io/biocontainers/bwa:0.7.17--he4a0461_11'

    input:
    tuple val(meta), path(reads_1), path(reads_2), path(reference), path(bwa_index_files)

    output:
    tuple val(meta), path(unmapped_reads),  emit: unmapped_reads

    script:
    unmapped_reads = "${meta.ID}_unused.sam"
    """
    # keep header and unmapped
    bwa mem -M -a -t ${task.cpus}  ${reference} ${reads_1} ${reads_2} | awk '/^@/ || !/NM:i:/' > ${unmapped_reads}
    """
}

process BWA_INDEX {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
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