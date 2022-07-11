#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { metawrap_qc } from './modules/metawrap_qc.nf'

// note: need to ensure cleanup and keep files can't both be used at same time in validate_parameters
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
    if $params.keep_assembly_files && $params.fastspades
    then
        metawrap assembly -1 $first_read -2 $second_read -o . --fastspades --keepfiles
    elif $params.fastspades
    then
        metawrap assembly -1 $first_read -2 $second_read -o . --fastspades
    elif $params.keep_assembly_files
    then
        metawrap assembly -1 $first_read -2 $second_read -o . --keepfiles
    else
        metawrap assembly -1 $first_read -2 $second_read -o .
    fi
    """
}

process binning {
    input:
    tuple val(sample_id), file(first_read), file(second_read)
    file(assembly_file)

    output:
    path "binning", emit: binning_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch

    script:
    """
    metawrap binning -a $assembly_file -o binning $first_read $second_read
    """
}

process bin_refinement {
    input:
    path(binning_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path "${sample_id}_bin_refinement_outdir", emit: bin_refinement_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch

    script:
    """
    metawrap bin_refinement -o ${sample_id}_bin_refinement_outdir -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    if $params.skip_reassembly
    then
       shopt -s globstar
       for f in **/*.{fa,stats}
       do
          file_name=\$(basename \$f)
          cp \$f ${workflow.projectDir}/${params.results_dir}/${sample_id}_bin_refinement_outdir/${sample_id}"_"\${file_name}
       done
    fi
    """
}

process bin_refinement_keep_allbins {
    input:
    path(binning_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path("${sample_id}_bin_refinement_allbins/*"), emit: bin_refinement_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch

    script:
    """
    metawrap bin_refinement --keep_allbins -o ${sample_id}_bin_refinement_allbins -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    if $params.skip_reassembly
    then
        mkdir -p ${workflow.projectDir}/${params.results_dir}/${sample_id}_bin_refinement_allbins
        cp ${sample_id}_bin_refinement_allbins/* ${workflow.projectDir}/${params.results_dir}/${sample_id}_bin_refinement_allbins
    fi
    """
}

process reassemble_bins {
    publishDir "${params.results_dir}/${sample_id}_reassemble_bins_outdir", mode: 'copy', overwrite: true
    input:
    path(bin_refinement_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path("*.fa")
    path("*.stats")

    script:
    """
    metawrap reassemble_bins -b ${bin_refinement_dir}/metawrap_50_5_bins/ -o ${sample_id}_reassemble_bins_outdir -1 $first_read -2 $second_read
    shopt -s globstar
    for f in **/*.{fa,stats}
    do
      file_name=\$(basename \$f)
      mv \$f ./${sample_id}_\${file_name}
    done
    """
}

workflow {
    validate_parameters()
    manifest_ch = Channel.fromPath(params.manifest)
    fastq_path_ch = manifest_ch.splitCsv(header: true, sep: ',')
            .map{ row -> tuple(row.sample_id, file(row.first_read), file(row.second_read)) }
    if (params.skip_qc) {
        assembly(fastq_path_ch)
    }
    else {
        metawrap_qc(fastq_path_ch)
        assembly(metawrap_qc.out.trimmed_fastqs)
    }
    binning(assembly.out.fastq_path_ch, assembly.out.assembly_ch)
    if (params.skip_reassembly) {
        bin_refinement(binning.out.binning_ch, binning.out.fastq_path_ch)
    }
    else {
    bin_refinement(binning.out.binning_ch, binning.out.fastq_path_ch)
    reassemble_bins(bin_refinement.out.bin_refinement_ch, bin_refinement.out.fastq_path_ch)
    }
}
