#!/bin/bash
# Script to summarize the output of a TDEFNODE run using several panels and tectoplot
# Will plot four panels, equally sized.

TDEFFOLDER="/Users/kylebradley/Dropbox/scripts/tdefnode/tdandaman/new_noeric/tda0/"
STMPDIR1="tdef_summary1/"
STMPDIR2="tdef_summary2/"
STMPDIR3="tdef_summary3/"
STMPDIR4="tdef_summary4/"

echo Go 1
tectoplot -r 65 145 -45 35 -t -tt 40 -tm "${STMPDIR1}"                        -pss 8 -psr 0.5 -pos 0.5i 0.5i  --tdefnode $TDEFFOLDER by    -a --keepopenps
echo Go 2
tectoplot -r 80 125 -15 30 -t -tt 40 -tm "${STMPDIR2}" -ips "${STMPDIR1}"map.ps -pss 8 -psr 0.5 -pos 4i 0i     --tdefnode $TDEFFOLDER ovr   -a --keepopenps
echo Go 3
tectoplot -r 80 125 -15 30 -t -tt 40 -tm "${STMPDIR3}" -ips "${STMPDIR2}"map.ps -pss 8 -psr 0.5 -pos 0i 4i     --tdefnode $TDEFFOLDER et    -a --keepopenps
echo Go 4
tectoplot -r 80 125 -15 30 -t -tt 40 -tm "${STMPDIR4}" -ips "${STMPDIR3}"map.ps -pss 8 -psr 0.5 -pos -4i 0i    --tdefnode $TDEFFOLDER l     -a
gmt psconvert -A0.3i -Tf "${STMPDIR4}"map.ps
