include { TRIMGALORE } from '../modules/metawrap_qc/trimgalore.nf'
include { BMTAGGER } from '../modules/metawrap_qc/bmtagger.nf'
include { FILTER_HOST_READS; GET_HOST_READS } from '../modules/metawrap_qc/filter_reads.nf'
include { GENERATE_STATS } from '../modules/metawrap_qc/generate_stats.nf'
include { COLLATE_STATS } from '../modules/metawrap_qc/collate_stats.nf'


workflow METAWRAP_QC {
    take:
    fastq_path_ch

    main:
    TRIMGALORE(fastq_path_ch)

    BMTAGGER(TRIMGALORE.out.trimmed_fastqs)

    FILTER_HOST_READS(BMTAGGER.out.data_ch, BMTAGGER.out.bmtagger_list_ch)

    GET_HOST_READS(BMTAGGER.out.data_ch, BMTAGGER.out.bmtagger_list_ch)

    all_reads_ch = FILTER_HOST_READS.out.data_ch
                    .join(FILTER_HOST_READS.out.cleaned_ch)
                    .join(GET_HOST_READS.out.host_ch)
                    .join(fastq_path_ch)

    GENERATE_STATS(all_reads_ch)

    COLLATE_STATS(GENERATE_STATS.out.stats_ch.collect())

    emit:
    filtered_reads = FILTER_HOST_READS.out.cleaned_ch

}