#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# This script will download GCMT data in ndk format and produce an initial earthquake catalogs for origin/centroid.
# These catalogs will be modified by scrape_isc_focals_expand.sh to and final GCMT catalogs will be made.

# Outputs 29 space separated fields using ndk2meca_keb_14.sh (which is modified from ndk2meca.sh from Thorsten Becker)
# Note that currently ndk2meca_keb_14.sh outputs the alternative depth as field 14 and we change that to field 29 here

# Tectoplot CMT format:
# 1: code             Code G=GCMT I=ISC
# 2: lon              Longitude (°)
# 3: lat              Latitude (°)
# 4: depth            Depth (km)
# 5: strike1          Strike of nodal plane 1
# 6: dip1             Dip of nodal plane 1
# 7: rake1            Rake of nodal plane 1
# 8: strike2          Strike of nodal plane 2
# 9: dip2             Dip of nodal plane 2
# 10: rake2            Rake of nodal plane 2
# 11: mantissa        Mantissa of M0
# 12: exponent        Exponent of M0
# 13: lonalt          Longitude alternative (col1=origin, col13=centroid etc) (°)
# 14: latalt          Longitude alternative (col1=origin, col13=centroid etc) (°)
# 15: newid           tectoplot ID code: YYYY-MM-DDTHH:MM:SS
# 16: TAz             Azimuth of T axis
# 17: TInc            Inclination of T axis
# 18: Naz             Azimuth of N axis
# 19: Ninc            Inclination of N axis
# 20: Paz             Azimuth of P axis
# 21: Pinc            Inclination of P axis
# 22: Mrr             Moment tensor
# 23: Mtt             Moment tensor
# 24: Mpp             Moment tensor
# 25: Mrt             Moment tensor
# 26: Mrp             Moment tensor
# 27: Mtp             Moment tensor
# 28: MW              MW converted from M0 using M_{\mathrm {w} }={\frac {2}{3}}\log _{10}(M_{0})-10.7
# 29: depthalt        Depth alternative (col1=origin, col13=centroid etc) (km)
# (30: seconds)       Epoch time in seconds after scrape_isc_focals_expand.sh is run

# Output is a file containing centroid (gcmt_centroid.txt) and origin (gcmt_origin.txt) location focal mechanisms in tectoplot 27 field format:

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
echo "Extracting GCMT focal mechanisms from NDK to tectoplot format, 29 fields"

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

rm -f ./gcmt_origin_init.txt
rm -f ./gcmt_centroid_init.txt

awk < all_txt.txt '{
  if ($12 > 180) {
    $12=$12-360
  }
  if ($12 < -360) {
    $12=$12+360
  }
  if ($1 > 180) {
    $1=$1-360
  }
  if ($1 < -360) {
    $1=$1+360
  }
  print "G", $12, $13, $14, $4, $5, $6, $7, $8, $9, $10, $11, $1, $2, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $3 >> "./gcmt_origin_init.txt"
  print "G", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $14 >> "./gcmt_centroid_init.txt"
  }'

rm -f ./all_txt.txt
rm -f ./gcmt_origin_init.txt
rm -f ./gcmt_centroid_init.txt
