process CLEANUP_SORTED_BAM_FILES {
    /**
    * Cleanup intermediate files
    */

    input:
        file(sorted_bam_file)

    script:
        """
        # Remove sorted bam files
        orig_bam=\$(readlink -f ${sorted_bam_file})
        rm ${sorted_bam_file} # Remove symlink
        rm \${orig_bam} # Remove original files
        """
}

process CLEANUP_TRIMMED_FASTQ_FILES {
    /**
    * Cleanup intermediate files
    */

    input:
        tuple val(sample_id), file(first_read), file(second_read)

    script:
        """
        # Remove trimmed fastq files
        orig_fastqs=\$(readlink -f ${first_read} ${second_read})
        rm ${first_read} ${second_read} # Remove symlink
        rm \${orig_fastqs} # Remove original files
        """
}

process CLEANUP_ASSEMBLY {
    /**
    * Cleanup assembly files
    */

    input:
        path(assembly_file)

    script:
        """
        orig_assembly=\$(readlink -f ${assembly_file})
        rm ${assembly_file} # Remove symlink
        rm \${orig_assembly} # Remove original files
        """
}

process CLEANUP_BINNING {
    /**
    * Cleanup binning output
    */

    input:
         path(workdir)

    script:
        """
        binning_dir=\$(cat $workdir)
        cd \$binning_dir
        rm -rf binning
        """
}

process CLEANUP_BIN_REFINEMENT {
    /**
    * Cleanup bin refinement output
    */

    input:
         path(refinement_dir)
         path(binning_workdir)

    script:
        """
        bin_refinement_dir=\$(cat $refinement_dir)
        cd \$bin_refinement_dir
        rm -rf *_bin_refinement*
        """
}

process CLEANUP_REFINEMENT_REASSEMBLY {
    /**
    * Cleanup reassembly and refinement
    */

    input:
         path(refinement_dir)
         path(reassembly_dir)

    script:
        """
        # clean reassembly
        reassembly_workdir=\$(cat $reassembly_dir)
        cd \$reassembly_workdir
        rm -rf *_reassemble_bins_outdir
        rm *.fa *.stats

        # clean refinement
        cd -
        bin_refinement_dir=\$(cat $refinement_dir)
        cd \$bin_refinement_dir
        rm -rf *_bin_refinement*
        """
}
