process BMTAGGER {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_10'
    label 'time_queue_from_normal'

    container 'quay.io/biocontainers/bmtagger:3.101--h470a237_4'

    input:
    tuple val(sample_id), path(first_read), path(second_read)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: data_ch
    path(bmtagger_list), emit: bmtagger_list_ch

    script:
    bmtagger_list="${sample_id}.bmtagger.list"
    bitmask_file="${params.bmtagger_db}/${params.bmtagger_host}.bitmask"
    srprism_prefix="${params.bmtagger_db}/${params.bmtagger_host}.srprism"
    """
    # make tmp folder for bmtagger
    mkdir bmtagger_tmp

    # run bmtagger
    bmtagger.sh -b ${bitmask_file} -x ${srprism_prefix} -T bmtagger_tmp -q1 \\
	-1 ${first_read} -2 ${second_read} \\
	-o ${bmtagger_list}
    """
}