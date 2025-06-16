process METASPADES {
    tag "${meta.ID}"
    label 'cpu_8'
    label 'mem_32'
    label 'time_12'

    container 'quay.io/biocontainers/spades:3.12.0--1'

    input:
    tuple val(meta), path(first_read), path(second_read)

    output:
    tuple val(meta), path("${meta.ID}_contigs.fasta"), emit: contigs

    script:
    def contigs = "metaspades/contigs.fasta"
    """
    metaspades.py ${params.fastspades ? "--only-assembler" : ""} \\
            --tmp-dir tmp \\
            -t ${task.cpus} \\
            -m ${task.memory.toGiga()} \\
            -o metaspades \\
            -1 ${first_read} \\
            -2 ${second_read} \\
            ${params.lock_phred ? "--phred-offset 33" : ""}

    mv ${contigs} ${meta.ID}_contigs.fasta
    """
}