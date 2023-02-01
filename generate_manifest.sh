#!/bin/bash

fastq_paths=$1
count=0
echo "sample_id,first_read,second_read" > manifest.csv

while read line
do
  let count=count+1
  if [ $count -eq 2 ]
    then
      lane_id=$(echo $line | awk -F "/" '{ print $NF }' | sed 's|_[12].fastq.gz||g')
      read2=$(echo $line)
      read1=$(cat $fastq_paths | grep ${lane_id}_ | grep -v ${read2})
      echo $lane_id,$read1,$read2 >> manifest.csv
      count=0
    fi
done < $fastq_paths

