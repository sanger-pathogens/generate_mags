process MEGAHIT {
    tag "${meta.ID}"
    label 'cpu_8'
    label 'mem_32'
    label 'time_12'

    container 'quay.io/biocontainers/megahit:1.2.9--h5ca1c30_6'

    input:
    tuple val(meta), path(first_read), path(second_read)

    output:
    tuple val(meta), path("${meta.ID}_contigs.fasta"), emit: contigs

    script:
    def contigs = "megahit/final.contigs.fa"
    """
    megahit -1 ${first_read} \\
            -2 ${second_read} \\
	        -o megahit \\
	        -t ${task.cpus} \\
            -m ${task.memory.toBytes()}

    mv ${contigs} ${meta.ID}_contigs.fasta
    """
}