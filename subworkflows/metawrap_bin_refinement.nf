include { BINNING_REFINER } from '../modules/bin_refinement/bin_refiner.nf'

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
    | flatMap { meta, bin_list ->
        // Get all 2-wise, 3-wise, ..., n-wise combinations
        def combinations = (2..bin_list.size()).collectMany { n ->
            getCombinations(bin_list, n)
        }

        // Map to new meta & bin group
        combinations.collect { combo ->
            def indices = combo.collect { bin_list.indexOf(it) + 1 }.join('-')
            def new_meta = meta + [ bins: indices ]
            return [ new_meta, combo ]
        }
    }
    | set { bin_combos }

    BINNING_REFINER(bin_combos)
}

    
    //n_binnings=0
    //if [[ -d $bins1 ]]; then 
    //    mkdir ${out}/binsA
    //    for F in ${bins1}/*; do
    //        SIZE=$(stat -c%s "$F")
    //        if (( $SIZE > 50000)) && (( $SIZE < 20000000)); then 
    //            BASE=${F##*/}
    //            cp $F ${out}/binsA/${BASE%.*}.fa
    //        else 
    //            echo "Skipping $F because the bin size is not between 50kb and 20Mb"
    //        fi
    //    done
    //    n_binnings=$((n_binnings +1))
    //    comm "there are $(ls ${out}/binsA | wc -l) bins in binsA"
    //    if [[ $(ls ${out}/binsA | wc -l) -eq 0 ]]; then error "Please provide valid input. Exiting..."; fi
    //else
    //    error "$bins1 is not a valid directory. Exiting."
    //fi
    

    //if [[ -d $bins2 ]]; then 
    //    mkdir ${out}/binsB
    //    for F in ${bins2}/*; do
    //        SIZE=$(stat -c%s "$F")
    //        if (( $SIZE > 50000)) && (( $SIZE < 20000000)); then 
    //            BASE=${F##*/}
    //            cp $F ${out}/binsB/${BASE%.*}.fa
    //        else 
    //            echo "Skipping $F because the bin size is not between 50kb and 20Mb"
    //        fi
    //        done
    //    n_binnings=$((n_binnings +1))
    //    comm "there are $(ls ${out}/binsB | wc -l) bins in binsB"
    //    if [[ $(ls ${out}/binsB | wc -l) -eq 0 ]]; then error "Please provide valid input. Exiting..."; fi
    //fi

    //if [[ -d $bins3 ]]; then 
    //    mkdir ${out}/binsC
    //    for F in ${bins3}/*; do
    //        SIZE=$(stat -c%s "$F")
    //        if (( $SIZE > 50000)) && (( $SIZE < 20000000)); then 
    //            BASE=${F##*/}
    //            cp $F ${out}/binsC/${BASE%.*}.fa
    //        else 
    //            echo "Skipping $F because the bin size is not between 50kb and 20Mb"
    //        fi
    //        done
    //    n_binnings=$((n_binnings +1))
    //    comm "there are $(ls ${out}/binsC | wc -l) bins in binsC"
    //    if [[ $(ls ${out}/binsC | wc -l) -eq 0 ]]; then error "Please provide valid input. Exiting..."; fi
    //fi

    //if [[ ! -s ${out}/work_files/binsA.stats ]]; then
    //    comm "Fix contig naming by removing special characters..."
    //    for f in ${out}/binsA/*; do ${SOFT}/fix_config_naming.py $f > ${out}/tmp.fa; mv ${out}/tmp.fa $f; done
    //    for f in ${out}/binsB/*; do ${SOFT}/fix_config_naming.py $f > ${out}/tmp.fa; mv ${out}/tmp.fa $f; done
    //    if [[ -d $bins3 ]]; then
    //        for f in ${out}/binsC/*; do ${SOFT}/fix_config_naming.py $f > ${out}/tmp.fa; mv ${out}/tmp.fa $f; done
    //    fi
    //fi



//# I have to switch directories here - Binning_refiner dumps everything into the current dir"
//home=$(pwd)
//cd $out
//
//if [ "$refine" == "true" ] && [[ ! -s work_files/binsA.stats ]]; then
//	announcement "BEGIN BIN REFINEMENT"	
//	if [[ $n_binnings -eq 1 ]]; then
//		comm "There is only one bin folder, so no refinement of bins possible. Moving on..."
//	elif [[ $n_binnings -eq 2 ]]; then
//		comm "There are two bin folders, so we can consolidate them into a third, more refined bin set."
//		${SOFT}/binning_refiner.py -1 binsA -2 binsB -o Refined_AB
//		comm "there are $(ls Refined_AB/Refined | grep ".fa" | wc -l) refined bins in binsAB"
//		mv Refined_AB/Refined binsAB
//		if [[ $? -ne 0 ]]; then error "Bin_refiner did not finish correctly. Exiting..."; fi
//		rm -r Refined_AB
//	elif [[ $n_binnings -eq 3 ]]; then
//		comm "There are three bin folders, so there 4 ways we can refine the bins (A+B, B+C, A+C, A+B+C). Will try all four in parallel!"
//		
//		${SOFT}/binning_refiner.py -1 binsA -2 binsB -3 binsC -o Refined_ABC &
//		${SOFT}/binning_refiner.py -1 binsA -2 binsB -o Refined_AB &
//		${SOFT}/binning_refiner.py -1 binsC -2 binsB -o Refined_BC &
//		${SOFT}/binning_refiner.py -1 binsA -2 binsC -o Refined_AC &
//		
//		wait
//	
//		comm "there are $(ls Refined_AB/Refined | grep ".fa" | wc -l) refined bins in binsAB"
//		comm "there are $(ls Refined_BC/Refined | grep ".fa" | wc -l) refined bins in binsBC"
//		comm "there are $(ls Refined_AC/Refined | grep ".fa" | wc -l) refined bins in binsAC"
//		comm "there are $(ls Refined_ABC/Refined | grep ".fa" | wc -l) refined bins in binsABC"
//
//
//		mv Refined_ABC/Refined binsABC
//		if [[ $? -ne 0 ]]; then error "Bin_refiner did not finish correctly with A+B+C. Exiting..."; fi
//		rm -r Refined_ABC
//		
//		mv Refined_AB/Refined binsAB
//		if [[ $? -ne 0 ]]; then error "Bin_refiner did not finish correctly with A+B. Exiting..."; fi
//		rm -r Refined_AB
//	
//		mv Refined_BC/Refined binsBC
//		if [[ $? -ne 0 ]]; then error "Bin_refiner did not finish correctly with B+C. Exiting..."; fi
//		rm -r Refined_BC
//		
//		mv Refined_AC/Refined binsAC
//		if [[ $? -ne 0 ]]; then error "Bin_refiner did not finish correctly with A+C. Exiting..."; fi
//		rm -r Refined_AC
//	else
//		error "Something is off here - somehow there are not 1, 2, or 3 bin folders ($n_binnings)"
//	fi
//	comm "Bin refinement finished successfully!"
//elif [ "$refine" == "true" ] && [[ -s work_files/binsM.stats ]]; then
//	comm "Previous bin refinment files found. If this was not intended, please re-run with a clear output directory. Skipping refinement..."
//else
//	comm "Skipping bin refinement. Will proceed with the $n_binnings bins specified."
//fi
//	
//comm "fixing bin naming to .fa convention for consistancy..."
//for i in $(ls); do 
//	for j in $(ls $i | grep .fasta); do 
//		mv ${i}/${j} ${i}/${j%.*}.fa
//	done
//done
//
//comm "making sure every refined bin set contains bins..."
//for bin_set in $(ls | grep bins); do 
//	if [[ $(ls $bin_set|grep -c fa) == 0 ]]; then
//		comm "Removing bin set $bin_set because it yielded 0 refined bins ... "
//		rm -r $bin_set
//	fi
//done
//
//
//########################################################################################################
//########################              RUN CHECKM ON ALL BIN SETS                ########################
//########################################################################################################
//if [ "$run_checkm" == "true" ] && [[ ! -s work_files/binsM.stats ]]; then
//	announcement "RUNNING CHECKM ON ALL SETS OF BINS"
//	for bin_set in $(ls | grep -v tmp | grep -v stats | grep bins); do 
//		comm "Running CheckM on $bin_set bins"
//		if [[ -d ${bin_set}.checkm ]]; then rm -r ${bin_set}.checkm; fi
//		if [[ ! -d ${bin_set}.tmp ]]; then mkdir ${bin_set}.tmp; fi
//		if [ "$quick" == "true" ]; then
//			comm "Note: running with --reduced_tree option"
//			checkm lineage_wf -x fa $bin_set ${bin_set}.checkm -t $threads --tmpdir ${bin_set}.tmp --pplacer_threads $p_threads --reduced_tree
//		else
//			checkm lineage_wf -x fa $bin_set ${bin_set}.checkm -t $threads --tmpdir ${bin_set}.tmp --pplacer_threads $p_threads
//		fi
//		
//		if [[ ! -s ${bin_set}.checkm/storage/bin_stats_ext.tsv ]]; then error "Something went wrong with running CheckM. Exiting..."; fi
//		${SOFT}/summarize_checkm.py ${bin_set}.checkm/storage/bin_stats_ext.tsv $bin_set | (read -r; printf "%s\n" "$REPLY"; sort) > ${bin_set}.stats
//		if [[ $? -ne 0 ]]; then error "Cannot make checkm summary file. Exiting."; fi
//		rm -r ${bin_set}.checkm; rm -r ${bin_set}.tmp
//
//		num=$(cat ${bin_set}.stats | awk -v c="$comp" -v x="$cont" '{if ($2>=c && $2<=100 && $3>=0 && $3<=x) print $1 }' | wc -l)
//		comm "There are $num 'good' bins found in $bin_set! (>${comp}% completion and <${cont}% contamination)"
//	done
//elif [ "$run_checkm" == "true" ] && [[ -s work_files/binsM.stats ]]; then
//	comm "Previous bin refinement files found. If this was not intended, please re-run with a clear output directory. Skipping CheckM runs..."
//	rm -r bins*
//	cp -r work_files/binsA* ./
//	cp -r work_files/binsB* ./
//	cp -r work_files/binsC* ./
//else
//	comm "Skipping CheckM. Warning: bin consolidation will not be possible."
//fi
//
//########################################################################################################
//########################               CONSOLIDATE ALL BIN SETS                 ########################
//########################################################################################################
//if [ "$cherry_pick" == "true" ]; then
//	announcement "CONSOLIDATING ALL BIN SETS BY CHOOSING THE BEST VERSION OF EACH BIN"
//	if [[ $n_binnings -eq 1 ]]; then
//	        comm "There is only one original bin folder, so no refinement of bins possible. Moving on..."
//		best_bin_set=binsA
//	elif [[ $n_binnings -eq 2 ]] || [[ $n_binnings -eq 3 ]]; then
//		comm "There are $n_binnings original bin folders, plus the refined bins."
//		rm -r binsM binsM.stats
//		cp -r binsA binsM; cp binsA.stats binsM.stats
//		for bins in $(ls | grep .stats | grep -v binsM); do
//			comm "merging $bins and binsM"
//			${SOFT}/consolidate_two_sets_of_bins.py binsM ${bins%.*} binsM.stats $bins binsM1 $comp $cont
//			if [[ $? -ne 0 ]]; then error "Something went wrong with merging two sets of bins"; fi
//			rm -r binsM binsM.stats
//			mv binsM1 binsM; mv binsM1.stats binsM.stats
//		done
//
//		if [[ $dereplicate == false ]]; then
//			comm "Skipping dereplication of contigs between bins..."
//			mv binsM binsO
//			mv binsM.stats binsO.stats
//		elif [[ $dereplicate == partial ]]; then
//			comm "Scanning to find duplicate contigs between bins and only keep them in the best bin..."
//			${SOFT}/dereplicate_contigs_in_bins.py binsM.stats binsM binsO
//		elif [[ $dereplicate == complete ]]; then
//			comm "Scanning to find duplicate contigs between bins and deleting them in all bins..."
//			${SOFT}/dereplicate_contigs_in_bins.py binsM.stats binsM binsO remove
//		else
//			error "there was an error in deciding how to dereplicate contigs"
//		fi
//
//		best_bin_set=binsO
//	else
//		error "Something went wrong with determining the number of bin folders... The number was ${n_binnings}. Exiting."
//	fi
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
//
//
//#if [ "$run_checkm" == "true" ]; then
//#	comm "making completion and contamination ranking plots for all refinement iterations"
//#	${SOFT}/plot_binning_results.py $comp $cont $(ls | grep ".stats")
//#	mkdir figures
//#	mv binning_results.eps figures/intermediate_binning_results.eps
//#	mv binning_results.png figures/intermediate_binning_results.png
//#fi
//
//########################################################################################################
//########################               MOVING OVER TEMPORARY FILES              ########################
//########################################################################################################
//announcement "MOVING OVER TEMPORARY FILES"
//
//if [ "${bins1:$((${#bins1}-1)):1}" = "/" ]; then bins1=${bins1%/*}; fi
//if [ "${bins2:$((${#bins2}-1)):1}" = "/" ]; then bins2=${bins2%/*}; fi
//if [ "${bins3:$((${#bins3}-1)):1}" = "/" ]; then bins3=${bins3%/*}; fi
//
//
//if [[ -s work_files/binsM.stats ]]; then
//	rm -r work_files/bins*
//	rm -r ${bins1##*/}* ${bins2##*/}* ${bins3##*/}*
//fi
//
//if [[ $n_binnings -ne 1 ]]; then
//	mkdir work_files
//	for f in binsA* binsB* binsC* binsM* binsO*; do
//		mv $f work_files/
//	done
//fi
//
//
//cp -r work_files/binsO metawrap_${comp}_${cont}_bins
//cp work_files/binsO.stats metawrap_${comp}_${cont}_bins.stats
//
//cp -r work_files/binsA ${bins1##*/}
//cp work_files/binsA.stats ${bins1##*/}.stats
//
//cp -r work_files/binsB ${bins2##*/}
//cp work_files/binsB.stats ${bins2##*/}.stats
//
//if [[ $n_binnings -eq 3 ]]; then
//	cp -r work_files/binsC ${bins3##*/}
//	cp work_files/binsC.stats ${bins3##*/}.stats
//fi
//
//if [ "$run_checkm" == "true" ]; then
//#        comm "making completion and contamination ranking plots of final outputs"
//#        ${SOFT}/plot_binning_results.py $comp $cont $(ls | grep ".stats")
//#	mv binning_results.eps figures/binning_results.eps
//#	mv binning_results.png figures/binning_results.png
//#	
//	comm "making contig membership files (for Anvio and other applications)"
//	for dir in *_bins; do
//		echo "summarizing $dir ..."
//		for i in ${dir}/*.fa; do f=${i##*/}; for c in $(cat $i | grep ">"); do echo -e "${c##*>}\t${f%.*}"; done; done > ${dir}.contigs
//	done
//fi
//}