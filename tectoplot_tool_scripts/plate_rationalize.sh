# plate_rationalize.sh
# Kyle Bradley, June 2020

# Script is currently not working (ripped from tectoplot)

# This script takes as input a multisegment (GMT style) plate file consisting
# of closed polygons. These polygons might have improper orientation (CW/CCW),
# might cross the international dateline, or might encompass a geographic pole.
# All of these conditions cause problems with tectoplot.

# This script produces as output a corrected plate polygon dataset.

# Input plates file is in the GMT multisegment format:
# > ID
# lon lat
# lon lat
# ...
# lon lat
# > ID2
# lon lat
# ...
# lon lat

PLATES="/path/to/plate/file.txt"

[[ $narrateflag -eq 1 ]] && echo using plates file $PLATES



# First thing to do is close all polygons. If we do this before we uniq, we don't
# actually have to worry about much.

cat $PLATES | awk 'BEGIN {fflag=0} {
  if ($0~/>/) {
    if (fflag==1) {
      print plotstr
    }
    print
    getline
    plotstr=$0
    print
    fflag=1
  } else {
    print
  }
}' > platesref.txt

# Plate data can either be from -180:180 or 0:360. Which one is preferred depends
# on which area of Earth we are working with. Plates need to be split across the
# longitude jump or else the GMT polygon commands get confused.

# First remove any duplicate points that are adjacent within the file.
# MORVEL data files have a TON of duplicated edge points...

uniq platesref.txt > platesrefuniq.txt
uniq -d platesref.txt > platesrefuniq.txt_del  # Record the deleted points in case

# Make the closed plates file

gmt spatial -F platesrefuniq.txt > platesclosed.txt

# However, GMT strips the plate names.
#
# # Reintroduce the plate names
# grep ">" platesrefuniq.txt > platescw_ids.txt
#
# IFS=$'\n' read -d '' -r -a pids < platescw_ids.txt
# i=0
# rm -f platescw_tmp.txt
# # Now read through the file and replace > with the next value in the pids array. This puts the names back in that GMT spatial stripped out for no good reason at all...
# while read p; do
#   if [[ ${p:0:1} == '>' ]]; then
#     printf  "%s\n" "${pids[i]}" >> platescw_tmp.txt
#     i=$i+1
#   else
#     printf "%s\n" "$p" >> platescw_tmp.txt
#   fi
#   # We will only plot kinematic arrows for double points; not triple (or more...) or single
# done < platescw.txt

# platescw_tmp.txt now contains clockwise oriented polygons with headers.

# Reformat to OGR_GMT polygon WGS84 file in order to split along dateline

echo "# @VGMT1.0 @GPOLYGON @Nname" > platesref.gmt
echo "# @Jp\"+proj=longlat +ellps=WGS84 \"" >> platesref.gmt
echo "# FEATURE_DATA" >> platesref.gmt

cat platesrefuniq.txt | awk '{
  if ($1 == ">") {
    print $1;
    printf "# @D\"%s\"\n", $2;
    print "# @P";
  }
  else {
    if ($1 > 180) {
      print $1, $2
    } else {
      print $1, $2
    }
  }
}' >> platesref.gmt

# Split polygons along dateline
ogr2ogr -wrapdateline wrap.gmt platesref.gmt

# Now re-parse the split polygons and output back to the original > ID header format,
# but we add an integer after each new individual plate segment.

cat wrap.gmt | awk '{
  if ($0~/#/) {
    if ($0~/# @D/) {
      split($0,arr,"@D");
      curplate=arr[2];
      indval=0;
    } else {
      if ($0~/# @P/) {
        indval = indval + 1;
        printf("> %s_%d\n", curplate, indval)
      }
    }
  } else {
    if ($0!~/>/){
      print
    }
  }
}' > platesref_recon2.txt

# platesref_recon2.txt contains polygons in > ID_N header format.

# Now clip the polygons to the AOI.

# This was a kludge to patch in the Kreemer dataset...
#cat $GMMFIXEDPLATES > platesref_recon2.txt

echo "# @VGMT1.0 @GPOLYGON @Nname" > morvelfixed.gmt
echo "# @Jp\"+proj=longlat +ellps=WGS84 \"" >> morvelfixed.gmt
echo "# FEATURE_DATA" >> morvelfixed.gmt

cat platesref_recon2.txt | awk '{
  if ($1 == ">") {
    print $1;
    printf "# @D\"%s\"\n", $2;
    print "# @P";
  }
  else {
    if ($1 > 180) {
      print $1, $2
    } else {
      print $1, $2
    }
  }
}' >> morvelfixed.gmt

# Not sure how this is supposed to fit in...
gmt spatial platesref_recon2.txt -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C | awk '{print $1, $2}' > map_plates_clip.txt

# map_plates_clip.txt now has adequately clipped plate polygons labeled by > NA_1 etc.
# There can be multiple polygons with the same Euler pole, NA_1, NA_2, etc.
# Most plates will be NA_1
# We just need to create an Euler pole file that includes all polygons.
# Also haven't confirmed the behavior of the polar cap polygons

# The only reason to clip the polygons is to reduce the points we consider and to discover
# which plates are within the field of view.
# However, we can just clip the points and not the polygons?

#gmt spatial $PLATES -C -R$CLIPMINLON/$CLIPMAXLON/$CLIPMINLAT/$CLIPMAXLAT | awk '{print $1, $2}' > map_plates_clip.txt
#gmt spatial platescw_tmp.txt -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C | awk '{print $1, $2}' > map_plates_clip.txt

# Kludge section to manually fix cropped polygon corners. UGGGH
if [[ fix1flag -eq 1 ]]; then
  # map_plates_clip has closed polygons but the corners might be the wrong ones.
  cat map_plates_clip.txt | awk -v c1="${FIX1STR1}" -v c2="${FIX1STR2}" -v c3="${FIX1STR3}" -v c4="${FIX1STR4}" -v plate=$FIX1PLATE -v minlat=$MINLAT -v maxlat=$MAXLAT -v minlon=$MINLON -v maxlon=$MAXLON 'BEGIN {i=1; }{
    if ($1 == ">") {
      curplate = $2
    }
    if (curplate == plate) {
      if (($1 == minlon && $2 == minlat) || ($1 == minlon && $2 == maxlat) || ($1 == maxlon && $2 == minlat) || ($1 == maxlon && $2 == maxlat)) {
        didflag=0;
        if (i==1) {
          if (c1=="a") { print minlon, minlat }
          if (c1=="b") { print minlon, maxlat }
          if (c1=="c") { print maxlon, maxlat }
          if (c1=="d") { print maxlon, minlat }
          didflag=1;
        }
        if (i==2) {
          if (c2=="a") { print minlon, minlat }
          if (c2=="b") { print minlon, maxlat }
          if (c2=="c") { print maxlon, maxlat }
          if (c2=="d") { print maxlon, minlat }
          didflag=1;
        }
        if (i==3) {
          if (c3=="a") { print minlon, minlat }
          if (c3=="b") { print minlon, maxlat }
          if (c3=="c") { print maxlon, maxlat }
          if (c3=="d") { print maxlon, minlat }
          didflag=1;
        }
        if (i==4) {
          if (c4=="a") { print minlon, minlat }
          if (c4=="b") { print minlon, maxlat }
          if (c4=="c") { print maxlon, maxlat }
          if (c4=="d") { print maxlon, minlat }
          didflag=1;
        }
        if (didflag == 1) {
          i=i+1;
        }
        else {
          print
        }
      }
      else {
        print;
      }
    }
    else {
      print;
    }
    }' > cornerrep.txt
    echo "Fixed first plate corners and updated map_plates_clip.txt. Updating polygon orientation using gmt spatial "
    gmt spatial cornerrep.txt -E+n > cornerrep_orient.txt  # CW orientation

    grep ">" cornerrep.txt > cornerrep_ids.txt

    IFS=$'\n' read -d '' -r -a pids < cornerrep_ids.txt
    i=0
    rm -f map_plates_clip.txt
    # Now read through the file and replace > with the next value in the pids array. This puts the names back in that GMT spatial stripped out for no good reason at all...
    while read p; do
      if [[ ${p:0:1} == '>' ]]; then
        printf  "%s\n" "${pids[i]}" >> map_plates_clip.txt
        i=$i+1
      else
        printf "%s\n" "$p" >> map_plates_clip.txt
      fi
      # We will only plot kinematic arrows for double points; not triple (or more...) or single
    done < cornerrep_orient.txt
fi

##### NOTE: None of the previous section is required IF we can appropriately crop the plate plate_polygons
##### Specific requirements here:
##### - map_plates_clip.txt is closed polygons correctly defined and clockwise oriented
##### map_plates_clip.txt does not end in a > header yet

##### Make the polygons clockwise
