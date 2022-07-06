process metawrap_qc {
    input:
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    tuple val(sample_id), path("${read_1}"), path("${read_2}"), emit: trimmed_fastqs

    script:
    read_1 = "${sample_id}_clean_1.fastq.gz"
    read_2 = "${sample_id}_clean_2.fastq.gz"
    """
    metawrap read_qc -1 $first_read -2 $second_read -o .
    """
}
