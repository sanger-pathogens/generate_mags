process BINNING_REFINER {
    tag "${meta.ID}"
    label 'cpu_1'
    label 'mem_1'
    label 'time_1'

    container 'quay.io/sangerpathogens/bin_refiner:1.4.3'

    input:
    tuple val(meta), path(bins)

    output:
    tuple val(meta), val("bins"), emit: refined_bins

    script:
    """
    mkdir binning_input
    mv ${bins} binning_input
    Binning_refiner -i binning_input -p ${meta.ID}
    """
}