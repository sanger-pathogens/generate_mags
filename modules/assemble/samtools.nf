process SAM_TO_FASTQ {
    label 'cpu_2'
    label 'mem_1'
    label 'time_30m'
    
    container 'quay.io/biocontainers/samtools:1.22--h96c455f_0'

    input:
    tuple val(meta), path(sam)

    output:
    tuple val(meta), path("${read1}.gz"), path("${read2}.gz"), emit: fastq_ch

    script:
    read1 = "${meta.ID}_1.fastq"
    read2 = "${meta.ID}_2.fastq"

    //-f 12 = both reads unmapped
    //-F 256 no secondary alignments
    """
    samtools view -b \\
        -f 12 \\
        -F 256 \\
        -@ ${task.cpus} \\
        ${sam} | \\
    samtools fastq -N \\
        -1 ${read1} \\
        -2 ${read2} \\
        -@ ${task.cpus} \\
        -

    gzip ${read1} ${read2}
    """
}