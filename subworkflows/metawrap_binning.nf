include { BWA_INDEX;
          BWA                     } from "${projectDir}/assorted-sub-workflows/strain_mapper/modules/bwa.nf"
include { SORT_BAM; 
          INDEX                   } from '../modules/assemble/samtools.nf'
include { CONTIG_DEPTHS;
          METABAT1; 
          METABAT2                } from '../modules/assemble/metabat2.nf'
include { CONTIG_DEPTHS_NO_INTRA; 
          SPLIT_DEPTHS; 
          MAXBIN2                 } from '../modules/assemble/maxbin2.nf'
include {CUT_UP_FASTA ;
         ESTIMATE_ABUNDANCE;
         CONCOCT                  } from '../modules/assemble/concoct.nf'

/*
##############################################################################################################################################################
#
# This script is meant to be run on the outputs of assembly.sh pipeline to split the assembly contigs into metagenomic bins.
# Ideally it should take in the assembly file of all of your samples, followed by the reads of all the samples that went into the assembly.
# The more samples, the better the binning. 
#
# The script uses metaBAT2 and/or CONCOCT and/or MaxBin2 to bin the contigs. MetaBAT2 is the defualt due to its speed and great performance,
# but all these binners have their advantages and disadvantages, so it recomended to run the bin_refinement module to QC the bins, get the 
# best bins of all of each method, and to reassembly and refine the final bins. 
#
# Author of pipeline: German Uritskiy. I do not clain any authorship of the many programs this pipeline uses.
# For questions, bugs, and suggestions, contact me at guritsk1@jhu.edu.
#
# Modified by Sam Dougan into nextflow :)
##############################################################################################################################################################
*/

workflow METAWRAP_BINNING {
    take:
    reads
    contigs

    main:

    BWA_INDEX(metaspades_contigs)
    | set { indexed_contigs }

    BWA(reads, indexed_contigs)
    | SORT_BAM
    | set { bam } 
    
    METABAT(bam, reads)

    emit:
    SORT_CONTIGS.out.sorted_contigs
}

workflow METABAT {
    take:
    bam
    reads

    main:

    CONTIG_DEPTHS(bam)
    | join(reads)
    | set { bam_and_reads }

    METABAT2(bam_and_reads)
    | set ( bins )

    if (params.metabat1) {
        METABAT1(bam_and_reads)
        | join(bins)
        | set { final_bins }
    } else {
        bins
        | set { final_bins }
    }

    emit:
    final_bins
}

workflow MAXBIN2 {
    take:
    bam
    reads

    main:
    CONTIG_DEPTHS_NO_INTRA(bam)
    | SPLIT_DEPTHS
    | MAXBIN2
    | set { bins }

    emit:
    bins
}

workflow CONCOCT {
    take:
    bam
    assembly

    main:
    INDEX(bam)

    CUT_UP_FASTA(assembly)

    CUT_UP_FASTA.out.bed
    | join(INDEX.out.bam_plux_index)
    | ESTIMATE_ABUNDANCE

    CUT_UP_FASTA.out.split_fasta
    | join(ESTIMATE_ABUNDANCE.out.depths)
    | CONCOCT
    | set { bins }

    emit:
    bins
}