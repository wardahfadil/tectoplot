#!/bin/bash

# Format for files extracted from GCMT by ndk2meca_keb_14.sh: space separated fields

# 1          , 2          , 3    ,
# loncentroid, latcentroid, depth,
#
# 4      , 5   , 6    , 7      , 8   , 9    ,
# strike1, dip1, rake1, strike2, dip2, rake2,
#
# 10      , 11      ,
# mantissa, exponent,
#
# 12       , 13       , 14   ,
# lonorigin, latorigin, newid,
#
# 15 , 16  , 17 , 18  , 19 , 20  ,
# TAz, TInc, Naz, Ninc, Paz, Pinc,
#
# 21 , 22 , 23 , 24 , 25 , 26 , 27
# Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, MW
#
# newid is in the format yyyy-mm-ddThh:mm:ss
#

# Download GCMT focal mechanism data and convert from NDK to psmeca format
#
NDK2MECA_AWK="/Users/kylebradley/Dropbox/scripts/tectoplot/ndk2meca_keb_14.awk"
GCMT_DIR="/Users/kylebradley/Dropbox/TectoplotData/GCMT/"

[[ ! -d $GCMT_DIR ]] && mkdir -p $GCMT_DIR

cd $GCMT_DIR

[[ ! -e jan76_dec17.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/jan76_dec17.ndk" > jan76_dec17.ndk

years=("2018" "2019" "2020")
months=("jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec")

for year in ${years[@]}; do
  YY=$(echo $year | tail -c 3)
  for month in ${months[@]}; do
    [[ ! -e ${month}${YY}.ndk ]] && curl "https://www.ldeo.columbia.edu/~gcmt/projects/CMT/catalog/NEW_MONTHLY/${year}/${month}${YY}.ndk" > ${month}${YY}.ndk
  done
done

rm -f all_txt.txt
echo "Extracting GCMT focal mechanisms from NDK to PSMECA format, 14 fields, origin locations"

for ndkfile in *.ndk; do
  res=$(grep 404 $ndkfile)
  if [[ $res =~ "<title>404" ]]; then
    echo "ndk file $ndkfile was not correctly downloaded... deleting."
    rm -f $ndkfile
  else
    echo "Extracting $ndkfile"
    gawk -E $NDK2MECA_AWK $ndkfile >> all_txt.txt
  fi
done

# awk < all_txt.txt '{print "G", $0}' > all_txt_2.txt
# all_txt_2.txt is in psmeca 14+13 format with a G field before

# gawk -E $NDK2MECA_AWK ndk_all.ndk > all_txt.txt
# lonc, latc, depth, strike1, dip1, rake1, strike2, dip2, rake2, moment, newX, newY, event_title

# echo "# lonc latc depth str1 dip1 rake1 str2 dip2 rake2 MA ME lon lat ID" > psmeca_all_centroid.txt
# echo "# lon lat depth str1 dip1 rake1 str2 dip2 rake2 MA ME lonc latc ID" > psmeca_all_orgin.txt
awk < all_txt.txt '{ if ($12 < 0) print "G", $12, $13, $3, $4, $5, $6, $7, $8, $9, $10, $11, $1, $2, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27; else if ($12 > 180) print "G", $12-360, $13, $3, $4, $5, $6, $7, $8, $9, $10, $11, $1-360, $2, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27; else print "G", $12, $13, $3, $4, $5, $6, $7, $8, $9, $10, $11, $1, $2, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27}' > gcmt_origin.txt
# echo "# lonc latc depth str1 dip1 rake1 str2 dip2 rake2 MA ME lon lat ID" > $GCMTCENTROID
awk < all_txt.txt '{ if ($12 < 0) print "G", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27; else if ($12 > 180) print "G", $1-360, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12-360, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27; else print "G", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27}' > gcmt_centroid.txt

# rm -f all_txt.txt
