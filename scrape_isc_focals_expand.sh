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

# CURRENT FOCAL MECH DATABASE FORMAT IS
# Code, 6, 5, 7
# 20, 21, 22, 23, 24, 25
# ?, ?
# 6, 5, newid
# 29, 28, 35, 34, 32, 31
# 14, 15, 16, 17, 19, 18
# 12, Seconds
#
# # Translates to
# 1     2    3    4      5   6   7   8   9   10  11        12        13   14   15     16   17   18   19   20   21   22   23   24   25   26   27   28  29
# Code, Lon, Lat, Depth, S1, D1, R1, S2, D2, R2, Mantissa, Exponent, Lon, Lat, NewID, TAz, Tpl, Naz, Npl, Paz, Ppl, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, Mw, Seconds


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

  echo "Removing events without MW reported; and converting from MW to M0 (coeff) (exponent)."
  awk -F, < isc_focals_allyears_orig.cat '{
    if ($12+0>0) {
      expmag=sprintf("%e", 10^(($12+10.7)*3/2));
      print $0 "," expmag
    }
  }' | sed 's/e+/,/g' > isc_focals_allyears_trim.cat

  # isc_focals_allyears_trim.cat is in ISC+2 (37) format

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

  # Remove GCMT mechanisms and events with centroid locations, output to psmeca I+14+13 format
  sed -f replacebackward.cat isc_focals_allyears_trim_withstrike_rep1.cat | awk -F, '{if ($2 !~ /GCMT/ && $8 !~ /TRUE/) print}' >  isc_focals_allyears_trim_withstrike_rep1_nogcmt_origin.cat
  awk < isc_focals_allyears_trim_withstrike_rep1_nogcmt_origin.cat -F, '{print "I", $6+0, $5+0, $7+0, $20+0, $21+0, $22+0, $23+0, $24+0, $25+0, $36+0, $37+0, $6+0, $5+0, sprintf("%sT%s", $3, substr($4, 1, 8)), $29+0, $28+0, $35+0, $34+0, $32+0, $31+0, $14+0, $15+0, $16+0, $17+0, $19+0, $18+0, $12+0 }' | grep -v 9999999999 > isc_nogcmt_origin.txt


  # Code 6, 5, 7
  # 20, 21, 22, 23, 24, 25
  # ?, ?
  # 6, 5, newid
  # 29, 28, 35, 34, 32, 31
  # 14, 15, 16, 17, 19, 18
  # 12

  # Keep only non-GCMT ISC centroid locations, output to psmeca I+14+13 format
  sed -f replacebackward.cat isc_focals_allyears_trim_withstrike_rep1.cat | awk -F, '{if ($2 !~ /GCMT/ && $8 ~ /TRUE/) print}' >  isc_focals_allyears_trim_withstrike_rep1_nogcmt_centroid.cat
  awk < isc_focals_allyears_trim_withstrike_rep1_nogcmt_centroid.cat -F, '{print "I", $6+0, $5+0, $7+0, $20+0, $21+0, $22+0, $23+0, $24+0, $25+0, $36+0, $37+0, $6+0, $5+0, sprintf("%sT%s", $3, substr($4, 1, 8)), $29+0, $28+0, $35+0, $34+0, $32+0, $31+0, $14+0, $15+0, $16+0, $17+0, $19+0, $18+0, $12+0 }' | grep -v 9999999999 > isc_nogcmt_centroid.txt
fi

# Currently, GCMT mechanisms not reported in the ISC catalog have their non-GCMT equivalents from ISC added to the mixed archive.
# This pollutes the dataset with two mechanisms from one event. More than two is unlikely due to removing duplicate IDs done above.
# # Tag GCMT with a G, ISC with an I.
# Concatenate all data.
# Sort by ID (time)
# For adjacent events, if the times are similar enough (within X seconds) and close enough (within Y degrees lat/lon), remove only the non-G event.

if [[ -d $GCMT_DIR && -e $GCMT_DIR/gcmt_origin.txt && -e $GCMT_DIR/gcmt_centroid.txt ]]; then

  awk < isc_nogcmt_origin.txt '{
    split($15, a, "-")
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
    print $0, secs
  }' > I_isc_nogcmt_origin.txt


  awk < isc_nogcmt_centroid.txt '{
    split($15, a, "-")
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
    print $0, secs
  }' > I_isc_nogcmt_centroid.txt

  awk < ${GCMT_DIR}gcmt_origin.txt '{
    split($15, a, "-")
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
    print $0, secs
  }' > ${GCMT_DIR}G_gcmt_origin.txt

  awk < ${GCMT_DIR}gcmt_centroid.txt '{
    split($15, a, "-")
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
    print $0, secs
  }' > ${GCMT_DIR}G_gcmt_centroid.txt

fi

cat ${GCMT_DIR}G_gcmt_origin.txt I_isc_nogcmt_origin.txt | sort -n -k 29 > IG_gcmt_isc_origin.txt
cat ${GCMT_DIR}G_gcmt_centroid.txt I_isc_nogcmt_centroid.txt | sort -n -k 29 > IG_gcmt_isc_centroid.txt

sed '1d'  IG_gcmt_isc_origin.txt > IG_gcmt_isc_origin_cut1.txt
sed '1d'  IG_gcmt_isc_origin_cut1.txt > IG_gcmt_isc_origin_cut2.txt

sed '1d'  IG_gcmt_isc_centroid.txt > IG_gcmt_isc_centroid_cut1.txt
sed '1d'  IG_gcmt_isc_centroid_cut1.txt > IG_gcmt_isc_centroid_cut2.txt

paste IG_gcmt_isc_origin.txt IG_gcmt_isc_origin_cut1.txt IG_gcmt_isc_origin_cut2.txt > 3comp_origin.txt

#
#          [Mrr Mrt Mrp]   [ M[1] M[4] M[5] ]
# M = M0 * [Mrt Mtt Mtp] = [ M[4] M[2] M[6] ]
#          [Mrp Mtp Mpp]   [ M[5] M[6] M[3] ]

#    [Mrr Mrt Mrp] [ P[1] ]        [ P[1] ]       (M[1]*P[1]+M[4]*P[2]+M[5]*P[3]) = PEIG * P[1]
# M0*[Mrt Mtt Mtp]*[ P[2] ] = PEIG*[ P[2] ]  so   or PEIG = (M[1]*P[1]+M[4]*P[2]+M[5]*P[3])/P[1] (P1!=0)
#    [Mrp Mtp Mpp] [ P[3] ]        [ P[3] ]

# We want to remove from A any A event that is close to a C event
awk < 3comp_origin.txt '
function abs(v) {return v < 0 ? -v : v}
function atan(x) { return atan2(x,1) }
function asin(x) { return atan2(x, sqrt(1-x*x)) }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }
BEGIN { pi=atan2(0,-1) }
{
  if ($30 == "I") { # Only potentially do not print ISC events that might be GCMT repeats
    printme = 1
    # Large magnitude events can have farther apart origins (1.5 degrees) if their times are quite similar
    if ($57>7) {
      if ($1 == "G" && $58-$29 < 5 && abs($31-$2) < 1.5 && abs($32-$3) < 1.5) {
        printme=0
      }
      if ($59 == "G" && $87-$58 < 5 && abs($60-$31) < 1.5 && abs($61-$32) < 1.5) {
          printme = 0
      }
    } else {  # Smaller events have larger time differences but smaller distance windows
      if ($1 == "G" && $58-$29 < 30 && abs($31-$2) < 0.2 && abs($32-$3) < 0.2) {
        printme = 0
      }
      if ($59 == "G" && $87-$58 < 30 && abs($60-$31) < 0.2 && abs($61-$32) < 0.2) {
        printme = 0
      }
    }
  } else {
    printme = 1
  }
  if ($30 && printme == 1) {
     # Calculate moment tensor from strike/dip/rake of NP1, if it is zero
     if ($51 == 0 && $52 == 0 && $53 == 0 && $54 == 0 && $55 == 0 && $56 == 0) {
       strike=pi/180*$34
       dip=pi/180*$35
       rake=pi/180*$36
       M0=$40*(10^$41)
       M[1]=M0*sin(2*dip)*sin(rake)
       M[2]=-M0*(sin(dip)*cos(rake)*sin(2*strike)+sin(2*dip)*sin(rake)*sin(strike)*sin(strike))
       M[3]=M0*(sin(dip)*cos(rake)*sin(2*strike)-sin(2*dip)*sin(rake)*cos(strike)*cos(strike))
       M[4]=-M0*(cos(dip)*cos(rake)*cos(strike)+cos(2*dip)*sin(rake)*sin(strike))
       M[5]=M0*(cos(dip)*cos(rake)*sin(strike)-cos(2*dip)*sin(rake)*cos(strike))
       M[6]=-M0*(sin(dip)*cos(rake)*cos(2*strike)+0.5*sin(2*dip)*sin(rake)*sin(2*strike))

       maxscale=0
       for (key in M) {
         scale=int(log(M[key]>0?M[key]:-M[key])/log(10))
         maxscale=scale>maxscale?scale:maxscale
       }

       $51=M[1]/10^maxscale
       $52=M[2]/10^maxscale
       $53=M[3]/10^maxscale
       $54=M[4]/10^maxscale
       $55=M[5]/10^maxscale
       $56=M[6]/10^maxscale
     }
     # Calculate T/N/P axes from NP1 strike/dip/rake, if the axes values in the file are 0.
     if ($45 == 0 && $47 == 0 && $49 == 0) {
       strike=pi/180*$34
       dip=pi/180*$35
       rake=pi/180*$36

       # l is the slick vector
       l[1]=sin(strike)*cos(rake)-cos(strike)*cos(dip)*sin(rake)
       l[2]=cos(strike)*cos(rake)+sin(strike)*cos(dip)*sin(rake)
       l[3]=sin(dip)*sin(rake)
       # n is the normal vector
       n[1]=cos(strike)*sin(dip)
       n[2]=-sin(strike)*sin(dip)
       n[3]=cos(dip)

       P[1]=1/sqrt(2)*(n[1]-l[1])
       P[2]=1/sqrt(2)*(n[2]-l[2])
       P[3]=1/sqrt(2)*(n[3]-l[3])

       T[1]=1/sqrt(2)*(n[1]+l[1])
       T[2]=1/sqrt(2)*(n[2]+l[2])
       T[3]=1/sqrt(2)*(n[3]+l[3])

       Paz = rad2deg(atan2(P[1],P[2]))
       Pinc = rad2deg(asin(P[3]))
       if (Pinc>0) {
         Paz=(Paz+180)%360
       }
       if (Pinc<0) {
         Pinc=-Pinc
         Paz=(Paz+360)%360
       }
       Taz = rad2deg(atan2(T[1],T[2]))
       Tinc = rad2deg(asin(T[3]))
       if (Tinc>0) {
         Taz=(Taz+180)%360
       }
       if (Tinc<0) {
         Tinc=-Tinc
         Taz=(Taz+360)%360
       }
       # B (aka N)= n × l
       B[1]=(n[2]*l[3]-n[3]*l[2])
       B[2]=-(n[1]*l[3]-n[3]*l[1])
       B[3]=(n[1]*l[2]-n[2]*l[1])

       Baz = rad2deg(atan2(B[1],B[2]))
       Binc = rad2deg(asin(B[3]))
       if (Binc>0) {
         Baz=(Baz+180)%360
       }
       if (Binc<0) {
         Binc=-Binc
         Baz=(Baz+360)%360
       }
       # printf "% 0.2f % 0.2f % 0.2f % 0.2f % 0.2f % 0.2f\n", Paz, Pinc, Taz, Tinc, Baz, Binc
       # TAz, TInc, Naz, Ninc, Paz, Pinc,
       $45=Taz
       $46=Tinc
       $47=Baz
       $48=Binc
       $49=Paz
       $50=Pinc
     } else {
       Tinc=$46
       Binc=$48
       Pinc=$50
     }

# Calculate the focal mechanism type (N,R,T) and append it to the ID CODE:
# e.g. IN = ISC/Normal  GT = GCMT/Thrust IS = ISC/StrikeSlip
# Following the classification scheme of FMC; Jose-Alvarez, 2019 https://github.com/Jose-Alvarez/FMC

    if (Pinc >= Binc && Pinc >= Tinc) {
      class="N"
    } else if (Binc >= Pinc && Binc >= Tinc) {
      class="S"
    } else {
      class="T"
    }

    printf "%s%s", $30, class
    for(i=31; i<=58; ++i) {
      printf " %s", $(i)
    }
    printf("\n")
  }
}' > ${GCMT_DIR}gcmt_isc_origin.txt

paste IG_gcmt_isc_centroid.txt IG_gcmt_isc_centroid_cut1.txt IG_gcmt_isc_centroid_cut2.txt > 3comp_centroid.txt

echo "Removing events closer than 0.2 degrees lat/lon AND within 30 seconds of each other"
awk < 3comp_centroid.txt '
function abs(v) {return v < 0 ? -v : v}
function atan(x) { return atan2(x,1) }
function asin(x) { return atan2(x, sqrt(1-x*x)) }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }
BEGIN { pi=atan2(0,-1) }
{
  if ($30 == "I") { # Only potentially do not print ISC events that might be GCMT repeats
    printme = 1
    # Large magnitude events can have farther apart origins (1.5 degrees) if their times are quite similar
    if ($57>7) {
      if ($1 == "G" && $58-$29 < 5 && abs($31-$2) < 1.5 && abs($32-$3) < 1.5) {
        printme=0
      }
      if ($59 == "G" && $87-$58 < 5 && abs($60-$31) < 1.5 && abs($61-$32) < 1.5) {
          printme = 0
      }
    } else {  # Smaller events have larger time differences but smaller distance windows
      if ($1 == "G" && $58-$29 < 30 && abs($31-$2) < 0.2 && abs($32-$3) < 0.2) {
        printme = 0
      }
      if ($59 == "G" && $87-$58 < 30 && abs($60-$31) < 0.2 && abs($61-$32) < 0.2) {
        printme = 0
      }
    }
  } else {
    printme = 1
  }
  if ($30 && printme == 1) {
     # Calculate moment tensor from strike/dip/rake of NP1, if it is zero
     if ($51 == 0 && $52 == 0 && $53 == 0 && $54 == 0 && $55 == 0 && $56 == 0) {
       strike=pi/180*$34
       dip=pi/180*$35
       rake=pi/180*$36
       M0=$40*(10^$41)
       M[1]=M0*sin(2*dip)*sin(rake)
       M[2]=-M0*(sin(dip)*cos(rake)*sin(2*strike)+sin(2*dip)*sin(rake)*sin(strike)*sin(strike))
       M[3]=M0*(sin(dip)*cos(rake)*sin(2*strike)-sin(2*dip)*sin(rake)*cos(strike)*cos(strike))
       M[4]=-M0*(cos(dip)*cos(rake)*cos(strike)+cos(2*dip)*sin(rake)*sin(strike))
       M[5]=M0*(cos(dip)*cos(rake)*sin(strike)-cos(2*dip)*sin(rake)*cos(strike))
       M[6]=-M0*(sin(dip)*cos(rake)*cos(2*strike)+0.5*sin(2*dip)*sin(rake)*sin(2*strike))

       maxscale=0
       for (key in M) {
         scale=int(log(M[key]>0?M[key]:-M[key])/log(10))
         maxscale=scale>maxscale?scale:maxscale
       }

       $51=M[1]/10^maxscale
       $52=M[2]/10^maxscale
       $53=M[3]/10^maxscale
       $54=M[4]/10^maxscale
       $55=M[5]/10^maxscale
       $56=M[6]/10^maxscale
     }
     # Calculate T/N/P axes from NP1 strike/dip/rake, if the axes values in the file are 0.
     if ($45 == 0 && $47 == 0 && $49 == 0) {
       strike=pi/180*$34
       dip=pi/180*$35
       rake=pi/180*$36

       # l is the slick vector
       l[1]=sin(strike)*cos(rake)-cos(strike)*cos(dip)*sin(rake)
       l[2]=cos(strike)*cos(rake)+sin(strike)*cos(dip)*sin(rake)
       l[3]=sin(dip)*sin(rake)
       # n is the normal vector
       n[1]=cos(strike)*sin(dip)
       n[2]=-sin(strike)*sin(dip)
       n[3]=cos(dip)

       P[1]=1/sqrt(2)*(n[1]-l[1])
       P[2]=1/sqrt(2)*(n[2]-l[2])
       P[3]=1/sqrt(2)*(n[3]-l[3])

       T[1]=1/sqrt(2)*(n[1]+l[1])
       T[2]=1/sqrt(2)*(n[2]+l[2])
       T[3]=1/sqrt(2)*(n[3]+l[3])

       Paz = rad2deg(atan2(P[1],P[2]))
       Pinc = rad2deg(asin(P[3]))
       if (Pinc>0) {
         Paz=(Paz+180)%360
       }
       if (Pinc<0) {
         Pinc=-Pinc
         Paz=(Paz+360)%360
       }
       Taz = rad2deg(atan2(T[1],T[2]))
       Tinc = rad2deg(asin(T[3]))
       if (Tinc>0) {
         Taz=(Taz+180)%360
       }
       if (Tinc<0) {
         Tinc=-Tinc
         Taz=(Taz+360)%360
       }
       # B (aka N)= n × l
       B[1]=(n[2]*l[3]-n[3]*l[2])
       B[2]=-(n[1]*l[3]-n[3]*l[1])
       B[3]=(n[1]*l[2]-n[2]*l[1])

       Baz = rad2deg(atan2(B[1],B[2]))
       Binc = rad2deg(asin(B[3]))
       if (Binc>0) {
         Baz=(Baz+180)%360
       }
       if (Binc<0) {
         Binc=-Binc
         Baz=(Baz+360)%360
       }
       # printf "% 0.2f % 0.2f % 0.2f % 0.2f % 0.2f % 0.2f\n", Paz, Pinc, Taz, Tinc, Baz, Binc
       # TAz, TInc, Naz, Ninc, Paz, Pinc,
       $45=Taz
       $46=Tinc
       $47=Baz
       $48=Binc
       $49=Paz
       $50=Pinc
     } else {
       Tinc=$46
       Binc=$48
       Pinc=$50
     }

# Calculate the focal mechanism type (N,R,T) and append it to the ID CODE:
# e.g. IN = ISC/Normal  GT = GCMT/Thrust IS = ISC/StrikeSlip
# Following the classification scheme of FMC; Jose-Alvarez, 2019 https://github.com/Jose-Alvarez/FMC

    if (Pinc >= Binc && Pinc >= Tinc) {
      class="N"
    } else if (Binc >= Pinc && Binc >= Tinc) {
      class="S"
    } else {
      class="T"
    }

    printf "%s%s", $30, class
    for(i=31; i<=58; ++i) {
      printf " %s", $(i)
    }
    printf("\n")
  }
}' > ${GCMT_DIR}gcmt_isc_centroid.txt

pre_c=$(wc -l < IG_gcmt_isc_centroid.txt)
post_c=$(wc -l < ${GCMT_DIR}gcmt_isc_centroid.txt)
pre_o=$(wc -l < IG_gcmt_isc_origin.txt)
post_o=$(wc -l < ${GCMT_DIR}gcmt_isc_origin.txt)
echo "Wrote combined ISC/GCMT origin/centroid datasets:"
echo "${GCMT_DIR}gcmt_isc_origin.txt (Before=$pre_o, After=$post_o)"
echo "${GCMT_DIR}gcmt_isc_centroid.txt (Before=$pre_c, After=$post_c)"

# rm -f *.cat I_* IG_*
