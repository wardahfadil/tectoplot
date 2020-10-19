#!/bin/bash
DODOWNLOAD=1
# Download the ISC focal mechanism catalog for the entire globe, using a month-by-month query
# Sanitize the data to be included with GCMT focal mechanisms. This means removing events
# that have a GCMT entry in the ISC database, removing events without Mw or S/D/R data.
# We convert from MW to M0.
#
# ISC FORMAT
# 1       , 2     , 3   , 4   , 5  , 6  , 7    , 8       , 9     ,
# EVENT_ID, AUTHOR, DATE, TIME, LAT, LON, DEPTH, CENTROID, AUTHOR,
#
# 10, 11, 12, 13,  14,  15,  16,  17,  18,  19,     20,  21,   22,     23,  24,   25,
# EX, MO, MW, EX, MRR, MTT, MPP, MRT, MTP, MPR, STRIKE, DIP, RAKE, STRIKE, DIP, RAKE,
#
# 26,    27,   28,    29,    30,   31,    32,    33,   34,    35
# EX, T_VAL, T_PL, T_AZM, P_VAL, P_PL, P_AZM, N_VAL, N_PL, N_AZM
#
# 6, 5, 7
# 20, 21, 22, 23, 24, 25
# ?, ?
# 6, 5, newid
# 29, 28, 35, 34, 32, 31
# 14, 15, 16, 17, 19, 18
# 12
#
# GCMT FORMAT
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
#
#

ISC_FOCALS_DIR="/Users/kylebradley/Dropbox/TectoplotData/ISC/monthly_focals/"
GCMT_DIR="/Users/kylebradley/Dropbox/TectoplotData/GCMT/"

[[ ! -d $ISC_FOCALS_DIR ]] && mkdir -p $ISC_FOCALS_DIR

cd $ISC_FOCALS_DIR

if [[ $DODOWNLOAD -eq 1 ]]; then

  earliest_year=1900
  this_year=2020

  for year in $(seq $earliest_year $this_year); do
    if [[ ! -e isc_focals_${year}.dat ]]; then
      echo "Dowloading focal mechanisms for ${year}"
      curl "http://www.isc.ac.uk/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=05&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=8&end_day=19&end_time=00%3A00%3A00" > isc_focals_${year}.dat
    else
      echo "Already have file isc_focals_${year}.dat... not downloading."
    fi
  done

  rm -f isc_focals_allyears_orig.cat
  for foc_file in isc_focals_*.dat; do
    echo "Concatenating file $foc_file to joined catalog."
    cat $foc_file | sed -n '/N_AZM/,/^STOP/p' | sed '1d;$d' | sed '$d' >> isc_focals_allyears_orig.cat
  done

  echo "Removing events without MW; and converting from MW to M0 (coeff) (exponent)."
  awk -F, < isc_focals_allyears_orig.cat '{

    if ($12+0>0) {
      expmag=sprintf("%e", 10^(($12+10.7)*3/2));
      print $0 "," expmag
    }
  }' | sed 's/e+/,/g' > isc_focals_allyears_trim.cat

  echo "Removing events without a nodal plane 1/2 strike value."
  awk -F, < isc_focals_allyears_trim.cat '{
    if ($20+0>0 && $23+0>0) {
      print
    }
  }' > isc_focals_allyears_trim_withstrike.cat

  cp isc_focals_allyears_trim_withstrike.cat isc_prioritize.cat

  # Determine the number of events per source institution and set priority
  awk < isc_focals_allyears_trim_withstrike.cat -F, '{ seen[$2]++ } END { for (key in seen) { print key key seen[key] } }' | sort -r -n -k 3 > source_list.cat

  awk < source_list.cat '{
    printf "s/%s/%02d%s/g\n", $1, NR, $1
  }' > replaceforward.cat

  awk < source_list.cat '{
    printf "s/%02d%s/%s/g\n", NR, $1, $1
  }' > replacebackward.cat

  # Remove duplicates based on ID with the priority list. Events with GCMT equivalent are removed.
  sed -f replaceforward.cat isc_focals_allyears_trim_withstrike.cat | awk -F, '!seen[$1]++' > isc_focals_allyears_trim_withstrike_rep1.cat

  # Need to make an event ID code out of $1 that matches: 2018-04-01T01:14:42
  # PNSN contributes nasty events with values of 9999999999 - remove!

  # Remove GCMT mechanisms and events with centroid locations, output to psmeca 14 format
  sed -f replacebackward.cat isc_focals_allyears_trim_withstrike_rep1.cat | awk -F, '{if ($2 !~ /GCMT/ && $8 !~ /TRUE/) print}' >  isc_focals_allyears_trim_withstrike_rep1_nogcmt_origin.cat
  awk < isc_focals_allyears_trim_withstrike_rep1_nogcmt_origin.cat -F, '{print $6+0, $5+0, $7+0, $20+0, $21+0, $22+0, $23+0, $24+0, $25+0, $36+0, $37+0, $6+0, $5+0, sprintf("%sT%s", $3, substr($4, 1, 8)) }' | grep -v 9999999999 > isc_nogcmt_origin.txt

  # Keep only non-GCMT ISC centroid locations, output to psmeca 14 format
  sed -f replacebackward.cat isc_focals_allyears_trim_withstrike_rep1.cat | awk -F, '{if ($2 !~ /GCMT/ && $8 ~ /TRUE/) print}' >  isc_focals_allyears_trim_withstrike_rep1_nogcmt_centroid.cat
  awk < isc_focals_allyears_trim_withstrike_rep1_nogcmt_centroid.cat -F, '{print $6+0, $5+0, $7+0, $20+0, $21+0, $22+0, $23+0, $24+0, $25+0, $36+0, $37+0, $6+0, $5+0, sprintf("%sT%s", $3, substr($4, 1, 8)) }' | grep -v 9999999999 > isc_nogcmt_centroid.txt
fi


# Need to manually concatenate ISC non-GCMT origins with GCMT origins
# cat ~/Dropbox/TectoplotData/GCMT/

# Currently, GCMT mechanisms not reported in the ISC catalog have their non-GCMT equivalents from ISC added to the mixed archive.
# This pollutes the dataset with two mechanisms from one event. More than two is unlikely due to removing duplicate IDs above.
# # Tag GCMT with a G, ISC with an I.
# Concatenate all data.
# Sort by ID (time)
# For adjacent events, if the times are similar enough (within 10 seconds) and close enough (within 1 degree lat/lon), remove the non-G event.


if [[ -d $GCMT_DIR && -e $GCMT_DIR/gcmt_origin.txt && -e $GCMT_DIR/gcmt_centroid.txt ]]; then

  awk < isc_nogcmt_origin.txt '{
    split($14, a, "-")
    year=a[1]
    month=a[2]
    split(a[3],b,"T")
    day=b[1]
    split(b[2],c,":")
    hour=c[1]
    minute=c[2]
    second=c[3]
    the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
    secs = mktime(the_time);
    print "I", $0, secs
  }' > I_isc_nogcmt_origin.txt


  awk < isc_nogcmt_centroid.txt '{
    split($14, a, "-")
    year=a[1]
    month=a[2]
    split(a[3],b,"T")
    day=b[1]
    split(b[2],c,":")
    hour=c[1]
    minute=c[2]
    second=c[3]
    the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
    secs = mktime(the_time);
    print "I", $0, secs
  }' > I_isc_nogcmt_centroid.txt

  awk < ${GCMT_DIR}gcmt_origin.txt '{
    split($14, a, "-")
    year=a[1]
    month=a[2]
    split(a[3],b,"T")
    day=b[1]
    split(b[2],c,":")
    hour=c[1]
    minute=c[2]
    second=c[3]
    the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
    secs = mktime(the_time);
    print "G", $0, secs
  }' > ${GCMT_DIR}G_gcmt_origin.txt

  awk < ${GCMT_DIR}gcmt_centroid.txt '{
    split($14, a, "-")
    year=a[1]
    month=a[2]
    split(a[3],b,"T")
    day=b[1]
    split(b[2],c,":")
    hour=c[1]
    minute=c[2]
    second=c[3]
    the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
    secs = mktime(the_time);
    print "G", $0, secs
  }' > ${GCMT_DIR}G_gcmt_centroid.txt

  cat ${GCMT_DIR}G_gcmt_origin.txt I_isc_nogcmt_origin.txt | sort -n -k 16 > IG_gcmt_isc_origin.txt
  cat ${GCMT_DIR}G_gcmt_centroid.txt I_isc_nogcmt_centroid.txt | sort -n -k 16 > IG_gcmt_isc_centroid.txt

  sed '1d'  IG_gcmt_isc_origin.txt > IG_gcmt_isc_origin_cut1.txt
  sed '1d'  IG_gcmt_isc_centroid.txt > IG_gcmt_isc_centroid_cut1.txt

  echo "Removing events closer than 0.1 degrees lat/lon AND within 30 seconds of each other"

  paste IG_gcmt_isc_origin.txt IG_gcmt_isc_origin_cut1.txt | awk 'function abs(v) {return v < 0 ? -v : v} {
    if (!($32-$16 < 60 && abs($2-$18) < 0.1 && (abs($3-$19) < 0.1))) {
      # Not a duplicate event
      if ($1 == "G" && $2 == "I") {
        # Keep the GCMT if it exists
        print $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
      } else if ($1 == "I" && $2 == "G") {
        # Keep the GCMT if it exists
        print $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
      } else {
        # No preference for I,I or G,G events
        print $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
      }
    }
}' > ${GCMT_DIR}gcmt_isc_origin.txt

paste IG_gcmt_isc_centroid.txt IG_gcmt_isc_centroid_cut1.txt | awk 'function abs(v) {return v < 0 ? -v : v} {
  if (!($32-$16 < 60 && abs($2-$18) < 0.1 && (abs($3-$19) < 0.1))) {
    # Not a duplicate event
    if ($1 == "G" && $2 == "I") {
      # Keep the GCMT if it exists
      print $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
    } else if ($1 == "I" && $2 == "G") {
      # Keep the GCMT if it exists
      print $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
    } else {
      # No preference for I,I or G,G events
      print $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
    }
  }
}' > ${GCMT_DIR}gcmt_isc_centroid.txt

pre_c=$(wc -l < IG_gcmt_isc_centroid.txt)
post_c=$(wc -l < ${GCMT_DIR}gcmt_isc_centroid.txt)
pre_o=$(wc -l < IG_gcmt_isc_origin.txt)
post_o=$(wc -l < ${GCMT_DIR}gcmt_isc_origin.txt)
echo "Wrote combined ISC/GCMT origin/centroid datasets:"
echo "${GCMT_DIR}gcmt_isc_origin.txt (Before=$pre_o, After=$post_o)"
echo "${GCMT_DIR}gcmt_isc_centroid.txt (Before=$pre_c, After=$post_c)"

fi

# rm -f *.cat I_* IG_*
