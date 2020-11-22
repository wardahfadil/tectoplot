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

echo "#!/bin/bash" > ./make_oblique_plots.sh
echo "PERSPECTIVE_AZ=\${1}" >> ./make_oblique_plots.sh
echo "PERSPECTIVE_INC=\${2}" >> ./make_oblique_plots.sh

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
  if [[ ${FIRSTWORD:0:1} == "^" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $5 }' >> widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "$" ]]; then
    head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print $3 }' >> widthlist.txt
  elif [[ ${FIRSTWORD:0:1} == "%" ]]; then
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

# Search for, parse, and pre-process datasets to be plotted
for i in $(seq 1 $k); do
  FIRSTWORD=$(head -n ${i} $TRACKFILE | tail -n 1 | awk '{print $1}')
  if [[ ${FIRSTWORD:0:1} == "^" ]]; then           # Found a gridded dataset; cut to AOI and store as a nc file
    myarr=($(head -n ${i} $TRACKFILE  | tail -n 1 | awk '{ print }'))

    # GRIDFILE 0.001 .1k 40k 0.1k
    grididnum[$i]=$(echo "grid${i}")
    gridfilelist[$i]=$(echo "$(cd "$(dirname "${myarr[1]}")"; pwd)/$(basename "${myarr[1]}")")
    gridfilesellist[$i]=$(echo "cut_$(basename "${myarr[1]}").nc")
    gridzscalelist[$i]="${myarr[2]}"
    gridspacinglist[$i]="${myarr[3]}"
    gridwidthlist[$i]="${myarr[4]}"
    gridsamplewidthlist[$i]="${myarr[5]}"

    info_msg "Loading swath profile grid: ${gridfilesellist[$i]}: Zscale ${gridzscalelist[$i]}, Spacing: ${gridspacinglist[$i]}, Width: ${gridwidthlist[$i]}, SampWidth: ${gridsamplewidthlist[$i]}"
    # Cut the grid to the AOI and multiply by its ZSCALE
    gmt grdcut ${gridfilelist[$i]} -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Gtmp.nc --GMT_HISTORY=false
    gmt grdmath tmp.nc ${gridzscalelist[$i]} MUL = ${gridfilesellist[$i]}
  elif [[ ${FIRSTWORD:0:1} == ":" ]]; then
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

  elif [[ ${FIRSTWORD:0:1} == "$" || ${FIRSTWORD:0:1} == ">" ]]; then        # Found an XYZ dataset
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
    [[ ${FIRSTWORD:0:1} == ">" ]] && xyzscaleeqsflag[$i]=1

    # echo "Found a dataset to load: ${xyzfilelist[$i]}"
    # echo "Scale factor for Z units is ${xyzunitlist[$i]}"
    # echo "Commands are ${xyzcommandlist[$i]}"
    # echo "Scale flag is ${xyzscaleeqsflag[$i]}"
  elif [[ ${FIRSTWORD:0:1} == "%" ]]; then         # Found a CMT dataset; currently, we only do one
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
        info_msg "Updated line $LINEID by shifting $XOFFSET_NUM km to match $ZEROFILE"
        tail -n 1 intersect.txt >> all_intersect.txt
      fi
    fi

    for i in ${!ptgridfilelist[@]}; do
      gridfileflag=1
      gmt sample1d ${LINEID}_trackfile.txt -Af -fg -I${ptgridspacinglist[$i]} > ${LINEID}_${ptgrididnum[$i]}_trackinterp.txt

      # Handle the XOFFSET displacement here directly.
      gmt mapproject -G+uk+a ${LINEID}_${ptgrididnum[$i]}_trackinterp.txt | awk -v xoff="${XOFFSET_NUM}" '{ print $1, $2, $3 + xoff }' > ${LINEID}_${ptgrididnum[$i]}_trackdist.txt
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
      echo "gmt psxy -Vn -R -J -O -K -L ${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> "${PSFILE}"" >> plot.sh
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -R -J -O -K -L ${LINEID}_${ptgrididnum[$i]}_data.txt ${ptgridcommandlist[$i]} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

      # [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&
      # ${LINEID}_${ptgrididnum[$i]_profile.ps

      grep "^[-*0-9]" ${LINEID}_${ptgrididnum[$i]}_data.txt >> ${LINEID}_all_data.txt
    done

    for i in ${!gridfilelist[@]}; do
      gridfileflag=1

      # echo "gmt grdtrack -G${gridfilesellist[$i]} ${LINEID}_trackfile.txt -C${gridwidthlist[$i]}/${gridsamplewidthlist[$i]}/${gridspacinglist[$i]}+lr -Ar > ${LINEID}_${grididnum[$i]}_profiletable.txt"
      gmt grdtrack -Vn -G${gridfilesellist[$i]} ${LINEID}_trackfile.txt -C${gridwidthlist[$i]}/${gridsamplewidthlist[$i]}/${gridspacinglist[$i]} -Af > ${LINEID}_${grididnum[$i]}_profiletable.txt
      grep ">" ${LINEID}_${grididnum[$i]}_profiletable.txt | awk -F- '{print $3}' | awk -F" " '{print $1}' > ${LINEID}_${grididnum[$i]}_profilepts.txt

      # Adding +0 to dinc changes "0.3k" to "0.3"
      # Shift the data according to XOFFSET_NUM value
      awk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" '{ print ( $1 * (dinc + 0) + xoff ) }' < ${LINEID}_${grididnum[$i]}_profilepts.txt > ${LINEID}_${grididnum[$i]}_profilekm.txt

      awk '{
        if ($1 == ">") {
          printf("\n")
        } else {
          printf("%s ", $5)
        }
      }' < ${LINEID}_${grididnum[$i]]}_profiletable.txt | sed '1d' > ${LINEID}_${grididnum[$i]}_profiledata.txt

      # First find the maximum value of X. We want X to be negative or zero for the block plot.
      MAX_X_VAL=$(awk < P1_grid2_profiletable.txt 'BEGIN{maxx=-999999} { if ($1 != ">" && $1 > maxx) {maxx = $1 } } END{print maxx}')
      echo MAX_X = $MAX_X_VAL

      if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then
        awk -v xoff="${XOFFSET_NUM}" -v dinc="${gridspacinglist[$i]}" -v maxx=$MAX_X_VAL '
          BEGIN{offset=0;minX=99999999;maxX=-99999999; minY=99999999; maxY=-99999999; minZ=99999999; maxZ=-99999999}
          {
            if ($1 == ">") {
              split($5, vec, "-");
              offset=vec[3]
            } else {
              xval=$3
              yval=(offset * (dinc + 0) + xoff);
              zval=$5
              if (zval == "NaN") {
                print xval*1000 "," yval*1000 "," zval
              } else {
                print xval*1000 "," yval*1000 "," zval*1000
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
            printf "%d %d %d %d %f %f", minX*1000, maxX*1000, minY*1000, maxY*1000, minZ*1000, maxZ*1000 > "./profilerange.txt"
          }' < ${LINEID}_${grididnum[$i]]}_profiletable.txt | sed '1d' > ${LINEID}_${grididnum[$i]}_data.csv
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

        minx=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $1}')
        maxx=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $2}')
        miny=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $3}')
        maxy=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $4}')
        minz=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $5}')
        maxz=$(awk < ${LINEID}_${grididnum[$i]}_profilerange.txt '{print $6}')
        echo minx $minx maxx $maxx miny $miny maxy $maxy minz $minz maxz $maxz

        xtoyratio=$(echo "($maxx - $minx)/($maxy - $miny)" | bc -l)
        ztoyratio=$(echo "($maxz - $minz)/($maxy - $miny)" | bc -l)

        ysize=7
        xsize=$(echo "$ysize * $xtoyratio" | bc -l)
        zsize=$(echo "$ysize * $ztoyratio * $PERSPECTIVE_EXAG" | bc -l)
        numx=$(echo "($maxx - $minx)/$PERSPECTIVE_RES" | bc)
        numy=$(echo "($maxy - $miny)/$PERSPECTIVE_RES" | bc)
        # echo numx $numx numy $numy

        gdal_grid -of "netCDF" -txe $minx $maxx -tye $miny $maxy -outsize $numx $numy -zfield field_3 -a nearest -l ${LINEID}_${grididnum[$i]}_data ${LINEID}_${grididnum[$i]}_data.vrt ${LINEID}_${grididnum[$i]}_newgrid.nc

        echo "#!/bin/bash" > ${LINEID}_maketopo.sh
        echo "PERSPECTIVE_AZ=\${1}" >> ${LINEID}_maketopo.sh
        echo "PERSPECTIVE_INC=\${2}" >> ${LINEID}_maketopo.sh
        echo "azplus=\$(echo \"\$PERSPECTIVE_AZ-90\" | bc -l)" >>  ${LINEID}_maketopo.sh
        echo "gmt grdview ${LINEID}_${grididnum[$i]}_newgrid.nc -R${minx}/${maxx}/${miny}/${maxy}/${minz}/${maxz} -p\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -JX${xsize}i/${ysize}i -JZ${zsize}i -W0p,white -Ctopo.cpt -I+d -Qi300  > ${LINEID}_${grididnum[$i]}_topo.ps" >> ${LINEID}_maketopo.sh
        echo "gmt psconvert ${LINEID}_${grididnum[$i]}_topo.ps -A+m1i -Tf -F${LINEID}_${grididnum[$i]}_topo" >> ${LINEID}_maketopo.sh
        chmod a+x ./${LINEID}_maketopo.sh
        echo "./${LINEID}_maketopo.sh \${PERSPECTIVE_AZ} \${PERSPECTIVE_INC}" >> ./make_oblique_plots.sh
      fi

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

      echo "gmt psxy -Vn ${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> "${PSFILE}"" >> plot.sh
      echo "gmt psxy -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> "${PSFILE}"" >> plot.sh
      echo "gmt psxy -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> "${PSFILE}"" >> plot.sh

      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn ${LINEID}_${grididnum[$i]}_profileenvelope.txt -t$SWATHTRANS -R -J -O -K -G${LIGHTERCOLOR}  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -R -J -O -K -t$SWATHTRANS -G${LIGHTCOLOR} ${LINEID}_${grididnum[$i]}_profileq13envelope.txt >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -R -J -O -K -W$SWATHLINE_WIDTH,$COLOR ${LINEID}_${grididnum[$i]}_profiledatamedian.txt >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

      ## Output data files to THIS_DIR
      echo "km_along_profile q0 q25 q25 q75 q100" > $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt
      paste ${LINEID}_${grididnum[$i]}_profilekm.txt ${LINEID}_${grididnum[$i]}_profilesummary.txt >> $THIS_DIR${LINEID}_${grididnum[$i]}_data.txt
      paste ${LINEID}_${grididnum[$i]}_profilekm.txt ${LINEID}_${grididnum[$i]}_profilesummary.txt >> ${LINEID}_all_data.txt
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

      # Only keep the lines that have

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

        awk < finaldist_${FNAME} -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1))}' > stretch_finaldist_${FNAME}
        echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT p" >> plot.sh
        echo "gmt psxy stretch_finaldist_${FNAME} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${PSFILE}" >> plot.sh
        echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> plot.sh

        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "OLD_PROJ_LENGTH_UNIT=\$(gmt gmtget PROJ_LENGTH_UNIT -Vn)" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT p" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy stretch_finaldist_${FNAME} -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -G$COLOR -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} ${xyzcommandlist[i]} $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt gmtset PROJ_LENGTH_UNIT \$OLD_PROJ_LENGTH_UNIT" >> ${LINEID}_plot.sh

      else
        echo "gmt psxy finaldist_${FNAME} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> "${PSFILE}"" >> plot.sh
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "gmt psxy finaldist_${FNAME} -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -G$COLOR ${xyzcommandlist[i]} -R -J -O -K  -Vn  >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi

      rm -f presort_${FNAME}
    done # XYZ data

    if [[ $cmtfileflag -eq 1 ]]; then

      # Select CMT events that are closest to this line vs other profile lines in the project
      # From cmt_thrust_sel.txt cmt_normal_sel.txt cmt_strikeslip_sel.txt

      awk < cmt_thrust.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4}' > tmpbuf.txt
      paste tmpbuf.txt cmt_thrust.txt | awk -v lineid=$PROFILE_INUM '{
        if ($1==lineid) {
          for (i=2;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_thrust_sel.txt

      awk < cmt_normal.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4}' > tmpbuf.txt
      paste tmpbuf.txt cmt_normal.txt | awk -v lineid=$PROFILE_INUM '{
        if ($1==lineid) {
          for (i=2;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_normal_sel.txt

      awk < cmt_strikeslip.txt '{print $1, $2}' | gmt mapproject -R${buf_min_x}/${buf_max_x}/${buf_min_z}/${buf_max_z} -Lline_buffer.txt+p -fg -Vn | awk '{print $4}' > tmpbuf.txt
      paste tmpbuf.txt cmt_strikeslip.txt | awk -v lineid=$PROFILE_INUM '{
        if ($1==lineid) {
          for (i=2;i<=NF;++i) {
            printf "%s ", $(i)
          }
          printf("\n")
        }
      }' > cmt_strikeslip_sel.txt

      # For each line segment in the profile
      numprofpts=$(cat ${LINEID}_trackfile.txt | wc -l)
      numsegs=$(echo "$numprofpts - 1" | bc -l)

      # For each line segment
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

      # echo "CMTRESCALE=${CMTRESCALE}"
      # gmt psmeca -E"${CMT_THRUSTCOLOR}" -Z$CPTDIR"neis2.cpt" -Sc"$CMTRESCALE"i/0 cmt_thrust.txt -L0.25p,black $RJOK "${VERBOSE}" >> map.ps

      if [[ cmtthrustflag -eq 1 ]]; then
        echo "sort < ${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_THRUSTCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh

        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_thrust_profile_data.txt -n -k 11 | gmt psmeca -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -E${CMT_THRUSTCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

        # gmt psmeca -E"${CMT_THRUSTCOLOR}" -Z$CPTDIR"neis2.cpt" -Sc"$CMTRESCALE"i/0 cmt_thrust.txt -L0.25p,black $RJOK "${VERBOSE}" >> map.ps
      fi
      if [[ cmtnormalflag -eq 1 ]]; then
         echo "sort < ${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_NORMALCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh
        # gmt psmeca -E"${CMT_NORMALCOLOR}" -Z$CPTDIR"neis2.cpt" -Sc"$CMTRESCALE"i/0 cmt_normal.txt -L0.25p,black $RJOK "${VERBOSE}" >> map.ps
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_normal_profile_data.txt -n -k 11 | gmt psmeca -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -E${CMT_NORMALCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

      fi
      if [[ cmtssflag -eq 1 ]]; then
        echo "sort < ${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -E"${CMT_SSCOLOR}" -S${CMTLETTER}"${CMTRESCALE}"i/0 -G$COLOR $CMTCOMMANDS $RJOK "${VERBOSE}" >> "${PSFILE}"" >> plot.sh
        # gmt psmeca -E"${CMT_SSCOLOR}" -Z$CPTDIR"neis2.cpt" -Sc"$CMTRESCALE"i/0 cmt_strikeslip.txt -L0.25p,black $RJOK "${VERBOSE}" >> map.ps
        [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "sort < ${LINEID}_cmt_strikeslip_profile_data.txt -n -k 11 | gmt psmeca -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -E${CMT_SSCOLOR} -S${CMTLETTER}${CMTRESCALE}i/0 -G$COLOR $CMTCOMMANDS $RJOK ${VERBOSE} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
      fi
    fi

    # Plot the locations of profile points above the profile, adjusting for XOFFSET and summing the incremental distance if necessary.
    echo "awk < xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${PSFILE}" >> plot.sh
    echo "awk < xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${PSFILE}" >> plot.sh

    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "awk < xpts_${LINEID}_dist_km.txt '(NR==1) { print \$1 + $XOFFSET_NUM, \$2}' | gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} -G${COLOR} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh
    [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] &&  echo "awk < xpts_${LINEID}_dist_km.txt 'BEGIN {runtotal=0} (NR>1) { print \$1+runtotal+$XOFFSET_NUM, \$2; runtotal=\$1+runtotal; }' | gmt psxy -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -J -R -K -O -Si0.1i -Ya${PROFHEIGHT_OFFSET}i -W0.5p,${COLOR} >> ${LINEID}_profile.ps" >> ${LINEID}_plot.sh

    if [[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]]; then

      awk < ${LINEID}_all_data.txt '{
          km[++c]=$1;
          val[++d]=$2;
          val[++d]=$6;
        } END {
          asort(km);
          asort(val);
          print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
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
        info_msg "Setting vertical aspect ratio to H=W for profile ${LINEID}"
        line_diffx=$(echo "$line_max_x - $line_min_x" | bc -l)
        line_hwratio=$(awk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
        line_diffz=$(echo "$line_hwratio * $line_diffx" | bc -l)
        line_min_z=$(echo "$line_max_z - $line_diffz" | bc -l)
        info_msg "Profile ${LINEID} new min_z is $line_min_z"
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

      # Plot the frame. This sets -R and -J for the actual plotting script commands in plot.sh
      echo "#!/bin/bash" > ${LINEID}_plot_final.sh
      echo "PERSPECTIVE_AZ=\${1}" >> ${LINEID}_plot_final.sh
      echo "PERSPECTIVE_INC=\${2}" >> ${LINEID}_plot_final.sh
      echo "gmt psbasemap -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -Bltrb -R$line_min_x/$line_max_x/$line_min_z/$line_max_z --MAP_FRAME_PEN=0p,black -K > ${LINEID}_profile.ps" >> ${LINEID}_plot_final.sh
      cat ${LINEID}_plot.sh >> ${LINEID}_plot_final.sh
      echo "gmt psbasemap -px\${PERSPECTIVE_AZ}/\${PERSPECTIVE_INC} -Vn -BtESW+t\"${LINETEXT}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=0.5p,black -R -J -O >> ${LINEID}_profile.ps" >> ${LINEID}_plot_final.sh
      echo "gmt psconvert ${LINEID}_profile.ps -A+m1i -Tf -F${LINEID}_profile" >> ${LINEID}_plot_final.sh
      # Execute plot script
      chmod a+x ${LINEID}_plot_final.sh
      echo "./${LINEID}_plot_final.sh \${PERSPECTIVE_AZ} \${PERSPECTIVE_INC}" >> ./make_oblique_plots.sh

      # gmt psconvert ${LINEID}_profile.ps -A+m1i -Tf -F${LINEID}_profile

    fi # Finalize individual profile plots

    PROFILE_INUM=$(echo "$PROFILE_INUM + 1" | bc)
  fi
done < $TRACKFILE

# Set a buffer around the data extent to give a nice visual appearance when setting auto limits
cat *_all_data.txt > all_data.txt

awk < all_data.txt '{
    km[++c]=$1;
    val[++d]=$2;
    val[++d]=$6;
  } END {
    asort(km);
    asort(val);
    print km[1]-(km[length(km)]-km[1])*0.01,km[length(km)]+(km[length(km)]-km[1])*0.01,val[1]-(val[length(val)]-val[1])*0.1,val[length(val)]+(val[length(val)]-val[1])*0.1
}' > limits.txt

# If we haven't manually specified a limit, set it using the buffered data limit

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

# Set minz to ensure that H=W
if [[ $profileonetooneflag -eq 1 ]]; then
  info_msg "Setting vertical aspect ratio to H=W"
  diffx=$(echo "$max_x - $min_x" | bc -l)
  hwratio=$(awk -v h=${PROFILE_HEIGHT_IN} -v w=${PROFILE_WIDTH_IN} 'BEGIN { print (h+0)/(w+0) }')
  diffz=$(echo "$hwratio * $diffx" | bc -l)
  min_z=$(echo "$max_z - $diffz" | bc -l)
  info_msg "new min_z is $min_z"
fi

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

# Plot the frame. This sets -R and -J for the actual plotting script commands in plot.sh

echo "gmt psbasemap -Vn -JX${PROFILE_WIDTH_IN}/${PROFILE_HEIGHT_IN} -X${PROFILE_X} -Y${PROFILE_Y} -Bltrb -R$min_x/$max_x/$min_z/$max_z --MAP_FRAME_PEN=0p,black -K -O >> ${PSFILE}" > newplot.sh
cat plot.sh >> newplot.sh
echo "gmt psbasemap -Vn -BtESW+t\"${LINETEXT}\" -Baf -Bx+l\"Distance (km)\" --FONT_TITLE=\"10p,Helvetica,black\" --MAP_FRAME_PEN=0.5p,black $RJOK >> ${PSFILE}" >> newplot.sh

# Execute plot script
chmod a+x ./newplot.sh
./newplot.sh

[[ $PLOT_SECTIONS_PROFILEFLAG -eq 1 ]] && chmod a+x ./make_oblique_plots.sh && ./make_oblique_plots.sh ${PERSPECTIVE_AZ} ${PERSPECTIVE_INC}

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
