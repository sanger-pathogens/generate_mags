include { BINNING_REFINER               } from '../modules/bin_refinement/bin_refiner.nf'
include { CHECKM2;
          CHECKM2 as CHECKM2_MERGED_BIN } from '../modules/bin_refinement/checkm2.nf'
include { CHECKM;
          SUMMARISE_CHECKM              } from '../modules/bin_refinement/checkm1.nf'
include { MERGE_BINS                    } from '../modules/bin_refinement/merge_bins.nf'

/*

##############################################################################################################################################################
#
# This script is meant to be run on the outputs of binning.sh pipeline to analyze the metagenomic bins and arrive at the best possible putative genomes.
# 
# Author of pipeline: German Uritskiy. I do not clain any authorship of the many programs this pipeline uses.
# For questions, bugs, and suggestions, contact me at guritsk1@jhu.edu.
# 
# Modified by Yan Shao 1) checkM threshold default to 50/5 to align with medium-quality MAGs criteria; 2) clean-up bin folders  
##############################################################################################################################################################
*/

// Recursive function to get all combinations of size `n` from a list `fullBinList`
def getCombinations(List fullBinList, int n) {
    //exit early if small
    if (n == 0) return [[]]
    if (fullBinList.isEmpty() || n > fullBinList.size()) return []

    def firstBin = fullBinList[0]

    // Remaining fullBinList after the first (or empty list)
    def remainingBins = fullBinList.size() > 1 ? fullBinList[1..-1] : []

    // Include the first item in the combination
    def combosWithFirst = getCombinations(remainingBins, n - 1).collect { combo ->
        [firstBin] + combo
    }

    // Exclude the first item from the combination
    def combosWithoutFirst = getCombinations(remainingBins, n)

    // All valid combinations are either with or without the first item
    return combosWithFirst + combosWithoutFirst
}


workflow METAWRAP_BIN_REFINEMENT {
    take:
    bins
    reads

    main:

    bins
    | map { whole_channel -> 
        def meta = whole_channel[0]
        def bin_list = whole_channel[1..-1] //everything after meta
        return [meta, bin_list]
    }
    | set { all_bins }

    all_bins
    | transpose
    | map { meta, bin -> 
        def bin_name = bin.name
        [ meta, bin_name, bin ]
    }
    | set{ individual_bins }

    all_bins
    | flatMap { meta, bin_list ->
        // Get all 2-wise, 3-wise, ..., n-wise combinations
        def combinations = (2..bin_list.size()).collectMany { n ->
            getCombinations(bin_list, n)
        }

        // Map to new meta & bin group
        combinations.collect { combo ->
            def bin_names = combo.collect { path -> path.name } 
            def bins_label = bin_names.join('-')
            return [ meta, bins_label, combo ]
        }
    }
    | set { bin_combos }

    BINNING_REFINER(bin_combos)
    | mix(individual_bins)
    | set { refined_bins }
    
    if (params.checkm1) {
        CHECKM(refined_bins)
        | SUMMARISE_CHECKM
        | set { checkm }
    } else {
        CHECKM2(refined_bins)
        | set { checkm }
    }
    
    checkm
    | groupTuple
    | MERGE_BINS

    CHECKM2_MERGED_BIN(MERGE_BINS.out.merged_bins)

    //todo add derep methods

    
}


//	
//elif [ "$cherry_pick" == "false" ]; then
//	comm "Skipping bin consolidation. Will try to pick the best binning folder without mixing bins from different sources."
//	if [ $run_checkm = false ]; then 
//		comm "cannot decide on best bin set because CheckM was not run. Will assume its binsA (first bin set)"
//		best_bin_set=binsA
//	elif [ $run_checkm = true ]; then
//		max=0
//		best_bin_set=none
//		for bin_set in $(ls | grep .stats); do
//			num=$(cat $bin_set | awk -v c="$comp" -v x="$cont" '{if ($2>=c && $2<=100 && $3>=0 && $3<=x) print $1 }' | wc -l)
//			comm "There are $num 'good' bins found in ${bin_set%.*}! (>${comp}% completion and <${cont}% contamination)"
//			if [ "$num" -gt "$max" ]; then
//				max=$num
//				best_bin_set=${bin_set%.*}
//			fi
//		done
//		if [[ ! -d $best_bin_set ]]; then error "Something went wrong with deciding on the best bin set. Exiting."; fi
//		comm "looks like the best bin set is $best_bin_set"
//	else
//		error "something is wrong with the run_checkm option (${run_checkm})"
//	fi
//else
//	error "something is wrong with the cherry_pick option (${cherry_pick})"
//fi
//
//comm "You will find the best non-reassembled versions of the bins in $best_bin_set"
//
//
//########################################################################################################
//########################               FINALIZING THE REFINED BINS              ########################
//########################################################################################################
//announcement "FINALIZING THE REFINED BINS"
//
//
//if [ "$run_checkm" == "true" ] && [ $dereplicate != "false" ]; then
//	comm "Re-running CheckM on binsO bins"
//	mkdir binsO.tmp
//
//	if [ "$quick" == "true" ]; then
//		checkm lineage_wf -x fa binsO binsO.checkm -t $threads --tmpdir binsO.tmp --pplacer_threads $p_threads --reduced_tree
//	else
//		checkm lineage_wf -x fa binsO binsO.checkm -t $threads --tmpdir binsO.tmp --pplacer_threads $p_threads
//	fi
//
//	if [[ ! -s binsO.checkm/storage/bin_stats_ext.tsv ]]; then error "Something went wrong with running CheckM. Exiting..."; fi
//	rm -r binsO.tmp
//	${SOFT}/summarize_checkm.py binsO.checkm/storage/bin_stats_ext.tsv manual binsM.stats | (read -r; printf "%s\n" "$REPLY"; sort -rn -k2) > binsO.stats
//	if [[ $? -ne 0 ]]; then error "Cannot make checkm summary file. Exiting."; fi
//	rm -r binsO.checkm
//	num=$(cat binsO.stats | awk -v c="$comp" -v x="$cont" '{if ($2>=c && $2<=100 && $3>=0 && $3<=x) print $1 }' | wc -l)
//	comm "There are $num 'good' bins found in binsO.checkm! (>${comp}% completion and <${cont}% contamination)"
//	
//	comm "Removing bins that are inadequate quality..."
//	for bin_name in $(cat binsO.stats | grep -v compl | awk -v c="$comp" -v x="$cont" '{if ($2<c || $2>100 || $3<0 || $3>x) print $1 }' | cut -f1); do
//		echo "${bin_name} will be removed because it fell below the quality threshhold after de-replication of contigs..."
//		rm binsO/${bin_name}.fa
//	done
//	head -n 1 binsO.stats > binsO.stats.tmp
//	cat binsO.stats | awk -v c="$comp" -v x="$cont" '$2>=c && $2<=100 && $3>=0 && $3<=x' >> binsO.stats.tmp
//	mv binsO.stats.tmp binsO.stats
//	n=$(cat binsO.stats | grep -v comp | wc -l)
//	comm "Re-evaluating bin quality after contig de-replication is complete! There are still $n high quality bins."
//fi