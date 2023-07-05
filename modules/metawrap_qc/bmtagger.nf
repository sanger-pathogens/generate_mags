process BMTAGGER {
    tag "$sample_id"
    container '/software/pathogen/images/bmtagger-3.101--h470a237_4.simg'

    input:
    tuple val(sample_id), path(first_read), path(second_read)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: data_ch
    path(bmtagger_list), emit: bmtagger_list_ch

    script:
    bmtagger_list="${sample_id}.bmtagger.list"
    """
    # make tmp folder for bmtagger
    mkdir bmtagger_tmp
    # run bmtagger
    bmtagger.sh -b ${params.bmtagger_db}/${params.bmtagger_host}.bitmask -x ${params.bmtagger_db}/${params.bmtagger_host}.srprism -T bmtagger_tmp -q1 \\
	 -1 ${first_read} -2 ${second_read} \\
	 -o ${sample_id}.bmtagger.list
    """
}