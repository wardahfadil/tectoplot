#!/bin/bash

# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# Download the ISC focal mechanism catalog for the entire globe, using a month-
# by-month query. GCMT mechanisms from before 1976 (when the GCMT catalog
# starts) are marked as G_CMTpre and are mainly deep focus earthquakes.

[[ ! -d $ISCDIR ]] && mkdir -p $ISCDIR

cd $ISCDIR

earliest_year=1952
# this_year=$(date | gawk '{print $(NF)}')

today=$(date "+%Y %m %d")
this_year=$(echo $today | gawk '{print $1}')
this_month=$(echo $today | gawk '{print $2}')
this_day=$(echo $today | gawk '{print $3}')


# echo "Deleting ISC scrape file from present year to ensure updated catalog: isc_focals_${this_year}.dat"
# rm -f isc_focals_${this_year}.dat

# for year in $(seq $earliest_year $this_year); do
#   if [[ ! -e isc_focals_${year}.dat ]]; then
#     echo "Dowloading focal mechanisms for ${year}"
#     curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=01&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=12&end_day=31&end_time=23%3A59%3A59" > isc_focals_${year}.dat
#   else
#     echo "Already have file isc_focals_${year}.dat... not downloading."
#   fi
# done

if [[ -e ${ISCDIR}"isc_extract.cat" ]]; then
  echo "ISC catalog ${ISCDIR}isc_extract.cat exists. Trying to update only with latest events."
  echo "This may fail if the database is so out of date that the web server chokes."

  lastevent_ymd=$(tail -n 1 ${ISCDIR}"isc_extract.cat" | gawk '{
    datestr=$3
    split(datestr, ymdstr, "T")
    split(ymdstr[1], ymd, "-")
    split(ymdstr[2], hms, ":")
    if (hms[3]<60) {
      hms[3]=hms[3]+1
    }
    print ymd[1], ymd[2], ymd[3], hms[1], hms[2], hms[3]
  }')
  last_year=$(echo $lastevent_ymd | gawk '{print $1}')
  last_month=$(echo $lastevent_ymd | gawk '{print $2}')
  last_day=$(echo $lastevent_ymd | gawk '{print $3}')
  last_hour=$(echo $lastevent_ymd | gawk '{print $4}')
  last_minute=$(echo $lastevent_ymd | gawk '{print $5}')
  last_second=$(echo $lastevent_ymd | gawk '{print $6}')
  echo "Trying to download only the events after last event in catalog:", $last_year "/" $last_month "/" $last_day " " $last_hour ":" $last_minute ":" $last_second, "to", $this_year "/" $this_month "/" $this_day
  echo   curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot"
  curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${last_year}&start_month=${last_month}&start_day=${last_day}&start_time=${last_hour}%3A${last_minute}%3A${last_second}&end_year=${this_year}&end_month=${this_month}&end_day=${this_day}&end_time=23%3A59%3A59" > isc_focals_uptodate.dat

  if [[ $(grep "EVENT_ID" isc_focals_uptodate.dat | wc -l) -lt 1 ]]; then
    echo "No ISC focal events to add to database"
  else
    echo "Here we add the events"
    BEFORE=$(wc -l < ${ISCDIR}"isc_extract.cat")
    cat isc_focals_uptodate.dat | sed -n '/N_AZM/,/^STOP/p' | sed '1d;$d' | sed '$d' | \
                    grep -v "PNSN" | grep -v "EVBIB" | ${CMTTOOLS} - I I >> ${ISCDIR}"isc_extract.cat"
    AFTER=$(wc -l < ${ISCDIR}"isc_extract.cat")
    ADDED=$(echo "$AFTER - $BEFORE" | bc)
    echo "Added $ADDED events to catalog."
  fi
else
  echo "ISC catalog does not exist. Reconstructing from downloaded files, or downloading as necessary."
  for year in $(seq $earliest_year $this_year); do
    # echo "Looking for isc_focals_${year}"
      if [[ $year -le $this_year ]]; then
        [[ ! -e isc_focals_${year}_01to04.dat ]] && echo "Dowloading ISC focals for ${year}-01to04" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=01&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=04&end_day=30&end_time=23%3A59%3A59" > isc_focals_${year}_01to04.dat
        [[ ! -e isc_focals_${year}_05to08.dat ]] && echo "Dowloading ISC focals for ${year}-05to08" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=05&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=08&end_day=31&end_time=23%3A59%3A59" > isc_focals_${year}_05to08.dat
        [[ ! -e isc_focals_${year}_09to12.dat ]] && echo "Dowloading ISC focals for ${year}-09to12" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=09&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=12&end_day=31&end_time=23%3A59%3A59" > isc_focals_${year}_09to12.dat
      else
        # Download the data from this year to ensure up-to-date seismicity
        echo "Dowloading seismicity for current ${year}-01to04" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=01&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=04&end_day=30&end_time=23%3A59%3A59" > isc_focals_${year}_01to04.dat
        echo "Dowloading seismicity for current ${year}-05to08" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=05&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=08&end_day=31&end_time=23%3A59%3A59" > isc_focals_${year}_05to08.dat
        echo "Dowloading seismicity for current ${year}-09to12" && curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=FMCSV&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&searchshape=GLOBAL&srn=&grn=&start_year=${year}&start_month=09&start_day=01&start_time=00%3A00%3A01&end_year=${year}&end_month=12&end_day=31&end_time=23%3A59%3A59" > isc_focals_${year}_09to12.dat
      fi
      # Currently the file size for no events is 160 bytes
      if [[ -e isc_focals_${year}_01to04.dat && $fsize -lt 2000 ]]; then
        fsize=$(wc -c < isc_focals_${year}_01to04.dat)
        echo "isc_focals_${year}_01to04.dat is empty"
        rm -f isc_focals_${year}_01to04.dat
      fi
      if [[ -e isc_focals_${year}_05to08.dat && $fsize -lt 2000 ]]; then
        fsize=$(wc -c < isc_focals_${year}_05to08.dat)
        echo "isc_focals_${year}_05to08.dat is empty"
        rm -f isc_focals_${year}_05to08.dat
      fi
      if [[ -e isc_focals_${year}_09to12.dat && $fsize -lt 2000 ]]; then
        fsize=$(wc -c < isc_focals_${year}_09to12.dat)
        echo "isc_focals_${year}_09to12.dat is empty"
        rm -f isc_focals_${year}_09to12.dat
      fi
  done


  # Label GCMT solutions earlier than 1976 so we don't delete them later.
  echo "Changing GCMT to G_CMTpre in files before 1976 (in place)"
  for year in $(seq $earliest_year 1976); do
      sed -i '' 's/GCMT     /G_CMTpre  /g' isc_focals_${year}_01to04.dat
      sed -i '' 's/GCMT     /G_CMTpre  /g' isc_focals_${year}_05to08.dat
      sed -i '' 's/GCMT     /G_CMTpre  /g' isc_focals_${year}_09to12.dat
  done

  # Parse the ISC format file (which has annoying header and footer) and import
  # into tectoplot format using CMTTOOLS

  rm -f isc_extract.cat
  for foc_file in isc_focals_*.dat; do
    echo "$foc_file: Removing EVBIB and PNSN mechanisms and extracting catalog."
    cat $foc_file | sed -n '/N_AZM/,/^STOP/p' | sed '1d;$d' | sed '$d' | \
                    grep -v "PNSN" | grep -v "EVBIB" | ${CMTTOOLS} - I I >> ${ISCDIR}"isc_extract.cat"
  done
fi
