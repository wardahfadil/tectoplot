#!/bin/bash
# Script to plot gravity over a square AOI given by lonmin lonmax latmin latmax

STMPDIR="gravity_summary_tmp/"

tectoplot -r "${1}" "${2}" "${3}" "${4}" -t -tc gray -v BG 50 -tm "${STMPDIR}"                        -pss 8 -psr 0.5  -pos 0.5i 0.5i -a --keepopenps  -title "WGM12 Bouguer anomaly"
tectoplot -r "${1}" "${2}" "${3}" "${4}" -t -tc gray -v FA 50 -tm "${STMPDIR}" -ips "${STMPDIR}"map.ps -pss 8 -psr 0.5  -pos 4i     0i -a --keepopenps  -title "WGM12 Free air anomaly"
tectoplot -r "${1}" "${2}" "${3}" "${4}" -t -tc gray -v IS 50 -tm "${STMPDIR}" -ips "${STMPDIR}"map.ps -pss 8 -psr 0.5  -pos 0i     4i -a --keepopenps  -title "WGM12 Isostatic anomaly"
tectoplot -r "${1}" "${2}" "${3}" "${4}" -t                   -tm "${STMPDIR}" -ips "${STMPDIR}"map.ps -pss 8 -psr 0.5  -pos -4i    0i -a               -title "Bathymetry"

gmt psconvert -A0.3i -Tf "${STMPDIR}"map.ps
