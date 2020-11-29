#!/bin/bash
#
# . multi_profile_tectoplot.sh
#
# Convert to a script that is sourced by tectoplot or by a wrapper script. Then we can do without
# passing variables or having problems returning information to tectoplot.
#
# PARAMETERS REQUIRED:
#
# MPROFFILE - command file
# PSFILE - ps file to plot on top of
# PROFILE_WIDTH_IN
# PROFILE_HEIGHT_IN
# PROFILE_X
# PROFILE_Z
# PLOT_SECTIONS_PROFILEFLAG   {=1 means plot section PDFs in perpective, =0 means don't}
#
# FILES EXPECTED:
# cmt_normal.txt, cmt_strikeslip.txt, cmt_thrust.txt (for focal mechanisms)
# cmt_alt_lines.xyz, cmt_alt_pts.xyz (if -cc flag is used)
#
# Script called by tectoplot to plot swath profiles of gridded data and (X,Y,Z) point data
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
# Should sort the plot.sh file appropriately to fix this

# These are the characters that determine the type of plots

# The challenge of this script is that we can't simply start plotting using GMT directly, as we
# need to know the extents for psbasemap before we can plot anything. So we have to create a
# script with the appropriate GMT commands (plot.sh) that can be run AFTER we process the data.

# @ XMIN XMAX ZMIN ZMAX CROSSINGZEROLINE_FILE ZMATCH_FLAG
#
# Normal profile
# P PROFILE_ID color XOFFSET ZOFFSET LON1 LAT1 ... ... LONN LATN
# Transverse profile
# T PROFILE_ID color XOFFSET ZOFFSET LON1 LAT1 ... ... LONN LATN
#
# Focal mechanism data file
# % CMTFILE WIDTH ZSCALE GMT_arguments
# Earthquake (scaled) xyzm data file
# > EQFILE SWATH_WIDTH ZSCALE GMT_arguments
# XYZ data file
# $ XYZFILE SWATH_WIDTH ZSCALE GMT_arguments
# Grid line profile
# : GRIDFILE ZSCALE SAMPLE_SPACING GMT_arguments
# Grid swath profile
# ^ GRIDFILE ZSCALE SWATH_SUBSAMPLE_DISTANCE SWATH_WIDTH SWATH_D_SPACING

# project_xyz_pts_onto_track $trackfile $xyzfile $outputfile $xoffset $zoffset $zscale
# $1=$trackfile

# profile_all.pdf needs to have each individual profile plotted on the combined axes

function project_xyz_pts_onto_track() {
  project_xyz_pts_onto_track_trackfile=$1
  project_xyz_pts_onto_track_xyzfile=$2
  project_xyz_pts_onto_track_outputfile=$3
  project_xyz_pts_onto_track_xoffset=$4
  project_xyz_pts_onto_track_zoffset=$5
  project_xyz_pts_onto_track_zscale=$6

  # Calculate distance from data points to the track, using only first two columns
  awk < ${project_xyz_pts_onto_track_xyzfile} '{print $1, $2, $3}' | gmt mapproject -L${project_xyz_pts_onto_track_trackfile} -fg -Vn | awk '{print $5, $6, $3}' > tmp_profile.txt
  # tmp.txt contains the lon*,lat*,depth of the projected points

  # Construct the combined track including the original track points
  awk < ${project_xyz_pts_onto_track_trackfile} '{
    printf "%s %s REMOVEME\n", $1, $2
  }' >> tmp_profile.txt

  pointsX=$(head -n 1 ${project_xyz_pts_onto_track_trackfile} | awk '{print $1}')
  pointsY=$(head -n 1 ${project_xyz_pts_onto_track_trackfile} | awk '{print $2}')

  # This gets the points into a general along-track order by calculating their true distance from the starting point
  # Tracks that loop back toward the first point might fail (but who would do that anyway...)

  gmt mapproject tmp_profile.txt -G$pointsX/$pointsY+uk -Vn | awk '{ print $0, NR }' > tmp_profile_distfrom0.txt

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
  awk < postsort_tmp_profile_truedist.txt -v xoff=${project_xyz_pts_onto_track_xoffset} -v zoff=${project_xyz_pts_onto_track_zoffset} -v zscale=${project_xyz_pts_onto_track_zscale} '{
    if ($3 != "NaN") {
      printf "%s %s %s\n", $6, ($3)*zscale+zoff, (($3)*zscale+zoff)/(zscale)
    }
  }' > ${project_xyz_pts_onto_track_outputfile}
}

# Return a sane interval and subinterval from a given value range and desired
# number of major tickmarks
INTERVALS_STRING="0.00001 0.0001 0.001 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 100 200 500 1000 2000 5000 10000 20000 50000 100000 200000 500000"

function interval_and_subinterval_from_minmax_and_number () {
  local vmin=$1
  local vmax=$2
  local numint=$3
  local diffval=$(echo "($vmax - $vmin) / $numint")
  echo $INTERVALS_STRING | awk -v seek=$diffval '{
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
TRACKFILE=$(echo "$(cd "$(dirname "control_file.txt")"; pwd)/$(basename "control_file.txt")")

# transfer the control file to the temporary directory and remove commented, blank lines
grep . $TRACKFILE_ORIG | grep -v "^[#]" > $TRACKFILE

# If we have specified profile IDS, remove lines where the second column is not one of the profiles in PSEL_LIST

if [[ $selectprofilesflag -eq 1 ]]; then
  awk < $TRACKFILE '{ if ($1 != "P") { print } }' > $TRACKFILE.tmp1
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
  cp $ZEROFILE_ORIG xy_intersect.txt
  ZEROFILE="xy_intersect.txt"
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

PROFHEIGHT_OFFSET=$(echo "${PROFILE_HEIGHT_IN}" | awk '{print ($1+0)/2 + 4/72}')

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
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $1}')

  if [[ ${FIRSTWORD:0:1} == "P" ]]; then
    echo ">" >> line_buffer.txt
    head -n ${i} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 >> line_buffer.txt
  fi
  if [[ ${FIRSTWORD:0:1} == "S" || ${FIRSTWORD:0:1} == "G" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $5 }' >> widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "X" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $3 }' >> widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "E" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $3 }' >> widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "C" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $3 }' >> widthlist.txt
  fi
done

# We accomplish buffering using geographic coordinates, so that buffers far from
# the equator will be too wide (longitudinally). This is not a real problem as we only use the
# buffers to define the AOI and graphically indicate the profile areas.

# We use ogr2ogr with SQlite instead of gmt spatial due to apparent problems with the latter's buffers.
# Any better buffering solution could easily go here

# This just gets the width of the widest swath from the data
# Use a minimum of 10km as a buffer (why?)

WIDTH_DEG_DATA=$(awk < widthlist.txt 'BEGIN {maxw=0; } {
    val=($1+0);
    if (val > maxw) {
      maxw = val
    }
  }
  END {print maxw/110/2}')

MAXWIDTH_KM=$(awk < widthlist.txt 'BEGIN {maxw=0; } {
    val=($1+0);
    if (val > maxw) {
      maxw = val
    }
  }
  END {print maxw}')

WIDTH_DEG=$(echo $WIDTH_DEG_DATA | awk '{ print ($1<10/110/2) ? 10/110/2 : $1}')

# Make the OGR_GMT format file

echo "# @VGMT1.0 @GLINESTRING @Nname" > linebuffer.gmt
echo "# @Jp\"+proj=longlat +ellps=WGS84 \"" >> linebuffer.gmt
echo "# FEATURE_DATA" >> linebuffer.gmt

awk < line_buffer.txt 'BEGIN{num=1} {
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
}' >> linebuffer.gmt

# We could theoretically project and then buffer in meters and then reproject... ick

ogr2ogr -f "OGR_GMT" buf_poly.gmt linebuffer.gmt -dialect sqlite -sql "select ST_buffer(geometry, $WIDTH_DEG) as geometry FROM linebuffer"

# Return to GMT multisegment format which is easier to work with
awk <  buf_poly.gmt '{ if ($1 != "#") { print } }' > buf_poly.txt

# The buffers are returned in line order and can be split into per-line buffers.

awk < buf_poly.txt 'BEGIN{ fn = "buf_1.txt"; n = 0 }
{
   if (substr($0,1,2) == ">") {
       close (fn)
       n++
       fn = "buf_" n ".txt"
   } else {
     print > fn
   }
}'

# gmt spatial (GMT 6.1) is producing bad buffers that are missing important points
# gmt spatial -Sb+"${WIDTH_DEG}" line_buffer.txt > buf_poly.txt

# Add a degree around each buffer extreme coordinate to determine the profile area AOI.
# This would impact very high resolution datasets of small areas and should probably be adjusted to suit.

buf_max_x=$(grep "^[^>]" buf_poly.txt | sort -n -k 1 | tail -n 1 | awk '{printf "%d", $1+1}')
buf_min_x=$(grep "^[^>]" buf_poly.txt | sort -n -k 1 | head -n 1 | awk '{printf "%d", $1-1}')
buf_max_z=$(grep "^[^>]" buf_poly.txt | sort -n -k 2 | tail -n 1 | awk '{printf "%d", $2+1}')
buf_min_z=$(grep "^[^>]" buf_poly.txt | sort -n -k 2 | head -n 1 | awk '{printf "%d", $2-1}')

# echo "Buffered extent is $buf_min_x/$buf_max_x/$buf_min_z/$buf_max_z"

# Currently I can only make gmt spatial -Sb work with degree units.
# Use a basic conversion of 110 km per degree and use the half-width

xyzfilelist=()
xyzcommandlist=()

# Change command characters to capital letters instead of ^ etc
# S = swath grid (^)
# T = track grid (:)
# G = oblique view top grid
# X = XYZ file ($ || >)
# E = seismicity file (>)
# C = CMT file (%)
# P = profile

# Default units are X=Y=Z=km. Use L command to update labels.
x_axis_label="Distance (km)"
y_axis_label="Distance (km)"
z_axis_label="Distance (km)"

# Search for, parse, and pre-process datasets to be plotted
for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $1}')


  if [[ ${FIRSTWORD:0:1} == "L" ]]; then
    # Remove leading and trailing whitespaces from the axis labels
    x_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | awk -F'|' '{gsub(/^[ \t]+/,"",$2);gsub(/[ \t]+$/,"",$2);print $2}')
    y_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | awk -F'|' '{gsub(/^[ \t]+/,"",$3);gsub(/[ \t]+$/,"",$2);print $3}')
    z_axis_label=$(head -n ${i} $TRACKFILE | tail -n 1 | awk -F'|' '{gsub(/^[ \t]+/,"",$4);gsub(/[ \t]+$/,"",$2);print $4}')

    # S defines grids that we calculate swath profiles from.
    # G defines a grid that will be displayed above oblique profiles.
  elif [[ ${FIRSTWORD:0:1} == "V" ]]; then
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))
    PERSPECTIVE_EXAG="${myarr[1]}"
  elif [[ ${FIRSTWORD:0:1} == "S" || ${FIRSTWORD:0:1} == "G" ]]; then           # Found a gridded dataset; cut to AOI and store as a nc file
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))

    # GRIDFILE 0.001 .1k 40k 0.1k
    grididnum[$i]=$(echo "grid${i}")
    gridfilelist[$i]=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    gridfilesellist[$i]=$(echo "cut_$(basename "${myarr[1]}").nc")
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
      info_msg "Loading top grid: ${gridfilesellist[$i]}: Zscale ${gridzscalelist[$i]}, Spacing: ${gridspacinglist[$i]}, Width: ${gridwidthlist[$i]}, SampWidth: ${gridsamplewidthlist[$i]}"
    else
      info_msg "Loading swath grid: ${gridfilesellist[$i]}: Zscale ${gridzscalelist[$i]}, Spacing: ${gridspacinglist[$i]}, Width: ${gridwidthlist[$i]}, SampWidth: ${gridsamplewidthlist[$i]}"
    fi

    # Cut the grid to the AOI and multiply by its ZSCALE
    gmt grdcut ${gridfilelist[$i]} -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Gtmp.nc --GMT_HISTORY=false
    gmt grdmath tmp.nc ${gridzscalelist[$i]} MUL = ${gridfilesellist[$i]}
  elif [[ ${FIRSTWORD:0:1} == "T" ]]; then
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))

    # GRIDFILE 0.001 .1k 40k 0.1k
    ptgrididnum[$i]=$(echo "ptgrid${i}")
    ptgridfilelist[$i]=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    ptgridfilesellist[$i]=$(echo "cut_$(basename "${myarr[1]}").nc")
    ptgridzscalelist[$i]="${myarr[2]}"
    ptgridspacinglist[$i]="${myarr[3]}"
    ptgridcommandlist[$i]=$(echo "${myarr[@]:4}")

    info_msg "Loading single track sample grid: ${ptgridfilelist[$i]}: Zscale: ${ptgridzscalelist[$i]} Spacing: ${ptgridspacinglist[$i]}"
    # Cut the grid to the AOI and multiply by its ZSCALE
    gmt grdcut ${ptgridfilelist[$i]} -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Gtmp.nc --GMT_HISTORY=false
    gmt grdmath tmp.nc ${ptgridzscalelist[$i]} MUL = ${ptgridfilesellist[$i]}

  elif [[ ${FIRSTWORD:0:1} == "X" || ${FIRSTWORD:0:1} == "E" ]]; then        # Found an XYZ dataset
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))
    # This is where we would load datasets to be displayed
    FILE_P=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    FILE_SEL=$(echo "crop_$(basename "${myarr[1]}")")

    # Remove lines that don't start with a number or a minus sign. Doesn't handle plus signs...
    # Store in a file called crop_X where X is the basename of the source data file.
    grep "^[-*0-9]" $FILE_P | gmt select -fg -Lline_buffer.txt+d"${myarr[2]}" > $FILE_SEL
    info_msg "Selecting data in file $FILE_P within buffer distance ${myarr[2]}: to $FILE_SEL"
    xyzfilelist[$i]=$FILE_SEL

    # In this case, the width given must be divided by two.
    xyzwidthlistfull[$i]="${myarr[2]}"
    xyzwidthlist[$i]=$(echo "${myarr[2]}" | awk '{ print ($1+0)/2 substr($1,length($1),1) }')
    xyzunitlist[$i]="${myarr[3]}"
    xyzcommandlist[$i]=$(echo "${myarr[@]:4}")

    # We mark the seismic data that are subject to rescaling (or any data with a scalable fourth column...)
    [[ ${FIRSTWORD:0:1} == "E" ]] && xyzscaleeqsflag[$i]=1

    # echo "Found a dataset to load: ${xyzfilelist[$i]}"
    # echo "Scale factor for Z units is ${xyzunitlist[$i]}"
    # echo "Commands are ${xyzcommandlist[$i]}"
    # echo "Scale flag is ${xyzscaleeqsflag[$i]}"
  elif [[ ${FIRSTWORD:0:1} == "C" ]]; then         # Found a CMT dataset; currently, we only do one
    cmtfileflag=1
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))
    # This is where we would load datasets to be displayed
    CMTFILE=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    CMTWIDTH_FULL="${myarr[2]}"
    # The following command assumes that WIDTH ends with a unit letter (e.g. k, m)
    CMTWIDTH=$(echo $CMTWIDTH_FULL | awk '{ print ($1+0)/2 substr($1,length($1),1) }')
    CMTZSCALE="${myarr[3]}"
    CMTCOMMANDS=$(echo "${myarr[@]:4}")
    # echo "CMT: ${CMTFILE} W: ${CMTWIDTH_FULL} Z: ${CMTZSCALE} C: ${CMTCOMMANDS}"
  fi
done

# Process the profile tracks one by one, in the order that they appear in the control file.
# Keep track of which profile we are working on. (first=0)
PROFILE_INUM=0

for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $1}')

  # Process the 'normal' type tracks.
  if [[ ${FIRSTWORD:0:1} == "P" ]]; then
    LINEID=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $2}')
    COLOR=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $3}')
    XOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $4}')
    ZOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $5}')

    # Initialize the profile plot script
    echo "#!/bin/bash" > ${LINEID}_profile_plot.sh


  # if [[ ${FIRSTWORD:0:1} != "#" && ${FIRSTWORD:0:1} != "$" && ${FIRSTWORD:0:1} != "%"  && ${FIRSTWORD:0:1} != "^" && ${FIRSTWORD:0:1} != "@" && ${FIRSTWORD:0:1} != ":" && ${FIRSTWORD:0:1} != ">" ]]; then
  #   LINEID=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $1}')
  #   COLOR=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $2}')
  #   XOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $3}')
  #   ZOFFSET=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $4}')

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

    COLOR_R=($(grep ^"$COLOR " $TECTOPLOT_COLORS | head -n 1 | awk '{print $2, $3, $4}'))

    # echo "COLOR $COLOR in R/G/B is ${COLOR_R[0]}/${COLOR_R[1]}/${COLOR_R[2]}"
    COLOR=$(echo "${COLOR_R[0]}/${COLOR_R[1]}/${COLOR_R[2]}")
    LIGHTCOLOR=$(echo $COLOR | awk -F/ '{
      printf "%d/%d/%d", (255-$1)*0.25+$1,  (255-$2)*0.25+$2, (255-$3)*0.25+$3
    }')
    LIGHTERCOLOR=$(echo $COLOR | awk -F/ '{
      printf "%d/%d/%d", (255-$1)*0.5+$1,  (255-$2)*0.5+$2, (255-$3)*0.5+$3
    }')

    # echo "$LINEID is LINEID / color is $COLOR light $LIGHTCOLOR lighter $LIGHTERCOLOR,  offset is $XOFFSET_NUM"
    head -n ${i} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 > ${LINEID}_trackfile.txt

    # Calculate the incremental length along profile between points
    gmt mapproject ${LINEID}_trackfile.txt -G+uk+i | awk '{print $3}' > ${LINEID}_dist_km.txt

    # Calculate the total along-track length of the profile
    PROFILE_LEN_KM=$(awk < ${LINEID}_dist_km.txt 'BEGIN{val=0}{val=val+$1}END{print val}')
    PROFILE_XMIN=0
    PROFILE_XMAX=$PROFILE_LEN_KM

    # Create swath width indicator for this track using the widest buffer
  	sed 1d < ${LINEID}_trackfile.txt > shift1_${LINEID}_trackfile.txt
  	paste ${LINEID}_trackfile.txt shift1_${LINEID}_trackfile.txt | grep -v "\s>" > geodin_${LINEID}_trackfile.txt

    # Script to return azimuth and midpoint between a pair of input points.
    # Comes within 0.2 degrees of geod() results over large distances, while being symmetrical which geod isn't
    # We need perfect symmetry in order to create exact point pairs in adjacent polygons

    awk < geodin_${LINEID}_trackfile.txt 'function acos(x) { return atan2(sqrt(1-x*x), x) }
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
        }' > az_${LINEID}_trackfile.txt

    paste ${LINEID}_trackfile.txt az_${LINEID}_trackfile.txt > jointrack_${LINEID}.txt

    LINETOTAL=$(wc -l < jointrack_${LINEID}.txt)
    cat jointrack_${LINEID}.txt | awk -v width="${WIDTH_DEG_DATA}" -v color="${COLOR}" -v lineval="${LINETOTAL}" -v lineid=${LINEID} '
      (NR==1) {
        print $1, $2, $5, width, color, lineid >> "start_points.txt"
        lastval=$5
      }
      (NR>1 && NR<lineval) {
        diff = ( ( $5 - lastval + 180 + 360 ) % 360 ) - 180
        angle = (360 + lastval + ( diff / 2 ) ) % 360
        print $1, $2, angle, width, color, lineid >> "mid_points.txt"
        thisval=lastval
        lastval=$5
      }
      END {
        print $1, $2, lastval, width, color, lineid >> "end_points.txt"
      }
      '

    xoffsetflag=0
    # Set XOFFSET to the distance from our first point to the crossing point of zero_point_file.txt
    if [[ $zeropointflag -eq 1 && $doxflag -eq 1 ]]; then
      head -n 1 ${LINEID}_trackfile.txt > intersect.txt
      gmt spatial -Vn -fg -Ie -Fl ${LINEID}_trackfile.txt $ZEROFILE | head -n 1 | awk '{print $1, $2}' >> intersect.txt
      INTNUM=$(wc -l < intersect.txt)
      if [[ $INTNUM -eq 2 ]]; then
        XOFFSET_NUM=$(gmt mapproject -Vn -G+uk+i intersect.txt | tail -n 1 | awk '{print 0-$3}')
        xoffsetflag=1
        PROFILE_XMIN=$(echo "$PROFILE_XMIN + $XOFFSET_NUM" | bc -l)
        PROFILE_XMAX=$(echo "$PROFILE_XMAX + $XOFFSET_NUM" | bc -l)
        info_msg "Updated line $LINEID by shifting $XOFFSET_NUM km to match $ZEROFILE"
        tail -n 1 intersect.txt >> all_intersect.txt
      fi
    fi

    # This section processes the grid data that we are sampling along the profile line itself

    for i in ${!ptgridfilelist[@]}; do
      gridfileflag=1

      # Resample the track at the specified X increment.
      gmt sample1d ${LINEID}_trackfile.txt -Af -fg -I${ptgridspacinglist[$i]} > ${LINEID}_${ptgrididnum[$i]}_trackinterp.txt

      # Calculate the X coordinate of the resampled track, accounting for any X offset due to profile alignment
      gmt mapproject -G+uk+a ${LINEID}_${ptgrididnum[$i]}_trackinterp.txt | awk -v xoff="${XOFFSET_NUM}" '{ print $1, $2, $3 + xoff }' > ${LINEID}_${ptgrididnum[$i]}_trackdist.txt

      # Sample the grid at the points
      gmt grdtrack -Vn -G${ptgridfilesellist[$i]} ${LINEID}_${ptgrididnum[$i]}_trackinterp.txt > ${LINEID}_${ptgrididnum[$i]}_sample.txt

      # *_sample.txt is a file containing lon,lat,val
      # We want to reformat to a multisegment polyline that can be plotted using psxy -Ccpt
      # > -Zval1
      # Lon1 lat1
      # lon2 lat2
      # > -Zval2
      paste  ${LINEID}_${ptgrididnum[$i]}_trackdist.txt ${LINEID}_${ptgrididnum[$i]}_sample.txt > dat.txt
      sed 1d < dat.txt > dat1.txt
    	paste  dat.txt dat1.txt | awk -v zscale=${ptgridzscalelist[$i]} '{ if ($7 && $6 != "NaN" && $12 != "NaN") { print "> -Z"($6+$12)/2*zscale*-1; print $3, $6*zscale; print $9, $12*zscale } }' > ${LINEID}_${ptgrididnum[$i]}_data.txt

      # PLOT ON THE MAP PS
      echo "gmt psxy -Vn -R -J -O -K -L ${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> "${PSFILE}"" >> plot.sh

      # PLOT ON THE FLAT PROFILE PS
      echo "gmt psxy -Vn -R -J -O -K -L ${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

      # PLOT ON THE OBLIQUE PROFILE PS
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -L ${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

      grep "^[-*0-9]" ${LINEID}_${ptgrididnum[$i]}_data.txt >> ${LINEID}_all_data.txt
    done

    # This section processes grid datasets (usually DEM, gravity, etc) by calculating swath profiles
    # this section and the topgrid section are very similar and if this is modified, please check the topgrid section!

    for i in ${!gridfilelist[@]}; do
      gridfileflag=1

      # Sample the input grid along space cross-profiles

      # echo "gmt grdtrack -G${gridfilesellist[$i]} ${LINEID}_trackfile.txt -C${gridwidthlist[$i]}/${gridsamplewidthlist[$i]}/${gridspacinglist[$i]}+lr -Ar > ${LINEID}_${grididnum[$i]}_profiletable.txt"
      gmt grdtrack -Vn -G${gridfilesellist[$i]} ${LINEID}_trackfile.txt -C${gridwidthlist[$i]}/${gridsamplewidthlist[$i]}/${gridspacinglist[$i]}${PERSPECTIVE_TOPO_HALF} -Af > ${LINEID}_${grididnum[$i]}_profiletable.txt

      # ${LINEID}_${grididnum[$i]}_profiletable.txt: FORMAT is grdtrack (> profile data), columns are lon, lat, distance_from_profile, back_azimuth, value

      # Extract the profile ID numbers.
      # !!!!! This could easily be simplified to be a list of numbers starting with 0 and incrementing by 1!
      grep ">" ${LINEID}_${grididnum[$i]}_profiletable.txt | awk -F- '{print $3}' | awk -F" " '{print $1}' > ${LINEID}_${grididnum[$i]}_profilepts.txt

      # Shift the X coordinates of each cross-profile according to XOFFSET_NUM value
      # In awk, adding +0 to dinc changes "0.3k" to "0.3"
      awk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" '{ print ( $1 * (dinc + 0) + xoff ) }' < ${LINEID}_${grididnum[$i]}_profilepts.txt > ${LINEID}_${grididnum[$i]}_profilekm.txt

      # Construct the profile data table.
      awk '{
        if ($1 == ">") {
          printf("\n")
        } else {
          printf("%s ", $5)
        }
      }' < ${LINEID}_${grididnum[$i]}_profiletable.txt | sed '1d' > ${LINEID}_${grididnum[$i]}_profiledata.txt

      # If we are doing an oblique section and the current grid is a top grid
      if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 && ${istopgrid[$i]} -eq 1 ]]; then

        # Export the along-profile DEM, resampled to a certain resolution.
        # Then estimate the coordinate extents and the z data range, to allow vertical exaggeration

        if [[ $DO_SIGNED_DISTANCE_DEM -eq 0 ]]; then
          # Just export the profile data to a CSV without worrying about profile kink problems. Faster.

          # First find the maximum value of X. We want X to be negative or zero for the block plot. Not sure what happens otherwise...
          MAX_X_VAL=$(awk < ${LINEID}_${grididnum[$i]}_profiletable.txt 'BEGIN{maxx=-999999} { if ($1 != ">" && $1 > maxx) {maxx = $1 } } END{print maxx}')

          awk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" -v maxx=$MAX_X_VAL '
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
            }' < ${LINEID}_${grididnum[$i]]}_profiletable.txt | sed '1d' > ${LINEID}_${grididnum[$i]}_data.csv
        else

          # Turn the gridded profile data into dt, da, Z data, shifted by X offset

          # Output the lon, lat, Z, and the sign of the cross-profile distance (left vs right)
          awk < ${LINEID}_${grididnum[$i]]}_profiletable.txt '{
            if ($1 != ">") {
              print $1, $2, $5, ($3>0)?-1:1
            }
          }' > ${LINEID}_${grididnum[$i]]}_prepdata.txt

            # I need a file with LON, LAT, Z

            # Interpolate at a spacing of ${gridspacinglist[$i]} (spacing between cross track profiles)
            gmt sample1d ${LINEID}_trackfile.txt -Af -fg -I${gridspacinglist[$i]} > line_trackinterp.txt

            # If this function can be sped up that would be great.
            echo "Distance to and along track calc... (takes some time!)"
            gmt mapproject ${LINEID}_${grididnum[$i]]}_prepdata.txt -Lline_trackinterp.txt+p -fg -Vn > ${LINEID}_${grididnum[$i]]}_dadtpre.txt
            # Output is Lon, Lat, Z, DistSign, DistX, ?, DecimalID
            # DecimalID * ${gridspacinglist[$i]} = distance along track

            awk < ${LINEID}_${grididnum[$i]]}_dadtpre.txt -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" '
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
                } ' | sed '1d' > ${LINEID}_${grididnum[$i]}_data.csv
        fi

        mv ./profilerange.txt ${LINEID}_${grididnum[$i]}_profilerange.txt

cat << EOF > ${LINEID}_${grididnum[$i]}_data.vrt
<OGRVRTDataSource>
    <OGRVRTLayer name="${LINEID}_${grididnum[$i]}_data">
        <SrcDataSource>${LINEID}_${grididnum[$i]}_data.csv</SrcDataSource>
        <GeometryType>wkbPoint</GeometryType>
        <LayerSRS>EPSG:32612</LayerSRS>
        <GeometryField encoding="PointFromColumns" x="field_1" y="field_2" z="field_3"/>
    </OGRVRTLayer>
</OGRVRTDataSource>
EOF

        dem_minx=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $1}')
        dem_maxx=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $2}')
        dem_miny=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $3}')
        dem_maxy=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $4}')
        dem_minz=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $5}')
        dem_maxz=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $6}')
        # echo dem_minx $dem_minx dem_maxx $dem_maxx dem_miny $dem_miny dem_maxy $dem_maxy dem_minz $dem_minz dem_maxz $dem_maxz

        dem_xtoyratio=$(echo "($dem_maxx - $dem_minx)/($dem_maxy - $dem_miny)" | bc -l)
        dem_ztoxratio=$(echo "($dem_maxz - $dem_minz)/($dem_maxx - $dem_minx)" | bc -l)

        # Calculate zsize from xsize
        xsize=$(echo $PROFILE_WIDTH_IN | awk '{print $1+0}')
        zsize=$(echo "$xsize * $dem_ztoxratio" | bc -l)

        numx=$(echo "($dem_maxx - $dem_minx)/$PERSPECTIVE_RES" | bc)
        numy=$(echo "($dem_maxy - $dem_miny)/$PERSPECTIVE_RES" | bc)
        # echo $numx $numy
        # echo numx $numx numy $numy

        gdal_grid -q -of "netCDF" -txe $dem_minx $dem_maxx -tye $dem_miny $dem_maxy -outsize $numx $numy -zfield field_3 -a nearest -l ${LINEID}_${grididnum[$i]}_data ${LINEID}_${grididnum[$i]}_data.vrt ${LINEID}_${grididnum[$i]}_newgrid.nc

        # From here on, only the zsize and dem_miny, dem_maxy variables are needed for plotting

        # echo "#!/bin/bash" > ${LINEID}_makeboxplot.sh
        # echo "PERSPECTIVE_AZ=\${1}" >> ${LINEID}_makeboxplot.sh
        # echo "PERSPECTIVE_INC=\${2}" >> ${LINEID}_makeboxplot.sh

        # If we are shading the dem using the gdaldem method, do so here for the top tile as well.
        # This code is copied over, could be turned into a function? Ah well. That's not the way I roll I guess.

        # Notably, any TIFF can be plotted using gridview, so this approach can be generalized...

        if [[ $gdemtopoplotflag -eq 1 ]]; then
          if [[ $gdaltzerohingeflag -eq 1 ]]; then
            # We need to make a gdal color file that respects the CPT hinge value (usually 0)
            # gdaldem is a bit funny about coloring around the hinge, so do some magic to make
            # the color from land not bleed to the hinge elevation.
            CPTHINGE=0

            # Need to rescale the Z values by multiplying by ${gridzscalelist[$i]}
            # This is because CPTS are given in source data units and not scaled units.

            awk < $TOPO_CPT -v hinge=$CPTHINGE -v scale=${gridzscalelist[$i]} '{
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
            }' | tr '/' ' ' > topocolor_km.dat
          else
            awk < $TOPO_CPT '{ print $1*scale, $2 }' | tr '/' ' ' > topocolor_km.dat
          fi

          # Calculate the color stretch
          gdaldem color-relief ${LINEID}_${grididnum[$i]}_newgrid.nc topocolor_km.dat ${LINEID}_${grididnum[$i]}_newgrid_colordem.tif -q

          # Calculate the multidirectional hillshade
          # s factor is 1 as our DEM is in km/km/km units
          gdaldem hillshade -compute_edges -multidirectional -alt ${HS_ALT} -s 1 ${LINEID}_${grididnum[$i]}_newgrid.nc ${LINEID}_${grididnum[$i]}_hs_md.tif -q
          # gdaldem hillshade -combined -s 111120 dem.nc hs_c.tif -q

          # Clip the hillshade to reduce extreme bright and extreme dark areas

          # Calculate the slope and shade the data
          gdaldem slope -compute_edges -s 111120 ${LINEID}_${grididnum[$i]}_newgrid.nc ${LINEID}_${grididnum[$i]}_slope.tif -q
          echo "0 255 255 255" > slope.txt
          echo "90 0 0 0" >> slope.txt
          gdaldem color-relief ${LINEID}_${grididnum[$i]}_slope.tif slope.txt ${LINEID}_${grididnum[$i]}_slopeshade.tif -q

          # gdal_calc.py --quiet -A hs_md.tif -B slope.tif --outfile=combhssl.tif --calc="uint8( (1 - A/255. * arctan(sqrt(abs(B)/90.))*0.4)**(1/${HS_GAMMA}) * 255)"
          # cang = 1 - cang * atan(sqrt(slope)) * INV_SQUARE_OF_HALF_PI;
          # gdal_calc.py --quiet -A hs_md.tif -B slopeshade.tif --calc="uint8( ((A/255.)*(B/255.)) * 255 )" --outfile=slope_hillshade.tif
          # if the colordem.tif band has a value of 0, this apparently messes things up badly as gdal
          # interprets that as the nodata value.

          # A hillshade is mostly gray (127) while a slope map is mostly white (255)

          # Combine the hillshade and slopeshade into a blended, gamma corrected image
          gdal_calc.py --quiet -A ${LINEID}_${grididnum[$i]}_hs_md.tif -B ${LINEID}_${grididnum[$i]}_slopeshade.tif --outfile=${LINEID}_${grididnum[$i]}_gamma_hs.tif --calc="uint8( ( ((A/255.)*(${HSSLOPEBLEND}) + (B/255.)*(1-${HSSLOPEBLEND}) ) )**(1/${HS_GAMMA}) * 255)"


          # Combine the shaded relief and color stretch using a multiply scheme

          gdal_calc.py --quiet -A ${LINEID}_${grididnum[$i]}_gamma_hs.tif -B ${LINEID}_${grididnum[$i]}_newgrid_colordem.tif --allBands=B --calc="uint8( ( \
                          2 * (A/255.)*(B/255.)*(A<128) + \
                          ( 1 - 2 * (1-(A/255.))*(1-(B/255.)) ) * (A>=128) \
                        ) * 255 )" --outfile=${LINEID}_${grididnum[$i]}_colored_hillshade.tif
        fi

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
        echo "PROFILE_DEPTH_IN=\$(echo \$PROFILE_DEPTH_RATIO \$PROFILE_WIDTH_IN | awk '{print (\$1*(\$2+0))}' )i"  >> ${LINEID}_topscript.sh

        echo "yshift=\$(awk -v height=\${PROFILE_HEIGHT_IN} -v inc=\$PERSPECTIVE_INC 'BEGIN{print cos(inc*3.1415926/180)*(height+0)}')" >> ${LINEID}_topscript.sh
        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_max_z} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${line_min_z}/\${line_max_z}r -JZ\${PROFILE_HEIGHT_IN} -JX\${PROFILE_WIDTH_IN}/\${PROFILE_DEPTH_IN} -Byaf+l\"${y_axis_label}\" --MAP_FRAME_PEN=thinner,black -K -O >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # Draw the box at the end of the profile. For other view angles, should draw the other box?

        echo "echo \"\$line_max_x \$dem_maxy \$line_max_z\" > ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_maxy \$line_min_z\" >> ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_miny \$line_min_z\" >> ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        echo "gmt psxyz ${LINEID}_rightbox.xyz -p -R -J -JZ -Wthinner,black -K -O >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${dem_minz} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -JZ\${ZSIZE}i -J -Bzaf -Bxaf --MAP_FRAME_PEN=thinner,black -K -O -Y\${yshift}i >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # I think this could be done with gmt makecpt -C+Uk but technical questions exist
        # This assumes topo is in m and needs to be in km... not applicable for other grids


        awk < ${gridcptlist[$i]} -v sc=${gridzscalelist[$i]} '{ if ($1 ~ /^[-+]?[0-9]*.*[0-9]+$/) { print $1*sc "\t" $2 "\t" $3*sc "\t" $4} else {print}}' > ${LINEID}_topokm.cpt

        if [[ $gdemtopoplotflag -eq 1 ]]; then
          echo "gmt grdview ${LINEID}_${grididnum[$i]}_newgrid.nc -G${LINEID}_${grididnum[$i]}_colored_hillshade.tif -Qi300 -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -J -JZ\${ZSIZE}i -O -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_min_z} -Y\${yshift}i >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        else
          echo "gmt grdview ${LINEID}_${grididnum[$i]}_newgrid.nc -Qi300 -R -J -JZ -I+d -C${LINEID}_topokm.cpt -O -p  >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
        fi
###
      fi

      # For grids that are not top grids, they are swath grids. So calculate and plot the swaths.
      if [[ ! ${istopgrid[$i]} -eq 1 ]]; then

        # profiledata.txt contains space delimited rows of data.

        # This function calculates the 0, 25, 50, 75, and 100 quartiles of the data. First strip out the NaN values which are in the data.
        cat ${LINEID}_${grididnum[$i]}_profiledata.txt | sed 's/NaN//g' |  awk '{
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
        }' > ${LINEID}_${grididnum[$i]}_profilesummary_pre.txt

        # Find the value of Z at X=0 and subtract it from the entire dataset
        if [[ $ZOFFSETflag -eq 1 && $dozflag -eq 1 ]]; then
          # echo ZOFFSETflag is set
          XZEROINDEX=$(awk < profilekm.txt '{if ($1 > 0) { exit } } END {print NR}')
          ZOFFSET_NUM=$(head -n $XZEROINDEX ${LINEID}_${grididnum[$i]}_profilesummary_pre.txt | tail -n 1 | awk '{print 0-$3}')
        fi

        cat ${LINEID}_${grididnum[$i]}_profilesummary_pre.txt | awk -v zoff="${ZOFFSET_NUM}" '{print $1+zoff, $2+zoff, $3+zoff, $4+zoff, $5+zoff}' > ${LINEID}_${grididnum[$i]}_profilesummary.txt

        # profilesummary.txt is min q1 q2 q3 max
        #           1  2   3  4  5   6
        # gmt wants X q2 min q1 q3 max

        paste ${LINEID}_${grididnum[$i]}_profilekm.txt ${LINEID}_${grididnum[$i]}_profilesummary.txt | tr '\t' ' ' | awk '{print $1, $4, $2, $3, $5, $6}' > ${LINEID}_${grididnum[$i]}_profiledatabox.txt

        awk '{print $1, $2}' < ${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${LINEID}_${grididnum[$i]}_profiledatamedian.txt
        awk '{print $1, $3}' < ${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${LINEID}_${grididnum[$i]}_profiledatamin.txt
        awk '{print $1, $6}' < ${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${LINEID}_${grididnum[$i]}_profiledatamax.txt

        # Makes an envelope plottable by GMT
        awk '{print $1, $4}' < ${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${LINEID}_${grididnum[$i]}_profiledataq13min.txt
        awk '{print $1, $5}' < ${LINEID}_${grididnum[$i]}_profiledatabox.txt > ${LINEID}_${grididnum[$i]}_profiledataq13max.txt

        cat ${LINEID}_${grididnum[$i]}_profiledatamax.txt > ${LINEID}_${grididnum[$i]}_profileenvelope.txt
        tac ${LINEID}_${grididnum[$i]}_profiledatamin.txt >> ${LINEID}_${grididnum[$i]}_profileenvelope.txt

        cat ${LINEID}_${grididnum[$i]}_profiledataq13min.txt > ${LINEID}_${grididnum[$i]}_profileq13envelope.txt
        tac ${LINEID}_${grididnum[$i]}_profiledataq13max.txt >> ${LINEID}_${grididnum[$i]}_profileq13envelope.txt

        # PLOT ON THE MAP PS
        echo "gmt psxy -Vn ${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> "${PSFILE}"" >> plot.sh
        echo "gmt psxy -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> "${PSFILE}"" >> plot.sh
        echo "gmt psxy -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> "${PSFILE}"" >> plot.sh

        # PLOT ON THE FLAT PROFILE PS
        echo "gmt psxy -Vn ${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt psxy -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt psxy -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn ${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -p -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

        ## Output data files to THIS_DIR
        echo "km_along_profile q0 q25 q25 q75 q100" > $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt
        paste ${LINEID}_${grididnum[$i]}_profilekm.txt ${LINEID}_${grididnum[$i]}_profilesummary.txt >> $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt
        paste ${LINEID}_${grididnum[$i]}_profilekm.txt ${LINEID}_${grididnum[$i]}_profilesummary.txt >> ${LINEID}_all_data.txt
      fi
    done  # for each grid

    echo -n "@;${COLOR};${LINEID}@;; " >> IDfile.txt
    if [[ $xoffsetflag -eq 1 && $ZOFFSETflag -eq 1 ]]; then
      printf "@:8: (%+.02g km/%+.02g) @::" $XOFFSET_NUM $ZOFFSET_NUM >> IDfile.txt
      echo -n " " >> IDfile.txt
    elif [[ $xoffsetflag -eq 1 && $ZOFFSETflag -eq 0 ]]; then
      printf "@:8: (%+.02g km (X)) @::" $XOFFSET_NUM >> IDfile.txt
      echo -n " " >> IDfile.txt
    elif [[ $xoffsetflag -eq 0 && $ZOFFSETflag -eq 1 ]]; then
      printf "@:8: (%+.02g km (Z)) @::" $ZOFFSET_NUM >> IDfile.txt
      echo -n " " >> IDfile.txt
    fi

    # Now treat the XYZ data. Make sure to append data to ${LINEID}_all_data.txt in the form km_along_profile val val val val val
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
      awk < ${xyzfilelist[i]} '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -L${LINEID}_trackfile.txt -fg -Vn | awk '{print $3, $4, $5}' > tmp.txt
      awk < ${xyzfilelist[i]} '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4}'> tmpbuf.txt

      # Paste result onto input lines and select the points that are closest to current track out of all tracks
      paste tmpbuf.txt ${xyzfilelist[i]} tmp.txt  > joinbuf.txt
#      head joinbuf.txt
#      echo PROFILE_INUM=$PROFILE_INUM
      cat joinbuf.txt | awk -v lineid=$PROFILE_INUM '{
        if ($1==lineid) {
          for (i=2;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > $FNAME

      # output is lon lat ... fields ... dist_to_track lon_at_track lat_at_track

      # Calculate distance from data points to any profile line, using only first two columns, then paste onto input file.

      pointsX=$(head -n 1 ${LINEID}_trackfile.txt | awk '{print $1}')
      pointsY=$(head -n 1 ${LINEID}_trackfile.txt | awk '{print $2}')
      pointeX=$(tail -n 1 ${LINEID}_trackfile.txt | awk '{print $1}')
      pointeY=$(tail -n 1 ${LINEID}_trackfile.txt | awk '{print $2}')

      # Exclude points that project onto the endpoints of the track, or are too far away. Distances are in meters in FNAME
      # echo "$pointsX $pointsY / $pointeX $pointeY"
      # rm -f ./cull.dat

      cat $FNAME | awk -v x1=$pointsX -v y1=$pointsY -v x2=$pointeX -v y2=$pointeY -v w=${xyzwidthlist[i]} '{
        if (($(NF-1) == x1 && $(NF) == y1) || ($(NF-1) == x2 && $(NF) == y2) || $(NF-2) > (w+0)*1000) {
          # Nothing. My awk skills are poor.
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
      }' > projpts_${FNAME}

      # echo tally
      # wc -l ./cull.dat
      # wc -l projpts_${FNAME}
      # echo endtally
      #
      # mv ./cull.dat ${xyzcullfile[i]}

      # This is where we can filter points based on whether they exist in previous profiles

      # Calculate along-track distances for points with distance less than the cutoff
      # echo XYZwidth to trim is ${xyzwidthlist[i]}
      # awk < trimmed_${FNAME} -v w=${xyzwidthlist[i]} '($4 < (w+0)*1000) {print $5, $6, $3}' > projpts_${FNAME}

      # Replaces lon lat with lon_at_track lat_at_track

      # Default sampling distance is 10 meters, hardcoded. Would cause trouble for
      # very long or short lines. Should use some logic to set this value?

      # To ensure the profile path is perfect, we have to add the points on the profile back, and then remove them later
      NUMFIELDS=$(head -n 1 projpts_${FNAME} | awk '{print NF}')

      awk < ${LINEID}_trackfile.txt -v fnum=$NUMFIELDS '{
        printf "%s %s REMOVEME", $1, $2
        for(i=3; i<fnum; i++) {
          printf " 0"
        }
        printf("\n")
      }' >> projpts_${FNAME}

      # This gets the points into a general along-track order by calculating their true distance from the starting point
      # Tracks that loop back toward the first point might fail (but who would do that anyway...)

      awk < projpts_${FNAME} '{print $1, $2}' | gmt mapproject -G$pointsX/$pointsY+uk -Vn | awk '{print $3}' > tmp.txt
      paste projpts_${FNAME} tmp.txt > tmp2.txt
      NUMFIELDS=$(head -n 1 tmp2.txt | awk '{print NF}')
      sort -n -k $NUMFIELDS < tmp2.txt > presort_${FNAME}

      # Calculate true distances along the track line. "REMOVEME" is output as "NaN" by GMT.
      awk < presort_${FNAME} '{print $1, $2}' | gmt mapproject -G+uk -Vn | awk '{print $3}' > tmp.txt

      # NF is the true distance along profile that needs to be the X coordinate, modified by XOFFSET_NUM
      # NF-1 is the distance from the zero point and should be discarded
      # $3 is the Z value that needs to be modified by zscale and ZOFFSET_NUM

      paste presort_${FNAME} tmp.txt | awk -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM -v zscale=${xyzunitlist[i]} '{
        if ($3 != "REMOVEME") {
          printf "%s %s %s", $(NF)+xoff, ($3)*zscale+zoff, (($3)*zscale+zoff)/(zscale)
          if (NF>=4) {
            for(i=4; i<NF-1; i++) {
              printf " %s", $(i)
            }
          }
          printf("\n")
        }
      }' > finaldist_${FNAME}

      awk < finaldist_${FNAME} '{print $1, $2, $2, $2, $2, $2 }' >> ${LINEID}_all_data.txt

      if [[ ${xyzscaleeqsflag[i]} -eq 1 ]]; then

        if  [[ $REMOVE_DEFAULTDEPTHS -eq 1 ]]; then
          # Plotting in km instead of in map geographic coords
          awk < finaldist_${FNAME} '{
            if ($3 == 10 || $3 == 33 || $3 == 5 ||$3 == 1 || $3 == 6  || $3 == 35 ) {
              seen[$3]++
            } else {
              print
            }
          }
          END {
            for (key in seen) {
              printf "%s (%s)\n", key, seen[key] >> "/dev/stderr"
            }
          }' > tmp.dat 2>removed.dat
          mv tmp.dat finaldist_${FNAME}
        fi

        # PLOT ON THE MAP PS
        awk < finaldist_${FNAME} -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1))}' > stretch_finaldist_${FNAME}
        echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT p" >> plot.sh
        echo "gmt psxy stretch_finaldist_${FNAME} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${PSFILE}" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> plot.sh

        # PLOT ON THE FLAT PROFILE PS
        echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> ${LINEID}_temp_plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT p"  >> ${LINEID}_temp_plot.sh
        echo "gmt psxy stretch_finaldist_${FNAME} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE}  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE SECTION PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT p" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy stretch_finaldist_${FNAME} -p -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> ${LINEID}_plot.sh

      else
        # PLOT ON THE MAP PS
        echo "gmt psxy finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> "${PSFILE}"" >> plot.sh

        # PLOT ON THE FLAT SECTION PS
        echo "gmt psxy finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ON THE OBLIQUE SECTION PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy finaldist_${FNAME} -p -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi

      rm -f presort_${FNAME}
    done # XYZ data

    if [[ $cmtfileflag -eq 1 ]]; then

      # Select CMT events that are closest to this line vs other profile lines in the project
      # Forms cmt_thrust_sel.txt cmt_normal_sel.txt cmt_strikeslip_sel.txt

      # This command outputs to tmpbuf.txt the ID of the line that each CMT mechanism is closest to. Then if that matches
      # the current line, we output it to the current profile. What happens if the alternative point is closer to a different profile?

      # Houston, we have a problem. This isn't actually selecting only the CMTs within the buffer of the profile; it is selecting all within
      # the rectangular AOI of the buffered region!

      # CMTWIDTH is e.g. 150k so in awk we do +0

      awk < cmt_thrust.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4, $3}' > tmpbuf.txt
      paste tmpbuf.txt cmt_thrust.txt | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_thrust_sel.txt

      if [[ -e cmt_alt_pts_thrust.xyz ]]; then
        paste tmpbuf.txt cmt_alt_pts_thrust.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${LINEID}_cmt_alt_pts_thrust_sel.xyz
      fi

      # cmt_alt_lines comes in the format >:lat1 lon1 z1:lat2 lon2 z2\n
      # Split into two XYZ files, project each file separately, and then merge to plot.
      if [[ -e cmt_alt_lines_thrust.xyz ]]; then
        paste tmpbuf.txt cmt_alt_lines_thrust.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > tmp.txt
        awk < tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv split1.txt ${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz
        mv split2.txt ${LINEID}_cmt_alt_lines_thrust_sel_P2.xyz
      fi

      awk < cmt_normal.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4, $3}' > tmpbuf.txt
      paste tmpbuf.txt cmt_normal.txt | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_normal_sel.txt

      if [[ -e cmt_alt_pts_normal.xyz ]]; then
        paste tmpbuf.txt cmt_alt_pts_normal.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
      }' > ${LINEID}_cmt_alt_pts_normal_sel.xyz
      fi

      if [[ -e cmt_alt_lines_normal.xyz ]]; then
        paste tmpbuf.txt cmt_alt_lines_normal.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > tmp.txt
        awk < tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv split1.txt ${LINEID}_cmt_alt_lines_normal_sel_P1.xyz
        mv split2.txt ${LINEID}_cmt_alt_lines_normal_sel_P2.xyz
      fi

      awk < cmt_strikeslip.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4, $3}' > tmpbuf.txt
      paste tmpbuf.txt cmt_strikeslip.txt | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
        if ($1==lineid && $2/1000 < (maxdist+0)) {
          for (i=3;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_strikeslip_sel.txt

      if [[ -e cmt_alt_pts_strikeslip.xyz ]]; then
        paste tmpbuf.txt cmt_alt_pts_strikeslip.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > ${LINEID}_cmt_alt_pts_strikeslip_sel.xyz
      fi

      if [[ -e cmt_alt_lines_strikeslip.xyz ]]; then
        paste tmpbuf.txt cmt_alt_lines_strikeslip.xyz | awk -v lineid=$PROFILE_INUM -v maxdist=$CMTWIDTH '{
          if ($1==lineid && $2/1000 < (maxdist+0)) {
            for (i=3;i<=NF;++i) {
              printf "%s ", $(i)
            }
            printf("\n")
          }
        }' > tmp.txt
        awk < tmp.txt -F: '{
          print $2 > "./split1.txt"
          print $3 > "./split2.txt"
        }'
        mv split1.txt ${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz
        mv split2.txt ${LINEID}_cmt_alt_lines_strikeslip_sel_P2.xyz
      fi
      ##### Now we need to project the alt_pts and alt_lines onto the profile.
      #####
      #####

      # project_xyz_pts_onto_track $trackfile $xyzfile $outputfile $xoffset $zoffset $zscale
      #
      if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then

        [[ -e ${LINEID}_cmt_alt_pts_strikeslip_sel.xyz ]] && project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_pts_strikeslip_sel.xyz ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        [[ -e ${LINEID}_cmt_alt_pts_thrust_sel.xyz ]] && project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_pts_thrust_sel.xyz ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
        [[ -e ${LINEID}_cmt_alt_pts_normal_sel.xyz ]] && project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_pts_normal_sel.xyz ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE

        if [[ -e ${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz ]]; then
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_thrust_sel_P1.xyz ${LINEID}_cmt_alt_lines_thrust_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_thrust_sel_P2.xyz ${LINEID}_cmt_alt_lines_thrust_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          awk < ${LINEID}_cmt_alt_lines_thrust_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > tmp1.txt
          paste -d '\0' tmp1.txt ${LINEID}_cmt_alt_lines_thrust_sel_P2_proj.xyz | tr ':' '\n' > ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz
        fi

        if [[ -e ${LINEID}_cmt_alt_lines_normal_sel_P1.xyz ]]; then
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_normal_sel_P1.xyz ${LINEID}_cmt_alt_lines_normal_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_normal_sel_P2.xyz ${LINEID}_cmt_alt_lines_normal_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          awk < ${LINEID}_cmt_alt_lines_normal_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > tmp1.txt
          paste -d '\0' tmp1.txt ${LINEID}_cmt_alt_lines_normal_sel_P2_proj.xyz | tr ':' '\n' > ${LINEID}_cmt_alt_lines_normal_proj_final.xyz
        fi

        if [[ -e ${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz ]]; then
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_strikeslip_sel_P1.xyz ${LINEID}_cmt_alt_lines_strikeslip_sel_P1_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          project_xyz_pts_onto_track ${LINEID}_trackfile.txt ${LINEID}_cmt_alt_lines_strikeslip_sel_P2.xyz ${LINEID}_cmt_alt_lines_strikeslip_sel_P2_proj.xyz $XOFFSET_NUM $ZOFFSET_NUM $CMTZSCALE
          awk < ${LINEID}_cmt_alt_lines_strikeslip_sel_P1_proj.xyz '{ print ">:" $0 ":" }' > tmp1.txt
          paste -d '\0' tmp1.txt ${LINEID}_cmt_alt_lines_strikeslip_sel_P2_proj.xyz | tr ':' '\n' > ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz
        fi
      fi

      # For each line segment in the potentially multipoint profile, we need to
      # project the CMTs orthogonally onto the segment using pscoupe

      numprofpts=$(cat ${LINEID}_trackfile.txt | wc -l)
      numsegs=$(echo "$numprofpts - 1" | bc -l)

      cur_x=0
      for segind in $(seq 1 $numsegs); do
        segind_p=$(echo "$segind + 1" | bc -l)
        p1_x=$(cat ${LINEID}_trackfile.txt | head -n ${segind} | tail -n 1 | awk '{print $1}')
        p1_z=$(cat ${LINEID}_trackfile.txt | head -n ${segind} | tail -n 1 | awk '{print $2}')
        p2_x=$(cat ${LINEID}_trackfile.txt | head -n ${segind_p} | tail -n 1 | awk '{print $1}')
        p2_z=$(cat ${LINEID}_trackfile.txt | head -n ${segind_p} | tail -n 1 | awk '{print $2}')
        add_x=$(cat ${LINEID}_dist_km.txt | head -n $segind_p | tail -n 1)

        cat cmt_thrust_sel.txt | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null

        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | awk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${LINEID}_cmt_thrust_profile_data.txt
          awk <  ${LINEID}_cmt_thrust_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${LINEID}_all_data.txt
        done
        rm -f Aa*

        cat cmt_normal_sel.txt | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null
        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | awk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${LINEID}_cmt_normal_profile_data.txt
          awk <  ${LINEID}_cmt_normal_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${LINEID}_all_data.txt
        done
        rm -f Aa*

        cat cmt_strikeslip_sel.txt | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13 }' | gmt pscoupe -R0/$add_x/-100/6500 -JX5i/-2i -Aa$p1_x/$p1_z/$p2_x/$p2_z/90/$CMTWIDTH/0/6500 -S${CMTLETTER}0.05i -Xc -Yc > /dev/null
        rm -f *_map
        for pscoupefile in Aa*; do
          info_msg "Shifting profile $pscoupefile by $cur_x km to account for segmentation"
          info_msg "Shifting profile $pscoupefile by X=$XOFFSET_NUM km and Z=$ZOFFSET_NUM to account for line shifts"

          cat $pscoupefile | awk -v shiftx=$cur_x -v scalez=$CMTZSCALE -v xoff=$XOFFSET_NUM -v zoff=$ZOFFSET_NUM '{
            printf "%s %f ", $1+shiftx+xoff, $2*scalez+zoff
            for(i=3; i<=NF; ++i) {
              printf "%s ", $i;
            }
            printf "\n"
          }' >> ${LINEID}_cmt_strikeslip_profile_data.txt
          awk <  ${LINEID}_cmt_strikeslip_profile_data.txt '{print $1, $2, $2, $2, $2, $2}' >> ${LINEID}_all_data.txt
        done

        rm -f Aa*

        if [[ ! $segind -eq $numsegs ]]; then
          add_x=$(cat ${LINEID}_dist_km.txt | head -n $segind_p | tail -n 1)
          # echo -n "new cur_x = $cur_x + $add_x"
          cur_x=$(echo "$cur_x + $add_x" | bc -l)
          # echo " = $cur_x"
        fi
      done

      # Generate the plotting commands for the shell script

      if [[ cmtthrustflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_THRUSTCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_THRUSTCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_thrust_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_thrust_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_THRUSTCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
      if [[ cmtnormalflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_normal_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_NORMALCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_normal_proj_final.xyz -W0.1p,black $RJOK $VERBOSE >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_NORMALCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_normal_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_lines_normal_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_normal_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_NORMALCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
      if [[ cmtssflag -eq 1 ]]; then
        # PLOT ONTO THE MAP DOCUMENT
        [[ -e ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${PSFILE}" >> plot.sh
        echo "sort < ${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_SSCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        # PLOT ONTO THE FLAT PROFILE PS
        [[ -e ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        [[ -e ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -W0.1p,black $RJOK $VERBOSE  >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
        echo "sort < ${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_SSCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

        # PLOT ONTO THE OBLIQUE PROFILE PS
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_pts_strikeslip_sel_proj.xyz -p -Sc0.03i -Gblack $RJOK $VERBOSE  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && [[ -e ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz ]] && echo "gmt psxy ${LINEID}_cmt_alt_lines_strikeslip_proj_final.xyz -p -W0.1p,black $RJOK $VERBOSE >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -p -E${CMT_SSCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
    fi

    # Plot the locations of profile points above the profile, adjusting for XOFFSET and summing the incremental distance if necessary.
    # ON THE MAP
    echo "awk < xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${PSFILE}" >> plot.sh
    echo "awk < xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${PSFILE}" >> plot.sh

    # ON THE FLAT PROFILES
    echo "awk < xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh
    echo "awk < xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR}>> ${LINEID}_flat_profile.ps" >> ${LINEID}_temp_plot.sh

    # ON THE OBLIQUE PLOTS
    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "awk < xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -p -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "awk < xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -p -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

    if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then
      # COMEBACK
      awk < ${LINEID}_all_data.txt '{
          if ($1 ~ /^[-+]?[0-9]*.*[0-9]+$/) { km[++c]=$1; }
          if ($2 ~ /^[-+]?[0-9]*.*[0-9]+$/) { val[++d]=$2; }
          if ($6 ~ /^[-+]?[0-9]*.*[0-9]+$/) { val[++d]=$6; }
        } END {
          asort(km);
          asort(val);
          print km[1], km[length(km)], val[1], val[length(val)]
        #  print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
      }' > ${LINEID}_limits.txt

      if [[ $xminflag -eq 1 ]]; then
        line_min_x=$(awk < ${LINEID}_limits.txt '{print $1}')
      else
        line_min_x=$min_x
      fi
      if [[ $xmaxflag -eq 1 ]]; then
        line_max_x=$(awk < ${LINEID}_limits.txt '{print $2}')
      else
        line_max_x=$max_x
      fi
      if [[ $zminflag -eq 1 ]]; then
        line_min_z=$(awk < ${LINEID}_limits.txt '{print $3}')
      else
        line_min_z=$min_z
      fi
      if [[ $zmaxflag -eq 1 ]]; then
        line_max_z=$(awk < ${LINEID}_limits.txt '{print $4}')
      else
        line_max_z=$max_z
      fi

      # Set minz to ensure that H=W
      if [[ $profileonetooneflag -eq 1 ]]; then
        info_msg "(-mob) Setting vertical aspect ratio to H=W for profile ${LINEID}"
        line_diffx=$(echo "$line_max_x - $line_min_x" | bc -l)
        line_hwratio=$(awk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
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
      #   awk < $distfile -v maxz=$max_z -v minz=$min_z -v profheight=${PROFILE_HEIGHT_IN} '{
      #     print $1, (maxz+minz)/2
      #   }' > xpts_$distfile
      # done

      # maxzval=$(awk -v maxz=$max_z -v minz=$min_z 'BEGIN {print (maxz+minz)/2}')

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

      echo "gmt psbasemap -py\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -JX\${PROFILE_WIDTH_IN}/\${PROFILE_HEIGHT_IN} -Bxaf+l\"${x_axis_label}\" -Byaf+l\"${z_axis_label}\" -BSEW -R\$line_min_x/\$line_max_x/\$line_min_z/\$line_max_z --MAP_FRAME_PEN=thinner,black -K > ${LINEID}_profile.ps" >> ${LINEID}_plot_start.sh

      # Concatenate the cross section plotting commands onto the script
      cat ${LINEID}_plot.sh >> ${LINEID}_plot_start.sh

      # Concatenate the terrain plotting commands onto the script.
      # If there is no top tile, we need to create some commands to allow a plot to be made correctly.

      if [[ -e ${LINEID}_topscript.sh ]]; then
        cat ${LINEID}_topscript.sh >> ${LINEID}_plot_start.sh
      else
        # COMEBACK
        echo "VEXAG=\${3}" > ${LINEID}_topscript.sh
        echo "dem_miny=-${MAXWIDTH_KM}" >> ${LINEID}_topscript.sh
        echo "dem_maxy=${MAXWIDTH_KM}" >> ${LINEID}_topscript.sh
        echo "dem_minz=10" >> ${LINEID}_topscript.sh
        echo "dem_maxz=-10" >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_RATIO=1" >> ${LINEID}_topscript.sh
        echo "PROFILE_DEPTH_IN=\$(echo \$PROFILE_DEPTH_RATIO \$PROFILE_HEIGHT_IN | awk '{print (\$1*(\$2+0))}' )i"  >> ${LINEID}_topscript.sh

        echo "yshift=\$(awk -v height=\${PROFILE_HEIGHT_IN} -v inc=\$PERSPECTIVE_INC 'BEGIN{print cos(inc*3.1415926/180)*(height+0)}')" >> ${LINEID}_topscript.sh
        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${line_max_z} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${line_min_z}/\${line_max_z}r -JZ\${PROFILE_HEIGHT_IN} -JX\${PROFILE_WIDTH_IN}/\${PROFILE_DEPTH_IN} -Byaf+l\"${y_axis_label}\" --MAP_FRAME_PEN=thinner,black -K -O >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        # Draw the box at the end of the profile. For other view angles, should draw the other box?

        echo "echo \"\$line_max_x \$dem_maxy \$line_max_z\" > ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_maxy \$line_min_z\" >> ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        echo "echo \"\$line_max_x \$dem_miny \$line_min_z\" >> ${LINEID}_rightbox.xyz" >> ${LINEID}_topscript.sh
        # NO -K
        echo "gmt psxyz ${LINEID}_rightbox.xyz -p -R -J -JZ -Wthinner,black -O >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh
#        echo "gmt psbasemap -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC}/\${dem_minz} -R\${line_min_x}/\${dem_miny}/\${line_max_x}/\${dem_maxy}/\${dem_minz}/\${dem_maxz}r -JZ\${ZSIZE}i -J -Bzaf -Bxaf --MAP_FRAME_PEN=thinner,black -K -O -Y\${yshift}i >> ${LINEID}_profile.ps" >> ${LINEID}_topscript.sh

        cat ${LINEID}_topscript.sh >> ${LINEID}_plot_start.sh
      fi

      echo "gmt psconvert ${LINEID}_profile.ps -A+m1i -Tf -F${LINEID}_profile" >> ${LINEID}_plot_start.sh

      # Execute plot script
      chmod a+x ${LINEID}_plot_start.sh
      echo "./${LINEID}_plot_start.sh \${PERSPECTIVE_AZ} \${PERSPECTIVE_INC} \${PERSPECTIVE_EXAG}" >> ./make_oblique_plots.sh

      # gmt psconvert ${LINEID}_profile.ps -A+m1i -Tf -F${LINEID}_profile

    fi # Finalize individual profile plots

    ### End of processing this profile.

    # Add profile X limits to all_data in case plotted data does not span profile.
    echo "$PROFILE_XMIN NaN NaN NaN NaN NaN" >> ${LINEID}_all_data.txt
    echo "$PROFILE_XMAX NaN NaN NaN NaN NaN" >> ${LINEID}_all_data.txt

    # Create the profile postscript plot
    # Profiles will be plotted by a master script that feeds in the appropriate parameters based on all profiles.
    echo "line_min_z=\$1" >> ${LINEID}_profile_plot.sh
    echo "line_max_z=\$2" >> ${LINEID}_profile_plot.sh
    echo "PROFILE_HEIGHT_IN=${PROFILE_HEIGHT_IN}" >> ${LINEID}_profile_plot.sh
    echo "PROFILE_WIDTH_IN=${PROFILE_WIDTH_IN}" >>${LINEID}_profile_plot.sh

    # Center the frame on the new PS document
    echo "gmt psbasemap -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -Bltrb -R${PROFILE_XMIN}/${PROFILE_XMAX}/\${line_min_z}/\${line_max_z} --MAP_FRAME_PEN=thinner,black -K -Xc -Yc >> ${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    cat ${LINEID}_temp_plot.sh >> ${LINEID}_profile_plot.sh
    echo "gmt psbasemap -Vn -BtESW+t\"${LINEID}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=thinner,black -R -J -O >> ${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    echo "gmt psconvert -Tf -A+m0.5i ${LINEID}_flat_profile.ps" >> ${LINEID}_profile_plot.sh
    echo "./${LINEID}_profile_plot.sh \$zmin \$zmax" >> ./make_flat_profiles.sh
    chmod a+x ./${LINEID}_profile_plot.sh

    # Increment the profile number
    PROFILE_INUM=$(echo "$PROFILE_INUM + 1" | bc)
  fi
done < $TRACKFILE

# Set a buffer around the data extent to give a nice visual appearance when setting auto limits
cat *_all_data.txt > all_data.txt

awk < all_data.txt '{
    if ($1 ~ /^[-+]?[0-9]*.*[0-9]+$/) { km[++c]=$1; }
    if ($2 ~ /^[-+]?[0-9]*.*[0-9]+$/) { val[++d]=$2; }
    if ($6 ~ /^[-+]?[0-9]*.*[0-9]+$/) { val[++d]=$6; }
  } END {
    asort(km);
    asort(val);
    print km[1], km[length(km)], val[1], val[length(val)]
  #  print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
}' > limits.txt

# These are hard data limits.

# If we haven't manually specified a limit, set it using the buffered data limit
# But for deep data sets, this will add a buffer to max_z that once one-to-one is applied
# will cause the section to be way too low. So we need to do the buffer after the one-to-one.

if [[ $xminflag -eq 1 ]]; then
  min_x=$(awk < limits.txt '{print $1}')
fi
if [[ $xmaxflag -eq 1 ]]; then
  max_x=$(awk < limits.txt '{print $2}')
fi
if [[ $zminflag -eq 1 ]]; then
  min_z=$(awk < limits.txt '{print $3}')
fi
if [[ $zmaxflag -eq 1 ]]; then
  max_z=$(awk < limits.txt '{print $4}')
fi

# Set minz/maxz to ensure that H=W
if [[ $profileonetooneflag -eq 1 ]]; then
  info_msg "Setting vertical aspect ratio to H=W"
  diffx=$(echo "$max_x - $min_x" | bc -l)
  hwratio=$(awk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
  diffz=$(echo "$hwratio * $diffx" | bc -l)
  min_z=$(echo "$max_z - $diffz" | bc -l)
  info_msg "new min_z is $min_z"
fi

# Add a buffer around the data if we haven't asked for hard limits.

# Create the data files that will be used to plot the profile vertex points above the profile

for distfile in *_dist_km.txt; do
  awk < $distfile -v maxz=$max_z -v minz=$min_z -v profheight=${PROFILE_HEIGHT_IN} '{
    print $1, (maxz+minz)/2
  }' > xpts_$distfile
done

maxzval=$(awk -v maxz=$max_z -v minz=$min_z 'BEGIN {print (maxz+minz)/2}')

echo "echo \"0 $maxzval\" | gmt psxy -J -R -K -O -St0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.7p,black -Gwhite >> ${PSFILE}" >> plot.sh


LINETEXT=$(cat IDfile.txt)
# echo LINETEXT is "${LINETEXT}"

# FOR THE MAP
# Plot the frame. This sets -R and -J for the actual plotting script commands in plot.sh

echo "gmt psbasemap -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -X${PROFILE_X} -Y${PROFILE_Y} -Bltrb -R$min_x/$max_x/$min_z/$max_z --MAP_FRAME_PEN=thinner,black -K -O >> ${PSFILE}" > newplot.sh
cat plot.sh >> newplot.sh
echo "gmt psbasemap -Vn -BtESW+t\"${LINETEXT}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=thinner,black $RJOK >> ${PSFILE}" >> newplot.sh

# Execute plot script
chmod a+x ./newplot.sh
./newplot.sh

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

# The idea here is to return to the correct X,Y position to allow further plotting on the map by tectoplot.
echo "0 -10" | gmt psxy -Sc0.01i -J -R -O -K -X$PROFILE_X -Y$PROFILE_Y -Vn >> "${PSFILE}"
