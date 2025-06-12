process SORT_BAM {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'
    
    container 'quay.io/biocontainers/samtools:1.22--h96c455f_0'

    input:
    tuple val(meta), path(mapped_reads)

    output:
    tuple val(meta), path(mapped_reads_bam),  emit: mapped_reads_bam

    script:
    mapped_reads_bam = "${meta.ID}.bam"
    """
    samtools sort -T tmp -@ ${task.cpus} -O BAM -o ${mapped_reads_bam} ${mapped_reads}
    rm ${mapped_reads}
    """
}

process INDEX {
    label 'cpu_1'
    label 'mem_1'
    label 'time_30m'

    container 'quay.io/biocontainers/samtools:1.22--h96c455f_0'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path(bam), path("*.bam.*"), emit: bam_plus_index

    script:
    mapped_reads_bam = "${meta.ID}.bam"
    """
    samtools index ${bam}
    """
}
