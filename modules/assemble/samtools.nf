process SAM_TO_FASTQ {
    label 'cpu_2'
    label 'mem_1'
    label 'time_30m'
    
    container 'quay.io/biocontainers/samtools:1.22--h96c455f_0'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path(read1), path(read2), emit: fastq_ch

    script:
    read1 = "${meta.ID}_1.fastq.gz"
    read2 = "${meta.ID}_2.fastq.gz"
    """
    samtools fastq -N \\
        -f ${sam} \\
        -1 ${read1} \\
        -2 ${read2} \\
        -@ ${task.cpus} \\
        ${sam}
    """
}