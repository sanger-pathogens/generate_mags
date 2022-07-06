#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

def validate_parameters() {
    // Parameter checking function
    def errors = 0

    if (params.manifest) {
        manifest=file(params.manifest)
        if (!manifest.exists()) {
            log.error("The manifest file specified does not exist.")
            errors += 1
        }
    }
    else {
        log.error("No manifest file specified. Please specify one using the --manifest option.")
        errors += 1
    }

    if (errors > 0) {
            log.error(String.format("%d errors detected", errors))
            exit 1
        }
}

process assembly {
    input:
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: fastq_path_ch
    path(assembly_file), emit: assembly_ch

    script:
    assembly_file="final_assembly.fasta"
    """
    metawrap assembly -1 $first_read -2 $second_read -o .
    """
}

process binning {
    input:
    tuple val(sample_id), file(first_read), file(second_read)
    file(assembly_file)

    output:
    path($workdir)
    tuple val(sample_id), file(first_read), file(second_read)

    script:
    workdir="workdir.txt"
    """
    pwd > workdir.txt
    metawrap binning -a $assembly_file -o binning $first_read $second_read
    """
}

process bin_refinement {
    input:
    file(binning_dir)
    script:
    """
    binning_work_dir=\$(cat $binning_dir)
    metawrap bin_refinement -o bin_refinement_outdir -A \$binning_work_dir/metabat2_bins/ -B \$binning_work_dir/maxbin2_bins/ -C \$binning_work_dir/concoct_bins/
    """
}

process reassemble_bins {
    input:

    script:
    """
    metawrap reassemble_bins -b bin_refinement_outdir/metawrap_50_5_bins/ -o reassemble_bins_outdir -1 44989_1#81_sub_clean_1.fastq.gz -2 44989_1#81_sub_clean_2.fastq.gz
    """
}

workflow {
    validate_parameters()
    manifest_ch = Channel.fromPath(params.manifest)
    fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')
            .map{ row -> tuple(row.sample_id, file(row.first_read), file(row.second_read)) }
    assembly(fastq_path_ch)
    binning(assembly.out.fastq_path_ch, assembly.out.assembly_ch)
}