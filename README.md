# Abundance estimation nextflow pipeline

## Usage
```
nextflow run abundance_estimation.nf
  --manifest                   Manifest containing paths to fastq files (mandatory)
  --skip_qc                    skip metawrap qc step - default false (optional)
  --keep_allbins               keep allbins option for bin refinement - default false (optional)
  --keep_assembly              don't cleanup assembly files - default false (optional)
  --keep_binning               don't cleanup binning files - default false (optional)
  --keep_bin_refinement        don't cleanup bin refinement files - default false (optional)
  --keep_reassembly            don't cleanup reassembly files - default false (optional)
  --keep_metawrap_qc           don't cleanup metawrap qc files - default false (optional)
  --skip_reassembly            skip reassembly step - default false (optional)
  --fastspades                 use fastspades assembly option - default false (optional)
  -profile                     always use sanger_lsf when running on the farm (mandatory)
  --help                       print this help message (optional)
```

## Generating manifests
### Step 1:
Obtain fastq paths:
`ls -d -1 <path>/*.fastq.gz > fastq_paths.txt`
### Step 2:
Generate manifest:
`./generate_manifest.sh fastq_paths.txt`

This will output the manifest to `manifest.csv` which can be fed into the nextflow pipeline

## Dependencies
This pipeline relies on the following modules:
```
ISG/singularity
nextflow
```

# Running
## Source beforehand
```
module load nextflow ISG/singularity/3.10.0  # there seem to be some issues with older versions of singularity
export NXF_SINGULARITY_CACHEDIR=<a fixed path on lustre that won't be removed (unlike the "work" directory)>
export queue=long
export mem=16GB
# Not sure this actually works, but it's also set in the image
export NXF_PYTHONNOUSERSITE=1
```

## Execution
`bsub -G <team> -q $queue -o ./out/%J.out -e ./err/%J.err -R "select[mem>$mem] rusage[mem=$mem]" -M $mem -J "nf_generate_mags" "nextflow run . --manifest <manifest> -profile sanger_lsf -with-trace -resume"`
