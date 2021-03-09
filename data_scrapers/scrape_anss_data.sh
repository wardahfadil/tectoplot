#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# scrape_anss_data.sh [directory]

# Download the entire global ANSS (Advanced National Seismic System) event
# catalog and store in semi-monthly data files in [directory]/, then process
# into 5 degree tiles in [directory]/Tiles/. The total download size is currently
# ~650 Mb (2020) and takes a LONG time.

# This script will only download files that have not been marked as COMPLETE,
# as indicated by their presence in anss_complete.txt, and will only add events
# to tiles if their epoch is later than the epoch of the most recently added
# event stored in anss_last_downloaded_event.txt. A file is marked as complete
# if a file with a later date is successfully downloaded during the same session.

# Example curl command:
# curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-${day}&endtime=${year}-${month}-${day}&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180"

# iso8601 is YYYY-MM-DDTHH:MM:SS = 19 characters

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

# input: name of file anss_events_year_month_index.cat
function download_anss_file() {
  local parsed=($(echo $1 | awk -F_ '{ split($5, d, "."); print $3, $4, d[1]}'))
  local year=${parsed[0]}
  local month=${parsed[1]}
  local segment=${parsed[2]}

  if [[ $1 =~ "anss_events_1000_to_1950.cat" ]]; then
    echo "Downloading seismicity for $1: Year=1000 to 1950"
    curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=1000-01-01T00:00:00&endtime=1950-12-31T23:59:59&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180&orderby=time-asc" > $1
  else
    echo "Downloading seismicity for $1: Year=${year} Month=${month} Segment=${segment}"

    case ${parsed[2]} in
      1)
      curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01T00:00:00&endtime=${year}-${month}-10T23:59:59&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180&orderby=time-asc" > $1
      ;;
      2)
      curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11T00:00:00&endtime=${year}-${month}-20T23:59:59&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180&orderby=time-asc" > $1
      ;;
      3)
      curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21T00:00:00&endtime=${year}-${month}-31T23:59:59&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180&orderby=time-asc" > $1
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

# Change into the ANSS data directory, creating if needed, and check Tiles directory
# Create tile files using touch

ANSSDIR="${1}"

[[ ! -d $ANSSDIR ]] && mkdir -p $ANSSDIR


ANSSTILEDIR=$ANSSDIR"Tiles/"

if [[ -d $ANSSTILEDIR ]]; then
  echo "ANSS tile directory exists."
  cd $ANSSDIR

else
  echo "Creating tile files in ANSS tile directory :${ANSSTILEDIR}:."

  mkdir -p ${ANSSTILEDIR}
  cd $ANSSDIR

  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ANSSTILEDIR}"tile_${long}_${lati}.cat"
    done
  done
fi

# Sort the anss_complete.txt file to preserve the order of earliest->latest
if [[ -e anss_complete.txt ]]; then
  sort < anss_complete.txt -t '_' -n -k 3 -k 4 -k 5 > anss_complete.txt.sort
  mv anss_complete.txt.sort anss_complete.txt
fi

if ! [[ $2 =~ "rebuild" ]]; then


  rm -f anss_just_downloaded.txt

  if [[ -e anss_last_downloaded_event.txt ]]; then
    lastevent_epoch=$(tail -n 1 anss_last_downloaded_event.txt | awk -F, '{print substr($1,1,19)}' | iso8601_to_epoch)
  else
    lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)
  fi
  echo "Last event from previous scrape has epoch $lastevent_epoch"


  this_year=$(date -u +"%Y")
  this_month=$(date -u +"%m")
  this_day=$(date -u +"%d")
  this_datestring=$(date -u +"%Y-%m-%dT%H:%M:%S")

  # Generate a list of all possible catalog files that can be downloaded
  # This takes a while and could be done differently with a persistent file

  # Look for the last entry in the list of catalog files
  final_cat=($(tail -n 1 ./anss_list.txt 2>/dev/null | awk -F_ '{split($5, a, "."); print $3, $4, a[1]}'))

  # If there is no last entry (no file), regenerate the list
  if [[ -z ${final_cat[0]} ]]; then
    echo "Generating new catalog file list..."
    echo "anss_events_1000_to_1950.cat" > ./anss_list.txt
    for year in $(seq 1951 $this_year); do
      for month in $(seq 1 12); do
        if [[ $(echo "($year == $this_year) && ($month > $this_month)" | bc) -eq 1 ]]; then
          break 1
        fi
        for segment in $(seq 1 3); do
          if [[ $(echo "($year == $this_year) && ($month == $this_month)" | bc) -eq 1 ]]; then
            [[ $(echo "($segment == 2) && ($this_day < 11)"  | bc) -eq 1 ]] && break
            [[ $(echo "($segment == 3) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          echo "anss_events_${year}_${month}_${segment}.cat" >> ./anss_list.txt
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
        for segment in $(seq 1 3); do
          # Determine when to exit the loop as we have gone into the future
          if [[ $(echo "($year >= $this_year) && ($month >= $this_month)" | bc) -eq 1 ]]; then
             [[ $(echo "($segment == 2) && ($this_day < 11)"  | bc) -eq 1 ]] && break
             [[ $(echo "($segment == 3) && ($this_day < 21)"  | bc) -eq 1 ]] && break
          fi
          # Determine whether to suppress printing of the catalog ID as it already exists
          if ! [[ $(echo "($year <= $final_year) && ($month < $final_month)" | bc) -eq 1 ]]; then
            if [[ $(echo "($year == $final_year) && ($month == $final_month) && ($segment <= $final_segment)" | bc) -eq 0 ]]; then
              echo "anss_events_${year}_${month}_${segment}.cat" >> ./anss_list.txt
            fi
          fi
        done
      done
    done
  fi

  # Get a list of files that should exist but are not marked as complete
  cat anss_complete.txt anss_list.txt | sort -r -n -t "_" -k 3 -k 4 -k 5 | uniq -u > anss_incomplete.txt

  anss_list_files=($(tail -r anss_incomplete.txt))

  echo ${anss_list_files[@]}

  # For each of these files, in order from oldest to most recent, download the file.
  # Keep track of the last complete download made. If a younger file is downloaded
  # successfully, mark the older file as complete. Keep track of which files we
  # downloaded (potentially new) data into.

  last_index=-1
  for d_file in ${anss_list_files[@]}; do
    download_anss_file ${d_file}
    if [[ ! -e ${d_file} || $(has_a_line ${d_file}) -eq 0 ]]; then
      echo "File ${d_file} was not downloaded or has no events. Not marking as complete"
    else
      echo ${d_file} >> anss_just_downloaded.txt
      if [[ $last_index -ge 0 ]]; then
        # Need to check whether the last file exists still before marking as complete (could have been deleted)
        echo "File ${d_file} had events... marking earlier file ${anss_list_files[$last_index]} as complete."
        [[ -e ${anss_list_files[$last_index]} ]] && echo ${anss_list_files[$last_index]} >> anss_complete.txt
      fi
    fi
    last_index=$(echo "$last_index + 1" | bc)
  done

else
  # Rebuild the tile from the downloaded
  echo "Rebuilding tiles from complete files"
  rm -f ${ANSSTILEDIR}tile*.cat
  cp anss_complete.txt anss_just_downloaded.txt
  lastevent_epoch=$(echo "1900-01-01T00:00:01" | iso8601_to_epoch)

  for long in $(seq -180 5 175); do
    for lati in $(seq -90 5 85); do
      touch ${ANSSTILEDIR}"tile_${long}_${lati}.cat"
    done
  done

fi

# Add downloaded data to Tiles.

# If we downloaded a file (should always happen as newest file is never marked complete)
if [[ -e anss_just_downloaded.txt ]]; then

  selected_files=$(cat anss_just_downloaded.txt)
  rm -f ./not_tiled.cat

  # For each candidate file, examine events and see if they are younger than the
  # last event that has been added to a tile file. Keep track of the youngest
  # event added to tiles and record that for future scrapes.

  for anss_file in $selected_files; do
    echo "Processing file $anss_file into tile files"
    awk < $anss_file -F, -v tiledir=${ANSSTILEDIR} -v minepoch=$lastevent_epoch '
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
    (NR>1) {
      timecode=substr($1,1,19)
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
        tilestr=sprintf("%stile_%d_%d.cat", tiledir, rd($3,5), rd($2,5));
        print $0 >> tilestr
        added++
      } else {
        print $0 >> "./not_tiled.cat"
      }
    }
    END {
      print "Added", added, "events to ANSS tiles."
    }'
  done

  # not_tiled.cat is a file containing old events that have alread been tiled
  # It is kept for inspection purposes but is deleted with each scrape

  last_downloaded_file=$(tail -n 1 anss_just_downloaded.txt)
  last_downloaded_event=$(tail -n 1 $last_downloaded_file)

  # Update last_downloaded_event.txt
  echo "Marking last downloaded event: $last_downloaded_event"
  echo $last_downloaded_event > anss_last_downloaded_event.txt
fi

# Done
