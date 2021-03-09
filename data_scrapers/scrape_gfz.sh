#!/bin/bash
# Kyle Bradley, NTU, January 2021

# Scrape the GFZ focal mechanism catalog

[[ ! -d $GFZDIR ]] && mkdir -p $GFZDIR
[[ ! -e ${GFZCATALOG} ]] && touch ${GFZCATALOG}
cd $GFZDIR

echo "Downloading GFZ catalog using stored MT files as basis"

pagenum=1
rm -f gfzmtlist.txt
while : ; do
    echo "Scraping GFZ moment tensor page $pagenum"
    curl "https://geofon.gfz-potsdam.de/eqinfo/list.php?page=${pagenum}&datemin=&datemax=&latmax=&lonmin=&lonmax=&latmin=&magmin=&mode=mt&fmt=txt&nmax=1000" > gfz_list_$pagenum.txt
    result=$(wc -l < gfz_list_$pagenum.txt)
    [[ $result -gt 0 ]] || break
    cat gfz_list_$pagenum.txt >> gfzmtlist.txt
    pagenum=$(echo "$pagenum +1 " | bc)
done

gawk < gfzmtlist.txt '{print $1}' > exists.txt

ls | gawk -F_ '(/_mt.txt/){ print $1}' >> exists.txt
gawk < exists.txt '{seen[$1]++} END {
  for (key in seen) {
    if (seen[key] < 2) {
      print key
    }
  }
}' > toadd_tocat.txt

totalcount=$(wc -l < toadd_tocat.txt)
currentcount=1

while read p; do
  echo "Trying to download missing file $p ($currentcount/$totalcount)"
  event_id=$(grep $p gfzmtlist.txt | head -n 1 | gawk '{print $1}')
  event_yr=$(grep $p gfzmtlist.txt | head -n 1 | gawk  '{split($5,idv,"-"); print idv[1]; }')
  curl "https://geofon.gfz-potsdam.de/data/alerts/${event_yr}/${event_id}/mt.txt" > ${event_id}_mt.txt
  linelen=$(wc -l < ${event_id}_mt.txt)
  if [[ $linelen -lt 20 ]]; then
    echo "Event report ${event_id}_mt.txt is not at least 20 lines long. Marking and excluding."
    mv ${event_id}_mt.txt ${event_id}_mtbad.txt
  else
    ${CMTTOOLS} ${event_id}_mt.txt Z Z >> ${GFZCATALOG}
  fi
  currentcount=$(echo "$currentcount + 1" | bc)
done < toadd_tocat.txt

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
