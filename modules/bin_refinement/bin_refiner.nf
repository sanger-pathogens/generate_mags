process BINNING_REFINER {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/sangerpathogens/bin_refiner:1.4.3'

    input:
    tuple val(meta), val(bins_label), path(bins)

    output:
    tuple val(meta), val(bins_label), path("${meta.ID}_${bins_label}_Binning_refiner_outputs/${bins_label}"), emit: refined_bin_fastas

    script:
    """
    mkdir binning_input
    mv ${bins} binning_input

    Binning_refiner -i binning_input -p ${meta.ID}_${bins_label}

    # remove suffixfix from bin directory name
    mv ${meta.ID}_${bins_label}_Binning_refiner_outputs/${meta.ID}_${bins_label}_refined_bins/ ${meta.ID}_${bins_label}_Binning_refiner_outputs/${bins_label}
    """
}