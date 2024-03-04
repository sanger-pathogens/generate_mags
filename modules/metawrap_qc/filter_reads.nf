process FILTER_HOST_READS {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    publishDir "${params.outdir}/metawrap_qc/cleaned_reads", mode: 'copy', overwrite: true, pattern: "*_clean*.fastq.gz"
    
    container 'quay.io/sangerpathogens/metawrap_qc_python:1.0'

    input:
    tuple val(sample_id), path(first_read), path(second_read)
    path(bmtagger_list)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: data_ch
    tuple val(sample_id), path(clean_1), path(clean_2), emit: cleaned_ch

    script:
    clean_1="${sample_id}_clean_1.fastq.gz"
    clean_2="${sample_id}_clean_2.fastq.gz"
    """
    # filter out host reads
    filter_reads.py -b ${bmtagger_list} -r ${first_read} --skip-human-reads > ${sample_id}_clean_1.fastq
    filter_reads.py -b ${bmtagger_list} -r ${second_read} --skip-human-reads > ${sample_id}_clean_2.fastq
    # compress
    pigz ${sample_id}_clean_1.fastq ${sample_id}_clean_2.fastq
    """
}

process GET_HOST_READS {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_4'  //TODO: Need 5GB?
    label 'time_1'  //TODO: Allow for longer time?

    if (params.publish_host_reads) { publishDir path: "${params.outdir}/host_reads", mode: 'copy', overwrite: true, pattern: "*_host*.fastq.gz" }
    tag "$sample_id"
    container 'quay.io/sangerpathogens/metawrap_qc_python:1.0'

    input:
    tuple val(sample_id), path(first_read), path(second_read)
    path(bmtagger_list)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: data_ch
    tuple val(sample_id), path(host_1), path(host_2), emit: host_ch

    script:
    host_1="${sample_id}_host_1.fastq.gz"
    host_2="${sample_id}_host_2.fastq.gz"
    """
    # filter out host reads
    filter_reads.py -b ${bmtagger_list} -r ${first_read} --get-human-reads > ${sample_id}_host_1.fastq
    filter_reads.py -b ${bmtagger_list} -r ${second_read} --get-human-reads > ${sample_id}_host_2.fastq
    # compress
    pigz ${sample_id}_host_1.fastq ${sample_id}_host_2.fastq
    """
}
