process ASSEMBLY {
    tag "${sample_id}"
    label 'cpu_4'
    label 'mem_32'
    label 'time_queue_from_normal'

    container 'quay.io/sangerpathogens/metawrap_custom:1.3.2-phred_locked-c3'

    publishDir enabled: params.keep_assembly, mode: 'copy', path: "${params.outdir}/${sample_id}_saved_raw_assemblies/", pattern: "${sample_id}*.{fa,fasta,gfa}"

    input:
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    tuple val(sample_id), path(first_read), path(second_read), emit: fastq_path_ch
    path(assembly_file), emit: assembly_ch
    path("*fa*"), optional: true

    // dummy process for testing publishDir directives
    stub:
    assembly_file="final_assembly.fasta"
    """
    touch final_assembly.fasta
    """

    script:
    assembly_file="final_assembly.fasta"

    def baseCmd = params.lock_phred ? 'metawrap assembly_locked_phred' : 'metawrap assembly'
    def fastspades = params.fastspades ? '--fastspades' : ''
    def keepfiles = params.keep_assembly ? '--keepfiles' : ''


    """
    ${baseCmd} -1 ${first_read} -2 ${second_read} -o . ${fastspades} ${keepfiles}

    # Move file if keepfiles is specified
    if [ "${params.keep_assembly}" = "true" ]; then
        mv megahit/final.contigs.fa ${sample_id}_megahit_final.contigs.fa
        mv metaspades/contigs.fasta ${sample_id}_metaspades_contigs.fasta
        mv metaspades/assembly_graph_with_scaffolds.gfa ${sample_id}_assembly_graph_with_scaffolds.gfa
        mv metaspades/scaffolds.fasta ${sample_id}_scaffolds.fasta
    fi
    """
}

process BINNING {
    tag "${sample_id}"
    label 'cpu_1'
    label 'mem_8'
    label 'time_queue_from_normal'

    publishDir enabled: params.keep_binning, mode: 'copy', path: "${params.outdir}/${sample_id}_saved_raw_bins/", pattern: "*_bins"

    container 'quay.io/sangerpathogens/metawrap_custom:1.3.2-phred_locked-c3'

    input:
    tuple val(sample_id), file(first_read), file(second_read)
    file(assembly_file)

    output:
    path "binning", emit: binning_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch
    path("${workdir}"), emit: workdir
    path("${assembly_file}"), emit: assembly_ch
    path("metabat2_bins"), emit: metabat2_bins
    path("maxbin2_bins"), emit: maxbin2_bins
    path("concoct_bins"), emit: concoct_bins

    // dummy process for testing publishDir directives
    stub:
    workdir="binning_workdir.txt"
    assembly_file="final_assembly.fasta"
    """
    pwd > binning_workdir.txt
    mkdir -p binning
    mkdir -p binning/metabat2_bins
    mkdir -p binning/maxbin2_bins
    mkdir -p binning/concoct_bins
    touch binning/metabat2_bins/blah.fa
    touch binning/maxbin2_bins/blah.fa
    touch binning/concoct_bins/blah.fa
    """

    script:
    workdir="binning_workdir.txt"
    assembly_file="final_assembly.fasta"
    """
    pwd > binning_workdir.txt
    metawrap binning -a $assembly_file -o binning $first_read $second_read
    """
}

process BIN_REFINEMENT {
    tag "${sample_id}"
    label 'cpu_4'
    label 'mem_64'
    label 'time_queue_from_normal'

    container 'quay.io/sangerpathogens/metawrap_custom:1.3.2-phred_locked-c3'

    if (params.keep_allbins) { 
        publishDir path: "${params.outdir}", mode: 'copy', pattern: "*_bin_refinement_outdir"
    }
    if (params.skip_reassembly && !params.keep_allbins) {
        publishDir path: { "${params.outdir}/${sample_id}_bin_refinement_outdir" }, mode: 'copy', pattern: '*.{fa,stats}'
    }

    input:
    path(binning_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path "${sample_id}_bin_refinement_outdir", emit: bin_refinement_ch
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch
    path("${workdir}"), emit: workdir
    path("*.fa"), optional: true
    path("*.stats"), optional: true

    // dummy process for testing publishDir directives
    stub:
    workdir="bin_refinement_workdir.txt"
    """
    pwd > bin_refinement_workdir.txt
    mkdir -p ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/blah.fa
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/bleh.fa
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/blah.stats
    touch ${sample_id}_bin_refinement_outdir/metawrap_50_5_bins/bleh.stats

    # if we are publishing results, collect fasta and stats files whilst renaming
    if  $params.skip_reassembly
    then
       if [ "$params.keep_allbins" == "false" ]
       then
           shopt -s globstar
           for f in **/*.{fa,stats}
           do
              file_name=\$(basename \$f)
              mv \$f ${sample_id}"_"\${file_name}
           done
       fi
    fi
    """

    script:
    workdir="bin_refinement_workdir.txt"
    """
    pwd > bin_refinement_workdir.txt
    if $params.keep_allbins
    then
        metawrap bin_refinement --keep_allbins -o ${sample_id}_bin_refinement_outdir -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    else
        metawrap bin_refinement -o ${sample_id}_bin_refinement_outdir -A ${binning_dir}/metabat2_bins/ -B ${binning_dir}/maxbin2_bins/ -C ${binning_dir}/concoct_bins/
    fi
    if  $params.skip_reassembly
    then
       if [ "$params.keep_allbins" == "false" ]
       then
           shopt -s globstar
           for f in **/*.{fa,stats}
           do
              file_name=\$(basename \$f)
              mv \$f ${sample_id}"_"\${file_name}
           done
       fi
    fi
    """
}

process REASSEMBLE_BINS {
    tag "${sample_id}"
    label 'cpu_4'
    label 'mem_64'
    label 'time_queue_from_normal'

    container 'quay.io/sangerpathogens/metawrap_custom:1.3.2-phred_locked-c3'

    publishDir "${params.outdir}/${sample_id}_reassemble_bins_outdir", mode: 'copy', overwrite: true, pattern: '*.{fa,stats}'
    
    input:
    path(bin_refinement_dir)
    tuple val(sample_id), file(first_read), file(second_read)

    output:
    path("*.fa")
    path("*.stats")
    path("${workdir}"), emit: workdir
    tuple val(sample_id), file(first_read), file(second_read), emit: fastq_path_ch

    // dummy process for testing publishDir directives
    stub:
    workdir="reassemble_bins_workdir.txt"
    """
    pwd > reassemble_bins_workdir.txt
    touch blah.fa
    touch bleh.fa
    touch blah.stats
    touch bleh.stats
    shopt -s globstar
    for f in **/*.{fa,stats}
    do
      file_name=\$(basename \$f)
      mv \$f ./${sample_id}_\${file_name}
    done
    """

    script:
    workdir="reassemble_bins_workdir.txt"
    if ( !params.lock_phred )
        """
        pwd > reassemble_bins_workdir.txt
        metawrap reassemble_bins -b ${bin_refinement_dir}/metawrap_50_5_bins/ -o ${sample_id}_reassemble_bins_outdir -1 $first_read -2 $second_read
        shopt -s globstar
        for f in **/*.{fa,stats}
        do
        file_name=\$(basename \$f)
        mv \$f ./${sample_id}_\${file_name}
        done
        """
    else
        """
        pwd > reassemble_bins_workdir.txt
        metawrap reassemble_bins_locked_phred -b ${bin_refinement_dir}/metawrap_50_5_bins/ -o ${sample_id}_reassemble_bins_outdir -1 $first_read -2 $second_read
        shopt -s globstar
        for f in **/*.{fa,stats}
        do
        file_name=\$(basename \$f)
        mv \$f ./${sample_id}_\${file_name}
        done
        """
}
