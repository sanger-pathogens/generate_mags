process CONTIG_DEPTHS_NO_INTRA {
    label 'cpu_1'
    label 'mem_100M'
    label 'time_30m'

    container 'quay.io/biocontainers/metabat2:2.18--h6f16272_0'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path(depth_text),  emit: depth

    script:
    depth_text = "${meta.ID}_depth.txt"
    """
    jgi_summarize_bam_contig_depths --outputDepth ${depth_text} --noIntraDepthVariance ${bam}
    """
}

process SPLIT_DEPTHS {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_100M'
    label 'time_30m'

    container 'quay.io/sangerpathogens/python-curl:3.11'

    input:
    tuple val(meta), path(depth_text)

    output:
    tuple val(meta), path(depth_out), emit: depths

    script:
    command = "${projectDir}/modules/binning/bin/split_depths.py"
    depth_out = "${meta.ID}_split_depths"
    """
    ${command} ${depth_text} ${depth_out}
    """
}

process MAXBIN2 {
    label 'cpu_2'
    label 'mem_1'
    label 'time_30m'

    container 'quay.io/biocontainers/maxbin2:2.2.7--h503566f_7'

    input:
    tuple val(meta), path(depth_dir), path(assembly)

    output:
    tuple val(meta), path("maxbin2/"),  emit: bins

    script:
    """
    mkdir maxbin2

    run_MaxBin.pl -contig ${assembly} \\
        -markerset ${params.maxbin_markers} \\
        -thread ${task.cpus} \\
        -min_contig_length ${params.min_contig} \\
	    -out maxbin2/${meta.ID} \\
	    -abund_list ${depth_dir}/mb2_abund_list.txt

    #move stuff out of the bin that isn't to use
    mv maxbin2/${meta.ID}.marker .
    mv maxbin2/${meta.ID}.noclass .
    mv maxbin2/${meta.ID}.tooshort .
    mv maxbin2/${meta.ID}.log .    
    mv maxbin2/${meta.ID}.marker_of_each_bin.tar.gz .
    mv maxbin2/${meta.ID}.summary .

    #maxbin is already fasta
    """
}