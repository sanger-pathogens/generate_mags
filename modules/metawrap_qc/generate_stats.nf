process GENERATE_STATS {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'  //TODO: Allow for longer time?
    
    container '/software/pathogen/images/metawrap_qc_python-1.0.simg'

    input:
    tuple val(sample_id), path(trimmed_read_1), path(trimmed_read_2), path(clean_read_1), path(clean_read_2), path(host_read_1), path(host_read_2), path(original_read_1), path(original_read_2)

    output:
    path(stats_file), emit: stats_ch

    script:
    stats_file="${sample_id}_stats.csv"
    """
    # get read numbers (bash quickest way)
    trimmed_1_reads=\$((`cat $trimmed_read_1 | wc -l` / 4))
    trimmed_2_reads=\$((`cat $trimmed_read_2 | wc -l` / 4))
    clean_1_reads=\$((`zcat $clean_read_1 | wc -l` / 4))
    clean_2_reads=\$((`zcat $clean_read_2 | wc -l` / 4))
    host_1_reads=\$((`zcat $host_read_1 | wc -l` / 4))
    host_2_reads=\$((`zcat $host_read_2 | wc -l` / 4))
    original_1_reads=\$((`zcat $original_read_1 | wc -l` / 4))
    original_2_reads=\$((`zcat $original_read_2 | wc -l` / 4))
    trimmed_reads_total=\$((\${trimmed_1_reads} + \${trimmed_2_reads}))
    clean_reads_total=\$((\${clean_1_reads} + \${clean_2_reads}))
    host_reads_total=\$((\${host_1_reads} + \${host_2_reads}))
    original_reads_total=\$((\${original_1_reads} + \${original_2_reads}))

    # generate stats
    generate_stats.py --sample-id ${sample_id} --host-reads \${host_reads_total} --non-host-reads \${clean_reads_total} --total-trimmed-reads \${trimmed_reads_total} --total-original-reads \${original_reads_total} > ${sample_id}_stats.csv
    """
}
