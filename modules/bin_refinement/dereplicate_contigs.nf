process DEREPLICATE_CONTIGS {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_100M'
    label 'time_30m'

    container 'quay.io/sangerpathogens/python-curl:3.11'

    input:
    tuple val(meta), path(fastas), path(report_txt)

    output:
    tuple val(meta), val("final_bins"), path(final_bins), emit: merged_bins

    script:
    command = "${projectDir}/modules/bin_refinement/bin/dereplicate_contigs_in_bins.py"
    final_bins = "${meta.ID}_final_bins"
    """
    ${command} ${report_txt} ${fastas} ${final_bins}
    """
}