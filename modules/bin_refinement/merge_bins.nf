process MERGE_BINS {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    publishDir mode: 'copy', path: "${params.outdir}/bin_merging/", pattern: "${meta.ID}_merge.log"
    publishDir mode: 'copy', path: "${params.outdir}/bin_merging/", pattern: "${meta.ID}_best_bins.stats"

    container 'quay.io/sangerpathogens/python-curl:3.11'

    input:
    tuple val(meta), path(bin_list), path(stats_list)

    output:
    tuple val(meta), val("merged_bins"), path("${meta.ID}_best_bins"), emit: merged_bins
    path("${meta.ID}_merge.log")

    script:
    command = "${projectDir}/modules/bin_refinement/bin/merge_bins.py"
    """
    ${command} -b ${bin_list} -s ${stats_list} -o ${meta.ID}_best_bins -c 50 -x 5 -l ${meta.ID}_merge.log -i ${meta.ID}
    """
}
