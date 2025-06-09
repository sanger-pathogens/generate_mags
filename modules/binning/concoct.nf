process CUT_UP_FASTA {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/biocontainers/concoct:1.1.0--py312h71dcd68_7'

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path(bed_file), emit: bed
    tuple val(meta), path(output_fasta), emit: split_fasta

    script:
    bed_file = "${meta.ID}.bed"
    output_fasta = "${meta.ID}_10k.fa"
    """
    cut_up_fasta.py ${assembly} -c 10000 --merge_last -b ${bed_file} -o 0 > ${output_fasta}
    """
}

process ESTIMATE_ABUNDANCE {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/biocontainers/concoct:1.1.0--py312h71dcd68_7'

    input:
    tuple val(meta), path(bam), path(bed_file), path(bam_index)

    output:
    tuple val(meta), path(depth_file), emit: depths

    script:
    depth_file = "${meta.ID}_depth.txt"
    """
    concoct_coverage_table.py ${bed_file} ${bam} > ${depth_file}
    """
}

process CONCOCT {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/biocontainers/concoct:1.1.0--py312h71dcd68_7'

    input:
    tuple val(meta), path(split_fasta), path(depths)

    output:
    tuple val(meta), path("concoct_out"), emit: depths

    script:
    depth_file = "${meta.ID}_depth.txt"
    """
    concoct -l ${min_contig} \\
            -t ${tasks.cpus} \\
		    --coverage_file ${depths} \\
		    --composition_file ${split_fasta} \\
		    -b concoct_out
    """
}