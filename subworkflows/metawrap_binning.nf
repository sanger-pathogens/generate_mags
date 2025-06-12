include { BWA_INDEX;
          BWA                     } from '../modules/assemble/bwa.nf'
include { SORT_BAM; 
          INDEX                   } from '../modules/binning/samtools.nf'
include { CONTIG_DEPTHS;
          METABAT1; 
          METABAT2                } from '../modules/binning/metabat2.nf'
include { CONTIG_DEPTHS_NO_INTRA; 
          SPLIT_DEPTHS; 
          MAXBIN2                 } from '../modules/binning/maxbin2.nf'
include {CUT_UP_FASTA ;
         ESTIMATE_ABUNDANCE;
         CONCOCT;
         CUTUP_CLUSTERING;
         SPLIT_BINS               } from '../modules/binning/concoct.nf'

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

// Function to join multiple binning channels into a single one
// that emits: [meta, [bin1, bin2, bin3]]
def join_bins(List binning_channels) {
    // Start with the first channel
    def joined_channel = binning_channels[0]

    // Iteratively join with the remaining channels
    (1..<binning_channels.size()).each { index ->
        def next_channel = binning_channels[index]

        joined_channel = joined_channel.join(next_channel)
            .map { tuple1, tuple2 ->
                def meta = tuple1[0]  // shared metadata (e.g. sample ID)

                // Get list of current bins from previous step
                def bin_list = (tuple1[1] instanceof List) ? tuple1[1] : [tuple1[1]]

                // Add the new bin to the list
                def new_bin = tuple2[1]
                return [meta, bin_list + [new_bin]]
            }
    }

    return joined_channel
}

workflow METAWRAP_BINNING {
    take:
    contigs
    reads

    main:

    BWA_INDEX(contigs)
    | set { indexed_contigs }

    reads.join(indexed_contigs)
    | BWA
    | SORT_BAM
    | set { bam } 
    
    METABAT_WF(bam, contigs)
    | set { metabat_bins }

    MAXBIN_WF(bam, contigs)
    | set { maxbins_bins }

    CONCOCT_WF(bam, contigs)
    | set { concoct_bins }

    metabat_bins
    | join(maxbins_bins)
    | join(concoct_bins)
    | set { final_bins }

    emit:
    final_bins
}

workflow METABAT_WF {
    take:
    bam
    contigs

    main:

    CONTIG_DEPTHS(bam)
    | join(contigs)
    | set { depth_file_and_contigs }

    METABAT2(depth_file_and_contigs)
    | set { bins }

    if (params.metabat1) {
        METABAT1(depth_file_and_contigs)
        | join(bins)
        | set { final_bins }
    } else {
        bins
        | set { final_bins }
    }

    emit:
    final_bins
}

workflow MAXBIN_WF {
    take:
    bam
    contigs

    main:
    CONTIG_DEPTHS_NO_INTRA(bam)
    | SPLIT_DEPTHS
    | join(contigs)
    | MAXBIN2
    | set { bins }

    emit:
    bins
}

workflow CONCOCT_WF {
    take:
    bam
    assembly

    main:
    INDEX(bam)

    CUT_UP_FASTA(assembly)

    CUT_UP_FASTA.out.bed
    | join(INDEX.out.bam_plus_index)
    | ESTIMATE_ABUNDANCE

    CUT_UP_FASTA.out.split_fasta
    | join(ESTIMATE_ABUNDANCE.out.depths)
    | CONCOCT
    | CUTUP_CLUSTERING
    | join(assembly)
    | SPLIT_BINS
    | set { bins }

    emit:
    bins
}
