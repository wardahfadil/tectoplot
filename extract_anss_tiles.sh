#!/bin/bash
# extract_anss.sh DATADIR MINLON MAXLON MINLAT MAXLAT MINTIME MAXTIME MINMAG MAXMAG OUTFILE

# This script will print all events from a tiled ANSS catalog directory (tile_lon_lat.cat)
# where the files are in Comcat CSV format without a header line, selected by:

# Additionally, the script will filter out some non-natural events by excluding lines
# containing: blast quarry explosion

# CSV format is:
# 1    2        3         4     5   6       7   8   9    10  11  12 13      14    15   16              17         18       19     20     21             22
# time,latitude,longitude,depth,mag,magType,nst,gap,dmin,rms,net,id,updated,place,type,horizontalError,depthError,magError,magNst,status,locationSource,magSource

# Epoch time calculation doesn't work for events before 1900 (mktime returns -1) so return 1900-01-01T00:00:00 time instead

# OSX has a strange problem, probably with libc? that makes gawk/awk mktime fail for a few specific
# dates: 1941-09-01, 1942-02-16, and 1982-01-01. This is not a problem on a tested linux machine.

# Reads stdin, converts each item in a column and outputs same column format

function iso8601_to_epoch() {
  TZ=UTC

  awk '{
    # printf("%s ", $0)
    for(i=1; i<=NF; i++) {
      done=0
      timecode=substr($(i), 1, 19)
      split(timecode, a, "-")
      year=a[1]
      if (year < 1900) {
        print -2209013725
        done=1
      }
      month=a[2]
      split(a[3],b,"T")
      day=b[1]
      split(b[2],c,":")

      hour=c[1]
      minute=c[2]
      second=c[3]

      if (year == 1982 && month == 01 && day == 01) {
        printf("%s ", 378691200 + second + 60*minute * 60*60*hour)
        done=1
      }
      if (year == 1941 && month == 09 && day == 01) {
        printf("%s ", -895153699 + second + 60*minute * 60*60*hour)
        done=1

      }
      if (year == 1941 && month == 09 && day == 01) {
        printf("%s ", -879638400 + second + 60*minute * 60*60*hour)
        done=1
      }

      if (done==0) {
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        # print the_time > "/dev/stderr"
        epoch=mktime(the_time);
        printf("%s ", epoch)
      }
    }
    printf("\n")
  }'
}

DATADIR=$1

if ! [[ -d $DATADIR ]]; then
  echo "Seismicity directory $DATADIR does not exist." > /dev/stderr
  exit 1
fi

cd $DATADIR

# Calculate the epoch of the given time window
MINDATE_EPOCH=$(echo $6 | iso8601_to_epoch)
MAXDATE_EPOCH=$(echo $7 | iso8601_to_epoch)

# # Calculate the epochs represented by the different anss_events_.dat files
# ls anss_events_*.dat | sort -n -t '_' -k 3 -k 4 -k 5 > anss_files.txt
# awk < anss_files.txt -F_ '{
#     year=$3
#     month=$4
#     split($5, d, ".")
#     if (d[1]==1) {
#       beginday=1
#       endday=10
#     } else if (d[1] == 2) {
#       beginday=11
#       endday=20
#     } else {
#       beginday=21
#       endday=31
#     }
#     printf("%04i-%02i-%02iT%02i:%02i:%02i ",year,month,beginday,0,0,0);
#     printf("%04i-%02i-%02iT%02i:%02i:%02i\n",year,month,endday,23,59,60);
#   }' | iso8601_to_epoch > anss_epochs.txt
#
# paste anss_files.txt anss_epochs.txt > anss_select.txt

# # Initial selection of files based on their epoch range vs the input epoch range
# selected_files+=($(awk < anss_select.txt -v minepoch=${MINDATE_EPOCH} -v maxepoch=${MAXDATE_EPOCH} '{
#   if (! ($2 > maxepoch || $3 < minepoch)) {
#     print $1
#   }
# }' ))

# # Initial selection of files based on the input latitude and longitude range
selected_files=($(awk -v minlon=${2} -v maxlon=${3} -v minlat=${4} -v maxlat=${5} '
  function rd(n, multipleOf)
  {
    if (n % multipleOf == 0) {
      num = n
    } else {
       if (n > 0) {
          num = n - n % multipleOf;
       } else {
          num = n + (-multipleOf - n % multipleOf);
       }
    }
    return num
  }
  BEGIN   {
    minlattile=rd(minlat,5);
    minlontile=rd(minlon,5);
    maxlattile=rd(maxlat,5);
    maxlontile=rd(maxlon,5);
    maxlattile=(maxlattile>85)?85:maxlattile;
    maxlontile=(maxlontile>175)?175:maxlontile;
    print "Selecting tiles in domain [" minlon, maxlon, minlat, maxlat "] -> [" minlontile, maxlontile, minlattile, maxlattile "]"  > "/dev/stderr"

    for (i=minlontile; i<=maxlontile; i+=5) {
      for (j=minlattile; j<=maxlattile; j+=5) {
        printf("tile_%d_%d.cat\n", i, j)
      }
    }
  }'))

# exit

# EPOCH_1950=$(echo "1950-01-01T00:00:00" | iso8601_to_epoch)

# if [[ $(echo "$MINDATE_EPOCH < $EPOCH_1950") -eq 1 ]]; then
#   [[ -e old_anss_events_1000_to_1950.dat ]] && selected_files+=("old_anss_events_1000_to_1950.dat")
# fi
# The CSV files can have commas within the ID string messing up fields.
# Remove these and also the quotation marks in ID strings to give a parsable CSV file

cat ${selected_files[@]} | gawk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' | sed 's/\"//g' | \
  gawk -F, -v minlon=${2} -v maxlon=${3} -v minlat=${4} -v maxlat=${5} -v minepoch=${MINDATE_EPOCH} -v maxepoch=${MAXDATE_EPOCH} -v minmag=${8} -v maxmag=${9} -v mindepth=${10} -v maxdepth=${11} '
  ($1 != "time" && $15 == "earthquake" && $2 <= maxlat && $2 >= minlat && $5 >= minmag && $5 <= maxmag && $4 >= mindepth && $4 <= maxdepth) {
    if (($3 <= maxlon && $3 >= minlon) || ($3+360 <= maxlon && $3+360 >= minlon)) {

      # Now we check if the event actually falls inside the specified time window

      timecode=substr($1, 1, 19)
      split($1, a, "-")
      year=a[1]
      if (year < 1900) {
        epoch=-2209013725
        done=1
      } else {
        month=a[2]
        split(a[3],b,"T")
        day=b[1]
        split(b[2],c,":")

        hour=c[1]
        minute=c[2]
        second=c[3]

        if (year == 1982 && month == 01 && day == 01) {
          epoch=378691200 + second + 60*minute * 60*60*hour
          done=1
        }
        if (year == 1941 && month == 09 && day == 01) {
          epoch=-895153699 + second + 60*minute * 60*60*hour
          done=1
        }
        if (year == 1941 && month == 09 && day == 01) {
          epoch=-879638400 + second + 60*minute * 60*60*hour
          done=1
        }
      }
      if (done==0) {
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        epoch=mktime(the_time);
      }
      if (epoch >= minepoch && epoch <= maxepoch) {
        print
      }
    }
  }' > ${12}
