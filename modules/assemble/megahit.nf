process MEGAHIT {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_32'
    label 'time_1'

    container 'quay.io/biocontainers/spades:3.12.0--1'

    input:
    tuple val(meta), path(first_read), path(second_read)

    output:
    tuple val(meta), path("${meta.ID}_contigs.fasta"), emit: contigs

    script:
    def contigs = "megahit/final.contigs.fa"
    """
    megahit \\
		 -1 ${first_read} \\
         -2 ${second_read} \\
		 -o megahit \\
		 --tmp-dir megahit.tmp \\
		 -t ${task.cpus} \\
         -m ${task.memory.toBytes()}

    mv ${contigs} ${meta.ID}_contigs.fasta
    """
}