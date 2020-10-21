#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# Download the entire global ANSS event catalog and store in semi-monthly data files, then process into a single smaller database file.
# All data files are downloaded into the current folder. The total download size is currently ~650 Mb (2020) and takes some time.

# Output files: ${ANSS_DIR}all_anss_events_data_lonlatdepthmagdateid.txt

# Most of the download time is the pull request, but making larger chunks leads to some failures due to number of events.
# The script can be run multiple times and will not re-download files that already exist.
# However, corrupted files or other responses from the catalog that aren't data will not be automatically deleted!

# Example curl command:
# curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-${day}&endtime=${year}-${month}-${day}&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180"

ANSS_DIR="/Users/kylebradley/Dropbox/TectoplotData/ANSS/"

[[ ! -d $ANSS_DIR ]] && mkdir -p $ANSS_DIR

cd $ANSS_DIR

earliest_year=1951

this_year=$(date +"%Y")
this_month=$(date +"%m")
echo "Downloading data until $this_month/$this_year"
[[ ! -e anss_events_1000_to_1950.dat ]] &&  echo "Dowloading seismicity for years 1000AD-1950AD" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=1000-01-01&endtime=1950-12-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_1000_to_1950.dat

for year in $(seq $earliest_year $this_year); do
  echo "Looking for anss_events_${year}_${month}"
  for month in $(seq 1 12); do
    if [[ $year -lt $this_year ]]; then
      [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for ${year}-${month}-01to10" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
      [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for ${year}-${month}-11to20" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
      [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for ${year}-${month}-21to31" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
    elif [[ $month -le "10#$this_month" ]]; then
      [[ ! -e anss_events_${year}_${month}_1.dat ]] && echo "Dowloading seismicity for ${year}-${month}-01to10" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-01&endtime=${year}-${month}-10&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_1.dat
      [[ ! -e anss_events_${year}_${month}_2.dat ]] && echo "Dowloading seismicity for ${year}-${month}-11to20" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-11&endtime=${year}-${month}-20&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_2.dat
      [[ ! -e anss_events_${year}_${month}_3.dat ]] && echo "Dowloading seismicity for ${year}-${month}-21to31" && curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=${year}-${month}-21&endtime=${year}-${month}-31&minlatitude=-90&maxlatitude=90&minlongitude=-180&maxlongitude=180" > anss_events_${year}_${month}_3.dat
    fi

    # Currently the file size for no events is 160 bytes
    fsize=$(wc -c < anss_events_${year}_${month}_1.dat)
    if [[ -e anss_events_${year}_${month}_1.dat && $fsize -eq 160 ]]; then
      echo "anss_events_${year}_${month}_1.dat is empty"
      rm -f anss_events_${year}_${month}_1.dat
    fi
    fsize=$(wc -c < anss_events_${year}_${month}_2.dat)
    if [[ -e anss_events_${year}_${month}_2.dat && $fsize -eq 160 ]]; then
      echo "anss_events_${year}_${month}_2.dat is empty"
      rm -f anss_events_${year}_${month}_2.dat
    fi
    fsize=$(wc -c < anss_events_${year}_${month}_3.dat)
    if [[ -e anss_events_${year}_${month}_3.dat && $fsize -eq 160 ]]; then
      echo "anss_events_${year}_${month}_3.dat is empty"
      rm -f anss_events_${year}_${month}_3.dat
    fi

  done
done

echo "Looking for errors from fetching... if grep returns any lines from a file, delete that particular file and redownload by rerunning the script."
grep "Error 400" *.dat
echo "Done looking for download errors."

# The smaller database is the following fields, space sparated, which are suitable for plotting directly using gmt psxy with -i0,1,2,3
# This way, the cropped data can be used to identify events if necessary.
# LON LAT DEPTH MAG DATETIME ID

# 2018-04-01T01:14:42
# All real events start with 1 (1920) or 2 (2020). Update script in the year 3000.
# We remove events without a depth ($4) or magnitude ($5)

# $1 in 1950-12-29T11:56:08.000Z format to 1950-12-29T11:56:08 tectoplot event ID format: just take first 19 characters
cat anss_events_* | awk -F, '{ if ($4 && $5 && $1 != "time") { print $3, $2, $4, $5, substr($1, 1, 19), $12 } }' >  all_anss_events_data_lonlatdepthmagdateid.txt

echo "uniq should only report a single value of 6"
awk < all_anss_events_data_lonlatdepthmagdateid.txt '{print NF}' | uniq
echo "If it didn't you have bad data points in the catalog!"
DATABASEFILE=$(echo "$(cd "$(dirname "all_anss_events_data_lonlatdepthmagdateid.txt")"; pwd)/$(basename "all_anss_events_data_lonlatdepthmagdateid.txt")")
echo "Database file path: $DATABASEFILE"

# Archive the downloaded data
#mkdir -p anss_archive
#mv anss_events* anss_archive
