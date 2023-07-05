process COLLATE_STATS {
    publishDir "${params.results_dir}/metawrap_qc", mode: 'copy', overwrite: true, pattern: "*_statistics.csv"
    input:
    path(stats_files)

    output:
    path(read_removal_stats_file), emit: stats_ch

    script:
    read_removal_stats_file="read_removal_statistics.csv"
    """
    echo "Sample_id,Total_host_reads,Total_non_host_reads,Total_trimmed_reads,%age_host_reads,%age_non_host_reads,Total_original_reads,%age_reads_trimmed" > "${read_removal_stats_file}"
    cat *_stats.csv >> "${read_removal_stats_file}"
    """
}
