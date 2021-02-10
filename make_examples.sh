#!/bin/bash
# tectoplot examples
#
# https://github.com/kyleedwardbradley/tectoplot
# Kyle Bradley, Nanyang Technological University, Singapore


NUMEXAMPLES=19

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
EXAMPLEDIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd )/examples/"
EXAMPLEDATA="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd )/data_examples/"


declare -a on_exit_items

function cleanup_on_exit()
{
      for i in "${on_exit_items[@]}"; do
        if [[ $CLEANUP_FILES -eq 1 ]]; then
          rm -f $i
        fi
      done
}

# Be sure to only cleanup files that are in the temporary directory

function cleanup()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        trap cleanup_on_exit EXIT
    fi
}

cleanup trench.xy profile.control gmt.history

mkdir -p $EXAMPLEDIR
cd $EXAMPLEDIR

if [[ $# -eq 0 ]]; then
  MAKENUMS=($(echo "$(seq 1 $NUMEXAMPLES)"))
else
  MAKENUMS=($(echo $@))
fi

for i in ${MAKENUMS[@]}; do
  echo Example $i
  case $i in
    1)
      echo "Example 1: Four global plots in one PDF" > example1.txt
      tectoplot -n -command -RJ N      -t 10m -gres 30 -title "Robinson"                                                    -pss 8 -a l --keepopenps    -z -zmag 7 10
      tectoplot -n -command -RJ W 45   -t 10m -gres 30 -title "Mollweide" -pos  9i    0i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l --keepopenps    -c -cmag 7 10
      tectoplot -n -command -RJ H 135  -t 10m -gres 30 -title "Hammer"    -pos -9i -5.5i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l --keepopenps    -z -zmag 8 10
      tectoplot -n -command -RJ R -180 -t 10m -gres 30 -title "Winkel"    -pos  9i -0.5i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l          -o example1
    ;;

    2)
      echo "Example 2: Two stereographic global plots in one PDF" > example2.txt
      tectoplot -n -command -RJ S 100 10   -t 10m -gres 120 -tshade --legend -title "Stereo 100E/10N" -tm ./newtmp/                     -pss 5 -a l             --keepopenps
      tectoplot -n -command -RJ S -80 -10  -t 10m -gres 120 -tshade --legend -title "Stereo 80W/10S" -pos  0i -6.5i -ips ./newtmp/map.ps  -pss 5 -a l -o example2
      rm -rf ./newtmp/
    ;;

    3)
      echo "Example 3: Regional seismotectonic map with Slab2" > example3.txt
      tectoplot -n -t -gres 120 -b c -z -c -a f -command -title "Solomon Islands seismicity" \
                --legend -author -o example3
    ;;

    4) # Example 4: Greece, GEBCO20 topo 50% transparent, GBM blocks,
       # UTM projection, GPS velocities relative to Africa, legend"
      echo "Example 4: GPS velocities and tectonic blocks" > example4.txt
      tectoplot -n -r GR -t GEBCO20 -tt 50 -gres 100 -RJ UTM -p GBM Nubia -pe -pl -g AF -i 2 \
                -setvars { GPS_FILLCOLOR black PLATELABEL_SIZE 10p } -author -command \
                --legend -title "Aegean GPS velocities and blocks" -o example4
    ;;

    5) # Example 5: Southern Taiwan, GMRT/SRTM topo, slopeshade, labeled
       # ISC seismicity, CMT at ORIGIN, legend"
      echo "Example 5: Topography and seismicity" > example5.txt
      tectoplot -n -r 120.5 120.8 22.4 23 -t BEST -tsl -pgo -pgs 0.1 -pss 4 \
                -zcat ISC -z -c ORIGIN --legend -author -command \
                -setvars { SEISSTRETCH_REFMAG 4 } -eqlabel 5.5 mag -o example5
    ;;

    6) # Example 6: Automated profile across the Izu-Ogasawaram Trench (Japan),
       #            one-to-one, CMT+seis+swath bathymetry, SLAB2, UTM projection
       #            Makes oblique profile using endpoint codes, and then adjusts view/vexag
      echo "Example 6: Profile across subduction zone seismicity" > example6.txt
      tectoplot -n -r 135 145 25 35 -RJ UTM -t GEBCO1 -gres 120 -tt 50 -z -c -b c -a l \
                -aprof BW 100k 1k -pss 7 -author -mob 220 20 5 1 -setvars \
                { SPROF_MINELEV -600 } -o example6

      cd tempfiles_to_delete/
      cp profiles/P_BW_profile.pdf ../example6_profile_220_20_5.pdf

      ./make_oblique_plots.sh 140 30 8
      cp profiles/P_BW_profile.pdf ../example6_profile_140_30_8.pdf

      cd ..
      echo "Example 6a: Oblique perspective of subduction zone seismicity" > example6_profile_220_20_5.txt
      echo "Example 6b: Oblique perspective of subduction zone seismicity" > example6_profile_140_30_8.txt

    ;;

    7) # Example 7: Seismicity of Chile, SLAB2 contours, texture shaded topography,
       # eq labels for M7+ events (datemag format)
      echo "Example 7: Large earthquakes of Chile over Bouguer gravity" > example7.txt
      tectoplot -n -r CL -v BG 0 -RJ UTM -b c -z -zmag 5 10 -cmag 5 10 -c ORIGIN \
                -eqlabel 7.5 datemag --legend -author -command -o example7
    ;;

    8) # Example 8: Stacked swath profiles across a forearc wedge in the Philippines.
       # Profiles are defined by aprof codes, MAX/MIN elevation are set using
       # -setvars, align to trench using -alignxy
       # author and command info are offset to bottom of page using -authoryx
       # This is an XY line of the trench
      echo "Example 8: Stacked swath profiles" > example8.txt
      cat <<-EOF > trench.xy
      119.2408936906884 17.61597125516211
      119.2409490926293 17.71465347829429
      119.2176107296602 17.83547883722725
      119.1942331465251 17.87677560184599
      119.1975648758081 17.94987541001941
      119.227615639307 18.01661872008892
      119.2275990143864 18.07696894615562
      119.2409440650472 18.13731872761894
      119.3312021974716 18.24530823999382
      119.4717667175919 18.45166262709513
      119.5623128686141 18.59138940695398
      119.690015031401 18.75344091149203
      119.7978649352516 18.88708229998535
      119.8249319064631 18.93487494555937
      119.9164561647038 19.08163699726974
      120.08999737773 19.33972244378843
      120.164849198207 19.45106115283675
      120.2295590693063 19.53381773565437
      120.2843808219882 19.62635491046482
EOF

      tectoplot -n -r 118.5 121 17 20 -pss 7 -t GEBCO20 -RJ UTM \
                -aprof IQ JR OW 15k 0.1k -setvars { SPROF_MINELEV -5 SPROF_MAXELEV 1 } \
                -alignxy trench.xy -title "Aligned swath profiles" \
                -author -authoryx -3.25 -command -o example8

    ;;

    9) # Example 9: Stacked gravity profiles across the Example 8 using a profile.control file.
       # Color land areas dark green, overlay rescaled gravity onto a grayscale hillshade,
       # contour bathymetry. Profiles have different colors. setvars is used to adjust the
       # DEM transparency (alpha)
      echo "Example 9: Stacked gravity profiles" > example9.txt

      cat <<-EOF > trench.xy
      119.2408936906884 17.61597125516211
      119.2409490926293 17.71465347829429
      119.2176107296602 17.83547883722725
      119.1942331465251 17.87677560184599
      119.1975648758081 17.94987541001941
      119.227615639307 18.01661872008892
      119.2275990143864 18.07696894615562
      119.2409440650472 18.13731872761894
      119.3312021974716 18.24530823999382
      119.4717667175919 18.45166262709513
      119.5623128686141 18.59138940695398
      119.690015031401 18.75344091149203
      119.7978649352516 18.88708229998535
      119.8249319064631 18.93487494555937
      119.9164561647038 19.08163699726974
      120.08999737773 19.33972244378843
      120.164849198207 19.45106115283675
      120.2295590693063 19.53381773565437
      120.2843808219882 19.62635491046482
EOF

      PROFXY=$(echo "$(cd "$(dirname "./trench.xy")"; pwd)/$(basename "./trench.xy")")
      echo "@ auto auto auto auto $PROFXY" > profile.control
      cat <<-EOF >> profile.control
      S grav/grav.nc 1 1k 15k 1k
      P P1 black 0 N 119.25 19.1 120.25 17.9
      P P2 green 0 N 119.25 19.7 120.25 18.5
      P P3 red 0 N 119.75 19.7 120.75 18.5
EOF

      tectoplot -n -r 118.5 121 17 20 -pss 7 -RJ UTM -t GEBCO20 -t1 \
                -v BG 50 rescale -ac darkgreen -a f -tn 1000 -clipgrav \
                -mprof profile.control -title "Bouguer anomaly" -author -authoryx -3.25 \
                -command --legend -setvars { DEM_ALPHA 0.01 } -o example9
    ;;

    10) # Example 10: Litho1 Vp profile and oblique perspective diagram across Tasmania.
        # Uses aprofcode to define profile and place scale bar.
      echo "Example 10: Litho1 profile / map and profile" > example10.txt

      tectoplot -r 141 152 -45 -38 -t -RJ UTM -z -zcat ISC -c -scale 150k A  \
                -aprof CW 150k 1k -pss 7 -litho1 Vp --legend -mob 150 40 10  \
                -o example10

      cp tempfiles_to_delete/profiles/P_CW_profile.pdf ./example10_profile_150_40_10.pdf
      echo "Example 10b: Litho1 perspective diagram" > example10_profile_150_40_10.txt

    ;;

    11) # Example 11: Oceanic crust age, topo, country borders, smaller PS size, raster resolution restricted to 72dpi
      echo "Example 11: Oceanic crust age" > example11.txt

      tectoplot -RJ S 120 0 -t 05m -gres 72 -pss 4 -oca --legend -author  \
                -command -pgo -a l -acb black 0.5p l -o example11
    ;;

    12) # Example 12:
      # tectoplot -RJ S 120 0 -t 05m -gres 72 -pss 4 -oca --legend -author \
      #           -command -pgo -a l -acb black 0.5p l -o example12
    ;;

    13) # Example 13: MORVEL57 NNR plate velocities.
      echo "Example 13: MORVEL57 NNR plate velocities" > example13.txt

      tectoplot -n -r g -p MORVEL NNR -pvg -a l -pf 1200 -i 1 \
                -setvars { PLATELINE_COLOR white PLATEVEC_COLOR black  \
                PLATEVEC_TRANS 30 PLATEVELRES 0.25d COAST_KM2 1000 } -pe  \
                -RJ G -title "MORVEL57 NNR velocity" -pss 4 -author -command  \
                -o example13
    ;;

    14) # Example 14: Extract IDs for large earthquakes within a 1°x1° box surrounding an event,
        # then plot a map of a wider region around that event, labeling only those earthquakes.
      echo "Example 14: Large earthquakes near EQ event" > example14.txt
      tectoplot -r eq iscgem913230 1.0 -z -zmag 6.5 10 -noplot
      tectoplot -query eqs.txt data id noheader > extract_eqs.txt
      tectoplot -r eq iscgem913230 1.5 -t -b c -z -zsort mag down -c ORIGIN  \
                -eqlist extract_eqs.txt -eqlabel datemag -o example14
      rm -f extract_eqs.txt
    ;;

    15) # Example 15: Use local seismicity and focal mechanism datasets to make a map of Lombok
        # (Data from Lythgoe et al., 2021). Seismicity is in lon lat depth mag format,
        # CMT data are in Aki and Richards (psmeca) format.
        # Currently we need to specify -pos 0i 0i to get the map to overplot correctly
      echo "Example 15: Plot custom seismicity/CMT data" > example15.txt

      if [[ -e ${EXAMPLEDATA}LombokHypodd.dat && -e ${EXAMPLEDATA}LombokFocals_aki.dat ]]; then
        tectoplot -n -t BEST -gres 100 -r 115.8 117.2 -9.2 -7.8 -z \
                  -c ORIGIN -pss 7 -cw -zfill black \
                  -tshade -author -command --keepopenps
        tectoplot -n -r 115.8 117.2 -9.2 -7.8 -ips ./tempfiles_to_delete/map.ps \
                  -z -zadd ${EXAMPLEDATA}LombokHypodd.dat replace -pos 0i 0i \
                  -c ORIGIN -cadd ${EXAMPLEDATA}LombokFocals_aki.dat a replace -pss 7 \
                  -setvars { EQMAXDEPTH_COLORSCALE 25 EQMINDEPTH_COLORSCALE 5 }  \
                  -o example15
      fi
    ;;

    16) # Example 16: Plot a focal mechanism database from an NDK file
      echo "Example 16: Plot CMT from custom NDK file" > example16.txt
      if [[ -e ${EXAMPLEDATA}quick.ndk ]]; then
        tectoplot -n -RJ V -ac lightbrown lightblue -a l -c \
        -cadd ${EXAMPLEDATA}quick.ndk K replace -cmag 7 10  \
        -title "Large QuickCMT earthquakes" -author -command -o example16
      fi
    ;;

    17) # Example 17: Convert a focal mechanism from NDK to psmeca moment tensor format
        # without plotting anything.
      if [[ -e ${EXAMPLEDATA}quick.ndk ]]; then
        tectoplot -n -RJ V -c CENTROID -cadd ${EXAMPLEDATA}quick.ndk K replace -cf MomentTensor -noplot
        echo "NDK format CMT1:"
        head -n 5 ${EXAMPLEDATA}quick.ndk
        echo "Moment Tensor format CMT (CENTROID):"
        head -n 1 tempfiles_to_delete/focal_mechanisms/cmt.dat
        tectoplot -RJ V -c ORIGIN -cadd ${EXAMPLEDATA}quick.ndk K replace -cf MomentTensor -noplot
        echo "Moment Tensor format CMT (ORIGIN):"
        head -n 1 tempfiles_to_delete/focal_mechanisms/cmt.dat
      fi
    ;;

    18) # Use an oblique Mercator projection defined by an center point and azimuth
     echo "Example 18: Oblique Mercator projection" > example18.txt

      tectoplot -RJ OA -88 12 122 800k 200k -t GEBCO20 -gres 120 -c -cmag 6.5 10 \
                --legend -inset 1i 20 3.5i 2.7i -author -command -o example18
    ;;

    19) # Make an oblique view of topography with cast shadows, Sentinel cloud
        # free imagery
      echo "Example 19: Sentinel imagery on slopesky with cast shadows - map" > example19.txt

      tectoplot -n -r 68 69 29 30 -t BEST --open -pgo -sent 0.8 -tsl -tsky -timg sentinel 0.8 -ob 120 20 3 -o example19
      cp tempfiles_to_delete/oblique.pdf ./example19_oblique.pdf
      echo "Example 19: Topography with cast shadows - perspective" > example19_oblique.txt
    ;;

    *)
    echo "Unknown example number $i"
    ;;
  esac
done

echo "<table>" > examples.html
# # Make the images for the GitHub README
for pdffile in *.pdf; do
  id="${pdffile%.*}"
  # echo "Converting $pdffile to ${id}.jpg"
  gs -dNOSAFER -dQUIET -dNOPLATFONTS -dNOPAUSE -dBATCH -sDEVICE=jpeg -sOutputFile="$id.jpg" \
  -r720 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -dUseCIEColor -dUseTrimBox -dFirstPage=1 -dLastPage=1 \
  -g1000x1000  -dPDFFitPage $pdffile

  echo "<tr>" >> examples.html
  echo -n "<td>" >> examples.html
  cat $id.txt >> examples.html
  echo "</td>" >> examples.html
  echo "</tr>" >> examples.html
  echo "<tr>" >> examples.html
  echo "<td><a href=examples/$id.pdf><img src=examples/$id.jpg height=100></a></td>" >> examples.html
  echo "</tr>" >> examples.html
done

# Create the README.md with the example HTML inside
sed -e '/REPLACEWITHEXAMPLEHTML/ {' -e 'r examples.html' -e 'd' -e '}' ../README.md.template > ../README.md
# rm -rf ./tempfiles_to_delete/
