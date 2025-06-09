process SCRUBBER_GETDB {
    label 'cpu_1'
    label 'mem_1'
    label 'time_queue_from_normal'

    container 'quay.io/sangerpathogens/python-curl:3.11'

    output:
    env(db_path)

    script:
    def init_db_script = "${projectDir}/bin/download_sra_scrubber.py"
    def version_flag = params.scrubber_version ? "--version ${params.scrubber_version}" : ""
    """
    db_path=\$(python3 ${init_db_script} ${params.scrubber_db} ${version_flag} --nextflow)
    """
}

process SCRUBBER {
    tag "${meta.ID}"
    label 'cpu_8'
    label 'mem_1'
    label 'time_queue_from_normal'

    container 'quay.io/biocontainers/sra-human-scrubber:2.2.1--hdfd78af_0'

    input:
    tuple val(meta), path(interleaved_reads)
    path(scrubber_db)

    output:
    tuple val(meta), path("${meta.ID}_cleaned.fastq"), emit: cleaned_ch

    script:
    """
    scrub.sh \\
        -x -s \\
        -i ${interleaved_reads} \\
        -o ${meta.ID}_cleaned.fastq \\
        -p ${task.cpus} \\
        -d ${scrubber_db} \\
        -r ${meta.ID}.scrubber.list
    """
}

process FIX_HEADERS {
    label 'cpu_1'
    label 'mem_250M'
    label 'time_queue_from_normal'

    container 'quay.io/sangerpathogens/python-curl:3.11'

    input:
    tuple val(meta), path(first_read), path(second_read)

    output:
    tuple val(meta), path(first_read), path(second_read), emit: repaired_ch

    script:
    def header_script = "${projectDir}/bin/fix_headers.py"
    """
    ${header_script} ${first_read} ${second_read}
    """
}