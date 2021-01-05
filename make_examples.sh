#!/bin/bash
# tectoplot examples
#
# https://github.com/kyleedwardbradley/tectoplot
# Kyle Bradley, Nanyang Technological University, Singapore

NUMEXAMPLES=16


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

mkdir -p ./examples
cd ./examples

if [[ $# -eq 0 ]]; then
  MAKENUMS=($(echo "$(seq 1 $NUMEXAMPLES)"))
else
  MAKENUMS=($(echo $@))
fi

for i in ${MAKENUMS[@]}; do
  echo Example $i
  case $i in
    1) # Example 1: Four global plots in one PDF
      tectoplot -n -command -RJ N      -t 10m -gres 30 -title "Robinson"                                                    -pss 8 -a l --keepopenps    -z -zmag 7 10
      tectoplot -n -command -RJ W 45   -t 10m -gres 30 -title "Mollweide" -pos  9i    0i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l --keepopenps    -c -zmag 7 10
      tectoplot -n -command -RJ H 135  -t 10m -gres 30 -title "Hammer"    -pos -9i -5.5i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l --keepopenps    -z -zmag 8 10
      tectoplot -n -command -RJ R -180 -t 10m -gres 30 -title "Winkel"    -pos  9i -0.5i -ips ./tempfiles_to_delete/map.ps  -pss 8 -a l          -o example1
    ;;

    2) # Example 2: Two stereographic global plots in one PDF
      tectoplot -n -command -RJ S 100 10   -t 10m -tshade --legend -title "Stereo 100E/10N" -tm ./newtmp/                     -pss 5 -a l             --keepopenps
      tectoplot -n -command -RJ S -80 -10  -t 10m -tshade --legend -title "Stereo 80W/10S" -pos  0i -6.5i -ips ./newtmp/map.ps  -pss 5 -a l -o example2
      rm -rf ./newtmp/
    ;;

    3) # Example 3: Solomon Islands, SRTM30 topo, Slab2 contours,
       # ANSS hypocenters, CMT, coastlines, title, legend
      tectoplot -n -t -b c -z -c -a f -command -title "Solomon Islands seismicity" \
                --legend -author -o example3
    ;;

    4) # Example 4: Greece, GEBCO20 topo 50% transparent, GBM blocks,
       # UTM projection, GPS velocities relative to Africa, legend"
      tectoplot -n -r GR -t GEBCO20 -tt 50 -RJ UTM -p GBM Nubia -pe -pl -g AF -i 2 \
                -setvars { GPS_FILLCOLOR black PLATELABEL_SIZE 10p } -author -command \
                --legend -title "Aegean GPS velocities and blocks" -o example4
    ;;

    5) # Example 5: Southern Taiwan, GMRT/SRTM topo, GDAL slopeshade, labeled
       # ISC seismicity, CMT at ORIGIN, legend"
      tectoplot -n -r 120.5 120.8 22.4 23 -t BEST -gdalt -pgo -pgs 0.1 -pss 4 \
                -zcat ISC -z -c ORIGIN --legend -author -command \
                -setvars { SEISSTRETCH_REFMAG 4 } -eqlabel 5.5 mag -o example5
    ;;

    6) # Example 6: Automated profile across the Izu-Ogasawaram Trench (Japan),
       #            one-to-one, CMT+seis+swath bathymetry, SLAB2, UTM projection
       #            Makes oblique profile using endpoint codes, and then adjusts view/vexag
      tectoplot -n -r 135 145 25 35 -RJ UTM -t -tt 50 -z -c -b c -a l \
                -aprof BW 100k 1k -oto -pss 7 -author -mob 220 20 5 1 -o example6

      cd tempfiles_to_delete/
      cp profiles/P_BW_profile.pdf ../example5_profile_220_20_5.pdf
      ./make_oblique_plots.sh 140 30 8
      cp profiles/P_BW_profile.pdf ../example5_profile_140_30_8.pdf
      cd ..
    ;;

    7) # Example 7: Seismicity of Chile, SLAB2 contours, texture shaded topography,
       # eq labels for M7+ events (datemag format)
      tectoplot -n -r CL -t -tshade -RJ UTM -b c -z -c ORIGIN \
                -eqlabel 7.5 datemag -author -command -o example7
    ;;

    8) # Example 8: Stacked swath profiles across a forearc wedge in the Philippines.
       # Profiles are defined by aprof codes, MAX/MIN elevation are set using
       # -setvars, align to trench using -alignxy
       # author and command info are offset to bottom of page using -authoryx
       # This is an XY line of the trench

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

      tectoplot -n -r 118.5 121 17 20 -pss 7 -RJ UTM -t GEBCO20 -gdalt 10 1 0.01 \
                -v BG 50 rescale -ac darkgreen -a f -tn 1000 -clipgrav \
                -mprof profile.control -title "Bouguer anomaly" -author -authoryx -3.25 \
                -command --legend -setvars { DEM_ALPHA 0.01 } -o example9
    ;;

    10) # Example 10: Litho1 Vp profile and oblique perspective diagram across Tasmania.
        # Uses aprofcode to define profile and place scale bar.
      tectoplot -r 141 152 -45 -38 -t -RJ UTM -z -zcat ISC -c -scale 150k A  \
                -aprof CW 150k 1k -pss 7 -litho1 Vp --legend -mob 150 40 10  \
                -o example10

      cp tempfiles_to_delete/profiles/P_CW_profile.pdf ./example10_profile_150_40_10.pdf
    ;;

    11) # Example 11: Oceanic crust age, topo, country borders, smaller PS size, raster resolution restricted to 72dpi
      tectoplot -RJ S 120 0 -t 05m -gres 72 -pss 4 -oca --legend -author  \
                -command -pgo -a l -acb black 0.5p l -o example11
    ;;

    12) # Example 12:
      tectoplot -RJ S 120 0 -t 05m -gres 72 -pss 4 -oca --legend -author \
                -command -pgo -a l -acb black 0.5p l -o example12
    ;;

    13) # Example 13: MORVEL57 NNR plate velocities on a Van der Grinten projection. Kind of strange.
      tectoplot -n -r g -p MORVEL NNR -pvg -a l -pf 1200 -i 1 \
                -setvars { PLATELINE_COLOR white PLATEVEC_COLOR black  \
                PLATEVEC_TRANS 30 PLATEVELRES 0.25d COAST_KM2 1000 } -pe  \
                -RJ G -title "MORVEL57 NNR velocity" -pss 4 -author -command  \
                -o example13
    ;;
    14) # Example 14: Extract IDs for large earthquakes within a 1°x1° box surrounding an event,
        # then plot a map of a wider region around that event, labeling only those earthquakes.
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
      if [[ -e ../example_data/LombokHypodd.dat && -e ../example_data/LombokFocals_aki.dat ]]; then
        tectoplot -n -t BEST -r 115.8 117.2 -9.2 -7.8 -z \
                  -c ORIGIN -pss 7 -cw -zfill black \
                  -tshade -author -command --keepopenps
        tectoplot -n -r 115.8 117.2 -9.2 -7.8 -ips ./tempfiles_to_delete/map.ps \
                  -z -zadd ../example_data/LombokHypodd.dat replace -pos 0i 0i \
                  -c ORIGIN -cadd ../example_data/LombokFocals_aki.dat a replace -pss 7 \
                  -setvars { EQMAXDEPTH_COLORSCALE 25 EQMINDEPTH_COLORSCALE 5 }  \
                  -o example15
      fi
    ;;
    16) # Example 16: Plot a focal mechanism database from an NDK file
      if [[ -e ../example_data/quick.ndk ]]; then
        tectoplot -n -RJ V -ac lightbrown lightblue -a l -c \
        -cadd ../example_data/quick.ndk K replace -zmag 7 10  \
        -title "Large QuickCMT earthquakes" -author -command -o example16
      fi
    ;;
    17) # Example 17: Convert a focal mechanism from NDK to psmeca moment tensor format
        # without plotting anything.
      if [[ -e ../example_data/quick.ndk ]]; then
        tectoplot -n -RJ V -c CENTROID -cadd ../example_data/quick.ndk K replace -cf MomentTensor -noplot
        echo "NDK format CMT1:"
        head -n 5 ../example_data/quick.ndk
        echo "Moment Tensor format CMT (CENTROID):"
        head -n 1 tempfiles_to_delete/focal_mechanisms/cmt.dat
        tectoplot -RJ V -c ORIGIN -cadd ../example_data/quick.ndk K replace -cf MomentTensor -noplot
        echo "Moment Tensor format CMT (ORIGIN):"
        head -n 1 tempfiles_to_delete/focal_mechanisms/cmt.dat
      fi
    ;;
    18) # Plot the Southeast Asian Ring of Fire and the Pacific Ring of Fire

    ;;
    19) # Compare topography visualizations
      tectoplot -r 28.6 30.6 67.7 69.5 -t --open

    ;;
    *)
    echo "Unknown example number $i"
    ;;
  esac
done

# # Make the images for the Git README
# gs -dNOSAFER -dQUIET -dNOPLATFONTS -dNOPAUSE -dBATCH -sOutputFile="example14" -dBackgroundColor=white \
#   -r300 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -dUseCIEColor -dUseTrimBox -dFirstPage=1 -dLastPage=1 \
#   example14.pdf
# rm -rf ./tempfiles_to_delete/
