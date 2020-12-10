#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# Download the entire global ANSS (Advanced National Seismic System) event
# catalog and store in semi-monthly data files, then process into one data file.
# All data files are downloaded into the current folder. The total download size
# is currently ~650 Mb (2020) and takes some time.

# Most of the download time is the pull request, but making larger chunks leads
# to some failures due to number of events. The script can be run multiple times
# and will not re-download files that already exist. Some error checking is done
# to look for empty files and delete them.

# Example curl command:
# curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-${day}&endtime=${year}-${month}-${day}&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180"

# Expects EQCATALOG, ANSSDIR to be set

[[ ! -d $ANSSDIR ]] && mkdir -p $ANSSDIR

cd $ANSSDIR

this_year=$(date +"%Y")
this_month=$(date +"%m")

# Find the ANSS catalog file with the latest date
lastfile=$(ls -l anss*.dat | awk '{print $(NF)}' | sort -n -t "_" -k 3 -k 4 -k 5 | tail -n 1)

if [[ -z $lastfile ]]; then
  echo "No ANSS data files exist. Scraping from January 1951 to present"
  touch $EQCATALOG
  earliest_year=1951
  earliest_month=1
else
  echo "ANSS files exist. Latest file is $lastfile"
  lastfile_timecode=$(tail -n 1 $lastfile | awk -F, '{print $1}')
  lastfile_year=$(echo $lastfile_timecode | cut -d '-' -f 1)
  lastfile_month=$(echo $lastfile_timecode | cut -d '-' -f 2)
  lastfile_day=$(echo $lastfile_timecode | cut -d '-' -f 3 | cut -c 1,2)
  echo Timecode is $lastfile_timecode : year=$lastfile_year month=$lastfile_month day=$lastfile_day

  if [[ $lastfile_year -ge 1950 ]]; then
    echo "Lastfile $lastfile_year is valid... continuing"
  else
    echo "Lastfile year $lastfile_year is not a valid year. Exiting."
  fi

  # Remove any files potentially containing younger events than the last one in the catalog
  if [[ $day -le 10 ]]; then
    echo "Month segment is 1"
    rm -f anss_events_${lastfile_year}_${lastfile_month}_1.dat anss_events_${lastfile_year}_${lastfile_month}_2.dat anss_events_${lastfile_year}_${lastfile_month}_3.dat
  elif [[ $day -le 20 ]]; then
    echo "Month segment is 2"
    rm -f anss_events_${lastfile_year}_${lastfile_month}_2.dat anss_events_${lastfile_year}_${lastfile_month}_3.dat
  else
    echo "Month segment is 3"
    rm -f anss_events_${lastfile_year}_${lastfile_month}_3.dat
  fi
  earliest_year=$lastfile_year
  earliest_month=$lastfile_month
fi



# If the EQ catalog exists, then find the latest event.
# *** The seismicity catalog is always sorted by time, latest event last.

if [[ -e anss.cat ]]; then
  lastevent=($(tail -n 1 anss.cat))
  lastevent_timecode=${lastevent[4]}
  lastevent_epoch=${lastevent[6]}
else
  lastevent_timecode="0000-00-00T00:00:00"
  lastevent_epoch=-9999999999999
fi

echo "Last event timecode: $lastevent_timecode  Epoch: $lastevent_epoch"

echo "Downloading ANSS data from $earliest_year, from month $earliest_month to 12"

[[ ! -e anss_events_1000_to_1950.dat ]] &&  echo "Dowloading seismicity for years 1000AD-1950AD"#&& curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=1000-01-01&endtime=1950-12-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_1000_to_1950.dat

# For the earliest year, start with the earliest month.
year=$earliest_year
for month in $(seq $earliest_month 12); do
  if [[ $year -lt $this_year ]]; then
    [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for ${year}-${month}-01to10"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
    [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for ${year}-${month}-11to20"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
    [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for ${year}-${month}-21to31"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
  elif [[ $month -le "10#$this_month" ]]; then
    # Download these data to ensure up-to-date seismicity
    [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-01to10"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
    [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-11to20"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
    [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-21to31"  && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
  fi
done

echo "Examining ANSS data up until $this_month/$this_year"

# If we have further years to download...
if [[ $(echo "$earliest_year == $this_year" | bc) -eq 0 ]]; then
  new_earliest_year=$(echo "$earliest_year + 1" | bc)
  for year in $(seq $new_earliest_year $this_year); do
    # echo "Looking for anss_events_${year}"
    for month in $(seq 1 12); do
      if [[ $year -lt $this_year ]]; then
        [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for ${year}-${month}-01to10" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
        [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for ${year}-${month}-11to20" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
        [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for ${year}-${month}-21to31" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
      elif [[ $month -le "10#$this_month" ]]; then
        # Download these data to ensure up-to-date seismicity
        [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-01to10" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
        [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-11to20" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
        [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for current year ${year}-${month}-21to31" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
      fi
    done
  done
fi

echo "Looking for download errors and adding events to presort catalog"
for datfile in anss_events_*.dat; do
  fsize=$(wc -c < $datfile)
  iserror=$(grep -c "Error 400" $datfile)
  if [[ fsize -lt 170 ]]; then
    echo "File $datfile is empty. Deleting"
    rm -f $datfile
  fi
  if [[ ! $iserror -eq 0 ]]; then
    echo "File $datfile has a download error. Deleting"
    rm -f $datfile
  fi
done

# We can assume that the catalog was built correctly and that we aren't
# missing events older than the last event pre-update. So we only need to
# add events from files where the last event is younger than our current event.

rm -f add_to_catalog.cat

# This will actually order the files correctly, so if we go in reverse order we
# are going from newest to oldest events. The first file with an event older
# than the youngest file in the existing catalog breaks the loop.

firstfiles=(anss_events_*.dat)
files=($(echo ${firstfiles[@]} | tr ' ' '\n' | sort -n -t '_' -k3 -k4))

for ((i=${#files[@]}-1; i>=0; i--)); do
  datfile=${files[i]}
  lastdatfile_event=($(tail -n 1 $datfile | awk -F, '{print $1}'))
  lastdatfile_epoch=$(echo $lastdatfile_event | awk '{
    split($1, a, "-")
    year=a[1]
    month=a[2]
    split(a[3],b,"T")
    day=b[1]
    split(b[2],c,":")
    hour=c[1]
    minute=c[2]
    second=c[3]
    the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
    epoch=mktime(the_time);
    print epoch
  }')

  if [[ $(echo "$lastdatfile_epoch > $lastevent_epoch" | bc) -eq 1 ]]; then
    awk < $datfile -F, -v lasttime=$lastevent_epoch '{
        if ($4 && $5 && $1 != "time") {
          timecode=substr($1, 1, 19)
          split(timecode, a, "-")
          year=a[1]
          month=a[2]
          split(a[3],b,"T")
          day=b[1]
          split(b[2],c,":")
          hour=c[1]
          minute=c[2]
          second=c[3]
          the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
          epoch=mktime(the_time);
          if (epoch > lasttime) {
            print $3, $2, $4, $5, timecode, $12, epoch
          }
        }
      }' >> add_to_catalog.cat
    else
      echo "File $datfile is too old to contain new events"
      break
    fi
done

if [[ -e add_to_catalog.cat ]]; then
  sort add_to_catalog.cat -n -k 7 >> $EQCATALOG
  echo "Added $(wc -l < add_to_catalog.cat | awk '{print $1}') events to seismicity catalog"
  rm -f add_to_catalog.cat
else
  echo "No new events"
fi

#
#
# cat anss_events_* | awk -F, '{
#   if ($4 && $5 && $1 != "time") {
#     timecode=substr($1, 1, 19)
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
#     print $3, $2, $4, $5, timecode, $12, epoch
#   }
# }' | sort -n -k 7 > $EQCATALOG


  #
  #
  # # The smaller database is the following fields, space sparated, which are suitable for plotting directly using gmt psxy with -i0,1,2,3
  # # This way, the cropped data can be used to identify events if necessary.
  # # LON LAT DEPTH MAG DATETIME ID
  #
  # # 2018-04-01T01:14:42
  # # All real events start with 1 (1920) or 2 (2020). Update script in the year 3000.
  # # We remove events without a depth ($4) or magnitude ($5)
  #
  # # $1 in 1950-12-29T11:56:08.000Z format to 1950-12-29T11:56:08 tectoplot event ID format: just take first 19 characters
  #
