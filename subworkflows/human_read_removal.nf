include { TRIMGALORE                              } from '../modules/metawrap_qc/trimgalore.nf'
include { SEQTK_MERGEPE; SEQTK_SPLIT              } from '../modules/human_read_removal/seqtk.nf'
include { SCRUBBER; SCRUBBER_GETDB; FIX_HEADERS   } from '../modules/human_read_removal/scrubber.nf'


workflow REMOVE_HUMAN {
    take:
    fastq_path_ch

    main:

    def db_pattern = params.scrubber_version
        ? "${params.scrubber_db}/human_filter.db.${db_pattern}"
        : "${params.scrubber_db}/human_filter.db.*"


    scrubber_located_ch = file(db_pattern)

    if (scrubber_located_ch.empty) {
        SCRUBBER_GETDB
        | set { scrubber_located_ch }
    }

    TRIMGALORE(fastq_path_ch)
    | FIX_HEADERS
    | SEQTK_MERGEPE
    
    SCRUBBER(SEQTK_MERGEPE.out.interleaved_ch , scrubber_located_ch)
    | SEQTK_SPLIT
    | set { final_fastqs }

    emit:
    final_fastqs
}