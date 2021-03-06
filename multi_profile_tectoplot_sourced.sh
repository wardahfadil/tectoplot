#!/bin/bash

# Kyle Bradley, Nanyang Technological University, kbradley@ntu.edu.sg
# February 2021

# Usage: . multi_profile_tectoplot.sh
#
# Convert to a script that is sourced by tectoplot or by a wrapper script. Then we can do without
# passing variables or having problems returning information to tectoplot.
#
# VARIABLES REQUIRED (in environment or set prior to sourcing using . bash command):
#
# MPROFFILE - command file
# PSFILE - ps file to plot on top of
# PROFILE_WIDTH_IN
# PROFILE_HEIGHT_IN
# PROFILE_X
# PROFILE_Z
# PLOT_SECTIONS_PROFILEFLAG   {=1 means plot section PDFs in perpective, =0 means do not}
# litho1profileflag   (=1 means extract and plot litho1 cross section, =0 means do not)
#
# FILES EXPECTED to exist:
# cmt_normal.txt, cmt_strikeslip.txt, cmt_thrust.txt (for focal mechanisms)
# cmt_alt_lines.xyz, cmt_alt_pts.xyz (if -cc flag is used)
#
# Number of arguments = 6
# 1                  2         3   4   5   6
# control_file.txt   psfile.ps A   B   X   Z
#
# A = height of profile (eg. 2i)
# B = width of profile (e.g. 5i)
# X,Y are the page shift applied before plotting the profile (to define its location)
#
# Currently overplots data in a profile-by-profile order and not a dataset-by-dataset order
# You can modify the plot.sh file to adjust as you like.

# These are the characters that determine the type of plots

# The challenge of this script is that we can't simply start plotting using GMT directly, as we
# need to know the extents for psbasemap before we can plot anything. So we have to create a
# script with the appropriate GMT commands (plot.sh) that can be run AFTER we process the data.

# @ XMIN XMAX ZMIN ZMAX CROSSINGZEROLINE_FILE ZMATCH_FLAG
#
# Normal profile
# P PROFILE_ID color XOFFSET ZOFFSET LON1 LAT1 ... ... LONN LATN
#

# Change command characters to capital letters instead of ^ etc
# S = swath grid (^)
# T = track grid (:)
# G = oblique view top grid
# X = XYZ file ($ || >)
# E = seismicity file (>)
# C = CMT file (%)
# P = profile

# Focal mechanism data file
# C CMTFILE WIDTH ZSCALE GMT_arguments
# Earthquake (scaled) xyzm data file
# E EQFILE SWATH_WIDTH ZSCALE GMT_arguments
# XYZ data file
# X XYZFILE SWATH_WIDTH ZSCALE GMT_arguments
# Grid line profile
# T GRIDFILE ZSCALE SAMPLE_SPACING GMT_arguments
# Grid swath profile
# S GRIDFILE ZSCALE SWATH_SUBSAMPLE_DISTANCE SWATH_WIDTH SWATH_D_SPACING
# Top grid for oblique profile
# G GRIDFILE ZSCALE SWATH_SUBSAMPLE_DISTANCE SWATH_WIDTH SWATH_D_SPACING
# Point labels
# B LABELFILE SWATH_WIDTH ZSCALE FONTSTRING

# project_xyz_pts_onto_track $trackfile $xyzfile $outputfile $xoffset $zoffset $zscale
# $1=$trackfile

# profile_all.pdf needs to have each individual profile plotted on the combined axes

function tac() {
  tail -r -- "$@";
}

function project_xyz_pts_onto_track() {
  project_xyz_pts_onto_track_trackfile=$1
  project_xyz_pts_onto_track_xyzfile=$2
  project_xyz_pts_onto_track_outputfile=$3
  project_xyz_pts_onto_track_xoffset=$4
  project_xyz_pts_onto_track_zoffset=$5
  project_xyz_pts_onto_track_zscale=$6

  # Calculate distance from data points to the track, using only first two columns
  gawk < ${project_xyz_pts_onto_track_xyzfile} '{print $1, $2, $3}' | gmt mapproject -L${project_xyz_pts_onto_track_trackfile} -fg -Vn | gawk '{print $5, $6, $3}' > tmp_profile.txt
  # tmp.txt contains the lon*,lat*,depth of the projected points

  # Construct the combined track including the original track points
  gawk < ${project_xyz_pts_onto_track_trackfile} '{
    printf "%s %s REMOVEME\n", $1, $2
  }' >> tmp_profile.txt

  pointsX=$(head -n 1 ${project_xyz_pts_onto_track_trackfile} | gawk '{print $1}')
  pointsY=$(head -n 1 ${project_xyz_pts_onto_track_trackfile} | gawk '{print $2}')

  # This gets the points into a general along-track order by calculating their true distance from the starting point
  # Tracks that loop back toward the first point might fail (but who would do that anyway...)

  gmt mapproject tmp_profile.txt -G$pointsX/$pointsY+uk -Vn | gawk '{ print $0, NR }' > tmp_profile_distfrom0.txt

  # Sort the points into an actual track that increases in distance
  sort -n -k 4 < tmp_profile_distfrom0.txt > presort_tmp_profile.txt

  # Calculate the true distance along the track comprised of the points
  gmt mapproject presort_tmp_profile.txt -G+uk+a -Vn  > tmp_profile_truedist.txt

  # unsort the points so that they are associated with the proper CMTs
  sort -n -k 5 < tmp_profile_truedist.txt > postsort_tmp_profile_truedist.txt

  # Correct the locations by XOFFSET_NUM, ZOFFSET_NUM, and CMTZSCALE
  # NF is the true distance along profile that needs to be the X coordinate, modified by XOFFSET_NUM
  # NF-1 is the distance from the zero point and should be discarded
  # $3 is the Z value that needs to be modified by zscale and ZOFFSET_NUM

  # REMOVEME was turned into NAN.
  gawk < postsort_tmp_profile_truedist.txt -v xoff=${project_xyz_pts_onto_track_xoffset} -v zoff=${project_xyz_pts_onto_track_zoffset} -v zscale=${project_xyz_pts_onto_track_zscale} '{
    if ($3 != "NaN") {
      printf "%s %s %s\n", $6, ($3)*zscale+zoff, (($3)*zscale+zoff)/(zscale)
    }
  }' > ${project_xyz_pts_onto_track_outputfile}

  # Cleanup
  rm -f tmp_profile.txt tmp_profile_distfrom0.txt presort_tmp_profile.txt postsort_tmp_profile_truedist.txt

}

# Return a sane interval and subinterval from a given value range and desired
# number of major tickmarks
INTERVALS_STRING="0.00001 0.0001 0.001 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 100 200 500 1000 2000 5000 10000 20000 50000 100000 200000 500000"

function interval_and_subinterval_from_minmax_and_number () {
  local vmin=$1
  local vmax=$2
  local numint=$3
  local diffval=$(echo "($vmax - $vmin) / $numint")
  echo $INTERVALS_STRING | gawk -v seek=$diffval '{
    n=split($0, var, " ");
    mindiff=var[n];
    for(i=0;i<n;i++) {
      diff=var[i]-seek;
      if (diff < mindiff) {
        mindiff=diff
      }
    }
    print diff
  }'
}

######## Start of script #######################################################

echo "#!/bin/bash" > ./make_oblique_plots.sh
echo "PERSPECTIVE_AZ=\${1}" >> ./make_oblique_plots.sh
echo "PERSPECTIVE_INC=\${2}" >> ./make_oblique_plots.sh
echo "PERSPECTIVE_EXAG=\${3}" >> ./make_oblique_plots.sh

PFLAG="-px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}"
PXFLAG="-px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}"
RJOK="-R -J -O -K"

# rm -f /var/tmp/tectoplot/*
# mkdir /var/tmp/tectoplot/

zeropointflag=0
xminflag=0
xmaxflag=0
zminflag=0
zmaxflag=0
ZOFFSETflag=0

XOFFSET=0
ZOFFSET=0

# Interpret the first line of the profile control file
TRACKFILE_ORIG=$MPROFFILE
TRACKFILE=$(echo "$(cd "$(dirname "${F_PROFILES}control_file.txt")"; pwd)/$(basename "${F_PROFILES}control_file.txt")")

# transfer the control file to the temporary directory and remove commented, blank lines
# Remove leading whitespace

grep . $TRACKFILE_ORIG | grep -v "^[#]" | awk '{$1=$1};1' > $TRACKFILE

# If we have specified profile IDS, remove lines where the second column is not one of the profiles in PSEL_LIST

if [[ $selectprofilesflag -eq 1 ]]; then
  gawk < $TRACKFILE '{ if ($1 != "P") { print } }' > $TRACKFILE.tmp1
  for i in ${PSEL_LIST[@]}; do
    # echo "^[P ${i}]"
    grep "P ${i} " $TRACKFILE >> $TRACKFILE.tmp1
  done
  mv $TRACKFILE.tmp1 $TRACKFILE
fi

# Read the first line and check whether it is a control line
firstline=($(head -n 1 $TRACKFILE))

if [[ ${firstline[0]:0:1} == "@" ]]; then
  info_msg "Found hash at start of control line"
else
  info_msg "Control file does not have @ at beginning of the first line";
  exit 1
fi

min_x="${firstline[1]}"
max_x="${firstline[2]}"
min_z="${firstline[3]}"
max_z="${firstline[4]}"
ZEROFILE="${firstline[5]}"
ZEROZ="${firstline[6]}"

if [[ -e $ZEROFILE ]]; then
  ZEROFILE_ORIG=$(echo "$(cd "$(dirname "$ZEROFILE")"; pwd)/$(basename "$ZEROFILE")")
  # rm -f /var/tmp/tectoplot/xy_intersect.txt
  ZEROFILE="${F_PROFILES}xy_intersect.txt"
  cp $ZEROFILE_ORIG $ZEROFILE
  zeropointflag=1;
fi

if [[ $min_x =~ "auto" ]]; then
  findauto=1
  xminflag=1
fi

if [[ $max_x =~ "uto" ]]; then
  findauto=1
  xmaxflag=1
fi

if [[ $min_z =~ "uto" ]]; then
  findauto=1
  zminflag=1
  zmin1to1flag=1
fi

if [[ $max_z =~ "uto" ]]; then
  findauto=1
  zmaxflag=1
  zmax1to1flag=1
fi

if [[ $ZEROZ =~ "match" ]]; then
  ZOFFSETflag=1
  info_msg "ZOFFSETflag is set... matching Z values at X=0"
fi

THIS_DIR=$(pwd)/

PROFHEIGHT_OFFSET=$(echo "${PROFILE_HEIGHT_IN}" | gawk '{print ($1+0)/2 + 4/72}')

# Each profile is specified by an ID, an X offset, and a set of lon,lat vertices.
# ID COLOR XOFFSET lon1 lat1 lon2 lat2 ... lonN latN
# FIX: color needs to be a GMT color with a 'lightcolor' variant.

gmt gmtset MAP_FRAME_PEN thin,black GMT_VERBOSE n
gmt gmtset FONT_ANNOT_PRIMARY 5p,Helvetica,black GMT_VERBOSE e

# 1    2    3    4    5    6          7        8
# grid lon1 lat1 lon2 lat2 spacing-km width-km samplewidth-km
# 1    2                3          4        5               6       7      8       9
# grid profile_ends.dat spacing-km width-km samplewidth-km  min_x   max_x  min_z   max_z

k=$(wc -l < $TRACKFILE)
# echo Looking for $k lines in $TRACKFILE

# Set up the clip area
# Can change into a while read linearray loop...

# We should add a command character to the profile lines
# P is for a normal profile
# T is for a transverse profile
# For a T profile, we calculate the distance along the profile and the distance from the profile.
# Negative is to the left of the profile and positive is to the right?

for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $1}')

  if [[ ${FIRSTWORD:0:1} == "P" ]]; then
    echo ">" >> ${F_PROFILES}line_buffer.txt
    head -n ${i} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 >> ${F_PROFILES}line_buffer.txt
  fi
  if [[ ${FIRSTWORD:0:1} == "S" || ${FIRSTWORD:0:1} == "G" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print $5 }' >> ${F_PROFILES}widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "X" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print $3 }' >> ${F_PROFILES}widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "E" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print $3 }' >> ${F_PROFILES}widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "C" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print $3 }' >> ${F_PROFILES}widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "B" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print $3 }' >> ${F_PROFILES}widthlist.txt
  fi
done

# If there are no swath-type data requests, set a nominal width of 1 km
if [[ ! -e ${F_PROFILES}widthlist.txt ]]; then
  info_msg "No swath data in profile control file; setting to 1 km"
  echo "1k" > ${F_PROFILES}widthlist.txt
fi

# We accomplish buffering using geographic coordinates, so that buffers far from
# the equator will be too wide (longitudinally). This is not a real problem as we only use the
# buffers to define the AOI and graphically indicate the profile areas.

# We use ogr2ogr with SQlite instead of gmt spatial due to apparent problems with the latter's buffers.
# Any better buffering solution could easily go here

# This just gets the width of the widest swath from the data
# Use a minimum of 10km as a buffer (why?)

WIDTH_DEG_DATA=$(gawk < ${F_PROFILES}widthlist.txt 'BEGIN {maxw=0; } {
    val=($1+0);
    if (val > maxw) {
      maxw = val
    }
  }
  END {print maxw/110/2}')

MAXWIDTH_KM=$(gawk < ${F_PROFILES}widthlist.txt 'BEGIN {maxw=0; } {
    val=($1+0);
    if (val > maxw) {
      maxw = val
    }
  }
  END {print maxw}')

WIDTH_DEG=$(echo $WIDTH_DEG_DATA | gawk '{ print ($1<10/110/2) ? 10/110/2 : $1}')

# Make the OGR_GMT format file

echo "# @VGMT1.0 @GLINESTRING @Nname" > ${F_PROFILES}linebuffer.gmt
echo "# @Jp\"+proj=longlat +ellps=WGS84 \"" >> ${F_PROFILES}linebuffer.gmt
echo "# FEATURE_DATA" >> ${F_PROFILES}linebuffer.gmt

gawk < ${F_PROFILES}line_buffer.txt 'BEGIN{num=1} {
  if ($1 == ">") {
    print "> -W0.25p";
    printf "# @D\"%s\"\n", num++;
  }
  else {
    if ($1 > 180) {
      print $1, $2
    } else {
      print $1, $2
    }
  }
}' >> ${F_PROFILES}linebuffer.gmt

# We could theoretically project and then buffer in meters and then reproject... ick

# ogr2ogr -f "OGR_GMT" buf_poly.gmt linebuffer.gmt -dialect sqlite -sql "select ST_buffer(geometry, $WIDTH_DEG) as geometry FROM linebuffer"
#
# # Return to GMT multisegment format which is easier to work with
# gawk <  buf_poly.gmt '{ if ($1 != "#") { print } }' > buf_poly.txt
#
# # The buffers are returned in line order and can be split into per-line buffers.
#
# gawk < buf_poly.txt 'BEGIN{ fn = "buf_1.txt"; n = 0 }
# {
#    if (substr($0,1,2) == ">") {
#        close (fn)
#        n++
#        fn = "buf_" n ".txt"
#    } else {
#      print > fn
#    }
# }'

# gmt spatial (GMT 6.1) is producing bad buffers that are missing important points
# gmt spatial -Sb+"${WIDTH_DEG}" line_buffer.txt > buf_poly.txt

# Add a degree around each buffer extreme coordinate to determine the profile area AOI.
# This would impact very high resolution datasets of small areas and should probably be adjusted to suit.

# buf_max_x=$(grep "^[^>]" buf_poly.txt | sort -n -k 1 | tail -n 1 | gawk '{printf "%d", $1+1}')
# buf_min_x=$(grep "^[^>]" buf_poly.txt | sort -n -k 1 | head -n 1 | gawk '{printf "%d", $1-1}')
# buf_max_z=$(grep "^[^>]" buf_poly.txt | sort -n -k 2 | tail -n 1 | gawk '{printf "%d", $2+1}')
# buf_min_z=$(grep "^[^>]" buf_poly.txt | sort -n -k 2 | head -n 1 | gawk '{printf "%d", $2-1}')

# echo "Buffered extent is $buf_min_x/$buf_max_x/$buf_min_z/$buf_max_z"

# Currently I can only make gmt spatial -Sb work with degree units.
# Use a basic conversion of 110 km per degree and use the half-width

xyzfilelist=()
xyzcommandlist=()

# Default units are X=Y=Z=km. Use L command to update labels.
x_axis_label="Distance (km)"
y_axis_label="Distance (km)"
z_axis_label="Distance (km)"

# Search for, parse, and pre-process datasets to be plotted
for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $1}')

  # L changes aspects of plot axis labels
  if [[ ${FIRSTWORD:0:1} == "L" ]]; then
    # Remove leading and trailing whitespaces from the axis labels
    x_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk -F'|' '{gsub(/^[ \t]+/,"",$2);gsub(/[ \t]+$/,"",$2);print $2}')
    y_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk -F'|' '{gsub(/^[ \t]+/,"",$3);gsub(/[ \t]+$/,"",$2);print $3}')
    z_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk -F'|' '{gsub(/^[ \t]+/,"",$4);gsub(/[ \t]+$/,"",$2);print $4}')

  # V changes the vertical exaggeration of perspective plots
  elif [[ ${FIRSTWORD:0:1} == "V" ]]; then
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))
    PERSPECTIVE_EXAG="${myarr[1]}"

  # B plots labels from an XYZ+text format file
  elif [[ ${FIRSTWORD:0:1} == "B" ]]; then
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))
    # This is where we would load datasets to be displayed
    LABEL_FILE_P=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    LABEL_FILE_SEL=$(echo "${F_PROFILES}label_$(basename "${myarr[1]}")")

    # Remove lines that don't start with a number or a minus sign. Doesn't handle plus signs...
    # Store in a file called crop_X where X is the basename of the source data file.
    grep "^[-*0-9]" $LABEL_FILE_P | gmt select -fg -L${F_PROFILES}line_buffer.txt+d"${myarr[2]}" > $LABEL_FILE_SEL
    info_msg "Selecting labels in file $LABEL_FILE_P within buffer distance ${myarr[2]}: to $LABEL_FILE_SEL"
    labelfilelist[$i]=$LABEL_FILE_SEL

    # In this case, the width given must be divided by two.
    labelwidthlistfull[$i]="${myarr[2]}"
    labelwidthlist[$i]=$(echo "${myarr[2]}" | gawk '{ print ($1+0)/2 substr($1,length($1),1) }')
    labelunitlist[$i]="${myarr[3]}"
    labelfontlist[$i]=$(echo "${myarr[@]:4}")

  # S defines grids that we calculate swath profiles from.
  # G defines a grid that will be displayed above oblique profiles.
  elif [[ ${FIRSTWORD:0:1} == "S" || ${FIRSTWORD:0:1} == "G" ]]; then           # Found a gridded dataset; cut to AOI and store as a nc file
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))

    # GRIDFILE 0.001 .1k 40k 0.1k
    grididnum[$i]=$(echo "grid${i}")
    gridfilelist[$i]=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    gridfilesellist[$i]=$(echo "cut_$(basename "${myarr[1]}")")
    gridzscalelist[$i]="${myarr[2]}"
    gridspacinglist[$i]="${myarr[3]}"
    gridwidthlist[$i]="${myarr[4]}"
    gridsamplewidthlist[$i]="${myarr[5]}"

    # If this is a top tile grid, we can specify its cpt here.
    if [[ ${FIRSTWORD:0:1} == "G" ]]; then
      istopgrid[$i]=1
      if [[ -z "${myarr[6]}" ]]; then
        echo "No CPT specified."
      else
        gridcptlist[$i]=$(echo "$(cd "$(dirname "${myarr[6]}")"; pwd)/$(basename "${myarr[6]}")")
      fi
      info_msg "Loading top grid: ${gridfilelist[$i]}: Zscale ${gridzscalelist[$i]}, Spacing: ${gridspacinglist[$i]}, Width: ${gridwidthlist[$i]}, SampWidth: ${gridsamplewidthlist[$i]}"
    else
      info_msg "Loading swath grid: ${gridfilelist[$i]}: Zscale ${gridzscalelist[$i]}, Spacing: ${gridspacinglist[$i]}, Width: ${gridwidthlist[$i]}, SampWidth: ${gridsamplewidthlist[$i]}"
    fi

    # # Cut the grid to the AOI and multiply by its ZSCALE
    # If the grid doesn't fall within the buffer AOI, there will be no result but it won't be a problem, so pipe error to /dev/null
    rm -f ${F_PROFILES}tmp.nc
    gmt grdcut ${gridfilelist[$i]} -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -G${F_PROFILES}tmp.nc --GMT_HISTORY=false -Vn 2>/dev/null
    gmt grdmath ${F_PROFILES}tmp.nc ${gridzscalelist[$i]} MUL = ${F_PROFILES}${gridfilesellist[$i]}

  # T is a grid sampled along a track line
  elif [[ ${FIRSTWORD:0:1} == "T" ]]; then
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))

    # GRIDFILE 0.001 .1k 40k 0.1k
    ptgrididnum[$i]=$(echo "ptgrid${i}")
    ptgridfilelist[$i]=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    ptgridfilesellist[$i]=$(echo "cut_$(basename "${myarr[1]}")")
    ptgridzscalelist[$i]="${myarr[2]}"
    ptgridspacinglist[$i]="${myarr[3]}"
    ptgridcommandlist[$i]=$(echo "${myarr[@]:4}")

    info_msg "Loading single track sample grid: ${ptgridfilelist[$i]}: Zscale: ${ptgridzscalelist[$i]} Spacing: ${ptgridspacinglist[$i]}"

    # Cut the grid to the AOI and multiply by its ZSCALE
    # If the grid doesn't fall within the buffer AOI, there will be no result but it won't be a problem, so pipe error to /dev/null

    rm -f ${F_PROFILES}tmp.nc
    # echo     gmt grdcut ${ptgridfilelist[$i]} -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -Gtmp.nc --GMT_HISTORY=false "-Vn 2>/dev/null"
    gmt grdcut ${ptgridfilelist[$i]} -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -G${F_PROFILES}tmp.nc --GMT_HISTORY=false -Vn 2>/dev/null
    if [[ -e ${F_PROFILES}tmp.nc ]]; then
      # echo tmp.nc exists
      gmt grdmath ${F_PROFILES}tmp.nc ${ptgridzscalelist[$i]} MUL = ${F_PROFILES}${ptgridfilesellist[$i]}
    fi

  # X is an xyz dataset; E is an XYZ dataset scaled like an earthquake
  elif [[ ${FIRSTWORD:0:1} == "X" || ${FIRSTWORD:0:1} == "E" ]]; then        # Found an XYZ dataset
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))
    # This is where we would load datasets to be displayed
    FILE_P=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    FILE_SEL=$(echo "${F_PROFILES}crop_$(basename "${myarr[1]}")")

    # Remove lines that don't start with a number or a minus sign. Doesn't handle plus signs...
    # Store in a file called crop_X where X is the basename of the source data file.
    grep "^[-*0-9]" $FILE_P | gmt select -fg -L${F_PROFILES}line_buffer.txt+d"${myarr[2]}" > $FILE_SEL
    info_msg "Selecting data in file $FILE_P within buffer distance ${myarr[2]}: to $FILE_SEL"
    xyzfilelist[$i]=$FILE_SEL

    # In this case, the width given must be divided by two.
    xyzwidthlistfull[$i]="${myarr[2]}"
    xyzwidthlist[$i]=$(echo "${myarr[2]}" | gawk '{ print ($1+0)/2 substr($1,length($1),1) }')
    xyzunitlist[$i]="${myarr[3]}"
    xyzcommandlist[$i]=$(echo "${myarr[@]:4}")

    # We mark the seismic data that are subject to rescaling (or any data with a scalable fourth column...)
    [[ ${FIRSTWORD:0:1} == "E" ]] && xyzscaleeqsflag[$i]=1

    # echo "Found a dataset to load: ${xyzfilelist[$i]}"
    # echo "Scale factor for Z units is ${xyzunitlist[$i]}"
    # echo "Commands are ${xyzcommandlist[$i]}"
    # echo "Scale flag is ${xyzscaleeqsflag[$i]}"

  # C is a CMT dataset
  elif [[ ${FIRSTWORD:0:1} == "C" ]]; then         # Found a CMT dataset; currently, we only do one
    cmtfileflag=1
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | gawk '{ print }'))
    # This is where we would load datasets to be displayed
    CMTFILE=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    CMTWIDTH_FULL="${myarr[2]}"
    # The following command assumes that WIDTH ends with a unit letter (e.g. k, m)
    CMTWIDTH=$(echo $CMTWIDTH_FULL | gawk '{ print ($1+0)/2 substr($1,length($1),1) }')
    CMTZSCALE="${myarr[3]}"
    CMTCOMMANDS=$(echo "${myarr[@]:4}")
    # echo "CMT: ${CMTFILE} W: ${CMTWIDTH_FULL} Z: ${CMTZSCALE} C: ${CMTCOMMANDS}"
  fi
done

# Process the profile tracks one by one, in the order that they appear in the control file.
# Keep track of which profile we are working on. (first=0)
PROFILE_INUM=0

for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $1}')

  # Process the 'normal' type tracks.
  if [[ ${FIRSTWORD:0:1} == "P" ]]; then
    LINEID=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $2}')
    COLOR=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $3}')
    XOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $4}')
    ZOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $5}')

    # Initialize the profile plot script
    echo "#!/bin/bash" > ${F_PROFILES}${LINEID}_profile_plot.sh

  # if [[ ${FIRSTWORD:0:1} != "#" && ${FIRSTWORD:0:1} != "$" && ${FIRSTWORD:0:1} != "%"  && ${FIRSTWORD:0:1} != "^" && ${FIRSTWORD:0:1} != "@" && ${FIRSTWORD:0:1} != ":" && ${FIRSTWORD:0:1} != ">" ]]; then
  #   LINEID=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $1}')
  #   COLOR=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $2}')
  #   XOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $3}')
  #   ZOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | gawk '{print $4}')

    if [[ ${XOFFSET:0:1} == "N" ]]; then
      info_msg "N flag: XOFFSET and X alignment is overridden for line $LINEID"
      doxflag=0
      XOFFSET_NUM=0
    else
      doxflag=1
      XOFFSET_NUM=$XOFFSET
    fi
    if [[ ${ZOFFSET:0:1} == "N" ]]; then
      info_msg "N flag: ZOFFSET and Z alignment is overridden for line $LINEID"
      dozflag=0
      ZOFFSET_NUM=0
    else
      ZOFFSET_NUM=$ZOFFSET
      dozflag=1
    fi

    COLOR_R=($(grep ^"$COLOR " $TECTOPLOT_COLORS | head -n 1 | gawk '{print $2, $3, $4}'))

    # echo "COLOR $COLOR in R/G/B is ${COLOR_R[0]}/${COLOR_R[1]}/${COLOR_R[2]}"
    COLOR=$(echo "${COLOR_R[0]}/${COLOR_R[1]}/${COLOR_R[2]}")
    LIGHTCOLOR=$(echo $COLOR | gawk -F/ '{
      printf "%d/%d/%d", (255-$1)*0.25+$1,  (255-$2)*0.25+$2, (255-$3)*0.25+$3
    }')
    LIGHTERCOLOR=$(echo $COLOR | gawk -F/ '{
      printf "%d/%d/%d", (255-$1)*0.5+$1,  (255-$2)*0.5+$2, (255-$3)*0.5+$3
    }')

    # echo "$LINEID is LINEID / color is $COLOR light $LIGHTCOLOR lighter $LIGHTERCOLOR,  offset is $XOFFSET_NUM"
    head -n ${i} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 > ${F_PROFILES}${LINEID}_trackfile.txt

    # Calculate the incremental length along profile between points
    gmt mapproject ${F_PROFILES}${LINEID}_trackfile.txt -G+uk+i | gawk '{print $3}' > ${F_PROFILES}${LINEID}_dist_km.txt

    # Calculate the total along-track length of the profile
    PROFILE_LEN_KM=$(gawk < ${F_PROFILES}${LINEID}_dist_km.txt 'BEGIN{val=0}{val=val+$1}END{print val}')
    PROFILE_XMIN=0
    PROFILE_XMAX=$PROFILE_LEN_KM

    # Pair the data points using a shift and paste.
  	sed 1d < ${F_PROFILES}${LINEID}_trackfile.txt > ${F_PROFILES}shift1_${LINEID}_trackfile.txt
  	paste ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}shift1_${LINEID}_trackfile.txt | grep -v "\s>" > ${F_PROFILES}geodin_${LINEID}_trackfile.txt

    # Script to return azimuth and midpoint between a pair of input points.
    # Comes within 0.2 degrees of geod() results over large distances, while being symmetrical which geod isn't
    # We need perfect symmetry in order to create exact point pairs in adjacent polygons

    # Note: this calculates the NORMAL DIRECTION to the profile and not its AZIMUTH

    gawk < ${F_PROFILES}geodin_${LINEID}_trackfile.txt 'function acos(x) { return atan2(sqrt(1-x*x), x) }
        {
            lon1 = $1*3.14159265358979/180;
            lat1 = $2*3.14159265358979/180;
            lon2 = $3*3.14159265358979/180;
            lat2 = $4*3.14159265358979/180;
            Bx = cos(lat2)*cos(lon2-lon1);
            By = cos(lat2)*sin(lon2-lon1);
            latMid = atan2(sin(lat1)+sin(lat2), sqrt((cos(lat1)+Bx)*(cos(lat1)+Bx)+By*By));
            lonMid = lon1+atan2(By, cos(lat1)+Bx);
            theta = atan2(sin(lon2-lon1)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1));
            printf "%.5f %.5f %.3f\n", lonMid*180/3.14159265358979, latMid*180/3.14159265358979, (theta*180/3.14159265358979+360-90)%360;
        }' > ${F_PROFILES}az_${LINEID}_trackfile.txt

    paste ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}az_${LINEID}_trackfile.txt > ${F_PROFILES}jointrack_${LINEID}.txt

    # The azimuth of the profile is the azimuth of its first segment.

    THISP_AZ=$(head -n 1 ${F_PROFILES}az_${LINEID}_trackfile.txt | awk '{print $3}')

    # A hillshade of the profile will need to be adjusted by
    # az=0/360 a2=az+a+90
    # az=45
    THISP_HS_AZ=$(echo $THISP_AZ $HS_AZ | awk '{
      val=$2+(90-$1)-90;
      while(val>360) {
        val=val-360;
      }
      print val
    }')


    LINETOTAL=$(wc -l < ${F_PROFILES}jointrack_${LINEID}.txt)
    cat ${F_PROFILES}jointrack_${LINEID}.txt | gawk -v width="${MAXWIDTH_KM}" -v color="${COLOR}" -v lineval="${LINETOTAL}" -v folderid=${F_PROFILES} -v lineid=${LINEID} '
      (NR==1) {
        print $1, $2, $5, width, color, lineid >> "start_points.txt"
        lastval=$5
      }
      (NR>1 && NR<lineval) {
        diff = ( ( $5 - lastval + 180 + 360 ) % 360 ) - 180
        angle = (360 + lastval + ( diff / 2 ) ) % 360
        print $1, $2, angle, width, color, lineid >> "mid_points.txt"
        lastval=$5
      }
      END {
        filename=sprintf("%s%s_end.txt", folderid, lineid)
        print $1, $2, lastval, width, color, folderid >> filename
        print $1, $2, lastval, width, color, lineid >> "end_points.txt"
      }
      '

    xoffsetflag=0
    # Set XOFFSET to the distance from our first point to the crossing point of zero_point_file.txt
    if [[ $zeropointflag -eq 1 && $doxflag -eq 1 ]]; then
      head -n 1 ${F_PROFILES}${LINEID}_trackfile.txt > ${F_PROFILES}intersect.txt
      gmt spatial -Vn -fg -Ie -Fl ${F_PROFILES}${LINEID}_trackfile.txt $ZEROFILE | head -n 1 | gawk '{print $1, $2}' >> ${F_PROFILES}intersect.txt
      INTNUM=$(wc -l < ${F_PROFILES}intersect.txt)
      if [[ $INTNUM -eq 2 ]]; then
        XOFFSET_NUM=$(gmt mapproject -Vn -G+uk+i ${F_PROFILES}intersect.txt | tail -n 1 | gawk '{print 0-$3}')
        xoffsetflag=1
        PROFILE_XMIN=$(echo "$PROFILE_XMIN + $XOFFSET_NUM" | bc -l)
        PROFILE_XMAX=$(echo "$PROFILE_XMAX + $XOFFSET_NUM" | bc -l)
        info_msg "Updated line $LINEID by shifting $XOFFSET_NUM km to match $ZEROFILE"
        tail -n 1 ${F_PROFILES}intersect.txt >> ${F_PROFILES}all_intersect.txt
      fi
    fi

    ##########################################################################
    # Extract LITHO1.0 data to plot on profile.
    # 1. depth(m)
    # 2. density(kg/m3)  [1000-3300]
    # 3. Vp(m/s)         [2500-8500]
    # 4. Vs(m/s)         [1000-5000]
    # 5. Qkappa          0?
    # 6. Qmu             [0 1000]
    # 7. Vp2(m/s)
    # 8. Vs2(m/s)
    # 9. eta

    # Find the cross profile locations

    p=($(head -n 1 ${F_PROFILES}${LINEID}_end.txt))
    # Determine profile of the oblique block end
    ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
    FOREAZ=$(echo "${p[2]} - 90" | bc -l)
    SUBWIDTH=$(echo "${p[3]} * 0.1" | bc -l)

    if [[ $PERSPECTIVE_TOPO_HALF == "+l" ]]; then
      # If we are doing the half profile, go from the profile and don't correct
      XOFFSET_CROSS=0
      # echo "${p[0]} ${p[1]}" > ${LINEID}_endprof.txt
      # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}k >> ${LINEID}_endprof.txt
      echo "${p[0]} ${p[1]}" > ${F_PROFILES}${LINEID}_endprof.txt
      gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${p[3]}k -L0/${p[3]} | gawk '{print $1, $2}' >> ${F_PROFILES}${LINEID}_endprof.txt
    else
      # echo "full"
      # If we are doing the full profile, we have to go from endpoint to endpoint
      # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}k > ${LINEID}_endprof.txt
      # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}k >> ${LINEID}_endprof.txt
      gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${p[3]}k -L0/${p[3]} | gawk '{print $1, $2}' > ${F_PROFILES}${LINEID}_endprof.txt
      gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${p[3]}k -L0/${p[3]} | gawk '{print $1, $2}' >> ${F_PROFILES}${LINEID}_endprof.txt

      # Get the distance between the points, in km
    fi
    TMPDIST=$(gmt mapproject ${F_PROFILES}${LINEID}_endprof.txt -G+uk+i | tail -n 1 | gawk '{print $3}')
    XOFFSET_CROSS=$(echo "0 - ($TMPDIST / 2)" | bc -l)

    if [[ $litho1profileflag -eq 1 ]]; then
      info_msg "Extracting LITHO1.0 data for profile ${LINEID}"

      # First, do the main profile, honoring the XOFFSET_NUM shift

      gmt sample1d ${F_PROFILES}${LINEID}_trackfile.txt -Af -fg -I${LITHO1_INC}k  > ${F_PROFILES}${LINEID}_litho1_track.txt
      rm -f ${F_PROFILES}lab.xy
      ptcount=0
      while read p; do
        lon=$(echo $p | gawk '{print $1}')
        lat=$(echo $p | gawk '{print $2}')
        access_litho -p $lat $lon -l ${LITHO1_LEVEL} 2>/dev/null | gawk -v extfield=$LITHO1_FIELDNUM -v xoff=${XOFFSET_NUM} -v ptcnt=$ptcount -v dinc=${LITHO1_INC} '
          BEGIN {
            widthfactor=1
            getline;
            lastz=-$1/1000
            lastval=$(extfield)
            dist=ptcnt*dinc+xoff
            print "> -Z" lastval
            print dist-dinc*widthfactor/2, -6000000/1000
            print dist+dinc*widthfactor/2, -6000000/1000
            print dist+dinc*widthfactor/2, lastz
            print dist-dinc*widthfactor/2, lastz
            print dist-dinc*widthfactor/2, -6000000/1000
          }
          {
            # print $10>>"/dev/stderr"
            dist=ptcnt*dinc+xoff
            if (lastz==-$1/1000 || $(extfield)<=1030) {
              # do not print empty boxes or water velocity boxes
            } else {
              print "> -Z" $(extfield)
              print dist-dinc*widthfactor/2, lastz
              print dist+dinc*widthfactor/2, lastz
              print dist+dinc*widthfactor/2, -$1/1000
              print dist-dinc*widthfactor/2, -$1/1000
              print dist-dinc*widthfactor/2, lastz
            }
            if ($10 == "LID-BOTTOM") {
              print dist-dinc*1/2, -$1/1000 >> "./lab.xy"
              print dist+dinc*1/2, -$1/1000 >> "./lab.xy"
            }
            lastz=-$1/1000
            lastval=$(extfield)
          }' >> ${F_PROFILES}${LINEID}_litho1_poly.dat

        ptcount=$(echo "$ptcount + 1" | bc)
      done < ${F_PROFILES}${LINEID}_litho1_track.txt
      mv lab.xy ${F_PROFILES}${LINEID}_lab.xy

      # Then, do the cross-profile to go on the end of the block diagram.

      if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then
        gmt sample1d ${F_PROFILES}${LINEID}_endprof.txt -Af -fg -I${LITHO1_INC}k  > ${F_PROFILES}${LINEID}_litho1_cross_track.txt
        rm -f lab.xy
        ptcount=0
        while read p; do
          lon=$(echo $p | gawk '{print $1}')
          lat=$(echo $p | gawk '{print $2}')
          access_litho -p $lat $lon -l ${LITHO1_LEVEL} 2>/dev/null | gawk -v extfield=$LITHO1_FIELDNUM -v xoff=${XOFFSET_CROSS} -v ptcnt=$ptcount -v dinc=${LITHO1_INC} '
            BEGIN {
              getline;
              widthfactor=1
              lastz=-$1/1000
              lastval=$(extfield)
              dist=ptcnt*dinc+xoff
              print "> -Z" lastval
              print dist-dinc*widthfactor/2, -6000000/1000
              print dist+dinc*widthfactor/2, -6000000/1000
              print dist+dinc*widthfactor/2, lastz
              print dist-dinc*widthfactor/2, lastz
              print dist-dinc*widthfactor/2, -6000000/1000
            }
            {
              # print $10>>"/dev/stderr"
              dist=ptcnt*dinc+xoff
              if (lastz==-$1/1000 || $(extfield)<=1030) {
                # do not print empty boxes or water velocity boxes
              } else {
                print "> -Z" $(extfield)
                print dist-dinc*widthfactor/2, lastz
                print dist+dinc*widthfactor/2, lastz
                print dist+dinc*widthfactor/2, -$1/1000
                print dist-dinc*widthfactor/2, -$1/1000
                print dist-dinc*widthfactor/2, lastz
              }
              if ($10 == "LID-BOTTOM") {
                print dist-dinc*1/2, -$1/1000 >> "./lab.xy"
                print dist+dinc*1/2, -$1/1000 >> "./lab.xy"
              }
              lastz=-$1/1000
              lastval=$(extfield)
            }' >> ${F_PROFILES}${LINEID}_litho1_cross_poly.dat
          ptcount=$(echo "$ptcount + 1" | bc)
        done < ${F_PROFILES}${LINEID}_litho1_cross_track.txt
        mv lab.xy ${F_PROFILES}${LINEID}_cross_lab.xy
      fi

      # PLOT ON THE MAP PS
      echo "gmt psxy -L ${F_PROFILES}${LINEID}_litho1_poly.dat -G+z -C$LITHO1_CPT -t${LITHO1_TRANS} -Vn -R -J -O -K >> ${PSFILE}" >> plot.sh
      echo "gmt psxy ${F_PROFILES}${LINEID}_lab.xy -W0.5p,black -Vn -R -J -O -K >> ${PSFILE}" >> plot.sh

      # PLOT ON THE FLAT PROFILE PS
      echo "gmt psxy -L ${F_PROFILES}${LINEID}_litho1_poly.dat -G+z -C$LITHO1_CPT -t${LITHO1_TRANS} -Vn -R -J -O -K >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
      echo "gmt psxy ${F_PROFILES}${LINEID}_lab.xy -W0.5p,black -Vn -R -J -O -K >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

      # PLOT ON THE OBLIQUE PROFILE PS
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -L -p ${F_PROFILES}${LINEID}_litho1_poly.dat -t${LITHO1_TRANS} -G+z -C$LITHO1_CPT -Vn -R -J -O -K >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p ${F_PROFILES}${LINEID}_lab.xy -W0.5p,black -Vn -R -J -O -K >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh

    fi

    ############################################################################
    # This section processes the grid data that we are sampling along the
    # profile line itself

    for i in ${!ptgridfilelist[@]}; do
      gridfileflag=1

      if [[ -e ${F_PROFILES}${ptgridfilesellist[$i]} ]]; then

        # Resample the track at the specified X increment.
        gmt sample1d ${F_PROFILES}${LINEID}_trackfile.txt -Af -fg -I${ptgridspacinglist[$i]} > ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_trackinterp.txt

        # Calculate the X coordinate of the resampled track, accounting for any X offset due to profile alignment
        gmt mapproject -G+uk+a ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_trackinterp.txt | gawk -v xoff="${XOFFSET_NUM}" '{ print $1, $2, $3 + xoff }' > ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_trackdist.txt

        # Sample the grid at the points.  Note that -N is needed to avoid paste problems.

        gmt grdtrack -N -Vn -G${F_PROFILES}${ptgridfilesellist[$i]} ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_trackinterp.txt > ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_sample.txt

        # *_sample.txt is a file containing lon,lat,val
        # We want to reformat to a multisegment polyline that can be plotted using psxy -Ccpt
        # > -Zval1
        # Lon1 lat1
        # lon2 lat2
        # > -Zval2
        paste ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_trackdist.txt ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_sample.txt > ${F_PROFILES}dat.txt
        sed 1d < ${F_PROFILES}dat.txt > ${F_PROFILES}dat1.txt
      	paste ${F_PROFILES}dat.txt ${F_PROFILES}dat1.txt | gawk -v zscale=${ptgridzscalelist[$i]} '{ if ($7 && $6 != "NaN" && $12 != "NaN") { print "> -Z"($6+$12)/2*zscale*-1; print $3, $6*zscale; print $9, $12*zscale } }' > ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_data.txt

        # PLOT ON THE MAP PS
        echo "gmt psxy -Vn -R -J -O -K -L ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> "${PSFILE}"" >> plot.sh

        # PLOT ON THE FLAT PROFILE PS
        echo "gmt psxy -Vn -R -J -O -K -L ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -L ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh

        grep "^[-*0-9]" ${F_PROFILES}${LINEID}_${ptgrididnum[$i]}_data.txt >> ${F_PROFILES}${LINEID}_all_data.txt
      fi
    done

    ############################################################################
    # This section processes grid datasets (usually DEM, gravity, etc) by
    # calculating swath profiles. This section and the topgrid section are very
    # similar and if this is modified, please check the topgrid section!

    for i in ${!gridfilelist[@]}; do
      gridfileflag=1

      # Sample the input grid along space cross-profile
      gmt grdtrack -N -Vn -G${F_PROFILES}${gridfilesellist[$i]} ${F_PROFILES}${LINEID}_trackfile.txt -C${gridwidthlist[$i]}/${gridsamplewidthlist[$i]}/${gridspacinglist[$i]}${PERSPECTIVE_TOPO_HALF} -Af > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiletable.txt

      # ${LINEID}_${grididnum[$i]}_profiletable.txt: FORMAT is grdtrack (> profile data), columns are lon, lat, distance_from_profile, back_azimuth, value

      # Extract the profile ID numbers.
      # !!!!! This could easily be simplified to be a list of numbers starting with 0 and incrementing by 1!
      grep ">" ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiletable.txt | gawk -F- '{print $3}' | gawk -F" " '{print $1}' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilepts.txt

      # Shift the X coordinates of each cross-profile according to XOFFSET_NUM value
      # In gawk, adding +0 to dinc changes "0.3k" to "0.3"
      gawk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" '{ print ( $1 * (dinc + 0) + xoff ) }' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilepts.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilekm.txt

      # Construct the profile data table.
      gawk '{
        if ($1 == ">") {
          printf("\n")
        } else {
          printf("%s ", $5)
        }
      }' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiletable.txt | sed '1d' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledata.txt

      # If we are doing an oblique section and the current grid is a top grid
      if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 && ${istopgrid[$i]} -eq 1 ]]; then

        # Export the along-profile DEM, resampled to a certain resolution.
        # Then estimate the coordinate extents and the z data range, to allow vertical exaggeration

        if [[ $DO_SIGNED_DISTANCE_DEM -eq 0 ]]; then
          # Just export the profile data to a CSV without worrying about profile kink problems. Faster.

          # First find the maximum value of X. We want X to be negative or zero for the block plot. Not sure what happens otherwise...
          MAX_X_VAL=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiletable.txt 'BEGIN{maxx=-999999} { if ($1 != ">" && $1 > maxx) {maxx = $1 } } END{print maxx}')

          gawk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" -v maxx=$MAX_X_VAL '
            BEGIN{offset=0;minX=99999999;maxX=-99999999; minY=99999999; maxY=-99999999; minZ=99999999; maxZ=-99999999}
            {
              if ($1 == ">") {
                split($5, vec, "-");
                offset=vec[3]
              } else {
                yval=-$3
                xval=(offset * (dinc + 0) + xoff);
                zval=$5
                if (zval == "NaN") {
                  print xval "," yval "," zval
                } else {
                  print xval "," yval "," zval
                  if (xval < minX) {
                    minX=xval
                  }
                  if (xval > maxX) {
                    maxX=xval
                  }
                  if (yval < minY) {
                    minY=yval
                  }
                  if (yval > maxY) {
                    maxY=yval
                  }
                  if (zval < minZ) {
                    minZ=zval
                  }
                  if (zval > maxZ) {
                    maxZ=zval
                  }
                }
              }
            }
            END {
              printf "%d %d %d %d %f %f", minX, maxX, minY, maxY, minZ, maxZ > "./profilerange.txt"
            }' < ${F_PROFILES}${LINEID}_${grididnum[$i]]}_profiletable.txt | sed '1d' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_data.csv
        else  # DO_SIGNED_DISTANCE_DEM is 1
          mv profilerange.txt ${F_PROFILES}/profilerange.txt

          # Turn the gridded profile data into dt, da, Z data, shifted by X offset

          # Output the lon, lat, Z, and the sign of the cross-profile distance (left vs right)
          gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]]}_profiletable.txt '{
            if ($1 != ">") {
              print $1, $2, $5, ($3>0)?-1:1
            }
          }' > ${F_PROFILES}${LINEID}_${grididnum[$i]]}_prepdata.txt

            # I need a file with LON, LAT, Z

            # Interpolate at a spacing of ${gridspacinglist[$i]} (spacing between cross track profiles)
            gmt sample1d ${F_PROFILES}${LINEID}_trackfile.txt -Af -fg -I${gridspacinglist[$i]} > ${F_PROFILES}line_trackinterp.txt

            # If this function can be sped up that would be great.
            info_msg "Doing signed distance calculation... (takes some time!)"
            gmt mapproject ${F_PROFILES}${LINEID}_${grididnum[$i]]}_prepdata.txt -L${F_PROFILES}line_trackinterp.txt+p -fg -Vn > ${F_PROFILES}${LINEID}_${grididnum[$i]]}_dadtpre.txt
            # Output is Lon, Lat, Z, DistSign, DistX, ?, DecimalID
            # DecimalID * ${gridspacinglist[$i]} = distance along track

            gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]]}_dadtpre.txt -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" '
                BEGIN{
                  offset=0;minX=99999999;maxX=-99999999; minY=99999999; maxY=-99999999; minZ=99999999; maxZ=-99999999
                }
                {
                  xval=($7 * (dinc + 0) + xoff)
                  yval=$4*$5/1000
                  zval=$3
                  print xval "," yval "," zval
                  if (zval != "NaN") {
                    if (xval < minX) {
                      minX=xval
                    }
                    if (xval > maxX) {
                      maxX=xval
                    }
                    if (yval < minY) {
                      minY=yval
                    }
                    if (yval > maxY) {
                      maxY=yval
                    }
                    if (zval < minZ) {
                      minZ=zval
                    }
                    if (zval > maxZ) {
                      maxZ=zval
                    }
                  }
                }
                END {
                  printf "%d %d %d %d %f %f", minX, maxX, minY, maxY, minZ, maxZ > "./profilerange.txt"
                } ' | sed '1d' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_data.csv
        fi

        mv profilerange.txt ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt

cat << EOF > ${F_PROFILES}${LINEID}_${grididnum[$i]}_data.vrt
<OGRVRTDataSource>
    <OGRVRTLayer name="${LINEID}_${grididnum[$i]}_data">
        <SrcDataSource>${LINEID}_${grididnum[$i]}_data.csv</SrcDataSource>
        <GeometryType>wkbPoint</GeometryType>
        <LayerSRS>EPSG:32612</LayerSRS>
        <GeometryField encoding="PointFromColumns" x="field_1" y="field_2" z="field_3"/>
    </OGRVRTLayer>
</OGRVRTDataSource>
EOF

        dem_minx=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $1}')
        dem_maxx=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $2}')
        dem_miny=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $3}')
        dem_maxy=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $4}')
        dem_minz=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $5}')
        dem_maxz=$(gawk < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilerange.txt '{print $6}')
        # echo dem_minx $dem_minx dem_maxx $dem_maxx dem_miny $dem_miny dem_maxy $dem_maxy dem_minz $dem_minz dem_maxz $dem_maxz

        dem_xtoyratio=$(echo "($dem_maxx - $dem_minx)/($dem_maxy - $dem_miny)" | bc -l)
        dem_ztoxratio=$(echo "($dem_maxz - $dem_minz)/($dem_maxx - $dem_minx)" | bc -l)

        # Calculate zsize from xsize
        xsize=$(echo $PROFILE_WIDTH_IN | gawk '{print $1+0}')
        zsize=$(echo "$xsize * $dem_ztoxratio" | bc -l)

        numx=$(echo "($dem_maxx - $dem_minx)/$PERSPECTIVE_RES" | bc)
        numy=$(echo "($dem_maxy - $dem_miny)/$PERSPECTIVE_RES" | bc)
        # echo $numx $numy
        # echo numx $numx numy $numy

        cd ${F_PROFILES}
          gdal_grid -q -of "netCDF" -txe $dem_minx $dem_maxx -tye $dem_miny $dem_maxy -outsize $numx $numy -zfield field_3 -a nearest -l ${LINEID}_${grididnum[$i]}_data ${LINEID}_${grididnum[$i]}_data.vrt ${LINEID}_${grididnum[$i]}_newgrid.nc
        cd ..

        # From here on, only the zsize and dem_miny, dem_maxy variables are needed for plotting

        # echo "#!/bin/bash" > ${LINEID}_makeboxplot.sh
        # echo "PERSPECTIVE_AZ=\${1}" >> ${LINEID}_makeboxplot.sh
        # echo "PERSPECTIVE_INC=\${2}" >> ${LINEID}_makeboxplot.sh

        # If we are shading the dem using the gdaldem method, do so here for the top tile as well.
        # This code is copied over, could be turned into a function? Ah well. That's not the way I roll I guess.

        # Notably, any TIFF can be plotted using gridview, so this approach can be generalized...

        # ${F_CPTS}topocolor.dat will already exist at this point for all topo grids but may not if the top tile
        # is not a topo grid.

        if [[ $zerohingeflag -eq 1 ]]; then
          # We need to make a gdal color file that respects the CPT hinge value (usually 0)
          # gdaldem is a bit funny about coloring around the hinge, so do some magic to make
          # the color from land not bleed to the hinge elevation.

          # Need to rescale the Z values by multiplying by ${gridzscalelist[$i]}
          # This is because CPTS are given in source data units and not scaled units.

          gawk < $TOPO_CPT -v hinge=$CPTHINGE -v scale=${gridzscalelist[$i]} '{
            if ($1 != "B" && $1 != "F" && $1 != "N" ) {
              if (count==1) {
                print ($1+0.01)*scale, $2
                count=2
              } else {
                print $1*scale, $2
              }

              if ($3 == hinge) {
                if (count==0) {
                  print ($3-0.0001)*scale, $4
                  count=1
                }
              }
            }
          }' | tr '/' ' ' > ${F_PROFILES}topocolor_km.dat
        else
          gawk < $TOPO_CPT -v scale=${gridzscalelist[$i]} '{ print $1*scale, $2 }' | tr '/' ' ' > ${F_PROFILES}topocolor_km.dat
        fi


        if [[ $gdemtopoplotflag -eq 1 ]]; then

          # Calculate the color stretch
          gdaldem color-relief ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc ${F_PROFILES}topocolor_km.dat ${F_PROFILES}${LINEID}_${grididnum[$i]}_colordem.tif -q

          # Calculate the multidirectional hillshade
          # s factor is 1 as our DEM is in km/km/km units
          gdaldem hillshade -compute_edges -multidirectional -alt ${HS_ALT} -s 1 ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc ${F_PROFILES}${LINEID}_${grididnum[$i]}_hs_md.tif -q

          # Clip the hillshade to reduce extreme bright and extreme dark areas

          # Calculate the slope and shade the data

          # Z factor doesn't matter here as we render it out...
          gdaldem slope -compute_edges -s 111120 ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc ${F_PROFILES}${LINEID}_${grididnum[$i]}_slope.tif -q
          echo "0 255 255 255" > ${F_PROFILES}slope.txt
          echo "90 0 0 0" >> ${F_PROFILES}slope.txt
          gdaldem color-relief ${F_PROFILES}${LINEID}_${grididnum[$i]}_slope.tif ${F_PROFILES}slope.txt ${F_PROFILES}${LINEID}_${grididnum[$i]}_slopeshade.tif -q

          # gdal_calc.py --overwrite --quiet -A hs_md.tif -B slope.tif --outfile=combhssl.tif --calc="uint8( (1 - A/255. * arctan(sqrt(abs(B)/90.))*0.4)**(1/${HS_GAMMA}) * 255)"
          # cang = 1 - cang * atan(sqrt(slope)) * INV_SQUARE_OF_HALF_PI;
          # gdal_calc.py --overwrite --quiet -A hs_md.tif -B slopeshade.tif --calc="uint8( ((A/255.)*(B/255.)) * 255 )" --outfile=slope_hillshade.tif
          # if the colordem.tif band has a value of 0, this apparently messes things up badly as gdal
          # interprets that as the nodata value.

          # A hillshade is mostly gray (127) while a slope map is mostly white (255)

          # Combine the hillshade and slopeshade into a blended, gamma corrected image
          gdal_calc.py --overwrite --quiet -A ${F_PROFILES}${LINEID}_${grididnum[$i]}_hs_md.tif -B ${F_PROFILES}${LINEID}_${grididnum[$i]}_slopeshade.tif --outfile=${F_PROFILES}${LINEID}_${grididnum[$i]}_intensity.tif --calc="uint8( ( ((A/255.)*(${HSSLOPEBLEND}) + (B/255.)*(1-${HSSLOPEBLEND}) ) )**(1/${HS_GAMMA}) * 255)"

        elif [[ $tshadetopoplotflag -eq 1 ]]; then

          # echo "New approach for tshade on -mob..."
          # We are doing the texture shading version

          rm -f ${F_PROFILES}texture.flt ${F_PROFILES}out_texture.tif ${F_PROFILES}newdem.flt ${F_PROFILES}newdem.hdr

          # fill NaNs
          gmt grdfill ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc -An -G${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc ${VERBOSE}

          # Flip the grid vertically

          gmt grdedit -Ev ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc -G${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan_flip.nc ${VERBOSE}
          mv ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan_flip.nc ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc

          # Calculate the color stretch
          gdaldem color-relief ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc ${F_PROFILES}topocolor_km.dat ${F_PROFILES}${LINEID}_${grididnum[$i]}_colordem.tif -q 2>/dev/null

          # Calculate the texture shade
          # Project to HDF format
          gdal_translate -of EHdr -ot Float32 ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc ${F_PROFILES}newdem.flt -q 2>/dev/null

          # Change the ULX and ULY in the .hdr file to fool texture
          cp ${F_PROFILES}newdem.hdr ${F_PROFILES}newdem.hdr.store
          awk < ${F_PROFILES}newdem.hdr '{
            if ($1 == "ULXMAP") {
              print "ULXMAP         1000000.00000000"
            } else if ($1 == "ULYMAP") {
              print "ULYMAP         -1000000.00000000"
            } else {
              printf "%s\n", $0
            }
          }' > ${F_PROFILES}newdem.hdr.2
          mv ${F_PROFILES}newdem.hdr.2 ${F_PROFILES}newdem.hdr

          rm -f ${F_PROFILES}texture.flt ${F_PROFILES}texture.hdr

          # texture the DEM. Pipe output to /dev/null to silence the program
          ${TEXTURE} ${TS_FRAC} ${F_PROFILES}newdem.flt ${F_PROFILES}texture.flt  > /dev/null 2>&1

          # ~/Dropbox/scripts/tectoplot/texture_shader/texture 0.66 newdem.flt texture.flt
          # Change the limits for the header
          awk < ${F_PROFILES}texture.hdr '{
            if ($1== "nrows") {
              yval=$2/2
            }
            if ($1 == "xllcorner") {
              printf "xllcorner     0\n"
            } else if ($1 == "yllcorner") {
              printf "yllcorner     %f\n", (yval)
            } else {
              printf "%s\n", $0
            }
          }' > ${F_PROFILES}texture.hdr.2
          cp ${F_PROFILES}texture.hdr.2 ${F_PROFILES}texture.hdr

          # make the image. Pipe output to /dev/null to silence the program
          ${TEXTURE_IMAGE} +${TS_STRETCH} ${F_PROFILES}texture.flt ${F_PROFILES}out_texture.tif > /dev/null 2>&1

          gmt grdedit -T ${F_PROFILES}out_texture.tif -G${F_PROFILES}tt_unflipped.tif ${VERBOSE}
          gmt grdedit -Ev ${F_PROFILES}tt_unflipped.tif -G${F_PROFILES}tt.tif ${VERBOSE}

          # Change to 8 bit unsigned format
          # This also flips the tiff upside down for some reason. So pre-flip it above.
          gdal_translate -of GTiff -ot Byte -scale 0 65535 0 255 ${F_PROFILES}tt.tif ${F_PROFILES}${LINEID}_${grididnum[$i]}_texture.tif -q 2>/dev/null

          # Calculate the multidirectional hillshade
          gdaldem hillshade -compute_edges -multidirectional -alt ${HS_ALT} -s 1 ${F_PROFILES}${LINEID}_${grididnum[$i]}_dem_no_nan.nc ${F_PROFILES}${LINEID}_${grididnum[$i]}_hs_md.tif -q 2>/dev/null

          # Combine the hillshade and texture into a blended, gamma corrected image
          gdal_calc.py --overwrite --quiet -A ${F_PROFILES}${LINEID}_${grididnum[$i]}_hs_md.tif -B ${F_PROFILES}${LINEID}_${grididnum[$i]}_texture.tif --outfile=${F_PROFILES}${LINEID}_${grididnum[$i]}_intensity.tif --calc="uint8( ( ((A/255.)*(${TS_TEXTUREBLEND}) + (B/255.)*(1-${TS_TEXTUREBLEND}) ) )**(1/${TS_GAMMA}) * 255)"
        else
          gdaldem color-relief ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc ${F_PROFILES}topocolor_km.dat ${F_PROFILES}${LINEID}_${grididnum[$i]}_colordem.tif -q
          gdaldem hillshade -compute_edges -az ${THISP_HS_AZ} -alt ${HS_ALT} -s 1 ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc ${F_PROFILES}${LINEID}_${grididnum[$i]}_intensity.tif -q
        fi


        gdal_calc.py --overwrite --quiet -A ${F_PROFILES}${LINEID}_${grididnum[$i]}_intensity.tif -B ${F_PROFILES}${LINEID}_${grididnum[$i]}_colordem.tif --allBands=B --calc="uint8( ( \
                        2 * (A/255.)*(B/255.)*(A<128) + \
                        ( 1 - 2 * (1-(A/255.))*(1-(B/255.)) ) * (A>=128) \
                      ) * 255 )" --outfile=${F_PROFILES}${LINEID}_${grididnum[$i]}_colored_hillshade.tif



###     The following script fragment will require the following variables to be defined in the script:
###     PERSPECTIVE_AZ, PERSPECTIVE_INC, line_min_x, line_max_x, line_min_z, line_max_z, PROFILE_HEIGHT_IN, PROFILE_WIDTH_IN, yshift
        echo "VEXAG=\${3}" > ${LINEID}_topscript.sh
        echo "ZSIZE_PRE=${zsize}" >> ${LINEID}_topscript.sh
        echo "ZSIZE=\$(echo \"\$VEXAG * \$ZSIZE_PRE\" | bc -l)" >> ${LINEID}_topscript.sh
        echo "dem_miny=${dem_miny}" >> ${LINEID}_topscript.sh
        echo "dem_maxy=${dem_maxy}" >> ${LINEID}_topscript.sh
        echo "dem_minz=${dem_minz}" >> ${LINEID}_topscript.sh
        echo "dem_maxz=${dem_maxz}" >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_RATIO=\$(echo \"(\$dem_maxy - \$dem_miny) / (\$line_max_x - \$line_min_x)\" | bc -l)"  >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_IN=\$(echo \$PROFILE_DEPTH_RATIO \$PROFILE_WIDTH_IN | gawk '{print (\$1*(\$2+0))}' )i"  >> ${LINEID}_topscript.sh

        echo "GUESS=\$(echo \"\$PROFILE_HEIGHT_IN \$PROFILE_DEPTH_IN\" | awk '{ print (\$1+0)-(\$2+0) }')" >> ${LINEID}_topscript.sh
        echo "if [[ \$(echo \"\${PERSPECTIVE_AZ} > 180\" | bc -l) -eq 1 ]]; then" >> ${LINEID}_topscript.sh
        echo "  xshift=\$(gawk -v height=\${GUESS} -v az=\$PERSPECTIVE_AZ 'BEGIN{print cos((270-az)*3.1415926/180)*(height+0)}')"  >> ${LINEID}_topscript.sh
        echo "else" >> ${LINEID}_topscript.sh
        echo "  xshift=0" >> ${LINEID}_topscript.sh
        echo "fi" >> ${LINEID}_topscript.sh

        echo "yshift=\$(gawk -v height=\${PROFILE_HEIGHT_IN} -v inc=\$PERSPECTIVE_INC 'BEGIN{print cos(inc*3.1415926/180)*(height+0)}')" >> ${LINEID}_topscript.sh

        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_max_z} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${line_min_z}/\${line_max_z}r -JZ\${PROFILE_HEIGHT_IN} -JX\${PROFILE_WIDTH_IN}/\${PROFILE_DEPTH_IN} -Byaf+l\"${y_axis_label}\" -X\${xshift}i --MAP_FRAME_PEN=thinner,black -K -O >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # If we have an end-cap plot (e.g. litho1), plot that here.
        # Data needs to be plottable by psxyz
        # There's a weird world where we project seismicity and CMTs onto this plane.....

        if [[ $litho1profileflag -eq 1 ]]; then

cat<<-EOF >> ${LINEID}_topscript.sh
gawk < ${F_PROFILES}${LINEID}_litho1_cross_poly.dat -v xval=\$line_max_x -v zval=\$line_min_z '{
if (\$1 == ">") {
print
} else {
  if (\$2 < zval) {
    print xval, \$1, zval
  } else {
    print xval, \$1, \$2
  }
}
}' > ${F_PROFILES}${LINEID}_litho1_cross_poly_xyz.dat
EOF
          echo "gmt psxyz -p ${F_PROFILES}${LINEID}_litho1_cross_poly_xyz.dat -L -G+z -C$LITHO1_CPT -t${LITHO1_TRANS} -Vn -R -J -JZ -O -K >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        fi

        # Draw the box at the end of the profile. For other view angles, should draw the other box?

        echo "if [[ \$(echo \"\${PERSPECTIVE_AZ} > 180\" | bc -l) -eq 1 ]]; then" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_min_x \$dem_maxy \$line_max_z\" > ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_min_x \$dem_maxy \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_min_x \$dem_miny \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_min_x \$dem_miny \$line_max_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "else" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_max_x \$dem_maxy \$line_max_z\" > ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_max_x \$dem_maxy \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_max_x \$dem_miny \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
          echo "echo \"\$line_max_x \$dem_miny \$line_max_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "fi" >> ${LINEID}_topscript.sh

        echo "gmt psxyz ${F_PROFILES}${LINEID}_endbox.xyz -p -R -J -JZ -Wthinner,black -K -O >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${dem_minz} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -JZ\${ZSIZE}i -J -Bzaf -Bxaf --MAP_FRAME_PEN=thinner,black -K -O -Y\${yshift}i >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # I think this could be done with gmt makecpt -C+Uk but technical questions exist
        # This assumes topo is in m and needs to be in km... not applicable for other grids


        gawk < ${gridcptlist[$i]} -v sc=${gridzscalelist[$i]} '{ if ($1 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { print $1*sc "\t" $2 "\t" $3*sc "\t" $4} else {print}}' > ${F_PROFILES}${LINEID}_topokm.cpt

        # if [[ $gdemtopoplotflag -eq 1 || $tshadetopoplotflag -eq 1 ]]; then
          echo "gmt grdview ${F_PROFILES}${LINEID}_${grididnum[$i]}_newgrid.nc  -G${F_PROFILES}${LINEID}_${grididnum[$i]}_colored_hillshade.tif -p -Qi300 -R -J -JZ -O  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
          # echo "gmt grdview ${LINEID}_${grididnum[$i]}_newgrid.nc -G${LINEID}_${grididnum[$i]}_colored_hillshade.tif -Qi300 -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -J -JZ\${ZSIZE}i -O -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_min_z} -Y\${yshift}i >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        # else
        #   echo "gmt grdview ${LINEID}_${grididnum[$i]}_newgrid.nc -p -Qi300 -R -J -JZ -C${LINEID}_topokm.cpt -O >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        # fi
###
      fi


      # For grids that are not top grids, they are swath grids. So calculate and plot the swaths.
      if [[ ! ${istopgrid[$i]} -eq 1 ]]; then

        # profiledata.txt contains space delimited rows of data.

        # This function calculates the 0, 25, 50, 75, and 100 quartiles of the data. First strip out the NaN values which are in the data.
        cat ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledata.txt | sed 's/NaN//g' |  gawk '{
          q1=-1;
          q2=-1;
          q3=-1
          split( $0 , a, " " );

          asort( a );
          n=length(a);

          p[1] = 0;
          for (i = 2; i<=n; i++) {
            p[i] = (i-1)/(n-1);
            if (p[i] >= .25 && q1 == -1) {
              f = (p[i]-.25)/(p[i]-p[i-1]);
              q1 = a[i-1]*(f)+a[i]*(1-f);
            }
            if (p[i] >= .5 && q2 == -1) {
              f = (p[i]-.5)/(p[i]-p[i-1]);
              q2 = a[i-1]*(f)+a[i]*(1-f);
            }
            if (p[i] >= .75 && q3 == -1) {
              f = (p[i]-.75)/(p[i]-p[i-1]);
              q3 = a[i-1]*(f)+a[i]*(1-f);
            }
          }
          printf("%g %g %g %g %g\n", a[1], q1, q2, q3, a[n])
        }' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary_pre.txt

        # Find the value of Z at X=0 and subtract it from the entire dataset
        if [[ $ZOFFSETflag -eq 1 && $dozflag -eq 1 ]]; then
          # echo ZOFFSETflag is set
          XZEROINDEX=$(gawk < ${F_PROFILES}profilekm.txt '{if ($1 > 0) { exit } } END {print NR}')
          ZOFFSET_NUM=$(head -n $XZEROINDEX ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary_pre.txt | tail -n 1 | gawk '{print 0-$3}')
        fi

        cat ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary_pre.txt | gawk -v zoff="${ZOFFSET_NUM}" '{print $1+zoff, $2+zoff, $3+zoff, $4+zoff, $5+zoff}' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary.txt

        # profilesummary.txt is min q1 q2 q3 max
        #           1  2   3  4  5   6
        # gmt wants X q2 min q1 q3 max

        paste ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilekm.txt ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary.txt | tr '\t' ' ' | gawk '{print $1, $4, $2, $3, $5, $6}' > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt

        gawk '{print $1, $2}' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamedian.txt
        gawk '{print $1, $3}' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamin.txt
        gawk '{print $1, $6}' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamax.txt

        # Makes an envelope plottable by GMT
        gawk '{print $1, $4}' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledataq13min.txt
        gawk '{print $1, $5}' < ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledataq13max.txt

        cat ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamax.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileenvelope.txt
        tac ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamin.txt >> ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileenvelope.txt

        cat ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledataq13min.txt > ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileq13envelope.txt
        tac ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledataq13max.txt >> ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileq13envelope.txt

        # PLOT ON THE MAP PS
        echo "gmt psxy -Vn ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> "${PSFILE}"" >> plot.sh
        echo "gmt psxy -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> "${PSFILE}"" >> plot.sh
        echo "gmt psxy -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> "${PSFILE}"" >> plot.sh

        # PLOT ON THE FLAT PROFILE PS
        echo "gmt psxy -Vn ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt psxy -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt psxy -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${F_PROFILES}${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${F_PROFILES}${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh

        # ## Output data files to THIS_DIR (why???)
        # echo "km_along_profile q0 q25 q25 q75 q100" > $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt
        # paste ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilekm.txt ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary.txt >> $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt

        paste ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilekm.txt ${F_PROFILES}${LINEID}_${grididnum[$i]}_profilesummary.txt >> ${F_PROFILES}${LINEID}_all_data.txt
      fi
    done  # for each grid

    echo -n "@;${COLOR};${LINEID}@;; " >> ${F_PROFILES}IDfile.txt
    if [[ $xoffsetflag -eq 1 && $ZOFFSETflag -eq 1 ]]; then
      printf "@:8: (%+.02g km/%+.02g) @::" $XOFFSET_NUM $ZOFFSET_NUM >> ${F_PROFILES}IDfile.txt
      echo -n " " >> ${F_PROFILES}IDfile.txt
    elif [[ $xoffsetflag -eq 1 && $ZOFFSETflag -eq 0 ]]; then
      printf "@:8: (%+.02g km (X)) @::" $XOFFSET_NUM >> ${F_PROFILES}IDfile.txt
      echo -n " " >> ${F_PROFILES}IDfile.txt
    elif [[ $xoffsetflag -eq 0 && $ZOFFSETflag -eq 1 ]]; then
      printf "@:8: (%+.02g km (Z)) @::" $ZOFFSET_NUM >> ${F_PROFILES}IDfile.txt
      echo -n " " >> ${F_PROFILES}IDfile.txt
    fi

    ############################################################################
    # Now treat the XYZ data. Make sure to append data to ${LINEID}_all_data.txt
    # in the form km_along_profile val val val val val
    #
    # gmt sample1d  ${LINEID}_trackfile.txt -T10e -Ar >  ${LINEID}_track_distance_pts.txt

    # currently breaks for files without exactly 3 data columns.
    # mapproject has a nasty habit of outputting the EQ id field AFTER the projected points.

    for i in ${!xyzfilelist[@]}; do
      # echo ${xyzfilelist[i]}
      # echo ${xyzcommandlist[i]}
      FNAME=$(echo -n "${LINEID}_"$i"projdist.txt")
      # echo FNAME is $FNAME
      #
      # echo "Using cull file with lines"
      # wc -l < ${xyzcullfile[i]}
      #
      # echo "wc -l < ${xyzcullfile[i]}"
      # echo "wc -l < ${xyzcullfile[$i]}"

      # Calculate distance from data points to the track, using only first two columns
      gawk < ${xyzfilelist[i]} '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}${LINEID}_trackfile.txt -fg -Vn | gawk '{print $3, $4, $5}' > ${F_PROFILES}tmp.txt
      gawk < ${xyzfilelist[i]} '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}line_buffer.txt+p -fg -Vn | gawk '{print $4}'> ${F_PROFILES}tmpbuf.txt
      # Paste result onto input lines and select the points that are closest to current track out of all tracks
      paste ${F_PROFILES}tmpbuf.txt ${xyzfilelist[i]} ${F_PROFILES}tmp.txt  > ${F_PROFILES}joinbuf.txt
#      head joinbuf.txt
#      echo PROFILE_INUM=$PROFILE_INUM
      cat ${F_PROFILES}joinbuf.txt | gawk -v lineid=$PROFILE_INUM '{
        if ($1==lineid) {
          for (i=2;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > ${F_PROFILES}$FNAME

      # output is lon lat ... fields ... dist_to_track lon_at_track lat_at_track

      # Calculate distance from data points to any profile line, using only first two columns, then paste onto input file.

      pointsX=$(head -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $1}')
      pointsY=$(head -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $2}')
      pointeX=$(tail -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $1}')
      pointeY=$(tail -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $2}')

      # Exclude points that project onto the endpoints of the track, or are too far away. Distances are in meters in FNAME
      # echo "$pointsX $pointsY / $pointeX $pointeY"
      # rm -f ./cull.dat

      cat ${F_PROFILES}$FNAME | gawk -v x1=$pointsX -v y1=$pointsY -v x2=$pointeX -v y2=$pointeY -v w=${xyzwidthlist[i]} '{
        if (($(NF-1) == x1 && $(NF) == y1) || ($(NF-1) == x2 && $(NF) == y2) || $(NF-2) > (w+0)*1000) {
          # Nothing. My gawk skills are poor.
          printf "%s %s", $(NF-1), $(NF) >> "./cull.dat"
          for (i=3; i < (NF-2); i++) {
            printf " %s ", $(i) >> "./cull.dat"
          }
          printf("\n") >> "./cull.dat"
        } else {
          printf "%s %s", $(NF-1), $(NF)
          for (i=3; i < (NF-2); i++) {
            printf " %s ", $(i)
          }
          printf("\n")
        }
      }' > ${F_PROFILES}projpts_${FNAME}
      cleanup cull.dat

      # echo tally
      # wc -l ./cull.dat
      # wc -l projpts_${FNAME}
      # echo endtally
      #
      # mv ./cull.dat ${xyzcullfile[i]}

      # This is where we can filter points based on whether they exist in previous profiles

      # Calculate along-track distances for points with distance less than the cutoff
      # echo XYZwidth to trim is ${xyzwidthlist[i]}
      # gawk < trimmed_${FNAME} -v w=${xyzwidthlist[i]} '($4 < (w+0)*1000) {print $5, $6, $3}' > projpts_${FNAME}

      # Replaces lon lat with lon_at_track lat_at_track

      # Default sampling distance is 10 meters, hardcoded. Would cause trouble for
      # very long or short lines. Should use some logic to set this value?

      # To ensure the profile path is perfect, we have to add the points on the profile back, and then remove them later
      NUMFIELDS=$(head -n 1 ${F_PROFILES}projpts_${FNAME} | gawk '{print NF}')

      gawk < ${F_PROFILES}${LINEID}_trackfile.txt -v fnum=$NUMFIELDS '{
        printf "%s %s REMOVEME", $1, $2
        for(i=3; i<fnum; i++) {
          printf " 0"
        }
        printf("\n")
      }' >> ${F_PROFILES}projpts_${FNAME}

      # This gets the points into a general along-track order by calculating their true distance from the starting point
      # Tracks that loop back toward the first point might fail (but who would do that anyway...)

      gawk < ${F_PROFILES}projpts_${FNAME} '{print $1, $2}' | gmt mapproject -G$pointsX/$pointsY+uk -Vn | gawk '{print $3}' > ${F_PROFILES}tmp.txt
      paste ${F_PROFILES}projpts_${FNAME} ${F_PROFILES}tmp.txt > ${F_PROFILES}tmp2.txt
      NUMFIELDS=$(head -n 1 ${F_PROFILES}tmp2.txt | gawk '{print NF}')
      sort -n -k $NUMFIELDS < ${F_PROFILES}tmp2.txt > ${F_PROFILES}presort_${FNAME}

      # Calculate true distances along the track line. "REMOVEME" is output as "NaN" by GMT.
      gawk < ${F_PROFILES}presort_${FNAME} '{print $1, $2}' | gmt mapproject -G+uk -Vn | gawk '{print $3}' > ${F_PROFILES}${FNAME}_tmp.txt

      # NF is the true distance along profile that needs to be the X coordinate, modified by XOFFSET_NUM
      # NF-1 is the distance from the zero point and should be discarded
      # $3 is the Z value that needs to be modified by zscale and ZOFFSET_NUM

      paste ${F_PROFILES}presort_${FNAME} ${F_PROFILES}${FNAME}_tmp.txt | gawk -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM -v zscale=${xyzunitlist[i]} '{
        if ($3 != "REMOVEME") {
          printf "%s %s %s", $(NF)+xoff, ($3)*zscale+zoff, (($3)*zscale+zoff)/(zscale)
          if (NF>=4) {
            for(i=4; i<NF-1; i++) {
              printf " %s", $(i)
            }
          }
          printf("\n")
        }
      }' > ${F_PROFILES}finaldist_${FNAME}

      gawk < ${F_PROFILES}finaldist_${FNAME} '{print $1, $2, $2, $2, $2, $2 }' >> ${F_PROFILES}${LINEID}_all_data.txt

      ##########################################################################
      # Plot earthquake data scaled by magnitude

      if [[ ${xyzscaleeqsflag[i]} -eq 1 ]]; then

        if  [[ $REMOVE_DEFAULTDEPTHS -eq 1 ]]; then
          # Plotting in km instead of in map geographic coords
          gawk < ${F_PROFILES}finaldist_${FNAME} -v defdepmag=${REMOVE_DEFAULTDEPTHS_MAXMAG} '{
            if ($4 <= defdepmag) {
              if ($3 == 10 || $3 == 33 || $3 == 5 ||$3 == 1 || $3 == 6  || $3 == 35 ) {
                seen[$3]++
              } else {
                print
              }
            } else {
              print
            }
          }
          END {
            for (key in seen) {
              printf "%s (%s)\n", key, seen[key] >> "/dev/stderr"
            }
          }' > ${F_PROFILES}tmp.dat 2>${F_PROFILES}removed.dat
          mv ${F_PROFILES}tmp.dat ${F_PROFILES}finaldist_${FNAME}
        fi

        # PLOT ON THE MAP PS
        gawk < ${F_PROFILES}finaldist_${FNAME} -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1))}' > ${F_PROFILES}stretch_finaldist_${FNAME}
        echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT p" >> plot.sh
        echo "gmt psxy ${F_PROFILES}stretch_finaldist_${FNAME} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${PSFILE}" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> plot.sh

        # PLOT ON THE FLAT PROFILE PS
        echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> ${LINEID}_temp_plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT p"  >> ${LINEID}_temp_plot.sh
        echo "gmt psxy ${F_PROFILES}stretch_finaldist_${FNAME} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE}  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE SECTION PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT p" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy ${F_PROFILES}stretch_finaldist_${FNAME} -p -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> ${LINEID}_plot.sh

      else
        # PLOT ON THE MAP PS
        echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> "${PSFILE}"" >> plot.sh

        # PLOT ON THE FLAT SECTION PS
        echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE SECTION PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -p -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi

      rm -f presort_${FNAME}
    done # XYZ data

    ############################################################################
    # Plot CMT data scaled by magnitude using pscoupe

    if [[ $cmtfileflag -eq 1 ]]; then

      # Select CMT events that are closest to this line vs other profile lines in the project
      # Forms cmt_thrust_sel.txt cmt_normal_sel.txt cmt_strikeslip_sel.txt

      # This command outputs to tmpbuf.txt the ID of the line that each CMT mechanism is closest to. Then if that matches
      # the current line, we output it to the current profile. What happens if the alternative point is closer to a different profile?

      # Houston, we have a problem. This isn't actually selecting only the CMTs within the buffer of the profile; it is selecting all within
      # the rectangular AOI of the buffered region!

      # CMTWIDTH is e.g. 150k so in gawk we do +0

      gawk < ${F_CMT}cmt_thrust.txt '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}line_buffer.txt+p -fg -Vn | gawk '{print $4, $3}' > ${F_PROFILES}tmpbuf.txt
      paste ${F_PROFILES}tmpbuf.txt ${F_CMT}cmt_thrust.txt | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > ${F_PROFILES}cmt_thrust_sel.txt

      if [[ -e ${F_PROFILES}cmt_alt_pts_thrust.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt cmt_alt_pts_thrust.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel.xyz
      fi

      # cmt_alt_lines comes in the format >:lat1 lon1 z1:lat2 lon2 z2\n
      # Split into two XYZ files, project each file separately, and then merge to plot.
      if [[ -e ${F_PROFILES}cmt_alt_lines_thrust.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt ${F_PROFILES}cmt_alt_lines_thrust.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${F_PROFILES}tmp.txt
        gawk < ${F_PROFILES}tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv split1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz
        mv split2.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P2.xyz
      fi

      gawk < ${F_CMT}cmt_normal.txt '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}line_buffer.txt+p -fg -Vn | gawk '{print $4, $3}' > ${F_PROFILES}tmpbuf.txt
      paste ${F_PROFILES}tmpbuf.txt ${F_CMT}cmt_normal.txt | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > ${F_PROFILES}cmt_normal_sel.txt

      if [[ -e ${F_PROFILES}cmt_alt_pts_normal.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt ${F_PROFILES}cmt_alt_pts_normal.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
      }' > ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel.xyz
      fi

      if [[ -e ${F_PROFILES}cmt_alt_lines_normal.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt ${F_PROFILES}cmt_alt_lines_normal.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${F_PROFILES}tmp.txt
        gawk < ${F_PROFILES}tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv ./split1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P1.xyz
        mv ./split2.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P2.xyz
      fi

      gawk < ${F_CMT}cmt_strikeslip.txt '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}line_buffer.txt+p -fg -Vn | gawk '{print $4, $3}' > ${F_PROFILES}tmpbuf.txt
      paste ${F_PROFILES}tmpbuf.txt ${F_CMT}cmt_strikeslip.txt | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > ${F_PROFILES}cmt_strikeslip_sel.txt

      if [[ -e ${F_PROFILES}cmt_alt_pts_strikeslip.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt ${F_PROFILES}cmt_alt_pts_strikeslip.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel.xyz
      fi

      if [[ -e ${F_PROFILES}cmt_alt_lines_strikeslip.xyz ]]; then
        paste ${F_PROFILES}tmpbuf.txt ${F_PROFILES}cmt_alt_lines_strikeslip.xyz | gawk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${F_PROFILES}tmp.txt
        gawk < ${F_PROFILES}tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv split1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz
        mv split2.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P2.xyz
      fi
      ##### Now we need to project the alt_pts and alt_lines onto the profile.
      #####
      #####

      # project_xyz_pts_onto_track $trackfile $xyzfile $outputfile $xoffset $zoffset $zscale


      [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel.xyz ]] && project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel.xyz ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
      [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel.xyz ]] && project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel.xyz ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
      [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel.xyz ]] && project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel.xyz ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE

      if [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz ]]; then
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P2.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        gawk < ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > ${F_PROFILES}tmp1.txt
        paste -d '\0' ${F_PROFILES}tmp1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_sel_P2_proj.xyz | tr ':' '\n' > ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz
      fi

      if [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P1.xyz ]]; then
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P1.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P2.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        gawk < ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > ${F_PROFILES}tmp1.txt
        paste -d '\0' ${F_PROFILES}tmp1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_sel_P2_proj.xyz | tr ':' '\n' > ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz
      fi

      if [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz ]]; then
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        project_xyz_pts_onto_track ${F_PROFILES}${LINEID}_trackfile.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P2.xyz ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        gawk < ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > ${F_PROFILES}tmp1.txt
        paste -d '\0' ${F_PROFILES}tmp1.txt ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_sel_P2_proj.xyz | tr ':' '\n' > ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz
      fi

      # For each line segment in the potentially multipoint profile, we need to
      # project the CMTs orthogonally onto the segment using pscoupe

      numprofpts=$(cat ${F_PROFILES}${LINEID}_trackfile.txt | wc -l)
      numsegs=$(echo "$numprofpts - 1" | bc -l)

      cur_x=0
      for segind in $(seq 1 $numsegs); do
        segind_p=$(echo "$segind + 1" | bc -l)
        p1_x=$(cat ${F_PROFILES}${LINEID}_trackfile.txt | head -n ${segind} | tail -n 1 | gawk '{print $1}')
        p1_z=$(cat ${F_PROFILES}${LINEID}_trackfile.txt | head -n ${segind} | tail -n 1 | gawk '{print $2}')
        p2_x=$(cat ${F_PROFILES}${LINEID}_trackfile.txt | head -n ${segind_p} | tail -n 1 | gawk '{print $1}')
        p2_z=$(cat ${F_PROFILES}${LINEID}_trackfile.txt | head -n ${segind_p} | tail -n 1 | gawk '{print $2}')
        add_x=$(cat ${F_PROFILES}${LINEID}_dist_km.txt | head -n $segind_p | tail -n 1)

        cat ${F_PROFILES}cmt_thrust_sel.txt | gawk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null

        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | gawk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${F_PROFILES}${LINEID}_cmt_thrust_profile_data.txt
          gawk <  ${F_PROFILES}${LINEID}_cmt_thrust_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${F_PROFILES}${LINEID}_all_data.txt
        done
        rm -f Aa*

        cat ${F_PROFILES}cmt_normal_sel.txt | gawk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null
        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | gawk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${F_PROFILES}${LINEID}_cmt_normal_profile_data.txt
          gawk <  ${F_PROFILES}${LINEID}_cmt_normal_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${F_PROFILES}${LINEID}_all_data.txt
        done
        rm -f Aa*

        cat ${F_PROFILES}cmt_strikeslip_sel.txt | gawk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null
        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | gawk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${F_PROFILES}${LINEID}_cmt_strikeslip_profile_data.txt
          gawk <  ${F_PROFILES}${LINEID}_cmt_strikeslip_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${F_PROFILES}${LINEID}_all_data.txt
        done

        rm -f Aa*

        if [[ ! $segind -eq $numsegs ]]; then
          add_x=$(cat ${F_PROFILES}${LINEID}_dist_km.txt | head -n $segind_p | tail -n 1)
          # echo -n "new cur_x = $cur_x + $add_x"
          cur_x=$(echo "$cur_x + $add_x" | bc -l)
          # echo " = $cur_x"
        fi
      done

      # Generate the plotting commands for the shell script

      if [[ $cmtthrustflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_THRUSTCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_THRUSTCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${F_PROFILES}${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_THRUSTCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
      if [[ $cmtnormalflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_NORMALCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz -W0.1p,black $RJOK $VERBOSE >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_NORMALCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_normal_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${F_PROFILES}${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_NORMALCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
      if [[ $cmtssflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_SSCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${F_PROFILES}${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_SSCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${F_PROFILES}${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${F_PROFILES}${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_SSCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
    fi


        ############################################################################
        # Now treat the labels.
        # Label files are in the format:
        # lon lat depth mag timecode ID epoch font justification
        # -70.3007 -33.2867 108.72 4.1 2021-02-19T11:49:05 us6000diw5 1613706545 10p,Helvetica,black TL

        for i in ${!labelfilelist[@]}; do
          FNAME=$(echo -n "${LINEID}_"$i"projdist.txt")

          # Calculate distance from data points to the track, using only first two columns
          gawk < ${labelfilelist[i]} '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}${LINEID}_trackfile.txt -fg -Vn | gawk '{print $3, $4, $5}' > ${F_PROFILES}tmp.txt
          gawk < ${labelfilelist[i]} '{print $1, $2}' | gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -L${F_PROFILES}line_buffer.txt+p -fg -Vn | gawk '{print $4}'> ${F_PROFILES}tmpbuf.txt
          # Paste result onto input lines and select the points that are closest to current track out of all tracks
          paste ${F_PROFILES}tmpbuf.txt ${labelfilelist[i]} ${F_PROFILES}tmp.txt  > ${F_PROFILES}joinbuf.txt
      #      head joinbuf.txt
      #      echo PROFILE_INUM=$PROFILE_INUM
          cat ${F_PROFILES}joinbuf.txt | gawk -v lineid=$PROFILE_INUM '{
            if ($1==lineid) {
              for (i=2;i<=NF;++i) {
                printf "%s ", $(i)
              }
              printf("\n")
            }
          }' > ${F_PROFILES}$FNAME

          # output is lon lat ... fields ... dist_to_track lon_at_track lat_at_track

          # Calculate distance from data points to any profile line, using only first two columns, then paste onto input file.

          pointsX=$(head -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $1}')
          pointsY=$(head -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $2}')
          pointeX=$(tail -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $1}')
          pointeY=$(tail -n 1 ${F_PROFILES}${LINEID}_trackfile.txt | gawk '{print $2}')

          # Exclude points that project onto the endpoints of the track, or are too far away. Distances are in meters in FNAME
          # echo "$pointsX $pointsY / $pointeX $pointeY"
          # rm -f ./cull.dat

          cat ${F_PROFILES}$FNAME | gawk -v x1=$pointsX -v y1=$pointsY -v x2=$pointeX -v y2=$pointeY -v w=${labelwidthlist[i]} '{
            if (($(NF-1) == x1 && $(NF) == y1) || ($(NF-1) == x2 && $(NF) == y2) || $(NF-2) > (w+0)*1000) {
              # Nothing. My gawk skills are poor.
              printf "%s %s", $(NF-1), $(NF) >> "./cull.dat"
              for (i=3; i < (NF-2); i++) {
                printf " %s ", $(i) >> "./cull.dat"
              }
              printf("\n") >> "./cull.dat"
            } else {
              printf "%s %s", $(NF-1), $(NF)
              for (i=3; i < (NF-2); i++) {
                printf " %s ", $(i)
              }
              printf("\n")
            }
          }' > ${F_PROFILES}projpts_${FNAME}
          cleanup cull.dat

          # echo tally
          # wc -l ./cull.dat
          # wc -l projpts_${FNAME}
          # echo endtally
          #
          # mv ./cull.dat ${labelcullfile[i]}

          # This is where we can filter points based on whether they exist in previous profiles

          # Calculate along-track distances for points with distance less than the cutoff
          # echo XYZwidth to trim is ${labelwidthlist[i]}
          # gawk < trimmed_${FNAME} -v w=${labelwidthlist[i]} '($4 < (w+0)*1000) {print $5, $6, $3}' > projpts_${FNAME}

          # Replaces lon lat with lon_at_track lat_at_track

          # Default sampling distance is 10 meters, hardcoded. Would cause trouble for
          # very long or short lines. Should use some logic to set this value?

          # To ensure the profile path is perfect, we have to add the points on the profile back, and then remove them later
          NUMFIELDS=$(head -n 1 ${F_PROFILES}projpts_${FNAME} | gawk '{print NF}')

          gawk < ${F_PROFILES}${LINEID}_trackfile.txt -v fnum=$NUMFIELDS '{
            printf "%s %s REMOVEME", $1, $2
            for(i=3; i<fnum; i++) {
              printf " 0"
            }
            printf("\n")
          }' >> ${F_PROFILES}projpts_${FNAME}

          # This gets the points into a general along-track order by calculating their true distance from the starting point
          # Tracks that loop back toward the first point might fail (but who would do that anyway...)

          gawk < ${F_PROFILES}projpts_${FNAME} '{print $1, $2}' | gmt mapproject -G$pointsX/$pointsY+uk -Vn | gawk '{print $3}' > ${F_PROFILES}tmp.txt
          paste ${F_PROFILES}projpts_${FNAME} ${F_PROFILES}tmp.txt > ${F_PROFILES}tmp2.txt
          NUMFIELDS=$(head -n 1 ${F_PROFILES}tmp2.txt | gawk '{print NF}')
          sort -n -k $NUMFIELDS < ${F_PROFILES}tmp2.txt > ${F_PROFILES}presort_${FNAME}

          # Calculate true distances along the track line. "REMOVEME" is output as "NaN" by GMT.
          gawk < ${F_PROFILES}presort_${FNAME} '{print $1, $2}' | gmt mapproject -G+uk -Vn | gawk '{print $3}' > ${F_PROFILES}tmp.txt

          # NF is the true distance along profile that needs to be the X coordinate, modified by XOFFSET_NUM
          # NF-1 is the distance from the zero point and should be discarded
          # $3 is the Z value that needs to be modified by zscale and ZOFFSET_NUM

          paste ${F_PROFILES}presort_${FNAME} ${F_PROFILES}tmp.txt | gawk -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM -v zscale=${labelunitlist[i]} '{
            if ($3 != "REMOVEME") {
              printf "%s %s %s", $(NF)+xoff, ($3)*zscale+zoff, (($3)*zscale+zoff)/(zscale)
              if (NF>=4) {
                for(i=4; i<NF-1; i++) {
                  printf " %s", $(i)
                }
              }
              printf("\n")
            }
          }' > ${F_PROFILES}finaldist_${FNAME}

          # 297.8 108.72 108.72 4.1 2021-02-19T11:49:05 us6000diw5 1613706545 10p,Helvetica,black TL

          [[ $EQ_LABELFORMAT == "idmag"    ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, 0-$2, $8, 0, $9, $6, $4  }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "datemag"  ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, 0-$2, $8, 0, $9, tmp[1], $4 }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "dateid"   ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, 0-$2, $8, 0, $9, tmp[1], $6 }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "id"       ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, 0-$2, $8, 0, $9, $6  }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "date"     ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, 0-$2, $8, 0, $9, tmp[1] }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "year"     ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, 0-$2, $8, 0, $9, tmp2[1] }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "yearmag"  ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, 0-$2, $8, 0, $9, tmp2[1], $4 }' >> ${F_PROFILES}labels_${FNAME}
          [[ $EQ_LABELFORMAT == "mag"      ]] && gawk  < ${F_PROFILES}finaldist_${FNAME} '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n", $1, 0-$2, $8, 0, $9, $4  }' >> ${F_PROFILES}labels_${FNAME}

          # PLOT ON THE MAP PS
          echo "uniq -u ${F_PROFILES}labels_${FNAME} | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite  -F+f+a+j -W0.5p,black -R -J -O -K -Vn >> "${PSFILE}"" >> plot.sh
          # echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> "${PSFILE}"" >> plot.sh

          # PLOT ON THE FLAT SECTION PS
          echo "uniq -u ${F_PROFILES}labels_${FNAME} | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite  -F+f+a+j -W0.5p,black -R -J -O -K -Vn>> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

          # echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

          # PLOT ON THE OBLIQUE SECTION PS
          [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "uniq -u ${F_PROFILES}labels_${FNAME} | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -p -Gwhite  -F+f+a+j -W0.5p,black -R -J -O -K -Vn >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
          # [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy ${F_PROFILES}finaldist_${FNAME} -p -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh

          rm -f presort_${FNAME}
        done # LABELS


    # Plot the locations of profile points above the profile, adjusting for XOFFSET and summing the incremental distance if necessary.
    # ON THE MAP
    echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${PSFILE}" >> plot.sh
    echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${PSFILE}" >> plot.sh

    # ON THE FLAT PROFILES
    echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
    echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR}>> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

    # ON THE OBLIQUE PLOTS
    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -p -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh
    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gawk < ${F_PROFILES}xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -p -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot.sh

    if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then
      gawk < ${F_PROFILES}${LINEID}_all_data.txt '{
          if ($1 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { km[++c]=$1; }
          if ($2 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { val[++d]=$2; }
          if ($6 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { val[++d]=$6; }
        } END {
          asort(km);
          asort(val);
          print km[1], km[length(km)], val[1], val[length(val)]
        #  print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
      }' > ${F_PROFILES}${LINEID}_limits.txt

      if [[ $xminflag -eq 1 ]]; then
        line_min_x=$(gawk < ${F_PROFILES}${LINEID}_limits.txt '{print $1}')
      else
        line_min_x=$min_x
      fi
      if [[ $xmaxflag -eq 1 ]]; then
        line_max_x=$(gawk < ${F_PROFILES}${LINEID}_limits.txt '{print $2}')
      else
        line_max_x=$max_x
      fi
      if [[ $zminflag -eq 1 ]]; then
        line_min_z=$(gawk < ${F_PROFILES}${LINEID}_limits.txt '{print $3}')
      else
        line_min_z=$min_z
      fi
      if [[ $zmaxflag -eq 1 ]]; then
        line_max_z=$(gawk < ${F_PROFILES}${LINEID}_limits.txt '{print $4}')
      else
        line_max_z=$max_z
      fi

      # Set minz to ensure that H=W
      if [[ $profileonetooneflag -eq 1 ]]; then
        info_msg "(-mob) Setting vertical aspect ratio to H=W for profile ${LINEID}"
        line_diffx=$(echo "$line_max_x - $line_min_x" | bc -l)
        line_hwratio=$(gawk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
        line_diffz=$(echo "$line_hwratio * $line_diffx" | bc -l)
        line_min_z=$(echo "$line_max_z - $line_diffz" | bc -l)
        info_msg "Profile ${LINEID} new min_z is $line_min_z"

        # Buffer with equal width based on Z range
        if [[ $BUFFER_PROFILES -eq 1 ]]; then
          zrange_buf=$(echo "($line_max_z - $line_min_z) * ($BUFFER_WIDTH_FACTOR)" | bc -l)
          line_max_x=$(echo "$line_max_x + $zrange_buf" | bc -l)
          line_min_x=$(echo "$line_min_x - $zrange_buf" | bc -l)
          line_max_z=$(echo "$line_max_z + $zrange_buf" | bc -l)
          line_min_z=$(echo "$line_min_z - $zrange_buf" | bc -l)
        fi
        info_msg "After buffering, range is $line_min_x $line_max_x $line_min_z $line_max_z"
      else
        # Buffer X and Z ranges separately
        if [[ $BUFFER_PROFILES -eq 1 ]]; then
          xrange_buf=$(echo "($line_max_x - $line_min_x) * ($BUFFER_WIDTH_FACTOR)" | bc -l)
          line_max_x=$(echo "$line_max_x + $xrange_buf" | bc -l)
          line_min_x=$(echo "$line_min_x - $xrange_buf" | bc -l)
          zrange_buf=$(echo "($line_max_z - $line_min_z) * ($BUFFER_WIDTH_FACTOR)" | bc -l)
          line_max_z=$(echo "$line_max_z + $zrange_buf" | bc -l)
          line_min_z=$(echo "$line_min_z - $zrange_buf" | bc -l)
        fi
      fi

      # Create the data files that will be used to plot the profile vertex points above the profile

      # for distfile in *_dist_km.txt; do
      #   gawk < $distfile -v maxz=$max_z -v minz=$min_z -v profheight=${PROFILE_HEIGHT_IN} '{
      #     print $1, (maxz+minz)/2
      #   }' > xpts_$distfile
      # done

      # maxzval=$(gawk -v maxz=$max_z -v minz=$min_z 'BEGIN {print (maxz+minz)/2}')

      # echo "echo \"0 $maxzval\" | gmt psxy -J -R -K -O -St0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.7p,black -Gwhite >> ${PSFILE}" >> plot.sh

      LINETEXT=$(echo $LINEID)
      # echo LINETEXT is "${LINETEXT}"
      ###     PERSPECTIVE_AZ, PERSPECTIVE_INC, line_min_x, line_max_x, line_min_z, line_max_z, PROFILE_HEIGHT_IN, PROFILE_WIDTH_IN, yshift

      # Plot the frame. This sets -R and -J for the actual plotting script commands in plot.sh
      echo "#!/bin/bash" > ${LINEID}_plot_start.sh
      echo "PERSPECTIVE_AZ=\${1}" >> ${LINEID}_plot_start.sh
      echo "PERSPECTIVE_INC=\${2}" >> ${LINEID}_plot_start.sh
      echo "line_min_x=${PROFILE_XMIN}" >> ${LINEID}_plot_start.sh
      echo "line_max_x=${PROFILE_XMAX}" >> ${LINEID}_plot_start.sh
      echo "line_min_z=${line_min_z}" >> ${LINEID}_plot_start.sh
      echo "line_max_z=${line_max_z}" >> ${LINEID}_plot_start.sh
      echo "PROFILE_HEIGHT_IN=${PROFILE_HEIGHT_IN}" >> ${LINEID}_plot_start.sh
      echo "PROFILE_WIDTH_IN=${PROFILE_WIDTH_IN}" >> ${LINEID}_plot_start.sh


      echo "GUESS=\$(echo \"\$PROFILE_HEIGHT_IN \$PROFILE_WIDTH_IN\" | awk '{ print 2.5414*(\$1+0) -0.5414*(\$2+0) - 0.0000  }')" >> ${LINEID}_plot_start.sh
      echo "if [[ \$(echo \"\${PERSPECTIVE_AZ} > 180\" | bc -l) -eq 1 ]]; then" >> ${LINEID}_plot_start.sh
        echo "xshift=\$(gawk -v height=\${GUESS} -v az=\$PERSPECTIVE_AZ 'BEGIN{print cos((270-az)*3.1415926/180)*(height+0)}')" >> ${LINEID}_plot_start.sh
      echo "else" >> ${LINEID}_plot_start.sh
        echo "xshift=0" >> ${LINEID}_plot_start.sh
      echo "fi" >> ${LINEID}_plot_start.sh

      echo "gmt psbasemap -py\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -JX\${PROFILE_WIDTH_IN}/\${PROFILE_HEIGHT_IN} -Bxaf+l\"${x_axis_label}\" -Byaf+l\"${z_axis_label}\" -BSEW -R\$line_min_x/\$line_max_x/\$line_min_z/\$line_max_z --MAP_FRAME_PEN=thinner,black -K > ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_plot_start.sh

      # Concatenate the cross section plotting commands onto the script
      cat ${LINEID}_plot.sh >> ${LINEID}_plot_start.sh
      cleanup ${LINEID}_plot.sh

      # Concatenate the terrain plotting commands onto the script.
      # If there is no top tile, we need to create some commands to allow a plot to be made correctly.

      if [[ -e ${LINEID}_topscript.sh ]]; then
        cat ${LINEID}_topscript.sh >> ${LINEID}_plot_start.sh
        cleanup ${LINEID}_topscript.sh
      else
        # COMEBACK
        echo "VEXAG=\${3}" > ${LINEID}_topscript.sh
        echo "dem_miny=-${MAXWIDTH_KM}" >> ${LINEID}_topscript.sh
        echo "dem_maxy=${MAXWIDTH_KM}" >> ${LINEID}_topscript.sh
        echo "dem_minz=10" >> ${LINEID}_topscript.sh
        echo "dem_maxz=-10" >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_RATIO=1" >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_IN=\$(echo \$PROFILE_DEPTH_RATIO \$PROFILE_HEIGHT_IN | gawk '{print (\$1*(\$2+0))}' )i"  >> ${LINEID}_topscript.sh

        echo "GUESS=\$(echo \"\$PROFILE_HEIGHT_IN \$PROFILE_DEPTH_IN\" | awk '{ print (\$1+0)-(\$2+0) }')" >> ${LINEID}_topscript.sh
        echo "if [[ \$(echo \"\${PERSPECTIVE_AZ} > 180\" | bc -l) -eq 1 ]]; then" >> ${LINEID}_topscript.sh
        echo "  xshift=\$(gawk -v height=\${GUESS} -v az=\$PERSPECTIVE_AZ 'BEGIN{print cos((270-az)*3.1415926/180)*(height+0)}')"  >> ${LINEID}_topscript.sh
        echo "else" >> ${LINEID}_topscript.sh
        echo "  xshift=0" >> ${LINEID}_topscript.sh
        echo "fi" >> ${LINEID}_topscript.sh

        echo "yshift=\$(gawk -v height=\${PROFILE_HEIGHT_IN} -v inc=\$PERSPECTIVE_INC 'BEGIN{print cos(inc*3.1415926/180)*(height+0)}')" >> ${LINEID}_topscript.sh
        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_max_z} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${line_min_z}/\${line_max_z}r -JZ\${PROFILE_HEIGHT_IN} -JX\${PROFILE_WIDTH_IN}/\${PROFILE_DEPTH_IN} -Byaf+l\"${y_axis_label}\" -X\${xshift}i --MAP_FRAME_PEN=thinner,black -K -O >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # Draw the box at the end of the profile. For other view angles, should draw the other box?

#        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${dem_minz} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -JZ\${ZSIZE}i -J -Bzaf -Bxaf --MAP_FRAME_PEN=thinner,black -K -O -Y\${yshift}i >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

      if [[ $litho1profileflag -eq 1 ]]; then

# Change limits based on profile limits, in the script itself.

cat<<-EOF >> ${LINEID}_topscript.sh
gawk < ${F_PROFILES}${LINEID}_litho1_cross_poly.dat -v xval=\$line_max_x -v zval=\$line_min_z '{
if (\$1 == ">") {
print
} else {
  if (\$2 < zval) {
    print xval, \$1, zval
  } else {
    print xval, \$1, \$2
  }
}
}' > ${F_PROFILES}${LINEID}_litho1_cross_poly_xyz.dat
EOF
        echo "gmt psxyz -p ${F_PROFILES}${LINEID}_litho1_cross_poly_xyz.dat -L -G+z -C$LITHO1_CPT -t${LITHO1_TRANS} -Vn -R -J -JZ -O -K >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
      fi
        cat ${LINEID}_topscript.sh >> ${LINEID}_plot_start.sh
        cleanup ${LINEID}_topscript.sh
      fi

      # echo "echo \"\$line_max_x \$dem_maxy \$line_max_z\" > ${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
      # echo "echo \"\$line_max_x \$dem_maxy \$line_min_z\" >> ${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
      # echo "echo \"\$line_max_x \$dem_miny \$line_min_z\" >> ${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
      # echo "echo \"\$line_max_x \$dem_miny \$line_max_z\" >> ${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh

      echo "if [[ \$(echo \"\${PERSPECTIVE_AZ} > 180\" | bc -l) -eq 1 ]]; then" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_min_x \$dem_maxy \$line_max_z\" > ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_min_x \$dem_maxy \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_min_x \$dem_miny \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_min_x \$dem_miny \$line_max_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
      echo "else" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_maxy \$line_max_z\" > ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_maxy \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_miny \$line_min_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_miny \$line_max_z\" >> ${F_PROFILES}${LINEID}_endbox.xyz" >> ${LINEID}_topscript.sh
      echo "fi" >> ${LINEID}_topscript.sh

      # NO -K
      echo "gmt psxyz ${F_PROFILES}${LINEID}_endbox.xyz -p -R -J -JZ -Wthinner,black -O >> ${F_PROFILES}${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

      echo "gmt psconvert ${F_PROFILES}${LINEID}_profile.ps -A+m1i -Tf -F${F_PROFILES}${LINEID}_profile" >> ${LINEID}_plot_start.sh

      # Execute plot script
      chmod a+x ${LINEID}_plot_start.sh
      echo "./${LINEID}_plot_start.sh \${PERSPECTIVE_AZ} \${PERSPECTIVE_INC} \${PERSPECTIVE_EXAG}" >> ./make_oblique_plots.sh

      # gmt psconvert ${LINEID}_profile.ps -A+m1i -Tf -F${LINEID}_profile

    fi # Finalize individual profile plots



    ### End of processing this profile.

    # Add profile X limits to all_data in case plotted data does not span profile.
    echo "$PROFILE_XMIN NaN NaN NaN NaN NaN" >> ${F_PROFILES}${LINEID}_all_data.txt
    echo "$PROFILE_XMAX NaN NaN NaN NaN NaN" >> ${F_PROFILES}${LINEID}_all_data.txt

    # Create the profile postscript plot
    # Profiles will be plotted by a master script that feeds in the appropriate parameters based on all profiles.
    echo "line_min_z=\$1" >> ${LINEID}_profile_plot.sh
    echo "line_max_z=\$2" >> ${LINEID}_profile_plot.sh
    echo "PROFILE_HEIGHT_IN=${PROFILE_HEIGHT_IN}" >> ${LINEID}_profile_plot.sh
    echo "PROFILE_WIDTH_IN=${PROFILE_WIDTH_IN}" >>${LINEID}_profile_plot.sh

    # Center the frame on the new PS document
    echo "gmt psbasemap -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -Bltrb -R${PROFILE_XMIN}/${PROFILE_XMAX}/\${line_min_z}/\${line_max_z} --MAP_FRAME_PEN=thinner,black -K -Xc -Yc >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    cat ${LINEID}_temp_plot.sh >> ${LINEID}_profile_plot.sh
    cleanup ${LINEID}_temp_plot.sh
    echo "gmt psbasemap -Vn -BtESW+t\"${LINEID}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=thinner,black -R -J -O >> ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    echo "gmt psconvert -Tf -A+m0.5i ${F_PROFILES}${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    echo "./${LINEID}_profile_plot.sh \$zmin \$zmax" >> ./make_flat_profiles.sh
    chmod a+x ./${LINEID}_profile_plot.sh

    # Increment the profile number
    PROFILE_INUM=$(echo "$PROFILE_INUM + 1" | bc)
  fi
done < $TRACKFILE

[[ -e end_points.txt ]] && mv end_points.txt ${F_PROFILES}
[[ -e mid_points.txt ]] && mv mid_points.txt ${F_PROFILES}
[[ -e start_points.txt ]] && mv start_points.txt ${F_PROFILES}

# Set a buffer around the data extent to give a nice visual appearance when setting auto limits
cat ${F_PROFILES}*_all_data.txt > ${F_PROFILES}all_data.txt

gawk < ${F_PROFILES}all_data.txt '{
    if ($1 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { km[++c]=$1; }
    if ($2 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { val[++d]=$2; }
    if ($6 ~ /^[-+]?[0-9]*\.?[0-9]+$/) { val[++d]=$6; }
  } END {
    asort(km);
    asort(val);
    print km[1], km[length(km)], val[1], val[length(val)]
  #  print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
}' > ${F_PROFILES}limits.txt

# These are hard data limits.

# If we haven't manually specified a limit, set it using the buffered data limit
# But for deep data sets, this will add a buffer to max_z that once one-to-one is applied
# will cause the section to be way too low. So we need to do the buffer after the one-to-one.

if [[ $xminflag -eq 1 ]]; then
  min_x=$(gawk < ${F_PROFILES}limits.txt '{print $1}')
fi
if [[ $xmaxflag -eq 1 ]]; then
  max_x=$(gawk < ${F_PROFILES}limits.txt '{print $2}')
fi
if [[ $zminflag -eq 1 ]]; then
  min_z=$(gawk < ${F_PROFILES}limits.txt '{print $3}')
fi
if [[ $zmaxflag -eq 1 ]]; then
  max_z=$(gawk < ${F_PROFILES}limits.txt '{print $4}')
fi

# Set minz/maxz to ensure that H=W
if [[ $profileonetooneflag -eq 1 ]]; then
  info_msg "Setting vertical aspect ratio to H=W"
  diffx=$(echo "$max_x - $min_x" | bc -l)
  hwratio=$(gawk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
  diffz=$(echo "$hwratio * $diffx" | bc -l)
  min_z=$(echo "$max_z - $diffz" | bc -l)
  info_msg "new min_z is $min_z"
fi

# Add a buffer around the data if we haven't asked for hard limits.

# Create the data files that will be used to plot the profile vertex points above the profile

cd ${F_PROFILES}
for distfile in *_dist_km.txt; do
  gawk < $distfile -v maxz=$max_z -v minz=$min_z -v profheight=${PROFILE_HEIGHT_IN} '{
    print $1, (maxz+minz)/2
  }' > xpts_$distfile
done
cd ..

maxzval=$(gawk -v maxz=$max_z -v minz=$min_z 'BEGIN {print (maxz+minz)/2}')

echo "echo \"0 $maxzval\" | gmt psxy -J -R -K -O -St0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.7p,black -Gwhite >> ${PSFILE}" >> plot.sh


if [[ $plotprofiletitleflag -eq 1 ]]; then
  LINETEXT=$(cat ${F_PROFILES}IDfile.txt)
else
  LINETEXT=""
fi
# FOR THE MAP
# Plot the frame. This sets -R and -J for the actual plotting script commands in plot.sh

echo "gmt psbasemap -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -X${PROFILE_X} -Y${PROFILE_Y} -Bltrb -R$min_x/$max_x/$min_z/$max_z --MAP_FRAME_PEN=thinner,black -K -O >> ${PSFILE}" > newplot.sh
cat plot.sh >> newplot.sh
echo "gmt psbasemap -Vn -BtESW+t\"${LINETEXT}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=thinner,black $RJOK >> ${PSFILE}" >> newplot.sh

# Execute plot script
chmod a+x ./newplot.sh
./newplot.sh
cleanup plot.sh

# FOR THE FLAT PROFILES
mv ./make_flat_profiles.sh ./tmp.sh
echo "#!/bin/bash" > ./make_flat_profiles.sh
echo "zmin=\$1" >> ./make_flat_profiles.sh
echo "zmax=\$2" >> ./make_flat_profiles.sh
cat ./tmp.sh >> ./make_flat_profiles.sh
chmod a+x ./make_flat_profiles.sh
./make_flat_profiles.sh $min_z $max_z

# FOR THE OBLIQUE SECTIONS
if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then
   chmod a+x ./make_oblique_plots.sh
   ./make_oblique_plots.sh ${PERSPECTIVE_AZ} ${PERSPECTIVE_INC} ${PERSPECTIVE_EXAG}
fi

# Pass intersection points, profile data back to tectoplot
#
# if [[ $gridfileflag -eq 1 ]]; then
#   cp *_profiletable.txt /var/tmp/tectoplot
# fi
# cp projpts_* /var/tmp/tectoplot
# cp buf_poly.txt /var/tmp/tectoplot
# [[ $zeropointflag -eq 1 && $doxflag -eq 1 ]] && cp all_intersect.txt /var/tmp/tectoplot/all_intersect.txt

# gmt psbasemap -Vn -BtESW+t"${LINETEXT}" -Baf -Bx+l"Distance (km)" --FONT_TITLE="10p,Helvetica,black" --MAP_FRAME_PEN=0.5p,black $RJOK >> "${PSFILE}"

if [[ ${PROFILE_X:0:1} == "-" ]]; then
  PROFILE_X="${PROFILE_X:1}"
elif [[ ${PROFILE_WIDTH_IN:0:1} == "+" ]]; then
  PROFILE_X=$(echo "-${PROFILE_X:1}")
else
  PROFILE_X=$(echo "-${PROFILE_X}")
fi

if [[ ${PROFILE_Y:0:1} == "-" ]]; then
  PROFILE_Y="${PROFILE_Y:1}"
elif [[ ${PROFILE_Y:0:1} == "+" ]]; then
  PROFILE_Y=$(echo "-${PROFILE_Y:1}")
else
  PROFILE_Y=$(echo "-${PROFILE_Y}")
fi

# The idea here is to return to the correct X,Y position to allow further
# plotting on the map by tectoplot, if mprof) was called in the middle of
# plotting for some reason.

# Changed from a different call to psxy ... not fully tested
gmt psxy -T -J -R -O -K -X$PROFILE_X -Y$PROFILE_Y -Vn >> "${PSFILE}"
