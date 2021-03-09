#!/bin/bash
# Kyle Bradley, Nanyang Technological University (kbradley@ntu.edu.sg)

# This script will download GCMT data in ndk format and produce an event catalog
# in tectoplot CMT format. That catalog will be merged with other catalogs to
# produce a final joined catalog.

# Output is a file containing centroid (gcmt_centroid.txt) and origin (gcmt_origin.txt) location focal mechanisms in tectoplot 27 field format:

[[ ! -d $GCMTDIR ]] && mkdir -p $GCMTDIR

cd $GCMTDIR

[[ ! -e jan76_dec17.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/jan76_dec17.ndk" > jan76_dec17.ndk

years=("2018" "2019" "2020")
months=("jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec")

for year in ${years[@]}; do
  YY=$(echo $year | tail -c 3)
  for month in ${months[@]}; do
    [[ ! -e ${month}${YY}.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/NEW_MONTHLY/${year}/${month}${YY}.ndk" > ${month}${YY}.ndk
  done
done

echo "Downloading Quick CMTs"

curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/NEW_QUICK/qcmt.ndk" > quick.ndk

rm -f gcmt_extract.cat
echo "Extracting GCMT focal mechanisms from NDK to tectoplot format"

for ndkfile in *.ndk; do
  res=$(grep 404 $ndkfile)
  if [[ $res =~ "<title>404" ]]; then
    echo "ndk file $ndkfile was not correctly downloaded... deleting."
    rm -f $ndkfile
  else
    echo "Extracting $ndkfile"
    ${CMTTOOLS} $ndkfile K G >> gcmt_extract.cat
  fi
done
