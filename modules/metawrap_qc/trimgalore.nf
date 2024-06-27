process TRIMGALORE {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/sangerpathogens/trimgalore:v0.4.4'

    input:
    tuple val(sample_id), path(first_read), path(second_read)

    output:
    tuple val(sample_id), path(trimmed_1), path(trimmed_2), emit: trimmed_fastqs

    script:
    trimmed_1="${sample_id}_trimmed_1.fastq"
    trimmed_2="${sample_id}_trimmed_2.fastq"
    """
    trim_galore --no_report_file --dont_gzip --paired ${first_read} ${second_read}
    # rename files
    mv ${sample_id}_1_val_1.fq ${sample_id}_trimmed_1.fastq
    mv ${sample_id}_2_val_2.fq ${sample_id}_trimmed_2.fastq
    """
}
