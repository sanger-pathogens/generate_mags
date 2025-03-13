#!/bin/bash

module load pf

usage() {
  cat <<EOT
Usage: $(basename $0) <OPTION>...
       Generates manifest for generate_mags nextflow pipeline using data stored centrally in the PaM informatics legacy pipelines

       -l,
       Lanes file - file containing list of lanes to be ran through the generate_mags pipeline (mandatory)
       -m,
       Manifest file - name of the manifest file generated to be used in the generate_mags pipeline - default: manifest.csv (optional)
       -h,
       Print this help message and exit the program


EOT
}

# validate file paths
validate_filepath () {
    if [[ ! -f $1 ]]; then
      echo "$1 is not a valid filepath!" >&2
      exit 1
  fi
}

if [[ "$#" == "0" ]]; then
    usage >&2
    exit 1
fi

while getopts "l:m:h" arg;
do
    case $arg in
      l) lanes_file="${OPTARG}";;
      m) manifest_file="${OPTARG}";;
      h) usage; exit 0;;
      *) echo "Error: invalid usage"; usage; exit 1;;
    esac
done

if  [ ! ${lanes_file} ]; then
    echo "lanes file (-l) is a mandatory argument, please ensure it is supplied using: -l <lanes_file>" >&2
    echo >&2
    usage >&2
    exit 1
fi

validate_filepath ${lanes_file}

if  [ ! ${manifest_file} ]; then
    manifest_file="manifest.csv"
fi

echo "ID,R1,R2" > ${manifest_file}

pf data -t file -i ${lanes_file} -f fastq | sort 2>/dev/null |  xargs -n1 echo > Temp_file_path.txt

while read lane
do
  read_1=$(grep -w "${lane}_1.fastq.gz" Temp_file_path.txt)
  read_2=$(grep -w "${lane}_2.fastq.gz" Temp_file_path.txt)
  if [[ ! -z ${read_1} ]] || [[ ! -z ${read_2} ]]
  then
      echo "${lane},${read_1},${read_2}" >> ${manifest_file}
  else
      echo "No data available for ${lane}, skipping..."
  fi
done < ${lanes_file}

rm Temp_file_path.txt

echo "Written manifest file to ${manifest_file}"

