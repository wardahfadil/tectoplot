#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# Download the entire global ISC seismicity
# catalog and store in weekly data files, then process into 5 degree tiles.

# Most of the download time is the pull request, but making larger chunks leads
# to some failures due to number of events. The script can be run multiple times
# and will not re-download files that already exist. Some error checking is done
# to look for empty files and delete them.

# Example curl command:
## curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=7&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > isc_seis_2019_01_week1.dat
# curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=31&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > isc_seis_${year}_${month}.dat

# Strategy: Download from 1900-1950 as single file
#           Download from 1950-1980 as yearly files
#           Download from 1981-present as weekly files

# tac not available in all environments but tail usually is

function tac() {
  tail -r -- "$@";
}

function epoch_ymdhms() {
  echo "$1 $2 $3 $4 $5 $6" | gawk '{
    the_time=sprintf("%i %i %i %i %i %i",$1,$2,$3,$4,$5,$6);
    print mktime(the_time);
  }'
}

function lastday_of_month() {
  month=$(printf "%02d" $1)
  case $month in
      0[13578]|10|12) days=31;;
      0[469]|11)	    days=30;;
      02) days=$(echo $year | gawk '{
          jul=strftime("%j",mktime($1 " 12 31 0 0 0 "));
          if (jul==366) {
            print 29
          } else {
            print 28
          }
         }')
  esac
  echo $days
}

function download_and_check() {
  local s_year=$1
  local s_month=$2
  local s_day=$3
  local e_year=$4
  local e_month=$5
  local e_day=$6

  start_epoch=$(epoch_ymdhms $s_year $s_month $s_day 0 0 0)
  end_epoch=$(epoch_ymdhms $e_year $e_month $e_day 23 59 59)

  # Test whether the file is entirely within the future. If so, don't download.
  if [[ $start_epoch -ge $today_epoch ]]; then
    echo "Requested range is beyond current date. Not downloading anything."
  else
    local OUTFILE=$(printf "isc_seis_%04d%02d%02d_%04d%02d%02d.dat" $s_year $s_month $s_day $e_year $e_month $e_day)
    # echo outfile is $OUTFILE
    if [[ $start_epoch -le $today_epoch && $end_epoch -gt $today_epoch ]]; then
      echo "Requested file spans today and needs to be redownloaded."
      rm -f $OUTFILE
    fi

    # Test whether the file time spans the current date. If so, delete it so we can redownload.

    # if [[ $s_year -le $this_year && $s_month -ge $this_month && $s_day -gt $this_day ]]; then
    #   if [[ $s_year -ge $this_year && $s_month -ge $this_month && $s_day -gt $this_day ]]; then
    #     echo "Requested range is beyond current date. Not downloading anything."
    #   echo "Requested range is beyond current date. Not downloading anything."

    # Check if this is a valid ISC_SEIS file by looking for the terminating STOP command
    if [[ -e "$OUTFILE" ]]; then
        # echo "Requested file $OUTFILE already exists"
        local iscomplete=$(tail -n 10 "${OUTFILE}" | grep STOP | wc -l)  # == 1 is complete, == 0 is not
        if [[ $iscomplete -eq 0 ]]; then
          echo "${OUTFILE} is not a complete/valid ISC SEIS file. Deleting"
          rm -f "${OUTFILE}"
        fi
    fi
    if [[ ! -e "$OUTFILE" ]]; then
      echo "Dowloading seismicity from ${s_year}-${s_month}-${s_day} to ${e_year}-${e_month}-${e_day}"
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${s_year}&start_month=${s_month}&start_day=${s_day}&start_time=00%3A00%3A00&end_year=${e_year}&end_month=${e_month}&end_day=${e_day}&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $OUTFILE
      local iscomplete=$(tail -n 10 "${OUTFILE}" | grep STOP | wc -l)  # == 1 is complete, == 0 is not
      if [[ $iscomplete -eq 0 ]]; then
        echo "Newly downloaded ${OUTFILE} is not a complete/valid ISC SEIS file. Deleting"
        rm -f "${OUTFILE}"
      else
        echo ${OUTFILE} >> to_add_to_cat.txt
        add_to_catalog+=("$OUTFILE")
      fi
    fi
  fi
}

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

function has_a_line() {
  if [[ -e $1 ]]; then
    gawk '
    BEGIN {
      x=0
    }
    {
      if(NR>2) {
        x=1;
        exit
      }
    }
    END {
      if(x>0) {
        print 1
      } else {
        print 0
      }
    }' < $1
  else
    echo 0
  fi
}

function download_isc_file() {
  local parsed=($(echo $1 | awk -F_ '{ split($5, d, "."); print $3, $4, d[1]}'))
  local year=${parsed[0]}
  local month=${parsed[1]}
  local segment=${parsed[2]}

  if [[ $1 =~ "isc_events_1900_to_1950.cat" ]]; then
    echo "Downloading seismicity for $1: Year=1900 to 1950"
    curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=1900&start_month=01&start_day=01&start_time=00%3A00%3A00&end_year=1950&end_month=12&end_day=31&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
  else
    echo "Downloading seismicity for $1: Year=${year} Month=${month} Segment=${segment}"

    case ${parsed[2]} in
      1)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=01&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=07&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      2)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=08&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=14&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      3)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=15&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=21&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
      4)
      last_day=$(lastday_of_month $month)
      curl "${ISC_MIRROR}/cgi-bin/web-db-v4?request=COMPREHENSIVE&out_format=CATCSV&searchshape=RECT&bot_lat=-90&top_lat=90&left_lon=-180&right_lon=180&ctr_lat=&ctr_lon=&radius=&max_dist_units=deg&srn=&grn=&start_year=${year}&start_month=${month}&start_day=22&start_time=00%3A00%3A00&end_year=${year}&end_month=${month}&end_day=${last_day}&end_time=23%3A59%3A59&min_dep=&max_dep=&min_mag=&max_mag=&req_mag_type=Any&req_mag_agcy=prime" > $1
      ;;
    esac
  fi
  # If curl returned a non-zero exit code or doesn't contain at least two lines, delete the file we just created
  if ! [ 0 -eq $? ]; then
    echo "File $1 had download error. Deleting."
    rm -f $1
  elif [[ $(has_a_line $1) -eq 0 ]]; then
    echo "File $1 was empty. Deleting."
    rm -f $1
  fi
}



ISC_MIRROR="http://isc-mirror.iris.washington.edu"



# Change into the ISC data directory, creating if needed, and check Tiles directory
# Create tile files using touch

ISCDIR="${1}"

[[ ! -d $ISCDIR ]] && mkdir -p $ISCDIR

cd $ISCDIR

ISCTILEDIR="Tiles/"

if [[ -d $ISCTILEDIR ]]; then
  echo "ISC tile directory exists."
else
  echo "Creating tile files in ISC tile directory :${ISCTILEDIR}:."

  mkdir -p ${ISCTILEDIR}
  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ISCTILEDIR}"tile_${long}_${lati}.cat"
    done
  done
fi

if ! [[ $2 =~ "rebuild" ]]; then

  rm -f isc_just_downloaded.txt

  if [[ -e isc_last_downloaded_event.txt ]]; then
    lastevent_epoch=$(tail -n 1 isc_last_downloaded_event.txt | awk -F, '{ printf("%sT%s", $3, substr($4, 1, 8)) }' | iso8601_to_epoch)
  else
    lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)
  fi
  echo "Last event from previous scrape has epoch $lastevent_epoch"

  this_year=$(date -u +"%Y")
  this_month=$(date -u +"%m")
  this_day=$(date -u +"%d")
  this_hour=$(date -u +"%H")
  this_minute=$(date -u +"%M")
  this_second=$(date -u +"%S")

  today_epoch=$(epoch_ymdhms $this_year $this_month $this_day $this_hour $this_minute $this_second)


  # new format for isc is isc_events_year_month_segment.cat

  # Look for the last entry in the list of catalog files
  final_cat=($(tail -n 1 ./isc_list.txt 2>/dev/null | awk -F_ '{split($5, a, "."); print $3, $4, a[1]}'))

  # If there is no last entry (no file), regenerate the list
  if [[ -z ${final_cat[0]} ]]; then
    echo "Generating new catalog file list..."
    echo "isc_events_1900_to_1950.cat" > ./isc_list.txt
    for year in $(seq 1951 $this_year); do
      for month in $(seq 1 12); do
        if [[ $(echo "($year == $this_year) && ($month > $this_month)" | bc) -eq 1 ]]; then
          break 1
        fi
        for segment in $(seq 1 4); do
          if [[ $(echo "($year == $this_year) && ($month == $this_month)" | bc) -eq 1 ]]; then
            [[ $(echo "($segment == 2) && ($this_day < 7)"  | bc) -eq 1 ]] && break
            [[ $(echo "($segment == 2) && ($this_day < 14)"  | bc) -eq 1 ]] && break
            [[ $(echo "($segment == 3) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          echo "isc_events_${year}_${month}_${segment}.cat" >> ./isc_list.txt
        done
      done
    done
  else
  # Otherwise, add the events that postdate the last catalog file.
    echo "Adding new catalog files to file list..."
    final_year=${final_cat[0]}
    final_month=${final_cat[1]}
    final_segment=${final_cat[2]}

    for year in $(seq $final_year $this_year); do
      for month in $(seq 1 12); do
        if [[  $(echo "($year == $this_year) && ($month > $this_month)" | bc) -eq 1 ]]; then
          break 1
        fi
        for segment in $(seq 1 4); do
          # Determine when to exit the loop as we have gone into the future
          if [[ $(echo "($year >= $this_year) && ($month >= $this_month)" | bc) -eq 1 ]]; then
             [[ $(echo "($segment == 2) && ($this_day < 7)"  | bc) -eq 1 ]] && break
             [[ $(echo "($segment == 3) && ($this_day < 14)"  | bc) -eq 1 ]] && break
             [[ $(echo "($segment == 4) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          # Determine whether to suppress printing of the catalog ID as it already exists
          if ! [[ $(echo "($year <= $final_year) && ($month < $final_month)" | bc) -eq 1 ]]; then
            if [[ $(echo "($year == $final_year) && ($month == $final_month) && ($segment <= $final_segment)" | bc) -eq 0 ]]; then
              echo "isc_events_${year}_${month}_${segment}.cat" >> ./isc_list.txt
            fi
          fi
        done
      done
    done
  fi

  # Get a list of files that should exist but are not marked as complete
  cat isc_complete.txt isc_list.txt | sort -r -n -t "_" -k 3 -k 4 -k 5 | uniq -u > isc_incomplete.txt

  isc_list_files=($(tail -r isc_incomplete.txt))

  # echo ${isc_list_files[@]}

  testcount=0
  last_index=-1
  for d_file in ${isc_list_files[@]}; do
    download_isc_file ${d_file}
    if [[ ! -e ${d_file} || $(has_a_line ${d_file}) -eq 0 ]]; then
      echo "File ${d_file} was not downloaded or has no events. Not marking as complete"
    else
      echo ${d_file} >> isc_just_downloaded.txt
      if [[ $last_index -ge 0 ]]; then
        # Need to check whether the last file exists still before marking as complete (could have been deleted)
        echo "File ${d_file} had events... marking earlier file ${isc_list_files[$last_index]} as complete."
        [[ -e ${isc_list_files[$last_index]} ]] && echo ${isc_list_files[$last_index]} >> isc_complete.txt
      fi
    fi
    last_index=$(echo "$last_index + 1" | bc)
    testcount=$(echo "$testcount + 1" | bc)
  done
else
  # Rebuild the tile from the downloaded
  echo "Rebuilding tiles from complete files"
  rm -f ${ISCTILEDIR}tile*.cat
  cp isc_complete.txt isc_just_downloaded.txt
  lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)

  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ISCTILEDIR}"tile_${long}_${lati}.cat"
    done
  done
fi
# If we downloaded a file (should always happen as newest file is never marked complete)

#   EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG

if [[ -e isc_just_downloaded.txt ]]; then

  selected_files=$(cat isc_just_downloaded.txt)
  rm -f ./not_tiled.cat

  # For each candidate file, examine events and see if they are younger than the
  # last event that has been added to a tile file. Keep track of the youngest
  # event added to tiles and record that for future scrapes.

  for isc_file in $selected_files; do
    echo "Processing file $isc_file into tile files"
    cat $isc_file | sed -n '/^  EVENTID/,/^STOP/p' | sed '1d;$d' | sed '$d' | gawk -F, -v tiledir=${ISCTILEDIR} -v minepoch=$lastevent_epoch '
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
    BEGIN { added=0 }
    {
      timecode=sprintf("%sT%s", $3, substr($4, 1, 8))
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
      if (done==0) {
        the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5));
        epoch=mktime(the_time);
      }

      if (epoch > minepoch) {
        tilestr=sprintf("%stile_%d_%d.cat", tiledir, rd($6,5), rd($5,5));
        print $0 >> tilestr
        added++
      } else {
        print $0 >> "./not_tiled.cat"
      }
    }
    END {
      print "Added", added, "events to ISC tiles."
    }'
  done

  # not_tiled.cat is a file containing old events that have alread been tiled
  # It is kept for inspection purposes but is deleted with each scrape

  last_downloaded_file=$(tail -n 1 isc_just_downloaded.txt)
  last_downloaded_event=$(cat $last_downloaded_file | sed -n '/^  EVENTID/,/^STOP/p' | sed '1d;$d' | sed '$d' | tail -n 1)

  # Update last_downloaded_event.txt
  echo "Marking last downloaded event: $last_downloaded_event"
  echo $last_downloaded_event > isc_last_downloaded_event.txt
fi

# Done








#
#
#
#
#
# # We treat the first years of the catalog differently because it is much faster
# # to download longer time intervals when possible.
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
# download_and_check 1900 01 01 1950 12 31
#
# for year in $(seq 1951 1980); do
#   download_and_check ${year} 01 01 ${year} 12 31
# done
#
# lastfile=$(ls -l isc_seis_*.dat | gawk '{print $(NF)}' | sort -n -t "_" -k 3 -k 4 -k 5 | tail -n 1)
# echo "The last existing database file is $lastfile"
# last_year=$(echo $lastfile | gawk -F_ '{print substr($3,1,4)}')
#
# if [[ $last_year -eq 1980 ]]; then
#   earliest_year=1981
# else
#   earliest_year=$last_year
# fi
#
# for year in $(seq $earliest_year $this_year); do
#   for cmonth in $(seq 1 12); do
#     month=$(printf "%02d" $cmonth)
#     case $month in
#         0[13578]|10|12) days=31;;
#         0[469]|11)	    days=30;;
#         02) days=$(echo $year | gawk '{
#             jul=strftime("%j",mktime($1 " 12 31 0 0 0 "));
#             if (jul==366) {
#               print 29
#             } else {
#               print 28
#             }
#            }')
#     esac
#     download_and_check ${year} ${cmonth} 01 ${year} ${cmonth} 7
#     download_and_check ${year} ${cmonth} 8 ${year} ${cmonth} 14
#     download_and_check ${year} ${cmonth} 15 ${year} ${cmonth} 22
#     download_and_check ${year} ${cmonth} 23 ${year} ${cmonth} ${days}
#   done
# done
#
# rm -f to_add_to_cat.txt
#
# # Process the files that we just downloaded to add them to the catalog.
# for i in ${add_to_catalog[@]}; do
#   echo $i >> to_add_to_cat.txt
# done
#
# # This will actually order the files correctly, so if we go in reverse order we
# # are going from newest to oldest events. The first file with an event older
# # than the youngest file in the existing catalog breaks the loop.
#
# # Each time we run the script, we only look at files that we downloaded this time
#
# # to_add_to cat is always in order latest=last
#
#
# # If the ISC EQ catalog exists, then find the latest event and its epoch. Then
# # going from present to past, add events to the catalog.
#
# # If the catalog doesn't exist, then go from past to present adding events.
#
# if [[ -e $ISC_EQ_CATALOG ]]; then
#   lastevent=($(tail -n 1 $ISC_EQ_CATALOG))
#   # lastevent_timecode=${lastevent[4]}
#   lastevent_epoch=${lastevent[6]}
#   catfiles=($(cat to_add_to_cat.txt))
# else
#   # lastevent_timecode="0000-00-00T00:00:00"
#   lastevent_epoch=-9999999999999
#   catfiles=($(tac to_add_to_cat.txt))
# fi
#
# echo "Last ISC event timecode in catalog: $lastevent_timecode  Epoch: $lastevent_epoch"
# rm -f added_to_cat.dat
#
# for ((i=${#catfiles[@]}-1; i>=0; i--)); do
#   datfile=${catfiles[i]}
#   cat $datfile | sed -n '/^  EVENTID/,/^STOP/p' | sed '1d;$d' | sed '$d' > tmp.dat
#   tail -n 1 tmp.dat
#   # Determine the epoch of the last event in the candidate catalog file
#   lastdatfile_event=($(tail -n 1 tmp.dat | gawk -F, '{print $1}'))
#   lastdatfile_epoch=$(tail -n 1 tmp.dat | gawk -F, '{
#     timecode=sprintf("%sT%s", $3, substr($4, 1, 8))
#     print "timecode is", timecode > "/dev/stderr"
#     split(timecode, a, "-")
#     year=a[1]
#     month=a[2]
#     split(a[3],b,"T")
#     day=b[1]
#     split(b[2],c,":")
#     hour=c[1]
#     minute=c[2]
#     second=c[3]
#     the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
#     epoch=mktime(the_time);
#     print epoch
#   }')
#
#   echo "$lastdatfile_epoch > $lastevent_epoch"
#
#   # Only output events that are younger than the last event in the preexisting catalog
#   if [[ $(echo "$lastdatfile_epoch > $lastevent_epoch" | bc) -eq 1 ]]; then
#     gawk < tmp.dat -F, -v lasttime=$lastevent_epoch '{
#         timecode=sprintf("%sT%s", $3, substr($4, 1, 8))
#         split(timecode, a, "-")
#         year=a[1]
#         month=a[2]
#         split(a[3],b,"T")
#         day=b[1]
#         split(b[2],c,":")
#         hour=c[1]
#         minute=c[2]
#         second=c[3]
#         the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
#         epoch=mktime(the_time);
#         if (epoch > lasttime) {
#           if ($7+0==0) {
#             print $6, $5, $7, $11, timecode, $1, epoch > "./isc_reject_depth0.dat"
#           } else {
#             print $6, $5, $7, $11, timecode, $1, epoch
#           }
#         }
#       }' >> added_to_cat.dat
#
# #   EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG
# # 1.      lon          (°)
# # 2.      lat          (°)
# # 3.      depth        (km)
# # 4.      magnitude    (varies)
# # 5.      origin time  (YYYY-MM-DDTHH:MM:SS)
# # 6.      ID           (string)
# # 7.      epoch        (seconds)
#       echo "Processed file $datfile" > /dev/stderr
#     else
#       echo "File $datfile was downloaded but data appears too old to contain new events."
#       echo $datfile > "./downloaded_but_not_added.txt"
#       break
#     fi
# done
#
# if [[ -e added_to_cat.dat ]]; then
#   if [[ -e $ISC_EQ_CATALOG ]]; then
#     sort added_to_cat.dat -n -k 7  | gawk '{print $1, $2, $3, $4, $5, $6, $7}' >> $ISC_EQ_CATALOG
#     echo "Added $(wc -l < added_to_cat.dat | gawk '{print $1}') events to seismicity catalog"
#     rm -f added_to_cat.dat
#   else
#     mv added_to_cat.dat $ISC_EQ_CATALOG
#   fi
# fi
#
#
# # rm -f to_add_to_cat.txt
#
#
#
#
#
#
# # Don't need to sort this as our code always keeps things in order?
# #
#
# #
# # #
