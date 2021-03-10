#!/bin/bash
# Kyle Bradley, NTU, January 2021

# Scrape the GFZ focal mechanism catalog

GFZDIR=${1}

[[ ! -d $GFZDIR ]] && mkdir -p $GFZDIR

cd $GFZDIR

GFZCATALOG=${GFZDIR}"gfz_extract.cat"

[[ ! -e ${GFZCATALOG} ]] && touch ${GFZCATALOG}

if [[ $2 =~ "rebuild" ]]; then
  echo "Rebuilding GFZ focal mechanism catalog from downloaded _mt files..."
  rm -f ${GFZCATALOG}
  for gfz_file in gfz*_mt.txt; do
    ${CMTTOOLS} ${gfz_file} Z Z >> ${GFZCATALOG}
    echo -n "${gfz_file} "
  done
  exit
fi

echo "Downloading GFZ catalog using stored MT files as basis"

# gfz_complete.txt contains file names of downloaded HTML pages
# marked complete when a following file is successfully downloaded

pagenum=1
while : ; do
    if ! [[ -e gfz_list_${pagenum}.txt ]]; then
      echo "Scraping GFZ moment tensor page $pagenum"
      curl "https://geofon.gfz-potsdam.de/eqinfo/list.php?page=${pagenum}&datemin=&datemax=&latmax=&lonmin=&lonmax=&latmin=&magmin=&mode=mt&fmt=txt&nmax=1000" > gfz_list_$pagenum.txt
      result=$(wc -l < gfz_list_$pagenum.txt)
      if [[ $result -eq 0 ]]; then
        rm -f gfz_list_$pagenum.txt
        break
      fi
        # We will delete on end to reset downloading of this file each time
    else
      echo "Skipping download of GFZ page list ${pagenum}"
    fi
    pagenum=$(echo "$pagenum + 1 " | bc)
done
pagenum=$(echo "$pagenum - 1 " | bc)

last_gfz="gfz_list_$pagenum.txt"

# Make a list of all existing moment tensors
cat gfz_list_*.txt | gawk '{print $1}' > exists_on_server.txt

# Find any moment tensors that are not downloaded already as _mt.txt files

while read p; do
  if ! [[ -s "${p}_mt.txt" ]]; then
    echo "Trying to download missing file ${p}_mt.txt"
    event_id=$p
    event_yr=$(echo $p | gawk  '{print substr($1,4,4); }')
    echo ":${event_id}:${event_yr}:"
    curl "https://geofon.gfz-potsdam.de/data/alerts/${event_yr}/${event_id}/mt.txt" > ${event_id}_mt.txt
    linelen=$(wc -l < ${event_id}_mt.txt)
    if [[ $linelen -lt 20 ]]; then
      echo "Event report ${event_id}_mt.txt is not at least 20 lines long. Marking and excluding."
      mv ${event_id}_mt.txt ${event_id}_mtbad.txt
    else
      ${CMTTOOLS} ${event_id}_mt.txt Z Z >> ${GFZCATALOG}
    fi
  fi
done < exists_on_server.txt

echo "Deleting last GFZ page list: $last_gfz"
rm -f ${last_gfz}

# Example GFZ event report (line numbers added)
# https://geofon.gfz-potsdam.de/data/alerts/2020/gfz2020xnmx/mt.txt


#1 GFZ Event gfz2020xrlv
#2 20/12/02 20:36:23.00
#3 Sulawesi, Indonesia
#4 Epicenter: -3.46 123.28
#5 MW 5.1
#6
#7 GFZ MOMENT TENSOR SOLUTION
#8 Depth  10         No. of sta: 93
#9 Moment Tensor;   Scale 10**16 Nm
#10   Mrr= 5.31       Mtt=-0.72
#11   Mpp=-4.60       Mrt=-1.02
#12   Mrp= 1.29       Mtp= 2.41
#13 Principal axes:
#14   T  Val=  5.57  Plg=81  Azm=217
#15   N        0.41       3      333
#16   P       -5.98       8       63
#17
#18 Best Double Couple:Mo=5.8*10**16
#19  NP1:Strike=158 Dip=37 Slip=  96
#20  NP2:       330     53        85
