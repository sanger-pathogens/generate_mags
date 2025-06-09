include { CHECKM2 as PRE_CHECKM2;
          CHECKM2                   } from '../modules/qc_mags/checkm2.nf'
include { GUNC as PRE_GUNC;
          GUNC                      } from '../modules/qc_mags/gunc.nf'
include { MDMCLEANER                } from '../modules/qc_mags/mdmcleaner.nf'
include { SEQKIT                    } from '../modules/qc_mags/seqkit.nf'


workflow REMOVE_HUMAN {
    take:
    fasta_directory

    main:
    
    fasta_directory
    | (PRE_CHECKM2 & PRE_GUNC)

    MDMCLEANER(fasta_directory)
    | SEQKIT
    | (CHECKM2 & GUNC)

    PRE_CHECKM2.join(PRE_GUNC).join(CHECKM2).join(GUNC)
    | REPORT

}