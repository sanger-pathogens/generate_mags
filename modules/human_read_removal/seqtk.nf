process SEQTK_MERGEPE {
    label 'cpu_1'
    label 'mem_100M'
    label 'time_30m'

    container 'quay.io/biocontainers/seqtk:1.4--he4a0461_2'

    input:
        tuple val(meta), path(read_1), path(read_2)

    output:
        tuple val(meta), path("${meta.ID}_interleaved.fq"), emit: interleaved_ch

    script:

    """
    seqtk mergepe ${read_1} ${read_2} > ${meta.ID}_interleaved.fq
    """
}

process SEQTK_SPLIT {
    label 'cpu_1'
    label 'mem_100M'
    label 'time_30m'

    container 'quay.io/biocontainers/seqtk:1.4--he4a0461_2'

    input:
        tuple val(meta), path(interleaved_fq)

    output:
        tuple val(meta), path("${meta.ID}_1.fastq.gz"), path("${meta.ID}_2.fastq.gz"), emit: fastq_ch

    script:
    
    """
    ## this produces .fa files as output but the content of the files are proper .fq
    ## cmd is: seqtk -n [NUM OF FILES] [OUTPUT PREFIX] path/to/input

    seqtk split -n 2 ${meta.ID} ${interleaved_fq}

    gzip ${meta.ID}.00001.fa ${meta.ID}.00002.fa

    mv ${meta.ID}.00001.fa.gz ${meta.ID}_1.fastq.gz
    mv ${meta.ID}.00002.fa.gz ${meta.ID}_2.fastq.gz
    """
}
