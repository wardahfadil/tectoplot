#!/bin/bash
TECTOPLOT_VERSION="TECTOPLOT 0.3, March 2021"

# Formula for an enhanced map
# tectoplot -n -r ~/Dropbox/SumatraMaps/Sumbawa.jpg -im ~/Dropbox/SumatraMaps/Sumbawa.jpg -noframe -t 01s -tclip 116.7 118.5 -9.116666 -8 -tflat -tuni -tunsetflat -tshad 55 5 -timg ~/Dropbox/SumatraMaps/Sumbawa.jpg --open

# tectoplot
#
# Script to make seismotectonic plots with integrated plate motions and
# earthquake kinematics, plus cross sections, primarily using GMT.
#
# Kyle Bradley, Nanyang Technological University (kbradley@ntu.edu.sg)
# Prefers GS 9.26 (and no later) for transparency

# NOTE: You have to be careful with culling earthquakes because it will remove
#       ORIGIN seismicity in favor of CENTROID focal mechanisms which may result
#       in non-plotting of the preserved CMT if the centroid is far away.

# ISSUE: If no top tile grid is given, various parts of the profile script will
# fail to work as we won't have the profile width and scale factors set correctly
# and won't generate the top plot script.

# To do: Select data using bounding box polygon instead of LON/LAT box?
#        gmt select

# CHANGELOG


# March    11, 2021: Incorporated smart_swath_update.sh as option -vres
# March    10, 2021: ANSS catalog excludes some anthropogenic events
#                  : Added Ms>Mw, mb>Mw, Ml>Mw conversion rules on ISC/ANSS data import
#                  : Added -tsea flag to recolor sea areas of Sentinel imagery (z<=0)
# March    08, 2021: Added -cprof option including Slab2 cross-strike azimuth
#                  : Added -zdep option to set max/min EQ depths
# March    02, 2021: Bug fixes, updated earthquake selection for 360° maps
#                  : Added -pc option to plot colored plate polygons
# March    01, 2021: Added TEMP/* option for paths which resolves to the absolute ${TMP}/* path
# February 26, 2021: Updated topo visualizations, added grid plotting onto topo, clipping
# February 19, 2021: Added -eventmap option, labels on profiles
# February 17, 2021: Added -r lonlat and -r latlon, and coordinate_parse function
# February 15, 2021: Added -tflat option to set below-sea-level cells to 0 elevation
#                  : Added -topog, -seismo, -sunlit recipes
# February 12, 2021: Large update to terrain visualizations
#                  : Added -rdel, -rlist, and -radd for custom regions
# February 04, 2021: Incomplete rework of DEM/hillshade/etc visualizations
#                    Added -gls to list GPS plates; fixed path to GPS data
# January  22, 2021: Added DEM shadowing option (-shade) in shadow_nc.sh, cleaned up code
# January  13, 2021: Fixed 255>NaN in making topocolor.dat ()
# January  06, 2021: Updated aprofcodes to work with any projection
# January  05, 2021: Fixed SEISDEPTH_CPT issue, added -grid, updated -inset
# January  05, 2021: Added Oblique Mercator (-RJ OA,OC) and updated -inset to show real AOI
# December 31, 2020: Updated external dataset routines (Seis+Cmt), bug fixes
# December 30, 2020: Fixed a bug in EQ culling that dropped earliest seismic events
# December 30, 2020: Added -noplot option to skip plotting and just output data
# December 30, 2020: Updated info_msg to save file, started building subdirectory structure
# December 29, 2020: Updated -inset and -acb to take options
# December 28, 2020: Added aprofcode option to locate scale bar.
# December 28, 2020: Profile width indicators were 2x too wide...! Fixed.
# December 28, 2020: Fixes to various parts of code, added -authoryx, -alignxy
# December 28, 2020: Fixed bug in ANSS scraper that was stopping addition of most recent events
# December 26, 2020: Fixed some issues with BEST topography, updated example script
# December 26, 2020: Added -author, -command options. Reset topo raster range if lon<-180, lon>180 {maybe make a function?}
# December 22, 2020: Significant update to projection options via -RJ. Recalc AOI as needed.
# December 21, 2020: Solstice update (and great confluence) - defined THISP_HS_AZ to get hillshading correct on top tiles
# December 20, 2020: Added -aprof and -aprofcodes options to allow easier -sprof type profile selection
# December 19, 2020: Updated profile to include texture shading for top tile (kind of strange but seems to work...)
# December 18, 2020: Added -tshade option to use Leland Brown's texture shading (added C code in tectoplot dir)
# December 17, 2020: Removed buffering from profile script, as it is not needed and sqlite has annoying messages
# December 17, 2020: Fixed -scale to accept negative lats/lons, creat EARTHRELIEF dir if it doesn't exist on load
# December 17, 2020: Fixed LITHO1 path issue. Note that we need to recompile access_litho if its path changes after -getdata
# December 16, 2020: Fixed issue where Slab2 was not found for AOI entirely within a slab clip polygon
# December 15, 2020: Added -query option and data file headers in {DEFDIR}tectoplot.headers
# December 13, 2020: Testing installation on a different machine (OSX Catalina)
#  Updated -addpath to actually work and also check for empty ~/.profile first
#  Changed tac to tail -r to remove a dependency
# December 13, 2020: Added -zcat option to select ANSS/ISC seismicity catalog
#  Note that earthquake culling may not work well for ISC catalog due to so many events?
# December 12, 2020: Updated ISC earthquake scraping to download full ISC catalog in CSV format
# December 10, 2020: Updated ANSS earthquake scraping to be faster
# December  9, 2020: Added LITHO1.0 download and plotting on cross sections (density, Vp, Vs)
# December  7, 2020: Updated -eqlabel options
# December  7, 2020: Added option to center map on a hypocenter/CMT based on event_id (-r eq EVENT_ID).
# December  7, 2020: Added GFZ focal mechanism scraping / reconciliation with GCMT/ISC
# December  4, 2020: Added option to filter EQ/CMT by magnitude: -zmag
# December  4, 2020: Added CMT/hypocenter labeling by provided list (file/cli) or by magnitude range, with some format options
#                   -eqlist -eqlabel
# December  4, 2020: Added ISC_MIRROR variable to tectoplot.paths to possibly speed up focal mechanism scraping
# December  4, 2020: Major update to CMT data format, scraping, input formats, etc.
#                    We now calculate all SDR/TNP/Moment tensor fields as necessary and do better filtering
# November 30, 2020: Added code to input and process CMT data from several formats (cmt_tools.sh)
# November 28, 2020: Added output of flat profile PDFs, V option in profile.control files
# November 28, 2020: Updated 3d perspective diagram to plot Z axes of exaggerated top tile
# November 26, 2020: Cleaned up usage, help messages and added installation/setup info
# November 26, 2020: Fixed a bug whereby CMTs were selected for profiles from too large of an AOI
# November 26, 2020: Added code to plot -cc alternative locations on profiles and oblique views
# November 25, 2020: Added ability of -sprof to plot Slab2 and revamped Slab2 selection based on AOI
# November 24, 2020: Added code to plot -gdalt style topo on oblique plots if that option is active for the map
# November 24, 2020: Added -msl option to only plot the left half of the DEM for oblique profiles, colocating slice with profile
# November 24, 2020: Added -msd option to use signed distance for profile DEM generation to avoid kink problems.
# November 22, 2020: Added -mob option to set parameters for oblique profile component outputs
# November 20, 2020: Added -psel option to plot only identified profiles from a profile.control file
# November 19, 2020: Label profiles at their start point
# November 16, 2020: Added code to download and verify online datasets, removed SLAB2 seismicity+CMTs
# November 15, 2020: Added BEST option for topography that merges 01s resampled to 2s and GMRT tiles.
# November 15, 2020: Added -gdalt option to use gdal to plot nice hillshade/slope shaded relief, with flexible options
# November 13, 2020: Added -zs option to include supplemental seismic dataset (cat onto eqs.txt)
# November 13, 2020: Fixed a bug in gridded data profile that added bad info to all_data.txt
# November 12, 2020: Added -rect option for -RJ UTM to plot rectangular map (updating AOI as needed)
# November 11, 2020: Added -zsort option to sort EQs before plotting
# November 11, 2020: Added ability to plot scale bar of specified length centered on lon/lat point
# November 11, 2020: Fixed a bug in ISC focal mechanism scraper that excluded all Jan-April events! (!!!), also adds pre-1976 GCMT/ISC mechanisms, mostly deep focus
# November 10, 2020: Updated topo contour plotting and CPT management scheme
# November  9, 2020: Adjusted GMRT tile size check, added -printcountries and edited country selection code
# November  3, 2020: Updated GMRT raster tile scraping and merging to avoid several crash issues
# November  2, 2020: Fixed DEM format problem (save as .nc and not .tif). Use gdal_translate to convert if necessary.
# October  28, 2020: Added -tt option back to change transparency of topo basemap
# October  28, 2020: Added -cn option to plot contours from an input grid file (without plotting grid)
# October  24, 2020: Range can be defined by a raster argument to -r option
# October  23, 2020: Added GMRT 1° tile scraping option for DEM (best global bathymetry data)
# October  23, 2020: Added -scrapedata, -reportdates, -recentglobaleq options
# October  21, 2020: Added -oto option to ensure 1:1 vertical exaggeration of profile plot
# October  21, 2020: Added -cc option to plot alternative location of CMT (centroid if plotting origin, origin if plotting centroid)
# October  20, 2020: Updated CMT file format and updated scrape_gcmt and scrape_isc focal mechanism scripts
# October  20, 2020: Added -clipdem to save a ${F_TOPO}dem.nc file in the temporary data folder, mainly for in-place profile control
# October  19, 2020: Initial git commit at kyleedwardbradley/tectoplot
# October  10, 2020: Added code to avoid double plotting of XYZ and CMT data on overlapping profiles.
# October   9, 2020: Project data only onto the closest profile from the whole collection.
# October   9, 2020: Add a date range option to restrict seismic/CMT data
# October   9, 2020: Add option to rotate CMTs based on back azimuth to a specified lon/lat point
# October   9, 2020: Update seismicity for legend plot using SEISSTRETCH

# FUN FACTS:
# You can make a Minecraft landscape in oblique perspective diagrams if you
# undersample the profile relative to the top grid.
# tectoplot -t -aprof HX 250k 5k -mob 130 20 5 0.1
#
# I have finally figured out how to call GMT without plotting anything: gmt psxy -T
# I need to change a few places in the script where I am calling something like psxy/pstext instead
#
# # KNOWN BUGS:
# tectoplot remake seems broken?
# -command and -aprof do not get along
#
# DREAM LEVEL:
# Generate a map_plot.sh script that contains all GMT/etc commands needed to replicate the plot.
# This script would be editable and would quite quickly rerun the plotting as the
# relevant data files would already be generated.
# Not 100% sure that the script is linear enough to do this without high complexity...

# TO DO:
#
# HIGHER PRIORITY:
#
# Litho1 end cap profile needs to go on one end or the other depending on view azimuth
#
# !! Convert from different magnitude types to Mw using scaling relationships (e.g. Wetherill et al. 2017)
#  (This should be done during catalog import so we don't have to manage different magnitude types)

# Add option to adjust PROFILE_WIDTH_IN rather than max_z when plotting one-to-one?
# Add option to decluster CMT/seismicity data before plotting to remove aftershocks?
# Update legend to include more plot elements
# Update multi_profile to plot data in 3D on oblique block plots? Need X',Y',Z,mag for eqs.
# Add option to plot GPS velocity vectors at the surface along profiles?
#     --> e.g. sample elevation at GPS point; project onto profile, plot horizontal velocity since verticals are not usually in the data
# Add option to profile.control to plot 3D datasets within the box?
# Add option to smooth/filter the DEM before hillshading?
# Add option to specify only a profile and plot default data onto that profile and a map within that AOI
# Add routines to plot existing cached data tile extents (e.g. GMRT, other topo) and clear cached data
# Need to formalize argument checking approach and apply it to all options
# Need to change program structure so that multiple grids can be overlaid onto shaded relief.
# Add option to plot a USGS event from a URL?
# Add option to plot stacked data across a profile swath
# Add option to take a data selection polygon from a plate model?
# add option to plot NASA Blue Marble / day/night images, and crustal age maps, from GMT online server
#
# LOW PRIORITY
#
# add a box-and-whisker option to the -mprof command, taking advantage of our quantile calculations and gmt psxy -E
# Check behavior for plots with areas that cross the Lon=0/360 meridian [general behavior is to FAIL HARD]
# Add options for controlling CPT of focal mechanisms/seismicity beyond coloring with depth (e.g. color with time)
# Add option to color data based on distance from profile?
#
# Update script to apply gmt.conf at start and also at various other points
# Update commands to use --GMT_HISTORY=false when necessary, rather than using extra tmp dirs
# Add option to plot Euler poles of rotation with confidence ellipses. May need to specify a region or a list of plates, as poles will by anywhere on the globe
# Add color and scaling options for -kg
# Perform GPS velocity calculations from Kreemer2014 ITRF08 to any reference frame
#     using Kreemer2014 Euler poles OR from other data using Model/ModelREF - ModelREF-ITRF08?
# Find way to make accurate distance buffers (without contouring a distance grid...)
# Develop a better description of scaling of map elements (line widths, arrow sizes, etc).
# 1 point = 1/72 inches = 0.01388888... inches

# if ((maxlon < 180 && (minlon <= $3 && $3 <= maxlon)) || (maxlon > 180 && (minlon <= $3+360 || $3+360 <= maxlon)))

################################################################################
################################################################################
##### FUNCTION DEFINITIONS

# Call without arguments will return current UTC time in the format YYYY-MM-DDTHH:MM:SS
# Call with arguments will add the specified number of
# days hours minutes seconds
# from the current time.
# Example: date_code_utc -7 0 0 0
# Returns: current date minus seven days

function date_shift_utc() {
  TZ=UTC0     # use UTC
  export TZ

  gawk 'BEGIN  {
      exitval = 0

      daycount=0
      hourcount=0
      minutecount=0
      secondcount=0

      if (ARGC > 1) {
          daycount = ARGV[1]
      }
      if (ARGC > 2) {
          hourcount = ARGV[2]
      }
      if (ARGC > 3) {
          minutecount = ARGV[3]
      }
      if (ARGC > 4) {
          secondcount = ARGV[2]
      }
      timestr = strftime("%FT%T")
      date = substr(timestr,1,10);
      split(date,dstring,"-");
      time = substr(timestr,12,8);
      split(time,tstring,":");
      the_time = sprintf("%i %i %i %i %i %i",dstring[1],dstring[2],dstring[3],tstring[1],tstring[2],int(tstring[3]+0.5));
      secs = mktime(the_time);
      newtime = strftime("%FT%T", secs+daycount*24*60*60+hourcount*60*60+minutecount*60+secondcount);
      print newtime
      exit exitval
  }' "$@"
}

################################################################################
# Messaging and debugging routines


# Returns true if argument is empty or starts with a hyphen; otherwise false
function arg_is_flag() {
  [[ ${1:0:1} == [-] || -z ${1} ]] && return
}

# Returns true if argument is a (optionally signed, optionally decimal) number
function arg_is_float() {
  [[ $1 =~ ^[+-]?([0-9]+\.?|[0-9]*\.[0-9]+)$ ]]
}

# Returns true if argument is a (optionally signed, optionally decimal) number
function arg_is_positive_float() {
  [[ $1 =~ ^[+]?([0-9]+\.?|[0-9]*\.[0-9]+)$ ]]
}

function error_msg() {
  printf "%s[%s]: %s\n" ${BASH_SOURCE[1]##*/} ${BASH_LINENO[0]} "${@}" > /dev/stderr
  exit 1
}

function info_msg() {
  if [[ $narrateflag -eq 1 ]]; then
    printf "TECTOPLOT %05s: " ${BASH_LINENO[0]}
    printf "${@}\n"
  else
    printf "TECTOPLOT %05s: " ${BASH_LINENO[0]} >> tectoplot.info_msg
    printf "${@}\n" >> tectoplot.info_msg
  fi
}

# Return the full path to a file or directory
function abs_path() {
    if [ -d "$1" ]; then
        (cd "$1"; echo "$(pwd)/")
    elif [ -f "$1" ]; then
        if [[ $1 = /* ]]; then
            echo "$1"
        elif [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    elif [[ $1 =~ TEMP/* ]]; then
      echo ${FULL_TMP}/${1##*/}
    fi
}

# Return the full path to the directory containing a file, or the directory itself
function abs_dir() {
    if [ -d "$1" ]; then
        (cd "$1"; echo "$(pwd)/")
    elif [ -f "$1" ]; then
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/"
        else
            echo "$(pwd)/"
        fi
    fi
}

# Exit cleanup code from Mitch Frazier
# https://www.linuxjournal.com/content/use-bash-trap-statement-cleanup-temporary-files

function cleanup_on_exit()
{
      for i in "${on_exit_items[@]}"; do
        if [[ $CLEANUP_FILES -eq 1 ]]; then
          info_msg "rm -f $i"
          rm -f $i
        else
          info_msg "Not cleaning up file $i"
        fi
      done
}

# Be sure to only cleanup files that are in the temporary directory
function cleanup()
{
    local n=${#on_exit_items[*]}
    on_exit_items[$n]="$*"
    if [[ $n -eq 0 ]]; then
        info_msg "Setting EXIT trap function cleanup_on_exit()"
        trap cleanup_on_exit EXIT
    fi
}

################################################################################
# Grid (raster) file functions

# Grid z range query function. Try to avoid querying the full grid when determining the range of Z values

function grid_zrange() {
   output=$(gmt grdinfo -C $@)
   zmin=$(echo $output | gawk  '{printf "%f", $6+0}')
   zmax=$(echo $output | gawk  '{printf "%f", $7+0}')
   if [[ $(echo "$zmin == 0 && $zmax == 0" | bc) -eq 1 ]]; then
      output=$(gmt grdinfo -C -L $@)
   fi
   echo $output | gawk  '{printf "%f %f", $6+0, $7+0}'
}

################################################################################
# XY (point and line) file functions

# XY range query function from a delimited text file
# variable=($(xy_range data_file.txt [[delimiter]]))
# Ignores lines that do not have numerical first and second columns

function xy_range() {
  local IFSval=""
  if [[ $2 == "" ]]; then
    IFSval=""
  else
    IFSval="-F${2:0:1}"
  fi
  gawk < $1 ${IFSval} '
    BEGIN {
      minlon="NaN"
      while (minlon=="NaN") {
        getline
        if ($1 == ($1+0) && $2 == ($2+0)) {
          minlon=($1+0)
          maxlon=($1+0)
          minlat=($2+0)
          maxlat=($2+0)
        }
      }
    }
    {
      if ($1 == ($1+0) && $2 == ($2+0)) {
        minlon=($1<minlon)?($1+0):minlon
        maxlon=($1>maxlon)?($1+0):maxlon
        minlat=($2<minlat)?($2+0):minlat
        maxlat=($2>maxlat)?($2+0):maxlat
      }
    }
    END {
      print minlon, maxlon, minlat, maxlat
    }'
}


################################################################################
# These variables are array indices used to plot multiple versions of the same
# data type and must be equal to ZERO at start

cmtfilenumber=0
seisfilenumber=0

usergridfilenumber=0
userlinefilenumber=0
userpointfilenumber=0
userpolyfilenumber=0

cprofnum=0

##### FORMATS MESSAGE is now in a file in tectoplot_defs

function formats() {
echo $TECTOPLOT_VERSION
cat $TECTOPLOT_FORMATS
}

# function test_requirements() {
#
# }

##### USAGE MESSAGES

function print_help_header() {
  cat <<-EOF

  -----------------------------------------------------------------------------

  $TECTOPLOT_VERSION
  Kyle Bradley, Nanyang Technological University
  www.github.com/kyleedwardbradley/tectoplot
  kbradley@ntu.edu.sg

  What does tectoplot do?

  tectoplot is a collection of scripts and programs that make it easy to plot
  topographic and seismotectonic data in publication quality figures using GMT
  and gdal. It is designed for a typical Unix command line work environment.
  All data and many intermediate products can be saved and queried. Map layering
  is specified by the order of commands given.

  Functions
    - Makes maps using GMT supported projections and GMT formatting options
    - Automatic determination of UTM zone from map AOI
    - Scrapes public global seismicity catalogs (ISC/ANSS/GCMT/GFZ)
    - Calculates focal mechanism parameters as necessary (e.g. SDR->MTensor)
    - Query seismicity by AOI, time, magnitude, depth range
    - Sort seismicity data before plotting (depth, magnitude, time)
    - Label seismicity on maps and profiles according to different rules
    - Plot kinematic data from focal mechanisms (PTN axes, slip vectors)
    - Generate automatic event maps using earthquake IDs
    - Downloads various useful datasets (SRTM30, WGM, Slab2.0, crust age, etc.)
    - Plot volcanoes, populated places
    - Downloads Sentinel cloud-free satellite imagery (EOX::Maps)
    - Flexible profiling including swath extraction, grid sampling, multi-point
      profiles, and signed distance along profile.
    - Profiles can be aligned to intersection of XY polyline, Z=0 at intersection
    - Profiles across non-DEM datasets (e.g. gravity)
    - Profiles can plot Litho1 Vp/Vp/Density
    - Profile azimuth can be taken from Slab2 down-dip direction
    - Multiple topography visualizations that can be combined together
      (hillshade, slope, sky view factor, cast shadows, texture mapping)
    - Oblique topography can be rotated/adjusted using a generated script
    - Generates 3D perspective diagrams from swath profiles
    - Visualization of plate motions from three published models (MORVEL,GSRM,GBM)
    - Plot GPS velocities (Kreemer et al., 2014) in different reference frames
    - Plot TDEFNODE model outputs
    - Run custom scripts in-line with access to internal variables and datasets
    - Generate georeferenced GEOTIFF and KML files without a map collar

  Requires: GMT6+, bash 3+, gdal (with gdal_calc.py), geod, gawk, perl, grep, data, sed, ls

  Open-source code that is redistributed (and/or modified) with tectoplot:
   1. texture_shader (c) 2010-2013 Leland Brown, (c) 2013 Brett Casebolt
     http://www.textureshading.com/
   2. MatrixReal.pm  (c) 1996, 1997 Steffen Beyer, (c) 1999 by Rodolphe Ortalo,
     (c) 2001-2016 by Jonathan Leto).

  Datasets that are distributed alongside tectoplot with minor reformatting only:
   1. Global Strain Rate Map plate polygons, Euler poles, and GPS velocities
     C. Kreemer et al. 2014, doi:10.1002/2014GC005407
   2. MORVEL56-NNR polygons, Euler poles
     D. Argus et al., 2011 doi:10.1111/j.1365-246X.2009.04491.x
   3. Global Block Model polygons, Euler poles]
     SE Graham et al. 2018, doi:10.1029/2017GC007391

  Portions of this code were inspired by or reworked from the following code:
   Thorsten Becker (ndk2meca.awk) - Uptal Kumar (diagonalize.pl) -
   G. Patau (IPGP) - (psmeca.c/ultimeca.c)

  Developed for OSX Catalina, minimal testing indicates works with Fedora linux

  USAGE: tectoplot -opt1 arg1 -opt2 arg2 arg3 ...

  Map layers are generally plotted in the order they are specified.

  HELP and INSTALLATION:    tectoplot -setup
  OPTIONS:                  tectoplot -options     (mostly updated)
  VARIABLES:                tectoplot -variables   (not fully updated)
  LONG HELP:                tectoplot

  -----------------------------------------------------------------------------

EOF
}

function print_options() {
cat <<-EOF
    Optional arguments:
    [opt] is required if the flag is present
    [[opt]] if not specified will assume a default value or will not be used

Common command recipes:

Seismotectonic map
    -seismo                      -t -t1 -z -c

Topography visualization with oblique perspective of topography
    -topog                       -t -t1 -ob 45 20 3

Map centered on an earthquake event with a simple profile, legend, title, and oblique perspective diagram
    -eventmap [eventID] [deg]    -t -b -z -c -eqlist -aprof -title --legend -mob

Map of recent earthquakes, labelled.
    -recenteq                    -z -c -a -eqlabel

  Data control, installation, information
    -addpath               add the tectoplot source directory to your ~.profile
    -getdata               download and validate builtin datasets
    -setopenprogram        configure program to open PDFs

    --data                 list data sources and exit
    --defaults             print default values and exit (Can edit and load using -setvars)
    --formats              print information on data formats and exit
    -h|--help              print this message and exit
    -megadebug             turn on hyper-verbose shell debugging
    -n|--narrate           echo a lot of information during processing
    -nocleanup             preserve all intermediate files instead of rm at end
    -query                 print headers for data files, print data columns in space delim/CSV format
             If no column selecting options are given, print all columns
             tectoplot -tm /PATH/ -query option1 option2
             options: csv         =   print in CSV format
                      noheader    =   don't print header line
                      nounits     =   don't print units (e.g. longitude[degrees] -> longitude)
                      data        =   print the data from the file
                      1 2 3 5 ... =   print data selected by column number
                      longitude...=   print column with field name=option
    --verbose              set gmt -V flag for all calls

  Input/output controls
    -ips             [filename]                          plot on top of an unclosed .ps file. Use -pos to set position
    --keepopenps                                         don't close the PS file to allow further plotting
    -pos X Y         Set X Y position of plot origin     (GMT format -Xval -Yval; e.g -Xc -Y1i etc)
    -geotiff                                             output GeoTIFF and .tfw, frame inside
    -kml                                                 output KML, frame inside
    --open           [[program]]                         open PDF file at end
    -o|--out         [filename]                          basename of output file [+.pdf, +.tif, etc added as needed]
    -pss   [size]          Set PS page size in inches (8).
    --inset          [[size]] [[deg]] [[x]] [[y]]        plot a globe with AOI polygon.
    --legend         [[width]]                           plot legend above the map area (color bar width=2i)
    -gres            [dpi]                               set dpi of grids printed to PS file (default: grid native res)
    -command                                             print tectoplot command at bottom of page
    -author          [[author_string]]                   print author and date info at bottom of page
    -authoryx        [yshift] [[xshift]]                 shift author info vertically by yshift and horizontally by xshift
                                                         If tectoplot.author does not exist in tectoplot_defs/, set it
                                                         author_string=reset will reset the author info
    -noplot                                              exit before plotting anything with GMT
    -noframe                                             don't plot a frame

  Low-level control
    -gmtvars         [{VARIABLE value ...}]              set GMT internal variables
    -psr             [0-1]                               scale factor of map ofs pssize
    -psm             [size]                              PS margin in inches (0.5)
    -cpts                                                remake default CPT files
    -setvars         { VAR1 VAL1 VAR2 VAL2 }             set bash variable values
    -vars            [variables file]                    set bash variable values by sourcing file
    -tm|--tempdir    [tempdir]                           use tempdir as temporary directory
    -e|--execute     [bash script file]                  runs a script using source command
    -i|--vecscale    [value]                             scale all vectors (0.02)

  Area of Interest options. The lat/lon AOI box is the region from which data are selected
    -r|--range       [MinLon MaxLon MinLat MaxLat]       area of interest, degrees
                     [g]                                 global domain [-180:180/-90:90]
                     [2 character ID]                    AOI of 2 character country code, breaks if crosses dateline!
                     [raster_file]                       take the limits of the given raster file
                     [customID]                          AOI defined in tectoplot.customrange

    -radd            [customID; no whitespace]           set customID based on -r arguments
    -rdel            [customID; no whitespace]           delete customID from custom region file and exit
    -rlist                                               print customIDs and extends and exit

  Map projection definition. Default projection is Plate Carrée [GMT -JQ, reference latitude is 0].
  Note that the width of the map in inches should be set using the -J command.
    -RJ              [{ -Retc -Jetc }]                   provide custom R, J GMT strings

    Local projections. AOI region needs to be specified using -r in addition to -RJ
    -RJ              UTM [[zone]]                        plot UTM, zone is defined by mid longitude (-r) or specified
    -rect                                                use rectangular map frame (UTM projection only)

    Global projections (-180:180/-90:90) specified by word or GMT letter and optional arguments
    -RJ              Hammer|H ; Molleweide|W ; Robinson|N       [[Meridian]]
                     Winkel|R ; VanderGrinten|V ; Sinusoidal|I  [[Meridian]]
                     Hemisphere|A                               [[Meridian]] [[Latitude]]

    Global projections with degree range, specified by word or GMT letter and optional arguments
                     Gnomonic|F ; Orthographic|G ; Stereo|S     [[Meridian]] [[Latitude]] [[Range]]

    Oblique Mercator projections
    -RJ              ObMercA/OA  [centerlon] [centerlat] [azimuth] [width]k [height]k
                     ObMercC/OC  [centerlon] [centerlat] [polelon] [polelat] [width]k [height]k

  Grid/graticule and map frame options
    -B               [{ -Betc -Betc }]                   provide custom B strings for map in GMT argument format
    -pgs             [gridline spacing]                  override automatic map gridline spacing
    -pgo                                                 turn grid lines on
    -pgl                                                 turn grid labels off
    -pgn                                                 don't plot grid at all
    -scale           [length] [lon] [lat]                plot a scale bar. length needs suffix (e.g. 100k).

  Plotting/control commands:

  Profiles and oblique block diagrams:
    -mprof           [control_file] [[A B X Y]]          plot multiple swath profile
                     A=width (7i) B=height (2i) X,Y=offset relative to current origin (0i -3i)
    -sprof           [lon1] [lat1] [lon2] [lat2] [width] [res]
                        plot an automatic profile using data plotted on map
                        width requires unit letter, e.g. 100k, and is full width of profile
                        res is the resolution at which we resample grids to make top tile grid (e.g. 1k)
    -aprof           [code1] [[code2 ...]] [width] [res]
                        plot an automatic profile using a code made of two letters: [A-Y][A-Y]
                        width, res are same as -sprof (both need unit letter such as k)
    -aprofcodes      plot the points and letters for the -aprof codes on the map
    -oto             adjust vertical scale (after all other options) to set V:H ratio at 1 (no exaggeration)
    -psel            [PID1] [[PID2...]]                  only plot profiles with specified PID from control file
    -mob             [[Azimuth(deg)]] [[Inclination(deg)]] [[VExagg(factor)]] [[Resolution(m)]]
                            create oblique perspective diagrams for profiles
    -msd             Use a signed distance formulation for profiling to generate DEM for display (for kinked profiles)
    -msl             Display only the left side of the profile so that the cut is exactly on-profile
    -litho1 [type]   Plot LITHO1.0 data for each profile. Allowed types are: density Vp Vs
    -alignxy         XY file used to align profiles.

  Topography/bathymetry:
    -t|--topo        [[ SRTM30 | GEBCO20 | GEBCO1 | ERCODE | GMRT | BEST | custom_grid_file ]] [[cpt]]
                     plot shaded relief (including a custom grid)
                     ERCODE: GMT Earth Relief Grids, dynamically downloaded and stored locally:
                     01d ~100km | 30m ~55 km | 20m ~37km | 15m ~28km | 10m ~18 km | 06m ~10km
                     05m ~9km | 04m ~7.5km | 03m ~5.6km | 02m ~3.7km | 01m ~1.9km | 15s ~500m
                     03s ~100m | 01s ~30m
                     BEST uses GMRT for elev < 0 and 01s for elev >= 0 (resampled to match GMRT)
    -ts                                                  don't plot shaded relief/topo grid
    -tr              [[minelev maxelev]]                 rescale CPT using data range or specified limits
    -tc|--cpt        [cptfile]                           use custom cpt file for topo grid
    -tx                                                  don't color topography (plot intensity directly)
    -tt|--topotrans  [transparency%]                     transparency of final plotted topo grid
    -clipdem                                             save terrain as dem.nc in temporary directory
    -tflat                                               set DEM elevations < 0 to 0 (no bathymetry)

  Popular recipes for topo visualization
    -t0              [[sun_el]] [[sun_az]]               single hillshade
    -t1              [[sun_el]]                          combination multiple hs/slope map

  Build your own topo visualization using these commands in sequence.
    [[fact]] is the blending factor (0-1) used to combine each layer with existing intensity map

    -tshad           [[shad_az]] [[shad_el]] [[alpha]]   add cast shadows to intensity (fact=opacity)
    -ttext           [[frac]]   [[stretch]]  [[fact]]    add texture shade to intensity
    -tmult           [[sun_el]]              [[fact]]    add multiple hillshade to intensity
    -tuni            [[sun_az]] [[sun_el]]   [[fact]]    add unidirectional hillshade to intensity
    -tsky            [[num_angles]]          [[fact]]    add sky view factor to intensity
    -tgam            [[gamma]]                           add gamma correction to black/white intensity
    -timg            [[alpha]]                           overlay referenced RGB raster instead of color ramp
    -tsent           [[alpha]]                           download and overlay Sentinel cloud free (EOX::Maps at eox.at)
                     image saved as \${TMP}sentinel.tif and can be plotted using -im TEMP/sentinel.tif
    -tunsetflat                                          set intensity at elevation=0 to white
    -tclip           [lonmin] [lonmax] [latmin] [latmax] clip dem to alternative rectangular AOI

    -tn              [interval (m)]                      plot topographic contours
    -gebcotid                                            plot GEBCO TID raster
    -ob              [[az]] [[inc]] [[floor_elev]] [[frame]]   plot oblique view of topography

  Additional map layers from downloadable data:
    -a|--coast       [[quality]] [[a,b]] { gmtargs }     plot coastlines [[a]] and borders [[b]]
                     quality = a,f,h,i,l,c
    -ac              [[LANDCOLOR]] [[SEACOLOR]]          fill coastlines/sea (requires subsequent -a command)
    -acb             [[color]] [[linewidth]] [[quality]] plot country borders (quality = a,l,f)
    -acl                                                 label country centroids
    -af              [[AFLINEWIDTH]] [[AFLINECOLOR]]     plot active fault traces
    -b|--slab2       [[layers string: c]]                plot Slab2 data; default is c
                     c: slab contours  d: slab depth grid
    -gcdm                                                plot Global Curie Depth Map
    -litho1_depth    [type] [depth]                      plot litho1 depth slice (positive depth in km)
    -m|--mag         [[transparency%]]                   plot crustal magnetization
    -oca             [[trans%]] [[MaxAge]]               oceanic crust age
    -pp|--cities     [[min population]]                  plot cities with minimum population, color by population
    -ppl             [[min population]]                  label cities with a minimum population
    -s|--srcmod                                          plot fused SRCMOD EQ slip distributions
    -v|--gravity     [[FA | BG | IS]] [transparency%] [rescale]            rescale=rescale colors to min/max
                     plot WGM12 gravity. FA = free air | BG == Bouguer | IS = Isostatic
    -vc|--volc                                           plot Pleistocene volcanoes

  Turn on and off clipping using a polygon file

    -clipon          [polygonFile]                       Turn on polygon clipping mask
    -clipoff                                             Turn off polygon clipping

  Layers from dynamically downloadable datasets:
    -blue                                                NASA Blue Marble (EOX::Maps at eox.at)

  GPS velocities:
    -g|--gps         [[RefPlateID]]                      plot GPS data from Kreemer 2014 / rel. to RefPlateID
    -gadd|--extragps [filename]                          plot an additional GPS / psvelo format file
    -gls                                                 list plate IDs for GPS data and exit

  Earthquake slip model with .grd and clipping path:
    -eqslip [gridfile1] [clipfile1] [[gridfile2]] [[clipfile2]] ...  Plot contoured, colored EQ slip model

  Both seismicity and focal mechanisms:
    -zcnoscale                                           don't rescale earthquake data by magnitude
    -zdep            [mindepth] [maxdepth]               rescrict CMT/hypocenters to between mindepth-maxdepth[km]

  Seismicity:
    -z|--seis        [[scale]]                           plot seismic epicenters (from scraped earthquake data)
    --time           [STARTTIME ENDTIME]                 select EQ/CMT between dates (midnight AM), format YYYY-MM-DD
    -zsort           [date|depth|mag] [up|down]          sort earthquake data before plotting
    -zadd            [file] [[replace]]                  add/replace seismicity [lon lat depth mag [timecode id epoch]]
    -zmag            [minmag] [[maxmag]]                 set minimum and maximum magnitude
    -zcat            [ANSS | ISC | NONE]                 select the scraped EQ catalog to use. NONE is used with -zadd
    -zcolor          [mindepth] [maxdepth]               set range of color stretch for EQ+CMT data
    -zfill           [color]                             set uniform fill color for seismicity

  Seismicity/focal mechanism data control:
    -reportdates                                         print date range of seismic, focal mechanism catalogs and exit
    -scrapedata                                          run the GCMT/ISC/ANSS scraper scripts and exit
    -eqlist          [[file]] { event1 event2 event3 ... }  highlight focal mechanisms/hypocenters with ID codes in file or list
    -eqselect                                            only consider earthquakes with IDs in eqlist
    -eqlabel         [[list]] [[r]] [[minmag]] [format]  label earthquakes in eqlist or within magnitude range
                                                         r=EQ from -r eq; format=idmag | datemag | dateid | id | date | mag
    -pg|--polygon    [polygon_file.xy] [[show]]          use a closed polygon to select data instead of AOI; show prints polygon to map

  Focal mechanisms:
    -c|--cmt         [[source]] [[scale]]                plot focal mechanisms from global databases
    -cx              [file]                              plot additional focal mechanisms, format matches -cf option
    -ca              [nts] [tpn]                         plot selected P/T/N axes for selected EQ types
    -cc                                                  plot dot and line connecting to alternative position (centroid/origin)
    -cd|--cmtdepth   [depth]                             maximum depth of CMTs, km
    -cf              [GlobalCMT | MomentTensor | TNP]    choose the format of focal mechanism to plot
    -cmag            [minmag] [[maxmag]]                 magnitude bounds for cmt
    -cr|--cmtrotate) [lon] [lat]                         rotate CMTs based on back-azimuth to a point
    -cw                                                  plot CMTs with white compressive quads
    -ct|--cmttype    [nts | nt | ns | n | t | s]         sets earthquake types to plot CMTs
    -zr1|--eqrake1   [[scale]]                           color focal mechs by N1 rake
    -zr2|--eqrake2   [[scale]]                           color focal mechs by N2 rake
    -cs                                                  plot TNP axes on a stereonet (output to stereo.pdf)
    -cadd            [file] [code] [[replace]]           plot focal mechanisms from local data file
                             code: a,c,x,m,I,K           (GMT:AkiR,GCMT,p.axes,m.tensor; ISC:I; NDK:K)

  Focal mechanism kinematics (CMT):
    -kg|--kingeo                                         plot strike and dip of nodal planes
    -kl|--nodalplane [1 | 2]                             plot only NP1 (lower dip) or NP2
    -km|--kinmag     [minmag maxmag]                     magnitude bounds for kinematics
    -kt|--kintype    [nts | nt | ns | n | t | s]         select types of EQs to plot kin data
    -ks|--kinscale   [scale]                             scale kinematic elements
    -kv|--slipvec                                        plot slip vectors

  Plate models (require a plate motion model specified by -p or --tdefpm)
    -f|--refpt       [Lon/Lat]                           reference point location
    -p|--plate       [[GBM | MORVEL | GSRM]] [[refplate]] select plate motion model, relative to stationary refplate
    -pe|--plateedge  [[GBM | MORVEL | GSRM]]             plot plate model polygon edges
    -pc              PlateID1 color1 [[trans1]] PlateID2 color2 [[trans2]] ... semi-transparent coloring of plate polygons
                     random [[trans]]                    semi-transparent random coloring of all plates in model
    -pf|--fibsp      [km spacing]                        Fibonacci spacing of plate motion vectors; turns on vector plot
    -px|--gridsp     [Degrees]                           Gridded spacing of plate motion vectors; turns on vector plot
    -pl                                                  label plates
    -ps              [[GBM | MORVEL | GSRM]]             list plates and exit. If -r is set, list plates in region
    -pr                                                  plot plate rotations as small circles with arrows
    -pz              [[scale]]                           plot plate boundary azimuth differences (does edge computations)
                                                         histogram is plotted into az_histogram.pdf
    -pv              [cutoff distance]                   plot plate boundary relative motion vectors (does edge computations)
                                                         cutoff distance dictates spacing between plotted velocity pairs
    -w|--euler       [Lat] [Lon] [Omega]                 plots vel. from Euler Pole (grid)
    -wp|--eulerplate [PlateID] [RefplateID]              plots vel. of PlateID wrt RefplateID
                     (requires -p or --tdefpm)
    -wg              [residual scale]                    plots -w or -wp at GPS sites (plot scaled residuals only)
    -pvg             [[res]] [[rescale]]                 plots a plate motion velocity grid. res=0.1d ; rescale=rescale colors to min/max

  User specified GIS datasets:
    -cn|--contour    [gridfile] [interval] { gmtargs }   plot contours of a gridded dataset
                                          gmtargs for -A -S and -C will replace defaults
    -gr|--grid       [gridfile] [[cpt]] [[trans%]]       plot a gridded dataset colored with a CPT
    -im|--image      [filename] { gmtargs }              plot a RGB GeoTiff file (georeferenced)
    -li|--line       [filename] [[color]] [[width]]                data: > ID (z)\n x y\n x y\n > ID2 (z) x y\n ...
    -pt|--point      [filename] [[symbol]] [[size]] [[cptfile]]    data: x y z
    -sv|--slipvector [filename]                          plot data file of slip vector azimuths [Lon Lat Az]

  TDEFNODE block model
    --tdefnode       [folder path] [lbsovrfet ]          plot TDEFNODE output data.
          l=locking b=blocks s=slip o=observed gps vectors v=modeled gps vectors
          r=residual gps vectors; f=fault slip rates; a=block name labels
          e=elastic component of velocity; t=block rotation component of velocity
          y=fault midpoint sliprates, spaced
    --tdefpm         [folder path] [RefPlateID]          use TDEFNODE results as plate model
    --tdeffaults     [1,2,3,5,...]                       select faults for coupling plotting and contouring

EOF
}

function print_usage() {
  print_help_header
  print_setup
  print_options
  print_variables
}

# Needs significant updating

function print_variables {
  cat <<-EOF

Common variables to modify using -vars [file] and -setvars { VAR value ... }

Topography:     TOPOTRANS [$TOPOTRANS]

Profiles:       SPROF_MAXELEV [$SPROF_MAXELEV] - SPROF_MINELEV [$SPROF_MINELEV]

Plate model:    PLATEARROW_COLOR [$PLATEARROW_COLOR] - PLATEARROW_TRANS [$PLATEARROW_TRANS]
                PLATEVEC_COLOR [$PLATEVEC_COLOR] - PLATEVEC_TRANS [$PLATEVEC_TRANS]
                LATSTEPS [$LATSTEPS] - GRIDSTEP [$GRIDSTEP] - AZDIFFSCALE [$AZDIFFSCALE]
                PLATELINE_COLOR [$PLATELINE_COLOR] - PLATELINE_WIDTH [$PLATELINE_WIDTH]
                PLATELABEL_COLOR [$PLATELABEL_COLOR] - PLATELABEL_SIZE [$PLATELABEL_SIZE]
                PDIFFCUTOFF [$PDIFFCUTOFF]

Both CMT and Earthquakes: EQCUTMINDEPTH [$EQCUTMINDEPTH] - EQCUTMAXDEPTH [$EQCUTMAXDEPTH]
                SCALEEQS [$SCALEEQS] - SEISSTRETCH [$SEISSTRETCH] - SEISSTRETCH_REFMAG [$SEISSTRETCH_REFMAG]
                EQMAXDEPTH_COLORSCALE [$EQMAXDEPTH_COLORSCALE]

Earthquakes:    SEISSIZE [$SEISSIZE] - SEISSCALE [$SEISSCALE] - SEISSYMBOL [$SEISSYMBOL] - SEISTRANS [$SEISTRANS]
                REMOVE_DEFAULTDEPTHS [$REMOVE_DEFAULTDEPTHS] - REMOVE_DEFAULTDEPTHS_WITHPLOT [$REMOVE_DEFAULTDEPTHS_WITHPLOT]
                REMOVE_EQUIVS [$REMOVE_EQUIVS]

CMT focal mech: CMT_NORMALCOLOR [$CMT_NORMALCOLOR] - CMT_SSCOLOR [$CMT_SSCOLOR] - CMT_THRUSTCOLOR [$CMT_THRUSTCOLOR]
                CMTSCALE [$CMTSCALE] - CMTFORMAT [$CMTFORMAT] - CMTSCALE [$CMTSCALE] - PLOTORIGIN [$PLOTORIGIN]
                CMT_NORMALCOLOR [$CMT_NORMALCOLOR] - CMT_SSCOLOR [$CMT_SSCOLOR] - CMT_THRUSTCOLOR [$CMT_THRUSTCOLOR]

CMT principal axes: CMTAXESSTRING [$CMTAXESSTRING] - CMTAXESTYPESTRING [$CMTAXESTYPESTRING] - CMTAXESARROW [$CMTAXESARROW]
                    CMTAXESSCALE [$CMTAXESSCALE] - T0PEN [$T0PEN] - FMLPEN [$FMLPEN]

CMT kinematics: KINSCALE [$KINSCALE] - NP1_COLOR [$NP1_COLOR] - NP2_COLOR [$NP2_COLOR]
                RAKE1SCALE [$RAKE1SCALE] - RAKE2SCALE [$RAKE2SCALE]

Active faults:  AFLINECOLOR [$AFLINECOLOR] - AFLINEWIDTH [$AFLINEWIDTH]

Volcanoes:      V_FILL [$V_FILL] - V_SIZE [$V_SIZE] - V_LINEW [$V_LINEW]

Coastlines:     COAST_QUALITY [$COAST_QUALITY] - COAST_LINEWIDTH [$COAST_LINEWIDTH] - COAST_LINECOLOR [$COAST_LINECOLOR] - COAST_KM2 [$COAST_KM2]
                LANDCOLOR [$LANDCOLOR] - SEACOLOR [$SEACOLOR]

Gravity:        GRAV_RESCALE [$GRAV_RESCALE]

Magnetics:      MAG_RESCALE [$MAG_RESCALE]

Point data:     POINTCOLOR [$POINTCOLOR] - POINTSIZE [$POINTSIZE] - POINTLINECOLOR [$POINTLINECOLOR] - POINTLINEWIDTH [$POINTLINEWIDTH]

Grid contours:  CONTOURNUMDEF [$CONTOURNUMDEF] - GRIDCONTOURWIDTH [$GRIDCONTOURWIDTH] - GRIDCONTOURCOLOUR [$GRIDCONTOURCOLOUR]
                GRIDCONTOURSMOOTH [$GRIDCONTOURSMOOTH] - GRIDCONTOURLABELS [$GRIDCONTOURLABELS]

EOF
}

function print_setup() {
  cat <<-EOF
  Dependencies:
    GMT${GMTREQ}
    gdal, geod
    Preview (or equivalent PDF viewer)
    Unix commands: gawk, bc, cat, curl, date, grep, sed

  Installation and setup:

  Prepare by installing GMT:

  For a fairly clean OSX Catalina machine, you can use Homebrew.

  ~/# /bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ~/# brew update
  ~/# brew install gmt
  ~/# brew install gawk

  As of December 2020, this will install GS9.26 on OSX

  ~/# brew unlink ghostscript
  ~/# cd /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula
  ~/# git checkout 6ec0c1a03ad789b6246bfbbf4ee0e37e9f913ee0 ghostscript.rb
  ~/# brew install ghostscript
  ~/# brew pin ghostscript

  Installing and configuring tectoplot

  1. First, clone into a new folder from Github, or unzip a Github ZIP file

  ~/# git clone https://github.com/kyleedwardbradley/tectoplot.git tectoplot

  2. cd into the script folder and add its path to ~/.profile, and then source
    the ~/.profile file to update your current shell environment:

  ~/# cd tectoplot
  ~/tectoplot/# ./tectoplot -addpath
  ~/tectoplot/# . ~/.profile

  3. Define the directory where downloaded data will be stored.

  ~/tectoplot/# tectoplot -setdatadir "/full/path to/data/directory/"

  4. Download the online datasets into the data directory (you need to be online!)
     If the data files exist and are the right size, we don't download them again.
     If something goes wrong with the download, run the command again.

  ~/tectoplot/# tectoplot -getdata

  5. Scrape and process the seismicity and focal mechanism catalogs.
     Then confirm the date range spanned by the processed datasets.

     If you want to avoid a long scrape session, download these ZIP files:
     https://www.dropbox.com/s/1tab7ww98bf129p/ANSS.zip?dl=1
     https://www.dropbox.com/s/lf52rhpzby5ktkp/ISC_SEIS.zip?dl=1
     and unzip them into your data directory.

  ~/tectoplot/# tectoplot -scrapedata
  ~/tectoplot/# tectoplot -reportdates

  6. Create a new folder for maps, change into it, and create a plot of the
     Solomon Islands including bathymetry, CMTs, and seismicity:

  ~/tectoplot/# mkdir ~/regionalplots/ && cd ~/regionalplots/
  ~/regionalplots/# tectoplot -r SB -t -z -c --open

  7. If the default PDF viewer doesn't work, set it
  ~/regionalplots/#

  Default variables are stored in ${TECTOPLOTDIR}tectoplot.defaults
  File paths are defined in ${TECTOPLOTDIR}tectoplot.paths
  Data root directory is ${DATAROOT}

EOF
}

# Update if TECTOPLOT_PATHS file is
function datamessage() {
  . $TECTOPLOT_PATHS_MESSAGE
}

function defaultsmessage() {
  cat $TECTOPLOT_DEFAULTS_FILE
}

# awk code inspired by lat_lon_parser.py by Christopher Barker
# https://github.com/NOAA-ORR-ERD/lat_lon_parser

# This function will take a string in the (approximate) form
# +-[deg][chars][min][chars][sec][chars][north|*n*]|[south|*s*]|[east|*e*]|[west|*w*][chars]
# and return the appropriately signed decimal degree
# -125°12'18" -> -125.205
# 125 12 18 WEST -> -125.205

function coordinate_parse() {
  echo $1 | gawk '
  @include "tectoplot_functions.awk"
  {
    printf("%.10f\n", coordinate_decimal($0))
  }'
}


# This function will check for and attempt to download data.


function check_and_download_dataset() {

  DOWNLOADNAME=$1
  DOWNLOAD_SOURCEURL=$2
  DOWNLOADGETZIP=$3
  DOWNLOADDIR=$4
  DOWNLOADFILE=$5
  DOWNLOADZIP=$6
  DOWNLOADFILE_BYTES=$7
  DOWNLOADZIP_BYTES=$8

  # Uncomment to understand why a download command is failing
  # echo DOWNLOADNAME=$1
  # echo DOWNLOAD_SOURCEURL=$2
  # echo DOWNLOADGETZIP=$3
  # echo DOWNLOADDIR=$4
  # echo DOWNLOADFILE=$5
  # echo DOWNLOADZIP=$6
  # echo DOWNLOADFILE_BYTES=$7
  # echo DOWNLOADZIP_BYTES=$8

  # First check if the download directory exists. If not, create it.

  info_msg "Checking ${DOWNLOADNAME}..."
  if [[ ! -d ${DOWNLOADDIR} ]]; then
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} does not exist. Creating."
    mkdir -p ${DOWNLOADDIR}
  else
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} exists."
  fi

  trytounzipflag=0
  testfileflag=0

  # Check if the target download file exists

  if [[ ! -e ${DOWNLOADFILE} ]]; then

    # If the target file doesn't already exist, check if we need to download an archive file
    if [[ $DOWNLOADGETZIP =~ "yes" ]]; then

      # If we need to download a ZIP file, check if we have the ZIP file already
      if [[ -e ${DOWNLOADZIP} ]]; then

        # If we already have a ZIP file, check whether its size matches the
        if [[ ! $DOWNLOADZIP_BYTES =~ "none" ]]; then

          # If the size of the zip is not labeled as 'none', measure its size
          filebytes=$(wc -c < ${DOWNLOADZIP})
          if [[ $(echo "$filebytes == ${DOWNLOADZIP_BYTES}" | bc) -eq 1 ]]; then

            # If the ZIP file matches the expecte size, we are OK
             info_msg "${DOWNLOADNAME} archive file exists and is complete"
          else
            # If the ZIP file doesn't match in size, try to continue its download from its present state
             info_msg "Trying to resume ${DOWNLOADZIP} download. If this doesn't work, delete ${DOWNLOADZIP} and retry."
             if ! curl --fail -L -C - ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADZIP}; then
               info_msg "Attempted resumption of ${DOWNLOAD_SOURCEURL} download using curl failed."
               echo "${DOWNLOADNAME}_resume" >> tectoplot.failed
             else
               trytounzipflag=1 # curl succeeded, so we will try to extract the ZIP
             fi
          fi
        fi
      fi

      # If we need to download an archive file but don't have it yet,

      if [[ ! -e ${DOWNLOADZIP} ]]; then

        # Trt to download the archive
        info_msg "${DOWNLOADNAME} file ${DOWNLOADFILE} and ZIP do not exist. Downloading ZIP from source URL into ${DOWNLOADDIR}."
        if ! curl --fail -L ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADZIP}; then
          info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
          echo "${DOWNLOADNAME}" >> tectoplot.failed
        else
          trytounzipflag=1
        fi
      fi

      # If the archive exists and we are clear to extract it

      if [[ -e ${DOWNLOADZIP} && $trytounzipflag -eq 1 ]]; then
        if [[ ${DOWNLOADZIP: -4} == ".zip" ]]; then
           unzip ${DOWNLOADZIP} -d ${DOWNLOADDIR}
        elif [[ ${DOWNLOADZIP: -6} == "tar.gz" ]]; then
           mkdir -p ${DOWNLOADDIR}
           tar -xf ${DOWNLOADZIP} -C ${DOWNLOADDIR}
        fi
        testfileflag=1
      fi

      # End processing of archive file

    else  # We don't need to download a ZIP - just download the file directly
      if ! curl --fail -L ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADFILE}; then
        info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
        echo "${DOWNLOADNAME}" >> tectoplot.failed
      else
        testfileflag=1
      fi
    fi
  else
    info_msg "${DOWNLOADNAME} file ${DOWNLOADFILE} already exists."
    testfileflag=1
  fi

  # If we are clear to test the target file
  if [[ $testfileflag -eq 1 ]]; then

    # If the file has an expected size
    if [[ ! $DOWNLOADFILE_BYTES =~ "none" ]]; then
      filebytes=$(wc -c < ${DOWNLOADFILE})
      if [[ $(echo "$filebytes == ${DOWNLOADFILE_BYTES}" | bc) -eq 1 ]]; then
        info_msg "${DOWNLOADNAME} file size is verified."
        if [[ ${DOWNLOADGETZIP} =~ "yes" && ${DELETEZIPFLAG} -eq 1 ]]; then
          echo "Deleting zip archive"
          rm -f ${DOWNLOADZIP}
        fi
      else
        info_msg "File size mismatch for ${DOWNLOADFILE} ($filebytes should be $DOWNLOADFILE_BYTES). Trying to continue download."
        if ! curl --fail -L -C - ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADFILE}; then
          info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
          echo "${DOWNLOADNAME}" >> tectoplot.failed
        else
          filebytes=$(wc -c < ${DOWNLOADFILE})
          if [[ $(echo "$filebytes == ${DOWNLOADFILE_BYTES}" | bc) -eq 1 ]]; then
            info_msg "Redownload of ${DOWNLOADNAME} file size is verified."
            if [[ ${DOWNLOADGETZIP} =~ "yes" && ${DELETEZIPFLAG} -eq 1 ]]; then
              echo "Deleting zip archive"
              rm -f ${DOWNLOADZIP}
            fi
          else
            info_msg "Redownload of ${DOWNLOADFILE} ($filebytes) does not match expected size ($DOWNLOADFILE_BYTES)."
          fi
        fi
      fi
    fi
  fi
}

# This function takes a Mw magnitude (e.g. 6.2) and prints the mantissa and
# exponent of the moment magnitude, scaled by a nonlinear stretch factor.

function stretched_m0_from_mw () {
  echo $1 | gawk  -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
            mwmod = ($1^str)/(sref^(str-1))
            a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
            split(a,b,"+")
            split(a,c,"E")
            print c[1], b[2] }'
}

# Stretch a Mw value from a Mw value

function stretched_mw_from_mw () {
  echo $1 | gawk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print ($1^str)/(sref^(str-1))}'
}

function is_gmt_cpt () {
  awk < ${GMTCPTS} -v id="$1" 'BEGIN{res=0} ($1==id) {res=1; exit} END {print res}'
}

function interval_and_subinterval_from_minmax_and_number () {
  local vmin=$1
  local vmax=$2
  local numint=$3
  local subval=$4
  local diffval=$(echo "($vmax - $vmin) / $numint" | bc -l)
  #
  #
  # echo $INTERVALS_STRING | gawk  -v s=$diffval -v md=$subval 'function abs(a) { return (a<0)?-a:a }{
  #   n=split($0, var, " ");
  #   mindiff=var[n];
  #   for(i=0;i<n;i++) {
  #     # print i
  #     diff=var[i]-s;
  #     # print "a", diff
  #     if (abs(diff) < mindiff) {
  #       mindiff=abs(diff)
  #       intval=var[i];
  #     }
  #   }
  #   print intval, intval/md
  # }'
  echo 100 50
}

# Take a string as argument and return an earthquake ID
# Currently just removes whitespace because USGS sometimes has spaces in IDs

function eq_event_parse() {
    echo ${1} | awk '{val=$0; gsub(/\s/,"",val); print val}'
}

### Image processing functions using gdal_calc.py

# out=(A + alpha * (B - A)); = A*(1-alpha)+B*alpha    alpha=1-n   =A*n+B(1-n)
#     (A*n + B(1-n))


function multiply_combine() {
  if [[ ! -e $2 ]]; then
    info_msg "Multiply combine: Raster $2 doesn't exist. Copying $1 to $3."
    cp $1 $3
  else
    info_msg "Executing multiply combine of $1 and $2 (1st can be multi-band) . Result=$3."
    gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --allBands=A --calc="uint8( ( \
                   (A/255.)*(B/255.)
                   ) * 255 )" --outfile=${3}
  fi
}

function alpha_value() {
  info_msg "Executing multiply combine of $1 and $2 [0-1]. Result=$3."
  gdal_calc.py --overwrite --quiet -A ${1} --allBands=A --calc="uint8( ( \
                 ((A/255.)*(1-$2)+(255/255.)*($2))
                 ) * 255 )" --outfile=${3}
}

# function alpha_multiply_combine() {
#   info_msg "Executing alpha $2 on $1 then multiplying with $3 (1st can be multi-band) . Result=$3."
#
# }

function lighten_combine() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band) . Result=$3."
  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --allBands=A --calc="uint8( ( \
                 (A>=B)*A/255. + (A<B)*B/255.
                 ) * 255 )" --outfile=${3}
}

function lighten_combine_alpha() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band)at alpha=$3 . Result=$4."
  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --allBands=B --calc="uint8( ( \
                 (A>=B)*(B/255. + (A/255.-B/255.)*${3}) + (A<B)*B/255.
                 ) * 255 )" --outfile=${4}
}

function darken_combine_alpha() {
  info_msg "Executing lighten combine of $1 and $2 (1st can be multi-band) . Result=$3."
  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --allBands=A --calc="uint8( ( \
                 (A<=B)*A/255. + (A>B)*B/255.
                 ) * 255 )" --outfile=${3}
}

function weighted_average_combine() {
  if [[ ! -e $2 ]]; then
    info_msg "Weighted average combine: Raster $2 doesn't exist. Copying $1 to $4."
    cp $1 $4
  else
    info_msg "Executing weighted average combine of $1(x$3) and $2(x1-$3) (1st can be multi-band) . Result=$4."
    gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --allBands=A --calc="uint8( ( \
                   ((A/255.)*($3)+(B/255.)*(1-$3))
                   ) * 255 )" --outfile=${4}
  fi
}

function gdal_stats {
  gdalinfo -stats $1 | grep "Minimum=" | awk -F, '{print $1; print $2; print $3; print $4}' | awk -F= '{print $2}'
}

# function normalize_sigma() {
#   info_msg "Normalizing raster $1 by $2 sigma to [$3, $4], outputting to $5."
#   gdal_rstats=($(gdal_stats $1))
#   r_mean=${gdal_rstats[2]}
#   r_sd=${gdal_rstats[3]}
#   r_insd=${2}
#   echo "${r_mean} - ${r_insd} * ${r_sd}"
#   echo "${r_mean} + ${r_insd} * ${r_sd}"
#   r_newmin=$(echo "${r_mean} - ${r_insd} * ${r_sd}" | bc -l)
#   r_newmax=$(echo "${r_mean} + ${r_insd} * ${r_sd}" | bc -l)
#
#   if [[ $(echo "${r_newmin} < 0" | bc -l) -eq 1 ]]; then
#     r_newmin=0
#   fi
#   if [[ $(echo "${r_newmax} > 255" | bc -l) -eq 1 ]]; then
#     r_newax=255
#   fi
#
# echo   histogram_rescale $1 $r_newmin $r_newmax $3 $4 $5
#
#   histogram_rescale $1 $3 $4 $r_newmin $r_newmax $5
# }

function gamma_stretch() {
  info_msg "Executing gamma stretch of ($1^(1/(gamma=$2))). Output is $3"
  gdal_calc.py --overwrite --quiet -A $1 --allBands=A --calc="uint8( ( \
          (A/255.)**(1/${2})
          ) * 255 )" --outfile=${3}
}

# Linearly rescale an image $1 from ($2, $3) to ($4, $5) output to $6
function histogram_rescale() {
  gdal_translate -q $1 $6 -scale $2 $3 $4 $5
}


# Rescale image $1 to remove values below $2% and above $3%, output to $4
function histogram_percentcut_byte() {
  # gdalinfo -hist produces a 256 bucket equally spaced histogram
  # Every integer after the first blank line following the word "buckets" is a histogram value

  cutrange=($(gdalinfo -hist $1 | tr ' ' '\n' | awk -v mincut=$2 -v maxcut=$3 '
    BEGIN {
      outa=0
      outb=0
      ind=0
      sum=0
      cum=0
    }
    {
      if($1=="buckets") {
        outa=1
        getline # from
        getline # minimum
        minval=$1+0
        getline # to
        getline # maximum:
        maxval=$1+0
      }
      if (outb==1 && $1=="NoData") {
        exit
      }
      if($1=="" && outa==1) {
        outb=1
      }
      if (outb==1 && $1==int($1)) {
        vals[ind]=$1
        cum=cum+$1
        cums[ind++]=cum*100
        sum+=$1
      }
    }
    # Now calculate the percentiles
    END {
      print minval
      print maxval
      for (key in vals) {
        range[key]=(maxval-minval)/255*key+minval
      }
      foundmin=0
      for (key in cums) {
        if (cums[key]/sum >= mincut && foundmin==0) {
          print range[key]
          foundmin=1
        }
        if (cums[key]/sum >= maxcut) {
          print range[key]
          exit
        }
        # print key, cums[key]/sum, range[key]
      }
    }'))
    gdal_translate -q $1 $4 -scale ${cutrange[2]} ${cutrange[3]} 1 254 -ot Byte
    gdal_edit.py -unsetnodata $4
}

# image_setval ${F_TOPO}intensity.tif ${F_TOPO}dem.nc 0 254 ${F_TOPO}unset.tif

# If raster $2 has value $3, outval=$4, else outval=raster $1, put into $5
function image_setval() {
  gdal_calc.py --type=Byte --overwrite --quiet -A $1 -B $2 --calc="uint8(( (B==${3})*$4.+(B!=${3})*A))" --outfile=$5
}


# Linearly rescale an image $1 from ($2, $3) to ($4, $5), stretch by $6>0, output to $7
function histogram_rescale_stretch() {
  gdal_translate -q $1 $7 -scale $2 $3 $4 $5 -exponent $6
}

# Select cells from $1 within a [$2 $3] value range; else set to $4. Output to $5
function histogram_select() {
   gdal_calc.py --overwrite --quiet -A $1 --allBands=A --calc="uint8(( \
           (A>=${2})*(A<=${3})*(A-$4) + $4
           ))" --outfile=${5}
}

# Select cells from $1 within a [$2 $3] value range; set to $4 if so, else set to $5. Output to $6
function histogram_select_set() {
   gdal_calc.py --overwrite --quiet -A $1 --allBands=A --calc="uint8(( \
           (A>=${2})*(A<=${3})*(${4}-${5}) + $5
           ))" --outfile=${6}
}

function overlay_combine() {
  info_msg "Overlay combining $1 and $2. Output is $3"
  gdal_calc.py --overwrite --quiet -A $1 -B $2 --allBands=A --calc="uint8( ( \
          (2 * (A/255.)*(B/255.)*(A<128) + \
          (1 - 2 * (1-(A/255.))*(1-(B/255.)) ) * (A>=128))/2 \
          ) * 255 )" --outfile=${3}
}

function flatten_sea() {
  info_msg "Setting DEM elevations less than 0 to 0"
  gdal_calc.py --overwrite --type=Float32 --format=NetCDF --quiet -A "${1}" --calc="((A>=0)*A + (A<0)*0)" --outfile="${2}"
}

# Takes a RGB tiff ${1} and a DEM ${2} and sets R=${3} G=${4} B=${5} for cells where DEM<=0, output to ${6}

function recolor_sea() {

  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --B_band=1 --calc  "uint8(255*((A>0)*B/255. + (A<=0)*${3}/255.))" --type=Byte --outfile=outA.tif
  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --B_band=2 --calc  "uint8(255*((A>0)*B/255. + (A<=0)*${4}/255.))" --type=Byte --outfile=outB.tif
  gdal_calc.py --overwrite --quiet -A ${1} -B ${2} --B_band=3 --calc  "uint8(255*((A>0)*B/255. + (A<=0)*${5}/255.))" --type=Byte --outfile=outC.tif

  # merge the out files
  rm -f ${6}
  gdal_merge.py -q -co "PHOTOMETRIC=RGB" -separate -o ${6} outA.tif outB.tif outC.tif
}


################################################################################
################################################################################
# MAIN BODY OF SCRIPT

# Startup code that runs every time the script is called

case "$OSTYPE" in
   cygwin*)
      alias open="cmd /c start"
      ;;
   linux*)
      alias open="xdg-open"
      ;;
   darwin*)
      alias start="open"
      ;;
esac

# Declare the associative array of items to be removed on exit

declare -a on_exit_items

# Load GMT shell functions
. gmt_shell_functions.sh


# If an old tectoplot.info_msg file exists, save it as a copy
[[ -e ./tectoplot.info_msg ]] && mv ./tectoplot.info_msg ./tectoplot.info_msg.old

################################################################################
# Define paths and defaults

THISDIR=$(pwd)

GMTREQ="6"
RJOK="-R -J -O -K"

# TECTOPLOTDIR is where the actual script resides
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
TECTOPLOTDIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd )"/

DEFDIR=$TECTOPLOTDIR"tectoplot_defs/"

# These files are sourced using the . command, so they should be valid bash
# scripts but without #!/bin/bash

TECTOPLOT_DEFAULTS_FILE=$DEFDIR"tectoplot.defaults"
TECTOPLOT_PATHS_FILE=$DEFDIR"tectoplot.paths"
TECTOPLOT_PATHS_MESSAGE=$DEFDIR"tectoplot.paths.message"
TECTOPLOT_COLORS=$DEFDIR"tectoplot.gmtcolors"
TECTOPLOT_CPTDEFS=$DEFDIR"tectoplot.cpts"
TECTOPLOT_AUTHOR=$DEFDIR"tectoplot.author"

# Awk functions are stored here:
export AWKPATH=${TECTOPLOTDIR}"awkscripts/"

# echo "$AWKPATH"
# gawk '
#   @include "tectoplot_functions.awk"
#   BEGIN {
#   test_include()
# }'

################################################################################
# Load CPT defaults, paths, and defaults

if [[ -e $TECTOPLOT_CPTDEFS ]]; then
  . $TECTOPLOT_CPTDEFS
else
  error_msg "CPT definitions file does not exist: $TECTOPLOT_CPTDEFS"
  exit 1
fi

if [[ -e $TECTOPLOT_PATHS_FILE ]]; then
  . $TECTOPLOT_PATHS_FILE
else
  # No paths file exists! Warn and exit.
  error_msg "Paths file does not exist: $TECTOPLOT_PATHS_FILE"
  exit 1
fi

if [[ -e $TECTOPLOT_DEFAULTS_FILE ]]; then
  . $TECTOPLOT_DEFAULTS_FILE
else
  # No defaults file exists! Warn and exit.
  error_msg "Defaults file does not exist: $TECTOPLOT_DEFAULTS_FILE"
  exit 1
fi

# Check GMT version (modified code from Mencin/Vernant 2015 p_tdefnode.bash)
if [ `which gmt` ]; then
	GMT_VERSION=$(gmt --version)
	if [ ${GMT_VERSION:0:1} != $GMTREQ ]; then
		echo "GMT version $GMTREQ is required"
		exit 1
	fi
else
	echo "$name: Cannot call gmt"
	exit 1
fi

FULL_TMP=$(abs_path ${TMP})

# DEFINE FLAGS (only those set to not equal zero are actually important to define)
if [[ 1 -eq 1 ]]; then
  calccmtflag=0
  customgridcptflag=0
  defnodeflag=0
  defaultrefflag=0
  doplateedgesflag=0
  dontplottopoflag=0
  euleratgpsflag=0
  eulervecflag=0
  filledcoastlinesflag=0
  gpsoverride=0
  keepopenflag=0
  legendovermapflag=0
  makelegendflag=0
  makegridflag=0
  makelatlongridflag=0
  manualrefplateflag=0
  narrateflag=0
  openflag=0
  outflag=0
  outputplatesflag=0
  overplotflag=0
  overridegridlinespacing=0
  platerotationflag=0
  plotcustomtopo=0
  ploteulerobsresflag=0
  plotmag=0
  plotplateazdiffsonly=0
  plotplates=0
  plotshiftflag=0
  plotsrcmod=0
  plottopo=0
  psscaleflag=0
  refptflag=0
  remakecptsflag=0
  replotflag=0
  strikedipflag=0
  svflag=0
  tdeffaultlistflag=0
  tdefnodeflag=0
  twoeulerflag=0
  usecustombflag=0
  usecustomgmtvars=0
  usecustomrjflag=0

  # Flags that start with a value of 1

  cmtnormalflag=1
  cmtssflag=1
  cmtthrustflag=1
  kinnormalflag=1
  kinssflag=1
  kinthrustflag=1
  normalstyleflag=1
  np1flag=1
  np2flag=1
  platediffvcutoffflag=1
fi

###### The list of things to plot starts empty

plots=()

# Argument arrays that are slurped

customtopoargs=()
imageargs=()
topoargs=()

# The full command is output into the ps file and .history file. We don't
# include the full path to the script anymore.

COMMANDBASE=$(basename $0)
C2=${@}
COMMAND="${COMMANDBASE} ${C2}"

# Exit if no arguments are given
if [[ $# -eq 0 ]]; then
  print_usage
  exit 1
fi

# SPECIAL CASE 1: If only one argument is given and it is '-remake', rerun
# the command in file tectoplot.last and exit
if [[ $# -eq 1 && ${1} =~ "-remake" ]]; then
  info_msg "Rerunning last tectoplot command executed in this directory"
  cat tectoplot.last
  . tectoplot.last
  exit 1
fi

# SPECIAL CASE 2: If two arguments are given and the first is -remake, then
# use the first line in the file given as the second argument as the command
if [[ $# -eq 2 && ${1} =~ "-remake" ]]; then
  if [[ ! -e ${2} ]]; then
    error_msg "Error: no file ${2}"
  fi
  head -n 1 ${2} > tectoplot.cmd
  info_msg "Rerunning last tectoplot command from first line in file ${2}"
  cat tectoplot.cmd
  . tectoplot.cmd
  exit 0
fi

# SPECIAL CASE 3: If the first argument is -query, OR if the first argument is
# -tm|--tempdir, the second argument is a file, and the third argument is -query,
# then process the query request and exit.
# tectoplot -tm this_dir/ -query seismicity/eqs.txt

if [[ $# -ge 3 && ${1} == "-tm" && ${3} == "-query" ]]; then
  # echo "Processing query request"
  if [[ ! -d ${2} ]]; then
    info_msg "[-query]: Temporary directory ${2} does not exist"
    exit 1
  else
    tempdirqueryflag=1
    cd "${2}"
    shift
    shift
  fi
fi

if [[ $1 == "-query" ]]; then
  shift
  # echo "Entered query processing block"
  if [[ ! $tempdirqueryflag -eq 1 ]]; then
    if [[ ! -d ${TMP} ]]; then
      echo "Temporary directory $TMP does not exist"
      exit 1
    else
      cd ${TMP}
    fi
  fi
  query_headerflag=1

  # First argument to -query needs to be a filename.

  if [[ ! -e $1 ]]; then
    # IF the file doesn't exist in the temporary directory, search for it in a
    # subdirectory.
    searchname=$(find . -name $1 -print)
    if [[ -e $searchname ]]; then
      fullpath=$(abs_path $searchname)
      QUERYFILE=$fullpath
      QUERYID=$(basename "$searchname")
      shift
    else
      exit 1
    fi
  else
    QUERYFILE=$(abs_path $1)
    QUERYID=$(basename "$1")
    shift
  fi

  headerline=($(grep "^$QUERYID" $TECTOPLOT_HEADERS))
  # echo ${headerline[@]}
  if [[ ${headerline[0]} != $QUERYID ]]; then
    echo "query ID $QUERYID not found in headers file $TECTOPLOT_HEADERS"
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    key="${1}"
    case ${key} in
      [0-9]*)
        # echo "Detected number argument $key"
        keylist+=("$key")
        if [[ "${headerline[$key]}" == "" ]]; then
          fieldlist+=("none")
        else
          fieldlist+=("${headerline[$key]}")
        fi
        ;;
      noheader)
        query_headerflag=0
        ;;
      nounits)
        query_nounitsflag=1
        ;;
      csv)
        query_csvflag=1
        ;;
      data)
        query_dataflag=1
        ;;
      *) # should get index of field coinciding with argument
        # echo "Other argument $key"
        ismatched=0
        for ((i=1; i < ${#headerline[@]}; ++i)); do
          # This needs to exactly match the field name before [...]
          lk=${#key}
          # echo $key $lk ${headerline[$i]:0:$lk} ${headerline[$i]:$lk:1}
          if [[ "${headerline[$i]:0:$lk}" == "${key}" && "${headerline[$i]:$lk:1}" == "[" ]]; then
            # echo "Found likely index for $key at index $i"
            keylist+=("$i")
            fieldlist+=("${headerline[$i]}")
            ismatched=1
          fi
        done
        if [[ $ismatched -eq 0 ]]; then
          echo "[-query]: Could not find field named $key"
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ ${#fieldlist[@]} -eq 0 ]]; then
    # echo "No fields: header is"
    fieldlist=(${headerline[@]:1})
    # echo ${fieldlist[@]}
  fi

  if [[ $query_headerflag -eq 1 ]]; then
    if [[ $query_nounitsflag -eq 1 ]]; then
      if [[ $query_csvflag -eq 1 ]]; then
        echo "${fieldlist[@]}" | sed 's/\[[^][]*\]//g' | tr ' ' ','
      else
        echo "${fieldlist[@]}" | sed 's/\[[^][]*\]//g'
      fi
    else
      if [[ $query_csvflag -eq 1 ]]; then
        echo "${fieldlist[@]}" | tr ' ' ','
      else
        echo "${fieldlist[@]}"
      fi
    fi
  fi

  if [[ $query_dataflag -eq 1 ]]; then
    keystr="$(echo ${keylist[@]})"
    gawk < ${QUERYFILE} -v keys="$keystr" -v csv=$query_csvflag '
    BEGIN {
      if (csv==1) {
        sep=","
      } else {
        sep=" "
      }
      numkeys=split(keys, keylist, " ")
      if (numkeys==0) {
        getline
        numkeys=NF
        for(i=1; i<=NF; i++) {
          keylist[i]=i
        }
        for(i=1; i<=numkeys-1; i++) {
          printf "%s%s", $(keylist[i]), sep
        }
        printf("%s\n", $(keylist[numkeys]))
      }
    }
    {
      for(i=1; i<=numkeys-1; i++) {
        printf "%s%s", $(keylist[i]), sep
      }
      printf("%s\n", $(keylist[numkeys]))
    }'
  fi
  exit 1
fi

# This file needs to be reset as they are used before the tempdir is created

rm -f tectoplot.sources
rm -f tectoplot.shortsources

##### Look for high priority arguments that need to be executed first

saved_args=( "$@" );
while [[ $# -gt 0 ]]
do
  key="${1}"
  case ${key} in
  -megadebug)
    set -x
    ;;
  -n|--narrate)
    narrateflag=1
    info_msg "${COMMAND}"
    ;;
  -pss)
    # Set size of the postscript page
    if arg_is_positive_float $2; then
      PSSIZE="${2}"
      shift
    else
      error_msg "[-pss]: PSSIZE $2 is not a positive number."
    fi
    ;;
  --verbose) # args: none
    VERBOSE="-V"
    ;;
  esac
  shift
done
set -- "${saved_args[@]}"

##### Parse command line arguments

while [[ $# -gt 0 ]]
do
  key="${1}"
  case ${key} in

  # Command 'recipes'

  -recenteq) # args: none | days
    if arg_is_flag $2; then
      info_msg "[-recenteq]: No day number specified, using last 7 days"
      LASTDAYNUM=7
    else
      info_msg "[-recenteq]: Using start of day ${2} days ago to end of today"
      LASTDAYNUM="${2}"
      shift
    fi
    # info_msg "Updating databases"
    # . $SCRAPE_GCMT
    # . $SCRAPE_ISCFOC
    # . $SCRAPE_ANSS
    # . $MERGECATS
    # Turn on time select
    timeselectflag=1
    STARTTIME=$(date_shift_utc -${LASTDAYNUM} 0 0 0)
    ENDTIME=$(date_shift_utc)    # COMPATIBILITY ISSUE WITH GNU date
    shift
    set -- "blank" "-a" "a" "-z" "-c" "--time" "${STARTTIME}" "${ENDTIME}" "$@"
    ;;
  -seismo)
    shift
    set -- "blank" "-t" "-t1" "-z" "-c" "-cmag" "$@"
    ;;
  -topog)
    shift
    set -- "blank" "-t" "-t1" "-ob" "45" "20" "3" "$@"
    ;;
  -sunlit)
    shift
    set -- "blank" "-t" "-tuni" "-tshad" "-ob" "45" "20" "3" "$@"
    ;;


  -eventmap)
    if arg_is_flag $2; then
      info_msg "[-eventmap]: Needs earthquakeID"
      exit 1
    else
      EVENTMAP_ID=$(eq_event_parse "${2}")
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-eventmap]: No degree buffer specified. Using 2 degrees"
      EVENTMAP_DEGBUF=2
    else
      EVENTMAP_DEGBUF="${2}"
      shift
    fi
    shift # Gets rid of EVENTMAP_ID somehow...
    #
    set -- "blank" "-r" "eq" ${EVENTMAP_ID} ${EVENTMAP_DEGBUF} "-t" "-b" "c" "-z" "-c" "-eqlist" "{" "${EVENTMAP_ID}" "}" "-eqlabel" "list" "--legend" "-cprof" "eq" "eq" "slab2" "300" "100k" "-oto" "-mob" "-title" "Earthquake $EVENTMAP_ID" "$@"
    ;;

  # Normal commands

  -a) # args: none || string
    plotcoastlines=1
    if arg_is_flag $2; then
			info_msg "[-a]: No quality specified. Using a"
			COAST_QUALITY="-Da"
		else
			COAST_QUALITY="-D${2}"
			shift
		fi
    # if arg_is_flag $2; then
    #   info_msg "[-a]: No line categories specified. Plotting ocean coastlines only."
    # else
    #   if [[ {$2} =~ .*c.* ]]; then
    #     info_msg "[-a]: Selected ocean coastlines"
    #   fi
    #   if [[ {$2} =~ .*b.* ]]; then
    #     info_msg "[-a]: Selected national borders"
    #     coastplotbordersflag=1
    #   fi
    #   shift
    # fi
    plots+=("coasts")
    echo $COASTS_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $COASTS_SOURCESTRING >> tectoplot.sources
    ;;

  -ac) # args: landcolor seacolor
    filledcoastlinesflag=1
    if arg_is_flag $2; then
      info_msg "[-ac]: No land/sea color specified. Using defaults"
      FILLCOASTS="-G${LANDCOLOR} -S${SEACOLOR}"
    else
      LANDCOLOR="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-ac]: No sea color specified. Not filling sea areas"
      FILLCOASTS="-G${LANDCOLOR}"
    else
      SEACOLOR="${2}"
      shift
      FILLCOASTS="-G$LANDCOLOR -S$SEACOLOR"
    fi
    ;;

  -acb)
    plots+=("countryborders")
    if arg_is_flag $2; then
      info_msg "[-acb]: No border line color specified. Using $BORDER_LINECOLOR"
    else
      BORDER_LINECOLOR="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-acb]: No border line width specified. Using $BORDER_LINEWIDTH"
    else
      BORDER_LINEWIDTH="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-acb]: No border quality specified [a,l,f]. Using $BORDER_QUALITY"
    else
      BORDER_QUALITY="-D${2}"
      shift
    fi
    ;;

  -acl)
    plots+=("countrylabels")
    ;;

  -addpath)   # Add tectoplot source directory to ~/.profile and exit
      if [[ ! -e ~/.profile ]]; then
        info_msg "[-addpath]: ~/.profile does not exist. Creating."
      else
        val=$(grep "tectoplot" ~/.profile | gawk  'END{print NR}')
        info_msg "[-addpath]: Backing up ~/.profile file to ${DEFDIR}".profile_old""

        if [[ ! $val -eq 0 ]]; then
          echo "[-addpath]: Warning: found $val lines containing tectoplot in ~/.profile. Remove manually."
        fi
        cp ~/.profile ${DEFDIR}".profile_old"
      fi
      echo >> ~/.profile
      echo "# tectoplot " >> ~/.profile
      echo "export PATH=${TECTOPLOTDIR}:\$PATH" >> ~/.profile
      exit
    ;;

  -af) # args: string string
    if arg_is_flag $2; then
      info_msg "[-af]: No line width specified. Using $AFLINEWIDTH"
    else
      AFLINEWIDTH="${2}"
      shift
      if arg_is_flag $2; then
        info_msg "[-af]: No line color specified. Using $AFLINECOLOR"
      else
        AFLINECOLOR="${2}"
        shift
      fi
    fi
    plots+=("gemfaults")
    ;;

  -alignxy)
    if arg_is_flag $2; then
      info_msg "[-alignxy]: No XY dataset specified. Not aligning profiles."
    else
      ALIGNXY_FILE=$(abs_path $2)
      shift
      if [[ ! -e $ALIGNXY_FILE ]]; then
        info_msg "[-alignxy]: XY file $ALIGNXY_FILE does not exist."
      else
        info_msg "[-alignxy]: Aligning profiles to $ALIGNXY_FILE."
        alignxyflag=1
      fi
    fi
    ;;

  -cprof) # args lon lat az length width res
  # Create profiles by constructing a new mprof) file with relevant data types
  # where the profile is specified by central point and azimuth

    # Sprof and cprof share SPROFWIDTH and SPROF_RES

    if arg_is_float $2; then
      CPROFLON="${2}"
      shift
    else
      if [[ $2 =~ "eq" ]]; then
        CPROFLON="eqlon"
        shift
      else
        info_msg "[-cprof]: No central longitude specified."
        exit
      fi
    fi
    if arg_is_float $2; then
      CPROFLAT="${2}"
      shift
    else
      if [[ $2 =~ "eq" ]]; then
        CPROFLAT="eqlat"
        shift
      else
        info_msg "[-cprof]: No central latitude specified."
        exit
      fi
    fi
    if arg_is_float $2; then
      CPROFAZ="${2}"
      shift
    else
      if [[ $2 =~ "slab2" ]]; then
        shift
        CPROFAZ="slab2"
      else
        info_msg "[-cprof]: No profile azimuth specified."
        exit
      fi
    fi
    if arg_is_float $2; then
      CPROFLEN="${2}"
      shift
    else
      info_msg "[-cprof]: No profile length specified."
      exit
    fi

    if arg_is_flag $2; then
      info_msg "[-cprof]: No width specified. Using 100k"
      SPROFWIDTH="100k"
    else
      SPROFWIDTH="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-cprof]: No resolution specified. Using 1k"
      SPROF_RES="1k"
    else
      SPROF_RES="${2}"
      shift
    fi

    cprofflag=1
    clipdemflag=1



    CPROFHALFLEN=$(echo "${CPROFLEN}" | gawk '{ print ($1+0)/2 }')

    # Create the template file that will be used to generate the cprof_profs.txt file
    # antiaz foreaz centerlon|eqlon centerlat|eqlat cprofhalflen
    echo $CPROFAZ $CPROFLON $CPROFLAT $CPROFHALFLEN >> ./cprof_prep.txt
    # Calculate the profile start and end points based on the given information
  ;;

  -aprof) # args: aprofcode1 aprofcode2 ... width res
    # Create profiles by constructing a new mprof) file with relevant data types
    aprofflag=1

    while [[ "${2}" == [A-Y][A-Y] ]]; do
      aproflist+=("${2}")
      shift
    done

    if arg_is_flag $2; then
      info_msg "[-aprof]: No width specified. Using 100k"
      SPROFWIDTH="100k"
    else
      SPROFWIDTH="${2}"
      shift
    fi

    if arg_is_flag $2; then
      info_msg "[-aprof]: No sampling interval specified. Using 1k"
      SPROF_RES="1k"
    else
      SPROF_RES="${2}"
      shift
    fi

    clipdemflag=1

    # echo "aprof profiles are ${aproflist[@]} / $SPROFWIDTH / $SPROF_RES"
    # cat aprof_profs.txt
    plots+=("mprof")

    ;;

  -aprofcodes)
    if arg_is_flag $2; then
      info_msg "[-aprofcodes]: No character string given. Plotting all codes."
      APROFCODES="ABCDEFGHIJKLMNOPQRSTUVWXY"
    else
      APROFCODES="${2}"
      shift
    fi
      plots+=("aprofcodes")
    ;;

  -author)
    authorflag=1
    if arg_is_flag $2; then
      info_msg "[-author]: No author indicated."
      if [[ -e $TECTOPLOT_AUTHOR ]]; then
        info_msg "Using author info in ${DEFDIR}tectoplot.author"
        AUTHOR_ID=$(head -n 1 $DEFDIR"tectoplot.author")
      else
        info_msg "No author in ${DEFDIR}tectoplot.author and no author indicated"
        AUTHOR_ID=""
      fi
    else
      AUTHOR_ID="${2}"
      shift
      if [[ ! -e $DEFDIR"tectoplot.author" ]]; then
        if [[ ! $AUTHOR_ID == "reset" ]]; then
          info_msg "Setting author information in ${DEFDIR}tectoplot.author: ${2}"
          echo "$AUTHOR_ID" > $TECTOPLOT_AUTHOR
        fi
      fi
      if [[ $AUTHOR_ID == "reset" ]]; then
        info_msg "Resetting ${DEFDIR}tectoplot.author"
        rm -f $TECTOPLOT_AUTHOR
        AUTHOR_ID=""
      fi
    fi
    DATE_ID=$(date -u $DATE_FORMAT)
    ;;

  -authoryx)
    if arg_is_float $2; then
      AUTHOR_YSHIFT="${2}"
      info_msg "[-authoryx]: Shifting author info (Y) by $AUTHOR_YSHIFT"
      shift
    else
      info_msg "[-authoryx]: No Y shift indicated. Using $AUTHOR_YSHIFT (i)"
    fi
    if arg_is_float $2; then
      AUTHOR_XSHIFT="${2}"
      info_msg "[-authoryx]: Shifting author info (X) by $AUTHOR_XSHIFT"
      shift
    else
      info_msg "[-authoryx]: No X shift indicated. Using $AUTHOR_XSHIFT (i)"
    fi
    ;;

	-b|--slab2) # args: none || strong
		if arg_is_flag $2; then
			info_msg "[-b]: Slab2 control string not specified. Using c"
			SLAB2STR="c"
		else
			SLAB2STR="${2}"
			shift
		fi
    plotslab2=1
		plots+=("slab2")
    cpts+=("seisdepth")
    echo $SLAB2_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $SLAB2_SOURCESTRING >> tectoplot.sources
		;;

  -B) # args: { ... }
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-B]: B argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          bj+=("${2}")
          shift
      done
      shift
      BSTRING="${bj[@]}"
    fi
    usecustombflag=1
    info_msg "[-B]: Custom map frame string: ${BSTRING[@]}"
    ;;

	-c|--cmt) # args: none || number
		calccmtflag=1
		plotcmtfromglobal=1
    cmtsourcesflag=1
    # CMTFILE=$FOCALCATALOG

    # Select focal mechanisms from GCMT, ISC, GCMT+ISC
    if arg_is_flag $2; then
      CENTROIDFLAG=1
      ORIGINFLAG=0
      CMTTYPE="CENTROID"
    else
      CMTTYPE="${2}"
      shift
      case ${CMTTYPE} in
        ORIGIN)
          CENTROIDFLAG=0
          ORIGINFLAG=1
          ;;
        CENTROID)
          CENTROIDFLAG=1
          ORIGINFLAG=0
          ;;
        *)
          info_msg "[-c]: Allowed CMT types are ORIGIN and CENTROID"
        ;;
      esac
      if arg_is_flag $2; then
        info_msg "[-c]: No scaling for CMTs specified... using default $CMTSCALE"
      else
        CMTSCALE="${2}"
        info_msg "[-c]: CMT scale updated to $CMTSCALE"
        shift
      fi
    fi
		plots+=("cmt")
    cpts+=("seisdepth")
    echo $ISC_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $ISC_SOURCESTRING >> tectoplot.sources
    echo $GCMT_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $GCMT_SOURCESTRING >> tectoplot.sources
    echo $GFZ_SOURCESTRING >> tectoplot.sources
    echo $GFZ_SHORT_SOURCESTRING >> tectoplot.shortsources
	  ;;

  -ca) #  [nts] [tpn] plot selected P/T/N axes for selected EQ types
    calccmtflag=1
    cmtsourcesflag=1
    if arg_is_flag $2; then
      info_msg "[-ca]: CMT axes eq type not specified. Using default ($CMTAXESSTRING)"
    else
      CMTAXESSTRING="${2}"
      shift
      if arg_is_flag $2; then
        info_msg "[-ca]: CMT axes selection string not specfied. Using default ($CMTAXESTYPESTRING)"
      else
        CMTAXESTYPESTRING="${2}"
        shift
      fi
    fi
    [[ "${CMTAXESSTRING}" =~ .*n.* ]] && axescmtnormalflag=1
    [[ "${CMTAXESSTRING}" =~ .*t.* ]] && axescmtthrustflag=1
    [[ "${CMTAXESSTRING}" =~ .*s.* ]] && axescmtssflag=1
    [[ "${CMTAXESTYPESTRING}" =~ .*p.* ]] && axespflag=1
    [[ "${CMTAXESTYPESTRING}" =~ .*t.* ]] && axestflag=1
    [[ "${CMTAXESTYPESTRING}" =~ .*n.* ]] && axesnflag=1
    plots+=("caxes")
    ;;

  -cadd)
    cmtfilenumber=$(echo "$cmtfilenumber+1" | bc)
    if arg_is_flag $2; then
      info_msg "[-cadd]: CMT file must be specified"
    else
      CMTADDFILE[$cmtfilenumber]=$(abs_path $2)
      if [[ ! -e "${CMTADDFILE[$cmtfilenumber]}" ]]; then
        info_msg "CMT file ${CMTADDFILE[$cmtfilenumber]} does not exist"
      fi
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-cadd]: CMT format code not specified. Using a (Aki and Richards)"
      CMTFORMATCODE[$cmtfilenumber]="a"
    else
      CMTFORMATCODE[$cmtfilenumber]="${2}"
      shift
    fi
    if [[ "${2}" != "replace" ]]; then
      info_msg "[-cadd]: CMT replace flag not specified. Not replacing catalog CMTs."
      cmtreplaceflag=0
    else
      cmtreplaceflag=1
      shift
    fi
    CMTIDCODE[$cmtfilenumber]="c"   # custom ID
    addcustomcmtsflag=1
    calccmtflag=1
    ;;

  -cc) # args: none
    connectalternatelocflag=1
    ;;

  -cd|--cmtdepth)  # args: number
    CMT_MAXDEPTH="${2}"
    shift
    ;;

  -cf) # args: string
    if arg_is_flag $2; then
      info_msg "[-cf]: CMT format not specified (GlobalCMT, MomentTensor, PrincipalAxes). Using default ${CMTFORMAT}"
    else
      CMTFORMAT="${2}"
      shift
      #CMTFORMAT="PrincipalAxes"        # Choose from GlobalCMT / MomentTensor/ PrincipalAxes
      case $CMTFORMAT in
      GlobalCMT)
        CMTLETTER="c"
        ;;
      MomentTensor)
        CMTLETTER="m"
        ;;
      TNP)
        CMTLETTER="y"
        ;;
      *)
        info_msg "[-cf]: CMT format ${CMTFORMAT} not recognized. Using GlobalCMT"
        CMTFORMAT="GlobalCMT"
        CMTLETTER="c"
        ;;
      esac
    fi
    ;;

  -clipdem)
    clipdemflag=1
    ;;

  -clipgrav)
    clipgravflag=1
    ;;

  -clipon)
    CLIP_POLY_FILE=$(abs_path $2)
    shift
    plots+=("clipon")
    ;;

  -clipoff)
    plots+=("clipoff")
    ;;

  -cmag) # args: number number
    if arg_is_flag $2; then
      info_msg "[-cmag]: No magnitudes speficied. Using $CMT_MINMAG - $CMT_MAGMAG"
    else
      CMT_MINMAG="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-cmag]: No maximum magnitude speficied. Using $CMT_MAGMAG"
    else
      CMT_MAXMAG="${2}"
      shift
    fi
    cmagflag=1
    ;;

  -cn|--contour)
    if arg_is_flag $2; then
      info_msg "[-cn]: Grid file not specified"
    else
      CONTOURGRID=$(abs_path $2)
      shift
      if arg_is_flag $2; then
        info_msg "[-cn]: Contour interval not specified. Calculating automatically from Z range using $CONTOURNUMDEF contours"
        gridcontourcalcflag=1
      else
        CONTOURINTGRID="${2}"
        shift
      fi
    fi
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-cn]: GMT argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          gridvars+=("${2}")
          shift
      done
      shift
      CONTOURGRIDVARS="${gridvars[@]}"
    fi
    info_msg "[-cn]: Custom GMT grid contour commands: ${CONTOURGRIDVARS[@]}"
    plots+=("gridcontour")
    ;;

  -command)
    printcommandflag=1
    ;;

  -countries)
    if arg_is_positive_float $2; then
      COUNTRIES_TRANS="${2}"
      shift
    fi
    plots+=("countries")
    ;;

  -cpts)
    remakecptsflag=1
    ;;

  -cr|--cmtrotate) # args: number number
    # Nothing yet
    cmtrotateflag=1
    CMT_ROTATELON="${2}"
    CMT_ROTATELAT="${3}"
    CMT_REFAZ="${4}"
    shift
    shift
    shift
    ;;

  -cs) # args: none
    caxesstereonetflag=1
    ;;

  -ct|--cmttype) # args: string
		calccmtflag=1
		cmtnormalflag=0
		cmtthrustflag=0
		cmtssflag=0
		if arg_is_flag $2; then
			info_msg "[-ct]: CMT eq type string is malformed"
		else
			[[ "${2}" =~ .*n.* ]] && cmtnormalflag=1
			[[ "${2}" =~ .*t.* ]] && cmtthrustflag=1
			[[ "${2}" =~ .*s.* ]] && cmtssflag=1
			shift
		fi
		;;

  -cw) # args: none
    CMT_THRUSTCOLOR="gray100"
    CMT_NORMALCOLOR="gray100"
    CMT_SSCOLOR="gray100"
    ;;

  --data)
    datamessage
    exit 1
    ;;

  --defaults)
    defaultsmessage
    exit 1
    ;;

  -e|--execute) # args: file
    EXECUTEFILE=$(abs_path $2)
    shift
    plots+=("execute")
    ;;

  -eps)
    epsoverlayflag=1
    EPSOVERLAY=$(abs_path $2)
    shift
    ;;

  -eqlabel)
      while [[ ${2:0:1} != [-] && ! -z $2 ]]; do
        if [[ $2 == "list" ]]; then
          labeleqlistflag=1
          shift
        elif arg_is_float $2; then
          labeleqmagflag=1
          labeleqlistflag=0
          labeleqminmag="${2}"
          shift
        elif [[ $2 == "r" ]]; then
          eqlistarray+=("${REGION_EQ}")
          labeleqlistflag=1
          shift
        elif [[ $2 == "idmag" || $2 == "datemag" || $2 == "dateid" || $2 == "id" || $2 == "date" || $2 == "mag" || $2 == "year" || $2 == "yearmag" ]]; then
          EQ_LABELFORMAT="${2}"
          shift
        else
          info_msg "[-eqlabel]: Label class $2 not recognized."
          EQ_LABELFORMAT="datemag"
          shift
        fi
      done
      # If we don't specify a source type, use the list assuming that -r eq or similar was used
      if [[ $labeleqlistflag -eq 0 && $labeleqmagflag -eq 0 ]]; then
        labeleqlistflag=1
      fi
      [[ $eqlabelflag -ne 1 ]]  && plots+=("eqlabel")
      eqlabelflag=1
    ;;

  -eqlist)
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-eqlist]: EQ array but no file specified."
      shift
      while : ; do
        [[ ${2:0:1} != [}] ]] || break
        eqlistarray+=("${2}")
        shift
      done
      shift
    else
      if arg_is_flag $2; then
        info_msg "[-eqlist]: Specify a file or { list } of events"
      else
        EQLISTFILE=$(abs_path $2)
        shift
        while read p; do
          pq=$(echo "${p}" | gawk  '{print $1}')
          eqlistarray+=("${pq}")
        done < $EQLISTFILE
      fi
      if [[ ${2:0:1} == [{] ]]; then
        info_msg "[-eqlist]: EQ array but no file specified."
        shift
        while : ; do
          [[ ${2:0:1} != [}] ]] || break
          eqlistarray+=("${2}")
          shift
        done
        shift
      fi
    fi
    if [[ ${#eqlistarray[@]} -gt 0 ]]; then
      eqlistflag=1
    fi
    ;;

  -eqslip)
    if arg_is_flag $2; then
      info_msg "[-eqslip]: grid file and clip path required"
    else
      numeqslip=0
      while : ; do
        arg_is_flag $2 && break
        numeqslip=$(echo "$numeqslip + 1" | bc)
        E_GRDLIST[$numeqslip]=$(abs_path "${2}")
        E_CLIPLIST[$numeqslip]=$(abs_path "${3}")
        shift
        shift
      done
      plots+=("eqslip")
    fi
    ;;

  -eqselect)
    eqlistselectflag=1;
    ;;

	-f|--refpt)   # args: number number
		refptflag=1
		REFPTLON="${2}"
		REFPTLAT="${3}"
		shift
		shift
		info_msg "[-f]: Reference point is ${REFPTLON}/${REFPTLAT}"
	   ;;

  --formats)
    formats
    exit 1
    ;;

	-g|--gps) # args: none || string
		plotgps=1
		info_msg "[-g]: Plotting GPS velocities"
		if arg_is_flag $2; then
			info_msg "[-g]: No override GPS reference plate specified"
		else
			GPSID="${2}"
			info_msg "[-g]: Ovveriding GPS plate ID = ${GPSID}"
			gpsoverride=1
			GPS_FILE=`echo $GPSDIR"/GPS_$GPSID.gmt"`
			shift
      echo $GPS_SOURCESTRING >> tectoplot.sources
      echo $GPS_SHORT_SOURCESTRING >> tectoplot.shortsources
		fi
		plots+=("gps")
		;;

  -gadd|--extragps) # args: file
    if arg_is_flag $2; then
      info_msg "[-gadd]: No extra GPS file given. Exiting"
      exit 1
    else
      EXTRAGPS=$(abs_path $2)
      info_msg "[-gadd]: Plotting GPS velocities from $EXTRAGPS"
      shift
    fi
    plots+=("extragps")
    ;;

  -gstable) # Plot only GPS velocities from Kreemer (2014) stable plate regions

    ;;

  -gcdm)
    plots+=("gcdm")
    cpts+=("gcdm")
    ;;

  -gdalt)
    if arg_is_flag $2; then
      info_msg "[-gdalt]: No Z-factor specified. Using default: ${HS_Z_FACTOR}"
    else
      HS_Z_FACTOR="${2}"
      info_msg "[-gdalt]: Z-factor value set to ${HS_Z_FACTOR}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-gdalt]: No gamma value specified. Using default: ${HS_GAMMA}"
    else
      HS_GAMMA="${2}"
      info_msg "[-gdalt]: Gamma value set to ${HS_GAMMA}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-gdalt]: No DEM opacity specified. Using default: ${DEM_ALPHA} "
    else
      DEM_ALPHA="${2}"
      info_msg "[-gdalt]: DEM alpha value set to ${DEM_ALPHA}"
      shift
    fi
    topocolorflag=1
    clipdemflag=1
    gdaltZEROHINGE=1
    topoctrlstring="cmsg"   # color multi-hs slope
    ;;

  -gebcotid)
    plots+=("gebcotid")
    clipdemflag=1
    ;;

  -geotiff)
    # Need to replicate the following commands to plot a geotiff: -Jx projection, -RMINLON/MAXLON/MINLAT/MAXLAT
    #   -geotiff -RJ { -R88/98/17/30 -Jx5i } -gmtvars { MAP_FRAME_TYPE inside }
    if [[ $regionsetflag -ne 1 ]]; then
      info_msg "[-geotiff]: Region should be set with -r before -geotiff flag is set. Using default region."
    fi
    gmt gmtset MAP_FRAME_TYPE inside
    RJSTRING="-R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -JX${PSSIZE}id"
    usecustomrjflag=1
    insideframeflag=1
    tifflag=1
    ;;

  -getdata)
    narrateflag=1
    info_msg "Checking and updating downloaded datasets: GEBCO1 GEBCO20 EMAG2 SRTM30 WGM Geonames GCDM Slab2.0 OC_AGE LITHO1.0"

    check_and_download_dataset "GEBCO1" $GEBCO1_SOURCEURL "yes" $GEBCO1DIR $GEBCO1FILE $GEBCO1DIR"data.zip" $GEBCO1_BYTES $GEBCO1_ZIP_BYTES
    check_and_download_dataset "EMAG_V2" $EMAG_V2_SOURCEURL "no" $EMAG_V2_DIR $EMAG_V2 "none" $EMAG_V2_BYTES "none"

    check_and_download_dataset "WGM2012-Bouguer" $WGMBOUGUER_SOURCEURL "no" $WGMDIR $WGMBOUGUER_ORIG "none" $WGMBOUGUER_BYTES "none"
    check_and_download_dataset "WGM2012-Isostatic" $WGMISOSTATIC_SOURCEURL "no" $WGMDIR $WGMISOSTATIC_ORIG "none" $WGMISOSTATIC_BYTES "none"
    check_and_download_dataset "WGM2012-FreeAir" $WGMFREEAIR_SOURCEURL "no" $WGMDIR $WGMFREEAIR_ORIG "none" $WGMFREEAIR_BYTES "none"

    [[ ! -e $WGMBOUGUER ]] && echo "Reformatting WGM Bouguer..." && gmt grdsample ${WGMBOUGUER_ORIG} -R-180/180/-80/80 -I2m -G${WGMBOUGUER} -fg
    [[ ! -e $WGMISOSTATIC ]] && echo "Reformatting WGM Isostatic..." && gmt grdsample ${WGMISOSTATIC_ORIG} -R-180/180/-80/80 -I2m -G${WGMISOSTATIC} -fg
    [[ ! -e $WGMFREEAIR ]] && echo "Reformatting WGM Free air..." && gmt grdsample ${WGMFREEAIR_ORIG} -R-180/180/-80/80 -I2m -G${WGMFREEAIR} -fg

    check_and_download_dataset "WGM2012-Bouguer-CPT" $WGMBOUGUER_CPT_SOURCEURL "no" $WGMDIR $WGMBOUGUER_CPT "none" $WGMBOUGUER_CPT_BYTES "none"
    check_and_download_dataset "WGM2012-Isostatic-CPT" $WGMISOSTATIC_CPT_SOURCEURL "no" $WGMDIR $WGMISOSTATIC_CPT "none" $WGMISOSTATIC_CPT_BYTES "none"
    check_and_download_dataset "WGM2012-FreeAir-CPT" $WGMFREEAIR_CPT_SOURCEURL "no" $WGMDIR $WGMFREEAIR_CPT "none" $WGMFREEAIR_CPT_BYTES "none"

    check_and_download_dataset "Geonames-Cities" $CITIES_SOURCEURL "yes" $CITIESDIR $CITIES500 $CITIESDIR"data.zip" "none" "none"
    info_msg "Processing cities data to correct format" && gawk  < $CITIESDIR"cities500.txt" -F'\t' '{print $6 "," $5 "," $2 "," $15}' > $CITIES

    check_and_download_dataset "GlobalCurieDepthMap" $GCDM_SOURCEURL "no" $GCDMDIR $GCDMDATA_ORIG "none" $GCDM_BYTES "none"
    [[ ! -e $GCDMDATA ]] && info_msg "Processing GCDM data to grid format" && gmt xyz2grd -R-180/180/-80/80 $GCDMDATA_ORIG -I10m -G$GCDMDATA

    check_and_download_dataset "SLAB2" $SLAB2_SOURCEURL "yes" $SLAB2_DATADIR $SLAB2_CHECKFILE $SLAB2_DATADIR"data.zip" $SLAB2_CHECK_BYTES $SLAB2_ZIP_BYTES
    [[ ! -d $SLAB2DIR ]] && [[ -e $SLAB2_CHECKFILE ]] && tar -xvf $SLAB2_DATADIR"Slab2Distribute_Mar2018.tar.gz" --directory $SLAB2_DATADIR
    # Change the format of the Slab2 grids so that longitudes go from -180:180
    # If we don't do this, some regions will have profiles/maps fail.
    for slab2file in $SLAB2DIR/*.grd; do
      echo gmt grdedit -L $slab2file
    done

    # check_and_download_dataset "GMT_DAY" $GMT_EARTHDAY_SOURCEURL "no" $GMT_EARTHDIR $GMT_EARTHDAY "none" $GMT_EARTHDAY_BYTES "none"
    # check_and_download_dataset "GMT_NIGHT" $GMT_EARTHNIGHT_SOURCEURL "no" $GMT_EARTHDIR $GMT_EARTHNIGHT "none" $GMT_EARTHNIGHT_BYTES "none"

    check_and_download_dataset "OC_AGE" $OC_AGE_URL "no" $OC_AGE_DIR $OC_AGE "none" $OC_AGE_BYTES "none"
    check_and_download_dataset "OC_AGE_CPT" $OC_AGE_CPT_URL "no" $OC_AGE_DIR $OC_AGE_CPT "none" $OC_AGE_CPT_BYTES "none"

    check_and_download_dataset "LITHO1.0" $LITHO1_SOURCEURL "yes" $LITHO1DIR $LITHO1FILE $LITHO1DIR"data.tar.gz" $LITHO1_BYTES $LITHO1_ZIP_BYTES
    if [[ ! -e $LITHO1_PROG ]]; then
      echo "Compiling LITHO1 extract tool"
      ${ACCESS_LITHO_CPP} -c ${LITHO1PROGDIR}access_litho.cc -DMODELLOC=\"${LITHO1DIR_2}\" -o ${LITHO1PROGDIR}access_litho.o
      ${ACCESS_LITHO_CPP}  ${LITHO1PROGDIR}access_litho.o -lm -DMODELLOC=\"${LITHO1DIR_2}\" -o ${LITHO1_PROG}
      echo "Testing LITHO1 extract tool"
      res=$(access_litho -p 20 20 2>/dev/null | gawk  '(NR==1) { print $3 }')
      if [[ $(echo "$res == 8060.22" | bc) -eq 1 ]]; then
        echo "access_litho returned correct value"
      else
        echo "access_litho returned incorrect result. Deleting executable. Check compiler, paths, etc."
        rm -f ${LITHO1_PROG}
      fi
    fi

    # # Download NASA Black Marble and merge into a single raster
    # These rasters are problematic as they have data at the degree grid, etc. Ugh
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_A1_NAME} ]] && curl ${BLACKM_A1} > ${GMT_EARTHDIR}${BLACKM_A1_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_B1_NAME} ]] && curl ${BLACKM_B1} > ${GMT_EARTHDIR}${BLACKM_B1_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_C1_NAME} ]] && curl ${BLACKM_C1} > ${GMT_EARTHDIR}${BLACKM_C1_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_D1_NAME} ]] && curl ${BLACKM_D1} > ${GMT_EARTHDIR}${BLACKM_D1_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_A2_NAME} ]] && curl ${BLACKM_A2} > ${GMT_EARTHDIR}${BLACKM_A2_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_B2_NAME} ]] && curl ${BLACKM_B2} > ${GMT_EARTHDIR}${BLACKM_B2_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_C2_NAME} ]] && curl ${BLACKM_C2} > ${GMT_EARTHDIR}${BLACKM_C2_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLACKM_D2_NAME} ]] && curl ${BLACKM_D2} > ${GMT_EARTHDIR}${BLACKM_D2_NAME}

    # # Download NASA Blue Marble image
    # echo "Downloading NASA Blue Marble"
    # [[ ! -e ${GMT_EARTHDIR}${BLUEM_EAST_NAME} ]] && curl ${BLUEM_EAST} > ${GMT_EARTHDIR}${BLUEM_EAST_NAME}
    # [[ ! -e ${GMT_EARTHDIR}${BLUEM_WEST_NAME} ]] && curl ${BLUEM_WEST} > ${GMT_EARTHDIR}${BLUEM_WEST_NAME}

    # SANDWELL_SOURCESTRING="Sandwell 2019 Free Air gravity, https://topex.ucsd.edu/pub/global_grav_1min/curv_30.1.nc"
    # SANDWELL_SHORT_SOURCESTRING="SW2019"
    #
    # SANDWELLDIR=$DATAROOT"Sandwell2019"
    # SANDWELLFREEAIR=$SANDWELLDIR"grav_30.1.nc"
    # SANDWELL2019_SOURCEURL="https://topex.ucsd.edu/pub/global_grav_1min/curv_30.1.nc"
    # SANDWELL2019_bytes="829690416"

    check_and_download_dataset "SW2019" $SANDWELL2019_SOURCEURL "no" $SANDWELLDIR $SANDWELLFREEAIR "none" $SANDWELL2019_bytes "none"

    # Save the biggest downloads for last.
    check_and_download_dataset "GEBCO20" $GEBCO20_SOURCEURL "yes" $GEBCO20DIR $GEBCO20FILE $GEBCO20DIR"data.zip" $GEBCO20_BYTES $GEBCO20_ZIP_BYTES
    check_and_download_dataset "SRTM30" $SRTM30_SOURCEURL "yes" $SRTM30DIR $SRTM30FILE "none" $SRTM30_BYTES "none"

    echo "Compiling texture shading code in ${TEXTUREDIR}"
    ${TEXTURE_COMPILE_SCRIPT} ${TEXTUREDIR}

    exit 0
    ;;

  -gls)
      for gpsfile in $(ls ${GPSDIR}/GPS_*.gmt); do
        echo "$(basename $gpsfile)" | gawk -F_ '{print $2}' | gawk -F. '{print $1}'
      done
      exit 0
    ;;

  -gmtvars)
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-gmtvars]: GMT argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          gmtv+=("${2}")
          shift
      done
      shift
      GMTVARS="${gmtv[@]}"
    fi
    usecustomgmtvars=1
    info_msg "[-gmtvars]: Custom GMT variables: ${GMVARS[@]}"
    ;;


  -gr|--usergrid) #      [gridfile] [[cpt]] [[trans%]]
    usergridfilenumber=$(echo "$usergridfilenumber+1" | bc)
    if arg_is_flag $2; then
      info_msg "[-gr]: Grid file must be specified"
    else
      GRIDADDFILE[$usergridfilenumber]=$(abs_path $2)
      if [[ ! -e "${GRIDADDFILE[$usergridfilenumber]}" ]]; then
        info_msg "GRID file ${GRIDADDFILE[$usergridfilenumber]} does not exist"
      fi
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-gr]: GRID CPT file not specified. Using turbo."
      GRIDADDCPT[$usergridfilenumber]="turbo"
    else
      ISGMTCPT="$(is_gmt_cpt $2)"
      if [[ ${ISGMTCPT} -eq 1 ]]; then
        info_msg "[-gr]: Using GMT CPT file ${2}."
        GRIDADDCPT[$usergridfilenumber]="${2}"
      elif [[ -e ${2} ]]; then
        info_msg "[-gr]: Copying user defined CPT ${2}"
        TMPNAME=$(abs_path $2)
        mkdir -p ./tmpcpts
        cp $TMPNAME ./tmpcpts
        GRIDADDCPT[$usergridfilenumber]="${F_CPTS}"$(basename "$2")
      else
        info_msg "CPT file ${2} cannot be found directly. Looking in CPT dir: ${CPTDIR}${2}."
        if [[ -e ${CPTDIR}${2} ]]; then
          mkdir -p tmpcpts
          cp "${CPTDIR}${2}" ./tmpcpts
          info_msg "Copying CPT file ${CPTDIR}${2} to temporary holding space"
          GRIDADDCPT[$usergridfilenumber]="./${F_CPTS}${2}"
        else
          info_msg "Using default CPT (turbo)"
          GRIDADDCPT[$usergridfilenumber]="turbo"
        fi
      fi
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-gr]: GRID transparency not specified. Using 0 percent"
      GRIDADDTRANS[$usergridfilenumber]=0
    else
      GRIDADDTRANS[$usergridfilenumber]="${2}"
      shift
    fi
    GRIDIDCODE[$usergridfilenumber]="c"   # custom ID
    addcustomusergridsflag=1
    plots+=("usergrid")
    ;;

  -grid)
    doplotgridflag=1
    plots+=("graticule")
    ;;

  -gridlabels) # args: string (quoted)
    GRIDCALL="${2}"
    shift
    ;;

  -gres)
    if arg_is_positive_float $2; then
      info_msg "[-gres]: Set grid output resolution to ${2} dpi"
      GRID_PRINT_RES="-E${2}"
    else
      info_msg "[-gres]: Cannot understand dpi value ${2}. Using native resolution."
      GRID_PRINT_RES=""
    fi
    shift
    ;;

  -h|--help|-help)
    print_usage
		exit 1
    ;;

  -i|--vecscale) # args: number
    VELSCALE=$(echo "${2} * $VELSCALE" | bc -l)
    info_msg "[-i]: Vectors scaled by factor of ${2}, result is ${VELSCALE}"
    shift
    ;;

  -im|--image) # args: file { arguments }
    IMAGENAME=$(abs_path $2)
    shift
    # Args come in the form $ { -t50 -cX.cpt }
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-im]: image argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          imageargs+=("${2}")
          shift
      done
      shift
      info_msg "[-im]: Found image args ${imageargs[@]}"
      IMAGEARGS="${imageargs[@]}"
    fi
    plotimageflag=1
    plots+=("image")
    ;;

  -inset)
    if arg_is_flag $2; then
      info_msg "[-inset]: No inset size specified. Using ${INSET_SIZE}".
    else
      INSET_SIZE="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-inset]: No horizon degree width specified. Using ${INSET_DEGREE}".
    else
      INSET_DEGWIDTH="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-inset]: No x shift relative to bottom left corner specified. Using ${INSET_XOFF}".
    else
      INSET_XOFF="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-inset]: No y shift relative to bottom left corner specified. Using ${INSET_YOFF}".
    else
      INSET_YOFF="${2}"
      shift
    fi
    addinsetplotflag=1
    ;;

  -ips) # args: file
    overplotflag=1
    PLOTFILE=$(abs_path $2)
    shift
    info_msg "[-ips]: Plotting over previous PS file: $PLOTFILE"
    ;;

  --keepopenps) # args: none
    keepopenflag=1
    KEEPOPEN="-K"
    ;;

	-kg|--kingeo) # args: none
		calccmtflag=1
    plotcmtfromglobal=1

		strikedipflag=1
		plots+=("kingeo")
		;;

  -kl|--nodalplane) # args: string
		calccmtflag=1
		np1flag=1
		np2flag=1
		if arg_is_flag $2; then
			info_msg "[-kl]: Nodal plane selection string is malformed"
		else
			[[ "${2}" =~ .*1.* ]] && np2flag=0
			[[ "${2}" =~ .*2.* ]] && np1flag=0
			shift
		fi
		;;

  -km|--kinmag) # args: number number
    KIN_MINMAG="${2}"
    KIN_MAXMAG="${3}"
    shift
    shift
    ;;


  -kml)
    # KML files need maps to be output in Cartesian coordinates
    # Need to replicate the following commands to plot a geotiff: -Jx projection, -RMINLON/MAXLON/MINLAT/MAXLAT
    #   -geotiff -RJ { -R88/98/17/30 -Jx5i } -gmtvars { MAP_FRAME_TYPE inside }
    if arg_is_flag $2; then
      info_msg "[-kml]: No resolution specified. Using $KMLRES"
    else
      KMLRES="${2}"
      shift
      info_msg "[-kml: KML resolution set to $KMLRES"
    fi
    if [[ $regionsetflag -ne 1 ]]; then
      info_msg "[-geotiff]: Region should be set with -r before -geotiff flag is set. Using default region."
    fi
    gmt gmtset MAP_FRAME_TYPE inside
    RJSTRING="-R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -JX${PSSIZE}id"
    GRIDCALL="bltr"
    usecustomrjflag=1
    insideframeflag=1
    kmlflag=1
    ;;

	-ks|--kinscale)  # args: number
		calccmtflag=1
		KINSCALE="${2}"
		shift
    info_msg "[-ks]: CMT kinematics scale updated to $KINSCALE"
	  ;;

	-kt|--kintype) # args: string
		calccmtflag=1
		kinnormalflag=0
		kinthrustflag=0
		kinssflag=0
		if arg_is_flag $2; then
			info_msg "[-kt]: kinematics eq type string is malformed"
		else
			[[ "${2}" =~ .*n.* ]] && kinnormalflag=1
			[[ "${2}" =~ .*t.* ]] && kinthrustflag=1
			[[ "${2}" =~ .*s.* ]] && kinssflag=1
			shift
		fi
		;;

 	-kv|--kinsv)  # args: none
 		calccmtflag=1
    plotcmtfromglobal=1
 		svflag=1
		plots+=("kinsv")
 		;;

  -li|--line) # args: file color width
      # Required arguments
      userlinefilenumber=$(echo "$userlinefilenumber + 1" | bc -l)
      USERLINEDATAFILE[$userlinefilenumber]=$(abs_path $2)
      shift
      if [[ ! -e ${USERLINEDATAFILE[$userlinefilenumber]} ]]; then
        info_msg "[-li]: User line data file ${USERLINEDATAFILE[$userlinefilenumber]} does not exist."
        exit 1
      fi
      # Optional arguments
      # Look for symbol code
      if arg_is_flag $2; then
        info_msg "[-li]: No color specified. Using $USERLINECOLOR."
        USERLINECOLOR_arr[$userlinefilenumber]=$USERLINECOLOR
      else
        USERLINECOLOR_arr[$userlinefilenumber]="${2}"
        shift
        info_msg "[-li]: User line color specified. Using ${USERLINECOLOR_arr[$userlinefilenumber]}."
      fi

      # Then look for width
      if arg_is_flag $2; then
        info_msg "[-li]: No width specified. Using $USERLINEWIDTH."
        USERLINEWIDTH_arr[$userlinefilenumber]=$USERLINEWIDTH
      else
        USERLINEWIDTH_arr[$userlinefilenumber]="${2}"
        shift
        info_msg "[-li]: Line width specified. Using ${USERLINEWIDTH_arr[$userlinefilenumber]}."
      fi

      info_msg "[-pt]: LINE${userlinefilenumber}: ${USERLINEDATAFILE[$userlinefilenumber]}"

      plots+=("userline")

    ;;

  --legend) # args: none
    makelegendflag=1
    legendovermapflag=1
    if arg_is_flag $2; then
      info_msg "[--legend]: No width for color bars specified. Using $LEGEND_WIDTH"
    else
      LEGEND_WIDTH="${2}"
      shift
      info_msg "[--legend]: Legend width for color bars is $LEGEND_WIDTH"
    fi
    ;;

  -litho1)
    litho1profileflag=1
    if arg_is_flag $2; then
      info_msg "[-litho1]: No type specified. Using default $LITHO1_TYPE"
    else
      LITHO1_TYPE="${2}"
      shift
      info_msg "[-litho1]: Using data type $LITHO1_TYPE"
    fi

    [[ $LITHO1_TYPE == "density" ]] && LITHO1_FIELDNUM=2 && LITHO1_CPT=$LITHO1_DENSITY_CPT
    [[ $LITHO1_TYPE == "Vp" ]] && LITHO1_FIELDNUM=3 && LITHO1_CPT=$LITHO1_VELOCITY_CPT
    [[ $LITHO1_TYPE == "Vs" ]] && LITHO1_FIELDNUM=4 && LITHO1_CPT=$LITHO1_VELOCITY_CPT

    cpts+=("litho1")
    plots+=("litho1")
    ;;

  -litho1_depth)
    litho1depthsliceflag=1
    if arg_is_flag $2; then
      info_msg "[-litho1_depth]: No type specified. Using default $LITHO1_TYPE and depth $LITHO1_DEPTH"
    else
      LITHO1_TYPE="${2}"
      shift
      info_msg "[-litho1_depth: Using data type $LITHO1_TYPE"
      if arg_is_flag $2; then
        info_msg "[-litho1_depth]: No depth specified. Using default $LITHO1_DEPTH"
      else
        LITHO1_DEPTH=${2}
        shift
      fi
    fi

    [[ $LITHO1_TYPE == "density" ]] && LITHO1_FIELDNUM=2 && LITHO1_CPT=$LITHO1_DENSITY_CPT
    [[ $LITHO1_TYPE == "Vp" ]] && LITHO1_FIELDNUM=3 && LITHO1_CPT=$LITHO1_VELOCITY_CPT
    [[ $LITHO1_TYPE == "Vs" ]] && LITHO1_FIELDNUM=4 && LITHO1_CPT=$LITHO1_VELOCITY_CPT
    cpts+=("litho1")
    plots+=("litho1_depth")
    ;;

  -longhelp)
    longhelp
    exit 0
    ;;

	-m|--mag) # args: transparency%
		plotmag=1
		if arg_is_flag $2; then
			info_msg "[-m]: No magnetism transparency set. Using default"
		else
			MAGTRANS="${2}"
			shift
		fi
		info_msg "[-m]: Magnetic data to plot is ${MAGMODEL}, transparency is ${MAGTRANS}"
		plots+=("mag")
    cpts+=("mag")
    echo $MAG_SOURCESTRING >> tectoplot.sources
    echo $MAG_SHORT_SOURCESTRING >> tectoplot.shortsources
	  ;;

  -megadebug)
    # set -x
    ;;

  -mob)
    clipdemflag=1
    PLOT_SECTIONS_PROFILEFLAG=1
    if arg_is_flag $2; then
      if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]]; then
        PERSPECTIVE_AZ="${2}"
        shift
      else
        info_msg "[-mob]: No oblique profile parameters specified. Using az=$PERSPECTIVE_AZ, inc=$PERSPECTIVE_INC, exag=$PERSPECTIVE_EXAG, res=$PERSPECTIVE_RES"
      fi
    else
      PERSPECTIVE_AZ="${2}"
      shift
    fi
    if arg_is_flag $2; then
      if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]]; then
        PERSPECTIVE_INC="${2}"
        shift
      else
        info_msg "[-mob]: No view inclination specified. Using $PERSPECTIVE_INC"
      fi
    else
      PERSPECTIVE_INC="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-mob]: No vertical exaggeration specified. Using $PERSPECTIVE_EXAG"
    else
      PERSPECTIVE_EXAG="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-mob]: No resampling resolution specified. Using $PERSPECTIVE_RES"
    else
      PERSPECTIVE_RES="${2}"
      shift
    fi
    info_msg "[-mob]: az=$PERSPECTIVE_AZ, inc=$PERSPECTIVE_INC, exag=$PERSPECTIVE_EXAG, res=$PERSPECTIVE_RES"
    ;;

  -mprof)
    if arg_is_flag $2; then
      info_msg "[-mprof]: No profile control file specified."
    else
      MPROFFILE=$(abs_path $2)
      shift
    fi

    if arg_is_flag $2; then
      info_msg "[-mprof]: No profile width specified. Using default ${PROFILE_WIDTH_IN}"
    else
      PROFILE_WIDTH_IN="${2}"
      shift
      PROFILE_HEIGHT_IN="${2}"
      shift
      PROFILE_X="${2}"
      shift
      PROFILE_Y="${2}"
      shift
    fi
    plots+=("mprof")
    clipdemflag=1
    ;;

  -msd)
    info_msg "[-msd]: Note: using signed distance for DEM generation for profiles to avoid kink artifacts."
    DO_SIGNED_DISTANCE_DEM=1
    ;;

  -msl)
    info_msg "[-msl]: Plotting only left half of DEM on block profile"
    PERSPECTIVE_TOPO_HALF="+l"
    ;;

    # This is now a high priority option
	-n|--narrate)
	# 	narrateflag=1
	;;

  -nocleanup)
    CLEANUP_FILES=0
    ;;

  -noplot)
    noplotflag=1
    ;;

	-o|--out)
		outflag=1
		MAPOUT="${2}"
		shift
		info_msg "[-o]: Output file is ${MAPOUT}"
	  ;;

  -ob)
    info_msg "[-ob]: Plotting oblique view of bathymetry data."
    obliqueflag=1
    OBBAXISTYPE="plain"
    if arg_is_flag $2; then
      info_msg "[-ob]: No azimuth/inc specified. Using default ${OBLIQUEAZ}/${OBLIQUEINC}."
    else
      OBLIQUEAZ="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-ob]: Azimuth but no inclination specified. Using default ${OBLIQUEINC}."
    else
      OBLIQUEINC="${2}"
      shift
    fi
    if arg_is_float $2; then
      OBLIQUE_VEXAG="${2}"
      shift
      info_msg "[-ob]: Vertical exaggeration is ${OBLIQUE_VEXAG}."
    else
      info_msg "[-ob]: No vertical exaggeration given. Using ${OBLIQUE_VEXAG}."
    fi
    if arg_is_float $2; then
      obplotboxflag=1
      OBBOXLEVEL="${2}"
      shift
      info_msg "[-ob]: Plotting box with base level ${OBBOXLEVEL}."
    else
      info_msg "[-ob]: No floor level specified. Not plotting box."
      obplotboxflag=0
      OBBOXLEVEL=-9999
    fi
    if arg_is_flag $2; then
      info_msg "[-ob]: No grid label indicated. Not labeling."
      OBBCOMMAND=""
    else
      if [[ $2 == "plain" ]]; then
        OBBCOMMAND="-Bxaf -Byaf -Bzaf"
      elif [[ $2 == "fancy" ]]; then
        OBBCOMMAND="-Bxaf -Byaf -Bzaf"
        OBBAXISTYPE="fancy"
      fi
      shift
    fi

    ;;

  -oca)
    plots+=("oceanage")
    cpts+=("oceanage")
    echo $OC_AGE_SOURCESTRING >> tectoplot.sources
    echo $OC_AGE_SHORT_SOURCESTRING >> tectoplot.shortsources

    if arg_is_flag $2; then
      info_msg "[-oc]: No transparency set. Using default $OC_TRANS"
    else
      OC_TRANS="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-oc]: No maximum age set for CPT. Using $OC_MAXAGE"
      stretchoccptflag=1
    else
      OC_MAXAGE="${2}"
      shift
      stretchoccptflag=1
    fi

    ;;

  --open)
    openflag=1
    if arg_is_flag $2; then
      info_msg "[--open]: Opening with default program ${OPENPROGRAM}"
    else
      OPENPROGRAM="${2}"
      shift
    fi
    ;;

  -options)
    print_help_header
    print_options
    exit 1
    ;;

  -oto)
    profileonetooneflag=1
    ;;

	-p|--plate) # args: string
		plotplates=1
		if arg_is_flag $2; then
			info_msg "[-p]: No plate model specified. Assuming MORVEL"
			POLESRC=$MORVELSRC
			PLATES=$MORVELPLATES
      MIDPOINTS=$MORVELMIDPOINTS
			POLES=$MORVELPOLES
			DEFREF="NNR"
      echo $MORVEL_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $MORVEL_SOURCESTRING >> tectoplot.sources
		else
			PLATEMODEL="${2}"
      shift
	  	case $PLATEMODEL in
			MORVEL)
				POLESRC=$MORVELSRC
				PLATES=$MORVELPLATES
				POLES=$MORVELPOLES
        MIDPOINTS=$MORVELMIDPOINTS
        EDGES=$MORVELPLATEEDGES
				DEFREF="NNR"
        echo $MORVEL_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $MORVEL_SOURCESTRING >> tectoplot.sources
				;;
			GSRM)
				POLESRC=$KREEMERSRC
				PLATES=$KREEMERPLATES
				POLES=$KREEMERPOLES
        MIDPOINTS=$KREEMERMIDPOINTS
        EDGES=$KREEMERPLATEEDGES
				DEFREF="ITRF08"
        echo $GSRM_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GSRM_SOURCESTRING >> tectoplot.sources
				;;
			GBM)
				POLESRC=$GBMSRC
				PLATES=$GBMPLATES
				POLES=$GBMPOLES
				DEFREF="ITRF08"
        EDGES=$GBMPLATEEDGES
        MIDPOINTS=$GBMMIDPOINTS
        echo $GBM_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GBM_SOURCESTRING >> tectoplot.sources
        ;;
			*) # Unknown plate model
				info_msg "[-p]: Unknown plate model $PLATEMODEL... using MORVEL56 instead"
				PLATEMODEL="MORVEL"
				POLESRC=$MORVELSRC
				PLATES=$MORVELPLATES
				POLES=$MORVELPOLES
        MIDPOINTS=$MORVELMIDPOINTS
				DEFREF="NNR"
				;;
			esac
      # Check for a reference plate ID
      if arg_is_flag $2; then
  			info_msg "[-p]: No manual reference plate specified."
      else
        MANUALREFPLATE="${2}"
        shift
        if [[ $MANUALREFPLATE =~ $DEFREF ]]; then
          manualrefplateflag=1
          info_msg "[-p]: Using default reference frame $DEFREF"
          defaultrefflag=1
        else
          info_msg "[-p]: Manual reference plate $MANUALREFPLATE specified. Checking."
          isthere=$(grep $MANUALREFPLATE $POLES | wc -l)
          if [[ $isthere -eq 0 ]]; then
            info_msg "[-p]: Could not find manually specified reference plate $MANUALREFPLATE in plate file $POLES."
            exit
          fi
          manualrefplateflag=1
        fi
      fi
		fi
		info_msg "[-p]: Plate tectonic model is ${PLATEMODEL}"
	  ;;

  -pc)              # PlateID1 color1 PlateID2 color2
    if [[ $2 =~ "random" ]]; then
      shift
      if arg_is_positive_float $2; then
        P_POLYTRANS+=("${2}")
        shift
      else
        P_POLYTRANS+=("50")
      fi
      plots+=("platepolycolor_all")
    else
      while : ; do
        arg_is_flag $2 && break
        P_POLYLIST+=("${2}")
        P_COLORLIST+=("${3}")
        shift
        shift
        if arg_is_positive_float $2; then
          P_POLYTRANS+=("${2}")
          shift
        else
          P_POLYTRANS+=("50")
        fi
      done
      info_msg "[-pc]: Plates to color: ${P_POLYLIST[@]}, colors: ${P_COLORLIST[@]}, trans: ${P_POLYTRANS[@]}"
      plots+=("platepolycolor_list")
    fi
    ;;
  -pe|--plateedge)  # args: none
    plots+=("plateedge")
    ;;

  -pf|--fibsp) # args: number
    gridfibonacciflag=1
    makegridflag=1
    FIB_KM="${2}"
    FIB_N=$(echo "510000000 / ( $FIB_KM * $FIB_KM - 1 ) / 2" | bc)
    shift
    if arg_is_flag $2; then
      info_msg "[-pf]: Plotting text labels for plate motion vectors"
    elif [[ $2 == "nolabels" ]]; then
      PLATEVEC_TEXT_PLOT=0
      shift
    fi

    plots+=("grid")
    ;;

  -pg) # args: file
    if arg_is_flag $2; then
      info_msg "[-pg]: No polygon file specified."
    else
      polygonselectflag=1
      POLYGONAOI=$(abs_path $2)
      shift
      if [[ ! -e $POLYGONAOI ]]; then
        info_msg "[-pg]: Polygon file $POLYGONAOI does not exist."
        exit 1
      fi
      if arg_is_flag $2; then
        info_msg "[-pg]: Not plotting polygon."
      else
        if [[ $2 == "show" ]]; then
          info_msg "Plotting polygon AOI"
          plots+=("polygonaoi")
        else
          info_msg "[-pg]: Unknown option $2"
        fi
        shift
      fi
    fi
    ;; # args: none

  -noframe)
    dontplotgridflag=1
    GRIDCALL="blrt"
    ;;

  -pgo)
    GRIDLINESON=1
    ;;

  -pgs) # args: number
    overridegridlinespacing=1
    OVERRIDEGRID="${2}"
    shift
    ;;

  -pl) # args: none
    plots+=("platelabel")
    ;;

  -pp|--cities)
    if arg_is_flag $2; then
      info_msg "[-pp]: No minimum population specified. Using ${CITIES_MINPOP}"
    else
      CITIES_MINPOP="${2}"
      shift
    fi
    plots+=("cities")
    cpts+=("population")
    echo $CITIES_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $CITIES_SOURCESTRING >> tectoplot.sources
    ;;

  -ppl)
    if arg_is_flag $2; then
      info_msg "[-pp]: No minimum population for labeling specified. Using ${CITIES_LABEL_MINPOP}"
    else
      CITIES_LABEL_MINPOP="${2}"
      shift
    fi
    citieslabelflag=1
    ;;

  -pos) # args: string string (e.g. 5i)
    plotshiftflag=1
    PLOTSHIFTX="${2}"
    PLOTSHIFTY="${3}"
    shift
    shift
    ;;

  -pr) # args: number
    if arg_is_flag $2; then
      info_msg "[-pr]: No colatitude step specified: using ${LATSTEPS}"
    else
      LATSTEPS="${2}"
      shift
    fi
    plots+=("platerotation")
    platerotationflag=1
    ;;

  -printcountries)
    gawk -F, < $COUNTRY_CODES '{ print $1, $4 }'
    exit
    ;;

  -prv) # plate relative velocity magnitude
    plots+=("platerelvel")
    doplateedgesflag=1
    ;;

  -ps)
    outputplatesflag=1
    ;;

  -psel)
    selectprofilesflag=1

    if [[ ${2:0:1} == [-] || -z $2  ]]; then
      info_msg "[-psel]: No profile IDs specified on command line"
      exit 1
    else
      while : ; do
        arg_is_flag $2 && break
        PSEL_LIST+=("${2}")
        shift
      done
    fi
    #
    # echo "Profile list is: ${PSEL_LIST[@]}"
    # echo ${PSEL_LIST[0]}
    ;;

  # CURRENTLY NOT USED
  -psm) # args: number
    MARGIN="${2}"
    shift
    ;;

  -psr) # args: number
    # Set scaling of map versus postscript page size $PSSIZE (factor 1=$PSSIZE, 0=0)
    psscaleflag=1
    PSSCALE="${2}"
    shift
    ;;

  # This is a high priority argument that is processed in the previous loop
  -pss) # args: string
    # Set size of the postscript page
    # PSSIZE="${2}"
    shift
    ;;

  -pt|--point)
    # COUNTER userpointfilenumber
    # Required arguments
    userpointfilenumber=$(echo "$userpointfilenumber + 1" | bc -l)
    POINTDATAFILE[$userpointfilenumber]=$(abs_path $2)
    shift
    if [[ ! -e ${POINTDATAFILE[$userpointfilenumber]} ]]; then
      info_msg "[-pt]: Point data file ${POINTDATAFILE[$userpointfilenumber]} does not exist."
      exit 1
    fi
    # Optional arguments
    # Look for symbol code
    if arg_is_flag $2; then
      info_msg "[-pt]: No symbol specified. Using $POINTSYMBOL."
      POINTSYMBOL_arr[$userpointfilenumber]=$POINTSYMBOL
    else
      POINTSYMBOL_arr[$userpointfilenumber]="${2:0:1}"
      shift
      info_msg "[-pt]: Point symbol specified. Using ${POINTSYMBOL_arr[$userpointfilenumber]}."
    fi

    # Then look for size
    if arg_is_flag $2; then
      info_msg "[-pt]: No size specified. Using $POINTSIZE."
      POINTSIZE_arr[$userpointfilenumber]=$POINTSIZE
    else
      POINTSIZE_arr[$userpointfilenumber]="${2}"
      shift
      info_msg "[-pt]: Point size specified. Using ${POINTSIZE_arr[$userpointfilenumber]}."
    fi

    # Finally, look for CPT file
    if arg_is_flag $2; then
      info_msg "[-pt]: No cpt specified. Using POINTCOLOR for -G"
      pointdatafillflag[$userpointfilenumber]=1
      pointdatacptflag[$userpointfilenumber]=0
    elif [[ ${2:0:1} == "@" ]]; then
      info_msg "[-pt]: No cpt specified using @. Using POINTCOLOR for -G"
      shift
      pointdatafillflag[$userpointfilenumber]=1
      pointdatacptflag[$userpointfilenumber]=0
    else
      POINTDATACPT[$userpointfilenumber]=$(abs_path $2)
      shift
      if [[ ! -e ${POINTDATACPT[$userpointfilenumber]} ]]; then
        info_msg "[-pt]: CPT file $POINTDATACPT does not exist. Using default $POINTCPT"
        POINTDATACPT[$userpointfilenumber]=$(abs_path $POINTCPT)
      else
        info_msg "[-pt]: Using CPT file $POINTDATACPT"
      fi
      pointdatacptflag[$userpointfilenumber]=1
      pointdatafillflag[$userpointfilenumber]=0
    fi

    info_msg "[-pt]: PT${userpointfilenumber}: ${POINTDATAFILE[$userpointfilenumber]}"
    plots+=("points")
    ;;

  -pv) # args: none
    doplateedgesflag=1
    plots+=("platediffv")
    if arg_is_flag $2; then
      info_msg "[-pv]: No cutoff value specified. Disabling."
      platediffvcutoffflag=0
    else
      PDIFFCUTOFF="${2}"
      info_msg "[-pv]: Cutoff is $PDIFFCUTOFF"
      shift
      platediffvcutoffflag=1
    fi
    ;;

  -pvg)
    platevelgridflag=1
    plots+=("platevelgrid")
    if arg_is_flag $2; then
      info_msg "[-pvg]: No resolution or rescaling specified. Using rescale=no; res=${PLATEVELRES}"
    else
      info_msg "[-pvg]: Resolution set to ${2}"
      PLATEVELRES="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-pvg]: No rescaling of gravity CPT specified"
    elif [[ ${2} =~ "rescale" ]]; then
      rescaleplatevecsflag=1
      info_msg "[-pvg]: Rescaling gravity CPT to AOI"
      shift
    else
      info_msg "[-pvg]: Unrecognized option ${2}"
      shift
    fi
    ;;

  -px|--gridsp) # args: number
    makelatlongridflag=1
    makegridflag=1
		GRIDSTEP="${2}"
		shift
    plots+=("grid")
		info_msg "[-px]: Plate model grid step is ${GRIDSTEP}"
	  ;;

  -pz) # args: number
    if arg_is_flag $2; then
      info_msg "[-pz]: No azimuth difference scale indicated. Using default: ${AZDIFFSCALE}"
    else
      AZDIFFSCALE="${2}"
      shift
    fi
    doplateedgesflag=1
    plots+=("plateazdiff")
    ;;

	-r|--range) # args: number number number number

  # info_msg "Zero ${2}"
  # [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]] && echo bbb || echo ccc
  #
  # if ! arg_is_float "${2}"
  # then
  #   Echo "First argument is not a float"
  # fi

	  if ! arg_is_float "${2}"; then
      # If first argument isn't a number, it is interpreted as a global extent (g), an earthquake event, an XY file, a raster file, or finally as a country code.
      # Option 1: Global extent from -180:180 longitude
      if [[ ${2} == "g" ]]; then
        MINLON=-180
        MAXLON=180
        MINLAT=-90
        MAXLAT=90
        globalextentflag=1
        shift

      # Option 2: Centered on an earthquake event from CMT(preferred) or seismicity(second choice) catalogs.
      # Arguments are eq Event_ID [[degwidth]]
      elif [[ "${2}" == "eq" ]]; then
        setregionbyearthquakeflag=1
        REGION_EQ=${3}
        shift
        shift
        if arg_is_flag "{$2}"; then
          info_msg "[-r]: EQ region width is default"
        else
          info_msg "[-r]: EQ region width is ${2}"
          EQ_REGION_WIDTH="${2}"
          shift
        fi
        info_msg "[-r]: Region will be centered on EQ $REGION_EQ with width $EQ_REGION_WIDTH degrees"
      # Option 3: Set region to be the same as an input lat lon point plus width
      elif [[ "${2}" == "latlon" ]]; then
        LATLON_LAT=$(coordinate_parse "${3}")
        LATLON_LON=$(coordinate_parse "${4}")
        LATLON_DEG="${5}"
        shift
        shift
        shift
        shift

        MINLON=$(echo "$LATLON_LON - $LATLON_DEG" | bc -l)
        MAXLON=$(echo "$LATLON_LON + $LATLON_DEG" | bc -l)
        MINLAT=$(echo "$LATLON_LAT - $LATLON_DEG" | bc -l)
        MAXLAT=$(echo "$LATLON_LAT + $LATLON_DEG" | bc -l)
       info_msg "[-r] latlon: Region is ${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}"
    # Option 3: Set region to be the same as an input lon lat point plus width
      elif [[ "${2}" == "lonlat" ]]; then
        LATLON_LAT=$(coordinate_parse "${3}")
        LATLON_LON=$(coordinate_parse "${4}")
        LATLON_DEG="${5}"
        shift
        shift
        shift
        shift

        MINLON=$(echo "$LATLON_LON - $LATLON_DEG" | bc -l)
        MAXLON=$(echo "$LATLON_LON + $LATLON_DEG" | bc -l)
        MINLAT=$(echo "$LATLON_LAT - $LATLON_DEG" | bc -l)
        MAXLAT=$(echo "$LATLON_LAT + $LATLON_DEG" | bc -l)
        info_msg "[-r] lonlat: Region is ${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}"
# Option 3: Set region to be the same as an input raster
      elif [[ -e "${2}" ]]; then
        info_msg "[-r]: File specified; trying to determine extent."
        # First check if it is a text file with X Y coordinates in the first two columns
        case $(file "${2}") in
          (*\ text|*\ text\ *)
              info_msg "[-r]: Input file is text: assuming X Y data"
              XYRANGE=($(xy_range "${2}"))
              MINLON=${XYRANGE[0]}
              MAXLON=${XYRANGE[1]}
              MINLAT=${XYRANGE[2]}
              MAXLAT=${XYRANGE[3]}
              ;;
          (*\ directory|*\ directory\ *)
              info_msg "[-r]: Input file is an existing directory. Not a valid extent."
              exit 1
              ;;
          (*)
              info_msg "[-r]: Input file is binary: assuming it is a grid file"
              rasrange=$(gmt grdinfo $(abs_path $2) -C -Vn)
              MINLON=$(echo $rasrange | gawk  '{print $2}')
              MAXLON=$(echo $rasrange | gawk  '{print $3}')
              MINLAT=$(echo $rasrange | gawk  '{print $4}')
              MAXLAT=$(echo $rasrange | gawk  '{print $5}')
              ;;
          esac

        if [[ $(echo "$MAXLON > $MINLON" | bc) -eq 1 ]]; then
          if [[ $(echo "$MAXLAT > $MINLAT" | bc) -eq 1 ]]; then
            info_msg "Set region to $MINLON/$MAXLON/$MINLAT/$MAXLAT to match $2"
          fi
        fi
        shift

      # Option 4: A single argument which doesn't match any of the above is a country ID OR a custom ID
      # Custom IDs override region IDs, so we search for that first
      else

        if arg_is_flag $2; then
          # Option 5: No arguments means no region

          info_msg "[-r]: No country code or custom region ID specified."
          exit 1
        fi

        ISCUSTOMREGION=($(grep "${2}" $CUSTOMREGIONS))

        if [[ -z ${ISCUSTOMREGION[0]} ]]; then
          # Assume that the string is a country ID code (only option left)
          COUNTRYID=${2}
          shift
          COUNTRYNAME=$(gawk -v cid="${COUNTRYID}" -F, '(index($0,cid)==1) { print $4 }' $COUNTRY_CODES)
          if [[ $COUNTRYNAME == "" ]]; then
            info_msg "Country code ${COUNTRYID} is not a valid code. Use tectoplot -printcountries"
            exit 1
          fi
          RCOUNTRY=($(gmt pscoast -E${COUNTRYID}+r1 ${VERBOSE} | gawk  '{v=substr($0,3,length($0)); split(v,w,"/"); print w[1], w[2], w[3], w[4]}'))

          # info_msg "RCOUNTRY=${RCOUNTRY[@]}"
          if [[ $(echo "${RCOUNTRY[0]} >= -360 && ${RCOUNTRY[1]} <= 360 && ${RCOUNTRY[2]} >= -90 && ${RCOUNTRY[3]} <= 90" | bc) -eq 1 ]]; then
            MINLON=${RCOUNTRY[0]}
            MAXLON=${RCOUNTRY[1]}
            MINLAT=${RCOUNTRY[2]}
            MAXLAT=${RCOUNTRY[3]}
            info_msg "Country [$COUNTRYNAME] bounding box set to $MINLON/$MAXLON/$MINLAT/$MAXLAT"
            # echo RC MINLON MAXLON MINLAT MAXLAT $MINLON $MAXLON $MINLAT $MAXLAT
          else
            info_msg "[]-r]: MinLon is malformed: $3"
            exit 1
          fi

        else
          shift
          if [[ $(echo "${ISCUSTOMREGION[1]} >= -360 && ${ISCUSTOMREGION[2]} <= 360 && ${ISCUSTOMREGION[3]} >= -90 && ${ISCUSTOMREGION[4]} <= 90" | bc) -eq 1 ]]; then
            MINLON=${ISCUSTOMREGION[1]}
            MAXLON=${ISCUSTOMREGION[2]}
            MINLAT=${ISCUSTOMREGION[3]}
            MAXLAT=${ISCUSTOMREGION[4]}
            info_msg "Region ID [${2}] bounding box set to $MINLON/$MAXLON/$MINLAT/$MAXLAT"
            ind=5
            while ! [[ -z ${ISCUSTOMREGION[${ind}]} ]]; do
              CUSTOMREGIONRJSTRING+=("${ISCUSTOMREGION[${ind}]}")
              ind=$(echo "$ind+1"| bc)
              usecustomregionrjstringflag=1
            done
            if [[ $usecustomregionrjstringflag -eq 1 ]]; then
              info_msg "[-r]: customID ${2} has RJSTRING: ${CUSTOMREGIONRJSTRING[@]}"
            else
              info_msg "[-r]: customID ${2} has no RJSTRING"
            fi
          else
            info_msg "[-r]: MinLon is malformed: $3"
            exit 1
          fi

        fi
      fi
    # Option 0: Four numbers in lonmin lonmax latmin latmax order
    else
      if ! [[ $3 =~ ^[-+]?[0-9]*.*[0-9]+$ || $3 =~ ^[-+]?[0-9]+$ ]]; then
        echo "MaxLon is malformed: $3"
        exit 1
      fi
      if ! [[ $4 =~ ^[-+]?[0-9]*.*[0-9]+$ || $4 =~ ^[-+]?[0-9]+$ ]]; then
        echo "MinLat is malformed: $4"
        exit 1
      fi
      if ! [[ $5 =~ ^[-+]?[0-9]*.*[0-9]+$ || $5 =~ ^[-+]?[0-9]+$ ]]; then
        echo "MaxLat is malformed: $5"
        exit 1
      fi
      MINLON="${2}"
      MAXLON="${3}"
      MINLAT="${4}"
      MAXLAT="${5}"
      shift # past argument
      shift # past value
      shift # past value
      shift # past value
    fi

    if [[ $setregionbyearthquakeflag -eq 0 ]]; then

      # Rescale longitudes if necessary to match the -180:180 convention used in this script

  		info_msg "[-r]: Range is $MINLON $MAXLON $MINLAT $MAXLAT"
      # [[ $(echo "$MAXLON > 180 && $MAXLON <= 360" | bc -l) -eq 1 ]] && MAXLON=$(echo "$MAXLON - 360" | bc -l)
      # [[ $(echo "$MINLON > 180 && $MINLON <= 360" | bc -l) -eq 1 ]] && MINLON=$(echo "$MINLON - 360" | bc -l)
      if [[ $(echo "$MAXLAT > 90 || $MAXLAT < -90 || $MINLAT > 90 || $MINLAT < -90"| bc -l) -eq 1 ]]; then
      	echo "Latitude out of range"
      	exit
      fi
      info_msg "[-r]: Range after possible rescale is $MINLON $MAXLON $MINLAT $MAXLAT"

    	# if [[ $(echo "$MAXLON > 180 || $MAXLON< -180 || $MINLON > 180 || $MINLON < -180"| bc -l) -eq 1 ]]; then
      # 	echo "Longitude out of range"
      # 	exit
    	# fi
    	# if [[ $(echo "$MAXLON <= $MINLON"| bc -l) -eq 1 ]]; then
      # 	echo "Longitudes out of order: $MINLON / $MAXLON"
      # 	exit
    	# fi
    	if [[ $(echo "$MAXLAT <= $MINLAT"| bc -l) -eq 1 ]]; then
      	echo "Latitudes out of order"
      	exit
    	fi
  		info_msg "[-r]: Map region is -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}"

      # We apparently need to deal with maps that wrap across the antimeridian? Ugh.
      regionsetflag=1
    fi # If the region is not centered on an earthquake and still needs to be determined

    ;;

  -radd)
    if arg_is_flag $2; then
      info_msg "[-radd]: No region ID code specified. Ignoring."
    else
      REGIONTOADD=$(echo ${2} | awk '{print $1}')
      addregionidflag=1
      info_msg "[-radd]: Adding or updating custom region ${REGIONTOADD} from -r arguments"
      shift
    fi
    ;;

  -rdel)
    if arg_is_flag $2; then
      info_msg "[-rdel]: No region ID code to delete was specified."
    else
      REGIONTODEL=$(echo ${2} | awk '{print $1}')
      info_msg "[-rdel]: Deleting region ID ${REGIONTODEL} and exiting."
      shift
    fi
    awk -v id=${REGIONTODEL} < $CUSTOMREGIONS '{
      if ($1 != id) {
        print
      }
    }' > ./regions.tmp
    mv ./regions.tmp ${CUSTOMREGIONS}
    exit
    ;;

  -rlist)
    cat ${CUSTOMREGIONS}
    exit
    ;;

  -rect)
    MAKERECTMAP=1
    ;;

  -reportdates)
    echo -n "Focal mechanisms: "
    echo "$(head -n 1 $FOCALCATALOG | cut -d ' ' -f 3) to $(tail -n 1 $FOCALCATALOG | cut -d ' ' -f 3)"
    # echo -n "Earthquake hypocenters: "
    # echo "$(head -n 1 $EQCATALOG | cut -d ' ' -f 5) to $(tail -n 1 $EQCATALOG | cut -d ' ' -f 5)"
    exit
    ;;

  -RJ) # args: { ... }
    # We need to shift the automatic UTM zone section to AFTER other arguments are processed

    ARG1="${2}"
    shift

    case $ARG1 in
      {)
      info_msg "[-RJ]: Custom RJ argument string detected"
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          rj+=("${2}")
          shift
      done
      shift
      RJSTRING="${rj[@]}"
      ;;

      UTM)
        if [[ $2 =~ ^[0-9]+$ ]]; then   # Specified a UTM Zone (positive integer)
          UTMZONE=$2
          shift
        else
          calcutmzonelaterflag=1
        fi
        setutmrjstringfromarrayflag=1
        recalcregionflag=1
      ;;

      # Global extents
      Hammer|H|Winkel|R|Robinson|N|Mollweide|W|VanderGrinten|V|Sinusoidal|I|Eckert4|Kf|Eckert6|Ks)
        MINLON=-180; MAXLON=180; MINLAT=-90; MAXLAT=90
        globalextentflag=1

        if arg_is_float $2; then   # Specified a central meridian
          CENTRALMERIDIAN=$2
          shift
        else
          CENTRALMERIDIAN=0
        fi
        rj+=("-Rg")
        case $ARG1 in
          Eckert4|Kf)      rj+=("-JKf${CENTRALMERIDIAN}/${PSSIZE}i")    ;;
          Eckert6|Ks)      rj+=("-JKs${CENTRALMERIDIAN}/${PSSIZE}i")    ;;
          Hammer|H)        rj+=("-JH${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
          Mollweide|W)     rj+=("-JW${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
          Robinson|N)      rj+=("-JN${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
          Sinusoidal|I)    rj+=("-JI${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
          VanderGrinten|V) rj+=("-JV${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
          Winkel|R)        rj+=("-JR${CENTRALMERIDIAN}/${PSSIZE}i")     ;;
        esac
        RJSTRING="${rj[@]}"
        recalcregionflag=0
      ;;
      Hemisphere|A)
        MINLON=-180; MAXLON=180; MINLAT=-90; MAXLAT=90
        globalextentflag=1

        if arg_is_float $2; then   # Specified a central meridian
          CENTRALMERIDIAN=$2
          shift
          if arg_is_float $2; then   # Specified a latitude
            CENTRALLATITUDE=$2
            shift
          else
            CENTRALLATITUDE=0
          fi
        else
          CENTRALMERIDIAN=0
          CENTRALLATITUDE=0
        fi
        rj+=("-Rg")
        case $ARG1 in
          Hemisphere|A) rj+=("-JA${CENTRALMERIDIAN}/${CENTRALLATITUDE}/${PSSIZE}i")   ;;
        esac
        RJSTRING="${rj[@]}"
        recalcregionflag=0
      ;;
      Gnomonic|F|Orthographic|G|Stereo|S)
        MINLON=-180; MAXLON=180; MINLAT=-90; MAXLAT=90
        globalextentflag=1

        if arg_is_float $2; then   # Specified a central meridian
          CENTRALMERIDIAN=$2
          shift
          if arg_is_float $2; then   # Specified a latitude
            CENTRALLATITUDE=$2
            shift
            if arg_is_float $2; then   # Specified a degree range
              DEGRANGE=$2
              shift
            else
              DEGRANGE=90
            fi
          else
            CENTRALLATITUDE=0
            DEGRANGE=90
          fi
        else
          CENTRALMERIDIAN=0
          CENTRALLATITUDE=0
          DEGRANGE=90
        fi
        rj+=("-Rg")
        case $ARG1 in
          Gnomonic|F)      [[ $DEGRANGE -ge 90 ]] && DEGRANGE=60   # Gnomonic can't have default degree range
                           rj+=("-JF${CENTRALMERIDIAN}/${CENTRALLATITUDE}/${DEGRANGE}/${PSSIZE}i")     ;;
          Orthographic|G)  rj+=("-JG${CENTRALMERIDIAN}/${CENTRALLATITUDE}/${DEGRANGE}/${PSSIZE}i")     ;;
          Stereo|S)        rj+=("-JS${CENTRALMERIDIAN}/${CENTRALLATITUDE}/${DEGRANGE}/${PSSIZE}i")     ;;
        esac
        RJSTRING="${rj[@]}"
        recalcregionflag=0
      ;;
      # Oblique Mercator A (lon lat azimuth widthkm heightkm)
      ObMercA|OA)
        # Set up default values
        CENTRALLON=0
        CENTRALLAT=0
        ORIENTAZIMUTH=0
        MAPWIDTHKM="200k"
        MAPHEIGHTKM="100k"
        if arg_is_float $2; then   # Specified a central meridian
          CENTRALLON=$2
          shift
          if arg_is_float $2; then   # Specified a latitude
            CENTRALLAT=$2
            shift
            if arg_is_float $2; then   # Specified a degree range
              ORIENTAZIMUTH=$2
              shift
              if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+[k]$ ]]; then   # Specified a width with unit k
                MAPWIDTHKM=$2
                shift
                if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+[k]$ ]]; then   # Specified a width with unit k
                  MAPHEIGHTKM=$2
                  shift
                fi
              fi
            fi
          fi
        fi

        rj+=("-Rk-${MAPWIDTHKM}/${MAPWIDTHKM}/-${MAPHEIGHTKM}/${MAPHEIGHTKM}")
        rj+=("-JOa${CENTRALLON}/${CENTRALLAT}/${ORIENTAZIMUTH}/${PSSIZE}i")
        RJSTRING="${rj[@]}"
        recalcregionflag=1
        projcoordsflag=1
      ;;
      # Lon Lat lonpole latPole widthkm heightkm
      ObMercC|OC)
        # Set up default values
        CENTRALLON=0
        CENTRALLAT=0
        POLELON=0
        POLELAT=0
        MAPWIDTHKM="200k"
        MAPHEIGHTKM="100k"
        if arg_is_float $2; then   # Specified a central meridian
          CENTRALLON=$2
          shift
          if arg_is_float $2; then   # Specified a latitude
            CENTRALLAT=$2
            shift
            if arg_is_float $2; then   # Specified a latitude
              POLELON=$2
              shift
              if arg_is_float $2; then   # Specified a latitude
                POLELAT=$2
                shift
                if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+[k]$ ]]; then   # Specified a width with unit k
                  MAPWIDTHKM=$2
                  shift
                  if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+[k]$ ]]; then   # Specified a width with unit k
                    MAPHEIGHTKM=$2
                    shift
                  fi
                fi
              fi
            fi
          fi
        fi

        MAPWIDTHNUM=$(echo $MAPWIDTHKM | awk '{print $1 + 0}')
        MAPHEIGHTNUM=$(echo $MAPHEIGHTKM | awk '{print $1 + 0}')

        rj+=("-Rk-${MAPWIDTHKM}/${MAPWIDTHKM}/-${MAPHEIGHTKM}/${MAPHEIGHTKM}")
        rj+=("-JOc${CENTRALLON}/${CENTRALLAT}/${POLELON}/$POLELAT/${PSSIZE}i")
        RJSTRING="${rj[@]}"
        recalcregionflag=1
        projcoordsflag=1
      ;;
    esac

    usecustomrjflag=1

    # Need to calculate the AOI using the RJSTRING. Otherwise, have to specify a
    # region manually using -r which may not be so obvious.

    # How?
    ;;

	-s|--srcmod) # args: none
		plotsrcmod=1
		info_msg "[-s]: Plotting SRCMOD fused slip data"
		plots+=("srcmod")
    cpts+=("faultslip")
    echo $SRCMOD_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $SRCMOD_SOURCESTRING >> tectoplot.sources
	  ;;

  -setdatadir)
    if arg_is_flag $2; then
      echo "[-setdatadir]: No data directory specified. Current dir is:"
      cat $DEFDIR"tectoplot.dataroot"
      exit 1
    else
      datadirpath=$(abs_path $2)
      # Directory will end with / after abs_path
      shift
      if [[ -d ${datadirpath} ]]; then
        echo "[-setdatadir]: Data directory ${datadirpath} exists."
        echo "${datadirpath}" > $DEFDIR"tectoplot.dataroot"
      else
        echo "[-setdatadir]: Data directory ${datadirpath} does not exist. Creating."
        mkdir -p "${datadirpath}"
        echo "${datadirpath}" > $DEFDIR"tectoplot.dataroot"
      fi
    fi
    exit
    ;;

  -setopenprogram)
    if arg_is_flag $2; then
      echo "[-setopenprogram]: PDFs are opened using: ${OPENPROGRAM}"
    else
      openapp="${2}"
      shift
      echo "${openapp}" > $DEFDIR"tectoplot.pdfviewer"
    fi
    ;;

  -scale)
    # We just use this section to create the SCALECMD values

    if arg_is_flag $2; then
      info_msg "[-scale]: No scale length specified. Using 100km"
      SCALELEN="100k"
    else
      SCALELEN="${2}"
      shift
    fi
    # Adjust position and buffering of scale bar using either letter combinations OR Lat/Lon location

    if arg_is_float $2; then
      SCALEREFLON="${2}"
      shift
      if arg_is_float $2; then
        SCALEREFLAT="${2}"
        SCALELENLAT="${2}"
        shift
      else
        info_msg "[-scale]: Only longitude and not latitude specified. Using $MAXLAT"
        SCALEREFLAT=$MINLAT
        SCALELENLAT=$MINLAT
      fi
    fi

    if [[ "${2}" =~ [A-Z] ]]; then  # This is an aprofcode location
      info_msg "[-scale]: aprofcode ${2:0:1} found."
      SCALEAPROF=($(echo $2 | gawk -v minlon=$MINLON -v maxlon=$MAXLON -v minlat=$MINLAT -v maxlat=$MAXLAT '
      BEGIN {
          row[1]="AFKPU"
          row[2]="BGLQV"
          row[3]="CHMRW"
          row[4]="DINSX"
          row[5]="EJOTY"
          difflat=maxlat-minlat
          difflon=maxlon-minlon

          newdifflon=difflon*8/10
          newminlon=minlon+difflon*1/10
          newmaxlon=maxlon-difflon*1/10

          newdifflat=difflat*8/10
          newminlat=minlat+difflat*1/10
          newmaxlat=maxlat-difflat*1/10

          minlon=newminlon
          maxlon=newmaxlon
          minlat=newminlat
          maxlat=newmaxlat
          difflat=newdifflat
          difflon=newdifflon

          for(i=1;i<=5;i++) {
            for(j=1; j<=5; j++) {
              char=toupper(substr(row[i],j,1))
              lats[char]=minlat+(i-1)/4*difflat
              lons[char]=minlon+(j-1)/4*difflon
              # print char, lons[char], lats[char]
            }
          }
      }
      {
        for(i=1;i<=length($0);++i) {
          char1=toupper(substr($0,i,1));
          print lons[char1], lats[char1]
        }
      }'))
      SCALEREFLON=${SCALEAPROF[0]}
      SCALEREFLAT=${SCALEAPROF[1]}
      SCALELENLAT=${SCALEAPROF[1]}
      shift
    fi
    plots+=("mapscale")
    ;;

  -scrapedata) # args: none | gia
    if arg_is_flag $2; then
      info_msg "[-scrapedata]: No datasets specified. Scraping GCMT/ISC/ANSS"
      SCRAPESTRING="giaczm"
    else
      SCRAPESTRING="${2}"
      shift
    fi

    if arg_is_flag $2; then
      info_msg "[-scrapedata]: No rebuild command specified"
      REBUILD=""
    elif [[ $2 =~ "rebuild" ]]; then
      REBUILD="rebuild"
      shift
    fi

    if [[ ${SCRAPESTRING} =~ .*g.* ]]; then
      info_msg "Scraping GCMT focal mechanisms"
      . $SCRAPE_GCMT
    fi
    if [[ ${SCRAPESTRING} =~ .*i.* ]]; then
      info_msg "Scraping ISC focal mechanisms"
      . $SCRAPE_ISCFOC
    fi
    if [[ ${SCRAPESTRING} =~ .*a.* ]]; then
      info_msg "Scraping ANSS seismic data"
      . $SCRAPE_ANSS ${ANSSDIR} ${REBUILD}
    fi
    if [[ ${SCRAPESTRING} =~ .*c.* ]]; then
      info_msg "Scraping ISC seismic data"
      . $SCRAPE_ISCSEIS ${ISC_EQS_DIR} ${REBUILD}
    fi
    if [[ ${SCRAPESTRING} =~ .*z.* ]]; then
      info_msg "Scraping GFZ focal mechanisms"
      . $SCRAPE_GFZ ${GFZDIR} ${REBUILD}
    fi
    if [[ ${SCRAPESTRING} =~ .*m.* ]]; then
      info_msg "Merging focal catalogs"
      . $MERGECATS
    fi
    exit
    ;;

  -blue)
    SENTINEL_TYPE="bluemarble"
    if arg_is_positive_float $2; then
      info_msg "[-blue]: Blue Marble image gamma correction set to $2"
      SENTINEL_GAMMA=${2}
      shift
    fi
    sentineldownloadflag=1
    ;;

  -seissum)
    if arg_is_flag $2; then
      SSRESC=""
    else
      SSRESC="-I${2}"
      shift
    fi
    if arg_is_flag $2; then
      SSTRANS="0"
    else
      SSTRANS="${2}"
      shift
    fi
    plots+=("seissum")
    ;;

  -setup)
    print_help_header
    print_setup
    exit 1
    ;;

  -setvars) # args: { VAR1 val1 VAR2 val2 VAR3 val3 }
    if [[ ${2:0:1} != [{] ]]; then
      info_msg "[-setvars]: { VAR1 val1 VAR2 val2 VAR3 val3 }"
      exit 1
    else
      shift
      while : ; do
        [[ ${2:0:1} != [}] ]] || break
        VARIABLE="${2}"
        shift
        VAL="${2}"
        shift
        export $VARIABLE=$VAL
      done
      shift
    fi
    ;;

  -shadow)

    if ! [[ ${topoctrlstring} =~ .*d.* ]]; then
      topoctrlstring=${topoctrlstring}"d"
    fi

    if arg_is_flag $2; then
      info_msg "[-shadow]: No sun azimuth specified. Using $SUN_AZ"
    else
      SUN_AZ="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-shadow]: No sun elevation specified. Using $SUN_EL"
    else
      SUN_EL="${2}"
      shift
    fi
    ;;

  -sprof) # args lon1 lat1 lon2 lat2 width res
    # Create a single profile across by constructing a new mprof) file with relevant data types
    # Needs some argument checking logic as too few arguments will mess things up spectacularly
    sprofflag=1
    SPROFLON1="${2}"
    SPROFLAT1="${3}"
    SPROFLON2="${4}"
    SPROFLAT2="${5}"
    SPROFWIDTH="${6}"
    SPROF_RES="${7}"
    shift
    shift
    shift
    shift
    shift
    shift
    clipdemflag=1
    ;;

  -sun)
    if arg_is_float $2; then
      SUN_AZ=$2
      HS_AZ=$2
      shift
    fi
    if arg_is_positive_float $2; then
      SUN_EL=$2
      HS_EL=$2
      shift
    fi
    ;;

  -sv|--slipvector) # args: filename
    plots+=("slipvecs")
    SVDATAFILE=$(abs_path $2)
    shift
    ;;

  -t|--topo) # args: ID | filename { args }
    if arg_is_flag $2; then
			info_msg "[-t]: No topo file specified: SRTM30 assumed"
			BATHYMETRY="SRTM30"
		else
			BATHYMETRY="${2}"
			shift
		fi
    clipdemflag=1
		case $BATHYMETRY in
      01d|30m|20m|15m|10m|06m|05m|04m|03m|02m|01m|15s|03s|01s)
        plottopo=1
        GRIDDIR=$EARTHRELIEFDIR
        GRIDFILE=${EARTHRELIEFPREFIX}${BATHYMETRY}
        plots+=("topo")
        remotetileget=1
        echo $EARTHRELIEF_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $EARTHRELIEF_SOURCESTRING >> tectoplot.sources
        ;;
      BEST)
        BATHYMETRY="01s"
        plottopo=1
        GRIDDIR=$EARTHRELIEFDIR
        GRIDFILE=${EARTHRELIEFPREFIX}${BATHYMETRY}
        plots+=("topo")
        remotetileget=1
        besttopoflag=1
        echo $GMRT_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GMRT_SOURCESTRING >> tectoplot.sources
        echo $SRTM_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $SRTM_SOURCESTRING >> tectoplot.sources
        ;;
			SRTM30)
			  plottopo=1
				GRIDDIR=$SRTM30DIR
				GRIDFILE=$SRTM30FILE
				plots+=("topo")
        echo $SRTM_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $SRTM_SOURCESTRING >> tectoplot.sources
        remotetileget=1
				;;
      GEBCO20)
        plottopo=1
        GRIDDIR=$GEBCO20DIR
        GRIDFILE=$GEBCO20FILE
        plots+=("topo")
        echo $GEBCO_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GEBCO_SOURCESTRING >> tectoplot.sources
        ;;
      GEBCO1)
        plottopo=1
        GRIDDIR=$GEBCO1DIR
        GRIDFILE=$GEBCO1FILE
        plots+=("topo")
        echo $GEBCO_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GEBCO_SOURCESTRING >> tectoplot.sources
        ;;
      GMRT)
        plottopo=1
        GRIDDIR=$GMRTDIR
        plots+=("topo")
        echo $GMRT_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GMRT_SOURCESTRING >> tectoplot.sources
        ;;
      *)
        plottopo=1
        plotcustomtopo=1
        info_msg "Using custom grid"
        BATHYMETRY="custom"
        GRIDDIR=$(abs_dir $1)
        GRIDFILE=$(abs_path $1)  # We already shifted
        plots+=("topo")
        ;;
    esac

    # Read any topo arguments we might want to specify... not sure which would be used?
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-t]: Topo args detected... slurping"
      shift
      while : ; do
        [[ ${2:0:1} != [}] ]] || break
        topoargs+=("${2}")
        shift
      done
      shift
      info_msg "[-t]: Found topo args ${imageargs[@]}"
      TOPOARGS="${imageargs[@]}"
    fi

    # Specify a CPT file
    if arg_is_flag $2; then
      info_msg "[-t]: No topo CPT specified. Using default."
    else
      customgridcptflag=1
      CPTNAME="${2}"
      CUSTOMCPT=$(abs_path $2)
      shift
      if ! [[ -e $CUSTOMCPT ]]; then
        info_msg "CPT $CUSTOMCPT does not exist... looking for $CPTNAME in $CPTDIR"
        if [[ -e $CPTDIR$CPTNAME ]]; then
          CUSTOMCPT=$CPTDIR$CPTNAME
          info_msg "Found CPT $CPTDIR$CPTNAME"
        else
          info_msg "No CPT could be assigned. Using $TOPO_CPT_DEF"
          CUSTOMCPT=$TOPO_CPT_DEF
        fi
      fi
    fi
    cpts+=("topo")

    MULFACT=$(echo "1 / $HS_Z_FACTOR * 111120" | bc -l)     # Effective z factor for geographic DEM with m elevation

    ;;
  #
  # -tc|--cpt) # args: filename
  #   customgridcptflag=1
  #   CPTNAME="${2}"
  #   CUSTOMCPT=$(abs_path $2)
  #   shift
  #   if ! [[ -e $CUSTOMCPT ]]; then
  #     info_msg "CPT $CUSTOMCPT does not exist... looking for $CPTNAME in $CPTDIR"
  #     if [[ -e $CPTDIR/$CPTNAME ]]; then
  #       CUSTOMCPT=$CPTDIR/$CPTNAME
  #       info_msg "Found CPT $CPTDIR/$CPTNAME"
  #     else
  #       info_msg "No CPT could be assigned. Using $TOPO_CPT"
  #       CUSTOMCPT=$TOPO_CPT
  #     fi
  #   fi
  #   ;;

  --tdeffaults)
    # Expects a comma-delimited list of numbers
    tdeffaultlistflag=1
    FAULTIDLIST="${2}"
    shift
    ;;

	--tdefnode) # args: filename
		tdefnodeflag=1
		TDPATH="${2}"
		TDSTRING="${3}"
		plots+=("tdefnode")
    cpts+=("slipratedeficit")
		shift
		shift
		;;

	--tdefpm)
		plotplates=1
    tdefnodeflag=1
		if arg_is_flag $2; then
			info_msg "[--tdefpm]: No path specified for TDEFNODE results folder"
			exit 2
		else
			TDPATH="${2}"
			TDFOLD=$(echo $TDPATH | xargs -n 1 dirname)
			TDMODEL=$(echo $TDPATH | xargs -n 1 basename)
			BASENAME="${TDFOLD}/${TDMODEL}/${TDMODEL}"
			! [[ -e "${BASENAME}_blk.gmt" ]] && echo "TDEFNODE block file does not exist... exiting" && exit 2
			! [[ -e "${BASENAME}.poles" ]] && echo "TDEFNODE pole file does not exist... exiting" && exit 2
      ! [[ -d "${TDFOLD}/${TDMODEL}/"def2tecto_out/ ]] && mkdir "${TDFOLD}/${TDMODEL}/"def2tecto_out/
			rm -f "${TDFOLD}/${TDMODEL}/"def2tecto_out/*.dat
			# echo "${TDFOLD}/${TDMODEL}/"def2tecto_out/
			str1="G# P# Name      Lon.      Lat.     Omega     SigOm    Emax    Emin      Az"
			str2="Relative poles"
			cat "${BASENAME}.poles" | sed '1,/G# P# Name      Lon.      Lat.     Omega     SigOm    Emax    Emin      Az     VAR/d;/ Relative poles/,$d' | sed '$d' | gawk  '{print $3, $5, $4, $6}' | grep '\S' > ${TDPATH}/def2tecto_out/poles.dat
			cat "${BASENAME}_blk.gmt" | gawk  '{ if ($1 == ">") print $1, $6; else print $1, $2 }' > ${TDPATH}/def2tecto_out/blocks.dat
			POLESRC="TDEFNODE"
			PLATES="${TDFOLD}/${TDMODEL}/"def2tecto_out/blocks.dat
			POLES="${TDFOLD}/${TDMODEL}/"def2tecto_out/poles.dat
	  	info_msg "[--tdefpm]: TDEFNODE block model is ${PLATEMODEL}"
	  	TDEFRP="${3}"
			DEFREF=$TDEFRP
	    shift
	  	shift
		fi
    plots+=("slipratedeficit")
		;;

    -tflat)
      tflatflag=1
    ;;

    -tshade)
      if arg_is_flag $2; then
        info_msg "[-tshade]: No fraction value specified. Using default: ${TS_FRAC}"
      else
        TS_FRAC="${2}"
        info_msg "[-tshade]: Fraction value set to ${TS_FRAC}"
        shift
      fi
      if arg_is_flag $2; then
        info_msg "[-tshade]: No contrast stretch specified. Using default: ${TS_STRETCH} "
      else
        TS_STRETCH="${2}"
        info_msg "[-tshade]: Contrast stretch value set to ${TS_STRETCH}"
        shift
      fi
      if arg_is_flag $2; then
        info_msg "[-tshade]: No texture blend factor specified. Using default: ${TS_TEXTUREBLEND} "
      else
        TS_TEXTUREBLEND="${2}"
        info_msg "[-tshade]: Texture blend factor set to ${TS_TEXTUREBLEND}"
        shift
      fi
      if arg_is_flag $2; then
        info_msg "[-tshade]: No gamma value specified. Using default: ${TS_GAMMA} "
      else
        TS_GAMMA="${2}"
        info_msg "[-tshade]: Gamma value set to ${TS_GAMMA}"
        shift
      fi
      tshadetopoplotflag=1
      topocolorflag=1

      clipdemflag=1
      tshadeZEROHINGE=1
      topoctrlstring="cmt"   # color multi-hs texture
      ;;

  -ti)
    if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]]; then   # first arg is a number
      ILLUM="-I+a${2}+nt1+m0"
      shift
    elif arg_is_flag $2; then   # first arg doesn't exist or starts with - but isn't a number
      info_msg "[-ti]: No options specified. Ignoring."
    elif [[ ${2} =~ "off" ]]; then
      ILLUM=""
      shift
    else
      info_msg "[-ti]: option $2 not understood. Ignoring"
      shift
    fi
    ;;

  -timeme)
    SCRIPT_START_TIME="$(date -u +%s)"
    scripttimeflag=1
    ;;

  --time)
    timeselectflag=1
    if [[ "${2}" == "week" ]]; then
      weeknum=1
      shift
      if arg_is_positive_float $2; then
        weeknum=${2}
        shift
      fi
      daynum=$(echo "-1 * $weeknum * 7" | bc -l)
      STARTTIME=$(date_shift_utc $daynum 0 0 0)
      ENDTIME=$(date_shift_utc)    # COMPATIBILITY ISSUE WITH GNU date
    elif [[ "${2}" == "year" ]]; then
      yearnum=1
      shift
      if arg_is_positive_float $2; then
        yearnum=${2}
        shift
      fi
      daynum=$(echo "-1 * $yearnum * 365.25" | bc -l)
      STARTTIME=$(date_shift_utc $daynum 0 0 0)
      ENDTIME=$(date_shift_utc)    # COMPATIBILITY ISSUE WITH GNU date
    else
      STARTTIME="${2}"
      ENDTIME="${3}"
      shift
      shift
    fi
    info_msg "Time constraints: $STARTTIME to $ENDTIME"
    ;;

  -title) # args: string
    PLOTTITLE=""
    while : ; do
      arg_is_flag $2 && break
      TITLELIST+=("${2}")
      shift
    done
    PLOTTITLE="${TITLELIST[@]}"
    ;;

  -tm|--tempdir) # Relative temporary directory placed into pwd
    TMP="${2}"
    info_msg "[-tm]: Temporary directory: ${THISDIR}/${2}"
    shift
    ;;

  -tn)
    # CONTOUR_INTERVAL="${2}"
    # shift
    # info_msg "[-tn]: Plotting topo contours at interval $CONTOUR_INTERVAL"
    # plots+=("contours")
    if arg_is_flag $2; then
      info_msg "[-tn]: Contour interval not specified. Calculating automatically from Z range using $TOPOCONTOURNUMDEF contours"
      topocontourcalcflag=1
    else
      TOPOCONTOURINT="${2}"
      shift
    fi
    if [[ ${2:0:1} == [{] ]]; then
      info_msg "[-tn]: GMT argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          topocvars+=("${2}")
          shift
      done
      shift
      CONTOURGRIDVARS="${topocvars[@]}"
    fi
    info_msg "[-tn]: Custom GMT topo contour commands: ${TOPOCONTOURVARS[@]}"
    plots+=("contours")
    ;;

  -tr)
    rescaletopoflag=1
    ;;

  -ts)
    dontplottopoflag=1
    ;;

  -tt)
    TOPOTRANS=${2}
    shift
    ;;

  -tx) #                                                  don't color topography (plot intensity directly)
    dontcolortopoflag=1
    ;;

  # Popular recipes for topo visualization
  -t0)  #  Slope/50% Multiple hillshade 45°/50% Gamma=1.4
    topoctrlstring="msg"
    useowntopoctrlflag=1
    SLOPE_FACT=0.5
    HS_GAMMA=1.4
    HS_ALT=45
    ;;

  -t1)  #            [[sun_el]]                          combination multiple hs/slope map
    ;;

  -t2)  # GMT standard hillshade using illumination
    fasttopoflag=1
    ;;
  #Build your own topo visualization using these commands in sequence.
  #  [[fact]] is the blending factor (0-1) used to combine each layer with existing intensity map

  -tshad) #         [[sun_az]] [[sun_el]]   [[fact]]    add cast shadows to intensity (fact=opacity)
    if arg_is_float $2; then   # first arg is a number
      SUN_AZ="$2"
      shift
    fi
    if arg_is_positive_float $2; then   #
      SUN_EL=${2}
      shift
    fi
    if arg_is_float $2; then
      SHADOW_ALPHA=$2
      shift
    fi
    info_msg "[-tshad]: Sun azimuth=${SUN_AZ}; elevation=${SUN_EL}; alpha=${SHADOW_ALPHA}"
    topoctrlstring=${topoctrlstring}"d"
    useowntopoctrlflag=1
    ;;

  -ttext) #           [[frac]]   [[stretch]]  [[fact]]    add texture shade to intensity
    if arg_is_positive_float $2; then   #
      TS_FRAC=${2}
      shift
    fi
    if arg_is_positive_float $2; then   #
      TS_STRETCH=${2}
      shift
    fi
    if arg_is_positive_float $2; then   #
      TS_FACT=${2}
      shift
    fi
    info_msg "[-ttext]: Texture detail=${TS_FRAC}; contrast stretch=${TS_STRETCH}; combine factor=${TS_FACT}"
    topoctrlstring=${topoctrlstring}"t"
    useowntopoctrlflag=1
    ;;

  -tmult) #           [[sun_el]]              [[fact]]    add multiple hillshade to intensity
    if arg_is_positive_float $2; then   #
      HS_ALT=${2}
      shift
    fi
    if arg_is_float $2; then
      MULTIHS_FACT=$2
      shift
    fi
    info_msg "[-tmult]: Sun elevation=${SUN_EL}; combine factor=${MULTIHS_FACT}"
    topoctrlstring=${topoctrlstring}"m"
    useowntopoctrlflag=1
    ;;

  -tuni) #            [[sun_az]] [[sun_el]]   [[fact]]    add unidirectional hillshade to intensity
    if arg_is_float $2; then   # first arg is a number
      HS_AZ="$2"
      shift
    fi
    if arg_is_positive_float $2; then   #
      HS_ALT=${2}
      shift
    fi
    if arg_is_float $2; then
      UNIHS_FACT=$2
      shift
    fi
    info_msg "[-tuni]: Sun azimuth=${SUN_AZ}; elevation=${SUN_EL}; combine factor=${UNIHS_FACT}"
    topoctrlstring=${topoctrlstring}"h"
    useowntopoctrlflag=1
    ;;

  -tpct) # percent cut
    if arg_is_float $2; then   # first arg is a number
      TPCT_MIN="$2"
      shift
    fi
    if arg_is_positive_float $2; then   #
      TPCT_MAX=${2}
      shift
    fi
    info_msg "[-tpct]"
    topoctrlstring=${topoctrlstring}"x"
    useowntopoctrlflag=1
    ;;

  -tsea)
    sentinelrecolorseaflag=1
    ;;

  -tsent)
    SENTINEL_TYPE="s2cloudless-2019"
    SENTINEL_FACT=0.5
    if arg_is_positive_float $2; then
      info_msg "[-tsent]: Sentinel image alpha values set to $2"
      SENTINEL_FACT=${2}
      shift
    fi
    if arg_is_positive_float $2; then
      info_msg "[-tsent]: Sentinel image gamma correction set to $2"
      SENTINEL_GAMMA=${2}
      shift
    fi
    touch ./sentinel.tif
    sentineldownloadflag=1
    # Replace -tsent with -timg [[sentinel.tif]] [[alpha]]
    shift
    set -- "blank" "$@" "-timg" "sentinel.tif" "${SENTINEL_FACT}"
    ;;

  -tsky) #            [[num_angles]]          [[fact]]    add sky view factor to intensity
    if arg_is_float $2; then   # first arg is a number
      NUM_ANGLES="$2"
      shift
    fi
    if arg_is_float $2; then
      SKYVIEW_FACT=$2
      shift
    fi
    info_msg "[-tsky]: Number of angles=${NUM_ANGLES}; combine factor=${SKYVIEW_FACT}"
    topoctrlstring=${topoctrlstring}"v"
    useowntopoctrlflag=1
    ;;

  -tsl)
    if arg_is_float $2; then
      SLOPE_FACT=$2
      shift
    fi
    info_msg "[-tsl]: Combine factor=${SLOPE_FACT}"

    topoctrlstring=${topoctrlstring}"s"
    useowntopoctrlflag=1
    ;;

  -ttri)
    topoctrlstring=${topoctrlstring}"i"
    useowntopoctrlflag=1
    ;;

  -timg)
    if arg_is_flag $2; then
      info_msg "[-timg]: No image given. Ignoring."
    else
      P_IMAGE=$(abs_path ${2})
      shift
      topoctrlstring=${topoctrlstring}"p"
      useowntopoctrlflag=1
    fi
    if arg_is_positive_float $2; then
      IMAGE_FACT=$2
      shift
    fi
    ;;

  -tclip) # Shouldn't I just clip the DEM here? Why have it as part of processing when that can mess things up?
    if arg_is_float $2; then
      # CLIP_MINLON="${2}"
      # CLIP_MAXLON="${3}"
      # CLIP_MINLAT="${4}"
      # CLIP_MAXLAT="${5}"
      DEM_MINLON="${2}"
      DEM_MAXLON="${3}"
      DEM_MINLAT="${4}"
      DEM_MAXLAT="${5}"
      shift # past argument
      shift # past value
      shift # past value
      shift # past value
    elif [[ -e ${2} ]]; then
      CLIP_XY_FILE=$(abs_path ${2})
      # Assume that this is an XY file whose extents we want to use for DEM clipping
      CLIPRANGE=($(xy_range ${CLIP_XY_FILE}))
      shift
      # Only adopt the new range if the max/min values are numbers and their order is OK
      usecliprange=1
      [[ ${CLIPRANGE[0]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usecliprange=0
      [[ ${CLIPRANGE[1]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usecliprange=0
      [[ ${CLIPRANGE[2]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usecliprange=0
      [[ ${CLIPRANGE[3]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usecliprange=0
      [[ $(echo "${CLIPRANGE[0]} < ${CLIPRANGE[1]}" | bc -l) -eq 1 ]] || usecliprange=0
      [[ $(echo "${CLIPRANGE[2]} < ${CLIPRANGE[3]}" | bc -l) -eq 1 ]] || usecliprange=0

      if [[ $usecliprange -eq 1 ]]; then
        info_msg "Clip range taken from XY file: ${CLIPRANGE[0]}/${CLIPRANGE[1]}/${CLIPRANGE[2]}/${CLIPRANGE[3]}"
        # CLIP_MINLON=${CLIPRANGE[0]}
        # CLIP_MAXLON=${CLIPRANGE[1]}
        # CLIP_MINLAT=${CLIPRANGE[2]}
        # CLIP_MAXLAT=${CLIPRANGE[3]}
        DEM_MINLON=${CLIPRANGE[0]}
        DEM_MAXLON=${CLIPRANGE[1]}
        DEM_MINLAT=${CLIPRANGE[2]}
        DEM_MAXLAT=${CLIPRANGE[3]}
      else
        info_msg "Could not assign DEM clip using XY file."
        # CLIP_MINLON=${MINLON}
        # CLIP_MINLAT=${MINLAT}
        # CLIP_MAXLON=${MAXLON}
        # CLIP_MAXLAT=${MAXLAT}
      fi
    fi

    demisclippedflag=1
    # topoctrlstring="w"${topoctrlstring}   # Clip before other actions
    ;;

  -tunsetflat)
    topoctrlstring=${topoctrlstring}"u"
    ;;

  -tgam) #            [gamma]                           add gamma correction to intensity
    if arg_is_positive_float $2; then
      HS_GAMMA=$2
      shift
    else
      info_msg "[-tgam]: Positive number expected. Using ${HS_GAMMA}."
    fi
    topoctrlstring=${topoctrlstring}"g"
    useowntopoctrlflag=1
    ;;



	-v|--gravity) # args: string number
		GRAVMODEL="${2}"
		GRAVTRANS="${3}"
		shift
		shift
    if arg_is_flag $2; then
			info_msg "[-v]: No rescaling of gravity CPT specified"
		elif [[ ${2} =~ "rescale" ]]; then
      rescalegravflag=1
			info_msg "[-v]: Rescaling gravity CPT to AOI"
			shift
    else
      info_msg "[-v]: Unrecognized option ${2}"
      shift
		fi
		case $GRAVMODEL in
			FA)
				GRAVDATA=$WGMFREEAIR
				GRAVCPT=$WGMFREEAIR_CPT
        echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GRAV_SOURCESTRING >> tectoplot.sources
				;;
			BG)
				GRAVDATA=$WGMBOUGUER
				GRAVCPT=$WGMBOUGUER_CPT
        echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GRAV_SOURCESTRING >> tectoplot.sources
				;;
			IS)
				GRAVDATA=$WGMISOSTATIC
				GRAVCPT=$WGMISOSTATIC_CPT
        echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
        echo $GRAV_SOURCESTRING >> tectoplot.sources
				;;
      SW)
        GRAVDATA=$SANDWELLFREEAIR
        GRAVCPT=$WGMFREEAIR_CPT
        echo $SANDWELL_SOURCESTRING >> tectoplot.sources
        echo $SANDWELL_SHORT_SOURCESTRING >> tectoplot.shortsources
        ;;
			*)
				echo "Gravity model not recognized."
				exit 1
				;;
		esac
		info_msg "[-v]: Gravity data to plot is ${GRAVDATA}, transparency is ${GRAVTRANS}"
		plots+=("grav")
    cpts+=("grav")
	  ;;

  -vres)  # Calculate residual gravity within specified distance of a provided XY line
  GRAVMODEL="${2}"
  GRAVXYFILE=$(abs_path "${3}")
  GRAVWIDTHKM="${4}"
  GRAVALONGAVKM="${5}"
  GRAVACROSSAVKM="${6}"
  shift
  shift
  shift
  shift
  shift
  if ! arg_is_flag $2; then
    if [[ $2 =~ contour ]]; then
      GRAVCONTOURFLAG=1
    fi
    shift
  fi


  case $GRAVMODEL in
    FA)
      GRAVDATA=$WGMFREEAIR
      GRAVCPT=$WGMFREEAIR_CPT
      echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $GRAV_SOURCESTRING >> tectoplot.sources
      ;;
    BG)
      GRAVDATA=$WGMBOUGUER
      GRAVCPT=$WGMBOUGUER_CPT
      echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $GRAV_SOURCESTRING >> tectoplot.sources
      ;;
    IS)
      GRAVDATA=$WGMISOSTATIC
      GRAVCPT=$WGMISOSTATIC_CPT
      echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $GRAV_SOURCESTRING >> tectoplot.sources
      ;;
    SW)
      GRAVDATA=$SANDWELLFREEAIR
      GRAVCPT=$WGMFREEAIR_CPT
      echo $SANDWELL_SOURCESTRING >> tectoplot.sources
      echo $SANDWELL_SHORT_SOURCESTRING >> tectoplot.shortsources
      ;;
    *)
      echo "Gravity model $GRAVMODEL not recognized."
      exit 1
      ;;
  esac

  resgravflag=1

  plots+=("resgrav")
  cpts+=("resgrav")

  ;;

  -variables)
    print_help_header
    print_variables
    exit 1
    ;;

  -vars) # argument: filename
    VARFILE=$(abs_path $2)
    shift
    info_msg "[-vars]: Sourcing variable assignments from $VARFILE"
    . $VARFILE
    ;;

  -vc|--volc) # args: none
    plots+=("volcanoes")
    volcanoesflag=1
    echo $VOLC_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $VOLC_SOURCESTRING >> tectoplot.sources
    ;;

  # A high priority option processed in the prior loop
  --verbose) # args: none
    # VERBOSE="-V"
    ;;

  -w|--euler) # args: number number number
    eulervecflag=1
    eulerlat="${2}"
    eulerlon="${3}"
    euleromega="${4}"
    shift
    shift
    shift
    plots+=("euler")
    ;;

  -wg) # args: number
    euleratgpsflag=1
    if arg_is_flag $2; then
			info_msg "[-wg]: No residual scaling specified... not plotting residuals"
		else
      ploteulerobsresflag=1
			WRESSCALE="${2}"
			info_msg "[-wg]: Plotting only residuals with scaling factor $WRESSCALE"
			shift
		fi
    ;;

  -wp) # args: string string
    twoeulerflag=1
    plotplates=1
    eulerplate1="${2}"
    eulerplate2="${3}"
    plots+=("euler")
    shift
    shift
    ;;

	-z|--seis) # args: number
		plotseis=1
		if arg_is_flag $2; then
			info_msg "[-z]: No scaling for seismicity specified... using default $SEISSIZE"
		else
			SEISSCALE="${2}"
			info_msg "[-z]: Seismicity scale updated to $SEIZSIZE * $SEISSCALE"
			shift
		fi
		plots+=("seis")
    cpts+=("seisdepth")
    echo $EQ_SOURCESTRING >> tectoplot.sources
    echo $EQ_SHORT_SOURCESTRING >> tectoplot.shortsources
    ;;

  -zadd) # args: file   - supplemental seismicity catalog in lon lat depth mag [datestr] [id] format
    seisfilenumber=$(echo "$seisfilenumber+1" | bc)
    if arg_is_flag $2; then
      info_msg "[-zadd]: Seismicity file must be specified"
    else
      SEISADDFILE[$seisfilenumber]=$(abs_path $2)
      if [[ ! -e "${SEISADDFILE[$seisfilenumber]}" ]]; then
        info_msg "Seismicity file ${SEISADDFILE[$seisfilenumber]} does not exist"
      else
        suppseisflag=1
      fi
      shift
    fi

    if [[ "${2}" != "replace" ]]; then
      info_msg "[-zadd]: Seis replace flag not specified. Not replacing catalog hypocenters."
      eqcatalogreplaceflag=0
    else
      eqcatalogreplaceflag=1
      shift
    fi
    ;;

  -zcnoscale)
    SCALEEQS=0
    ;;

  -zdep)
    EQCUTMINDEPTH=${2}
    shift
    EQCUTMAXDEPTH=${2}
    shift
    info_msg "[-zdep]: Plotting seismic data between ${EQCUTMINDEPTH} km and ${EQCUTMAXDEPTH} km"
  ;;

  -zfill)
    seisfillcolorflag=1
    if arg_is_flag $2; then
      info_msg "[-zfill]:  No color specified. Using black."
      ZSFILLCOLOR="black"
    else
      ZSFILLCOLOR="${2}"
      shift
    fi
    ;;

  -zcat) #            [ANSS or ISC]
    if arg_is_flag $2; then
      info_msg "[-zcat]: No catalog specified. Using default."
    else
      EQCATNAME="${2}"
      shift
      info_msg "[-z]: Seismicity scale updated to $SEIZSIZE * $SEISSCALE"
      case $EQCATNAME in
        ISC)
          EQ_CATALOG_TYPE="ISC"
          EQ_SOURCESTRING=$ISC_EQ_SOURCESTRING
          EQ_SHORT_SOURCESTRING=$ISC_EQ_SHORT_SOURCESTRING
        ;;
        ANSS)
          EQ_CATALOG_TYPE="ANSS"
          EQ_SOURCESTRING=$ANSS_EQ_SOURCESTRING
          EQ_SHORT_SOURCESTRING=$ANSS_EQ_SHORT_SOURCESTRING
        ;;
        NONE)
          EQ_CATALOG_TYPE="NONE"
        ;;
      esac
    fi
    ;;

  -zcolor)
    if arg_is_flag $2; then
      info_msg "[-zcolor]: No min/max depth specified. Using default $EQMINDEPTH_COLORSCALE/$EQMAXDEPTH_COLORSCALE"
    else
      EQMINDEPTH_COLORSCALE=$2
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-zcolor]: No max depth specified. Using default $EQMAXDEPTH_COLORSCALE"
    else
      EQMAXDEPTH_COLORSCALE=$2
      shift
    fi
    ;;

  -zmag)
    if arg_is_flag $2; then
      info_msg "[-zmax]: No limits specified [minmag] [maxmag]"
    else
      EQ_MINMAG="${2}"
      shift
      if arg_is_flag $2; then
        info_msg "[-zmax]: No maximum magnitude specified. Using default."
      else
        EQ_MAXMAG="${2}"
        shift
      fi
    fi
    eqmagflag=1
    ;;

  -znoplot)
    dontplotseisflag=1
    ;;

  -zr1|--eqrake1) # args: number
    if arg_is_flag $2; then
      info_msg "[-zr]:  No rake color scale indicated. Using default: ${RAKE1SCALE}"
    else
      RAKE1SCALE="${2}"
      shift
    fi
    plots+=("seisrake1")
    ;;

  -zr2|--eqrake2) # args: number
    if arg_is_flag $2; then
      info_msg "[-zr]:  No rake color scale indicated. Using default: ${RAKE2SCALE}"
    else
      RAKE2SCALE="${2}"
      shift
    fi
    plots+=("seisrake2")
    ;;

  -zsort)
    if arg_is_flag $2; then
      info_msg "[-zsort]:  No sort dimension specified. Using depth."
      ZSORTTYPE="depth"
    else
      ZSORTTYPE="${2}"
      shift
    fi
    if arg_is_flag $2; then
      info_msg "[-zsort]:  No sort direction specified. Using down."
      ZSORTDIR="down"
    else
      ZSORTDIR="${2}"
      shift
    fi
    dozsortflag=1
    ;;

	*)    # unknown option.
		echo "Unknown argument encountered: ${1}" 1>&2
    exit 1
    ;;
  esac
  shift
done

# IMMEDIATELY AFTER PROCESSING ARGUMENTS, DO THESE CRITICAL TASKS

# We made it to the calc/plotting sections, so record the command
echo $COMMAND > tectoplot.last

if [[ $setregionbyearthquakeflag -eq 1 ]]; then
  LOOK1=$(grep $REGION_EQ $FOCALCATALOG | head -n 1)
  if [[ $LOOK1 != "" ]]; then
    # echo "Found EQ region focal mechanism $REGION_EQ"
    case $CMTTYPE in
      ORIGIN)
        REGION_EQ_LON=$(echo $LOOK1 | gawk  '{print $8}')
        REGION_EQ_LAT=$(echo $LOOK1 | gawk  '{print $9}')
        ;;
      CENTROID)
        REGION_EQ_LON=$(echo $LOOK1 | gawk  '{print $5}')
        REGION_EQ_LAT=$(echo $LOOK1 | gawk  '{print $6}')
        ;;
    esac
  else
    if [[ $EQ_CATALOG_TYPE =~ "ANSS" ]]; then
      info_msg "Looking for event ${REGION_EQ}"
      LOOK2=$(grep $REGION_EQ ${ANSSDIR}"Tiles/"*)
      echo $LOOK2
      if [[ $LOOK2 != "" ]]; then
        # echo "Found EQ region hypocenter $REGION_EQ"
        REGION_EQ_LON=$(echo $LOOK2 | gawk -F, '{print $3}')
        REGION_EQ_LAT=$(echo $LOOK2 | gawk -F, '{print $2}')
        # Remove quotation marks before getting title
        PLOTTITLE="Event $REGION_EQ, $(echo $LOOK2 | gawk -F'"' -v OFS='' '{ for (i=2; i<=NF; i+=2) gsub(",", "", $i) } 1' | gawk -F, '{print $14}'), Depth=$(echo $LOOK2 | gawk -F, '{print $4}') km"
      else
        info_msg "[-r]: EQ mode: No event found"
        exit
      fi
    elif [[ $EQ_CATALOG_TYPE =~ "ISC" ]]; then
      echo "ISC grep for event"
    elif [[ $EQ_CATALOG_TYPE =~ "NONE" ]]; then
      echo "No EQ catalog"
    fi
  fi
  MINLON=$(echo "$REGION_EQ_LON - $EQ_REGION_WIDTH" | bc -l)
  MAXLON=$(echo "$REGION_EQ_LON + $EQ_REGION_WIDTH" | bc -l)
  MINLAT=$(echo "$REGION_EQ_LAT - $EQ_REGION_WIDTH" | bc -l)
  MAXLAT=$(echo "$REGION_EQ_LAT + $EQ_REGION_WIDTH" | bc -l)

  if [[ $(echo "${MAXLON} < ${MINLON}" | bc) -eq 1 ]]; then
    echo "Longitude range is messed up. Trying to adjust"
    MAXLON=$(echo "${MAXLON}+180" | bc -l)
  fi
  info_msg "[-r]: Earthquake centered region: $MINLON/$MAXLON/$MINLAT/$MAXLAT centered at $REGION_EQ_LON/$REGION_EQ_LAT"
fi


################################################################################
###### Calculate some sizes for the final map document based on AOI aspect ratio

LATSIZE=$(echo "$MAXLAT - $MINLAT" | bc -l)
LONSIZE=$(echo "$MAXLON - $MINLON" | bc -l)

CENTERLON=$(echo "($MINLON + $MAXLON) / 2" | bc -l)
CENTERLAT=$(echo "($MINLAT + $MAXLAT) / 2" | bc -l)

if [[ ! $usecustomrjflag -eq 1 ]]; then
  rj+=("-R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}")
  rj+=("-JQ${CENTERLON}/${PSSIZE}i")
  RJSTRING="${rj[@]}"
  # echo "Basic RJSTRING is $RJSTRING"
  usecustomrjflag=1
fi


# For a standard run, we want something like this. For other projections, unlikely to be sufficient
# We want a page that is PSSIZE wide with a MARGIN. It scales vertically based on the
# aspect ratio of the map region

INCH=$PSSIZE

# If MAKERECTMAP is set to 1, the RJSTRING will be changed to a different format
# to allow plotting of a rectangular map not bounded by parallels/meridians.
# However, data that does not fall within the AOI region given by MINLON/MAXLON/etc
# will not be processed or plotted. So we would need to recalculate these parameters
# based on the maximal range present in the final plot. I would usually do this by
# rendering the map frame as populated polylines and finding the maximal coordinates of the vertices.

# We have to set the RJ flag after setting the plot size (INCH)

if [[ $setutmrjstringfromarrayflag -eq 1 ]]; then

  if [[ $calcutmzonelaterflag -eq 1 ]]; then
    # This breaks terribly if the average longitude is not between -180 and 180
    UCENTERLON=$(gmt mapproject -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -WjCM ${VERBOSE} | gawk '{print $1}')
    AVELONp180o6=$(echo "(($UCENTERLON) + 180)/6" | bc -l)
    UTMZONE=$(echo $AVELONp180o6 1 | gawk  '{val=int($1)+($1>int($1)); print (val>0)?val:1}')
  fi
  info_msg "Using UTM Zone $UTMZONE"

  if [[ $MAKERECTMAP -eq 1 ]]; then
    rj[1]="-R${MINLON}/${MINLAT}/${MAXLON}/${MAXLAT}r"
    rj[2]="-JU${UTMZONE}/${INCH}i"
    RJSTRING="${rj[@]}"

    gmt psbasemap -A $RJSTRING | grep -v "#" > mapoutline.txt
    MINLONNEW=$(gawk < mapoutline.txt 'BEGIN {getline;min=$1} NF { min=(min>$1)?$1:min } END{print min}')
    MAXLONNEW=$(gawk < mapoutline.txt 'BEGIN {getline;max=$1} NF { max=(max>$1)?max:$1 } END{print max}')
    MINLATNEW=$(gawk < mapoutline.txt 'BEGIN {getline;min=$2} NF { min=(min>$2)?$2:min } END{print min}')
    MAXLATNEW=$(gawk < mapoutline.txt 'BEGIN {getline;max=$2} NF { max=(max>$2)?max:$2} END{print max}')
    info_msg "Updating AOI from ${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} to ${MINLONNEW}/${MAXLONNEW}/${MINLATNEW}/${MAXLATNEW}"
    MINLON=$MINLONNEW
    MAXLON=$MAXLONNEW
    MINLAT=$MINLATNEW
    MAXLAT=$MAXLATNEW

  else
    rj[1]="-R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}"
    rj[2]="-JU${UTMZONE}/${INCH}i"
  fi
  rj[2]="-JU${UTMZONE}/${INCH}i"
  RJSTRING="${rj[@]}"
  info_msg "[-RJ]: Custom region and projection string is: ${RJSTRING[@]}"
fi

### NOTE: All "Default projection" sections below are now unneeded as we have
###       a well defined RJSTRING for all maps

# Examine boundary of map to see of we want to reset the AOI to only the map area

info_msg "Recalculating AOI from map boundary"

# Get the bounding box and normalize longitudes to the range [-180:180]
# gmt psbasemap ${RJSTRING[@]} -A ${VERBOSE} > thisb.txt

gmt psbasemap ${RJSTRING[@]} -A ${VERBOSE} | gawk '
  ($1!="NaN") {
    while ($1>180) { $1=$1-360 }
    while ($1<-180) { $1=$1+360 }
    if ($1==($1+0) && $2==($2+0)) {
      print
    }
  }' > bounds.txt

# Project the bounding box using the RJSTRING

# This was always a bad method, try to jettison it
gmt mapproject bounds.txt ${RJSTRING[@]} ${VERBOSE} > projbounds.txt


# The reason to do this is because our -R/// string needs to change based on
# various earlier settings, so we need to update MINLON/MAXLON/MINLAT/MAXLAT

if [[ $recalcregionflag -eq 1 ]]; then

    NEWRANGETL=($(gmt mapproject ${RJSTRING[@]} -WjTL ${VERBOSE}))
    NEWRANGEBR=($(gmt mapproject ${RJSTRING[@]} -WjBR ${VERBOSE}))
    # NEWRANGECM=($(gmt mapproject ${RJSTRING[@]} -WjCM ${VERBOSE}))

    # echo "TL: ${NEWRANGETL[@]}"
    # echo "BR: ${NEWRANGEBR[@]}"
    # echo "CM: ${NEWRANGECM[@]}"

    NEWRANGE=($(echo ${NEWRANGETL[0]} ${NEWRANGEBR[0]} ${NEWRANGEBR[1]} ${NEWRANGETL[1]}))

    # # Only adopt the new range if the max/min values are numbers and their order is OK
    # usenewrange=1
    # [[ ${NEWRANGE[0]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usenewrange=0
    # [[ ${NEWRANGE[1]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usenewrange=0
    # [[ ${NEWRANGE[2]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usenewrange=0
    # [[ ${NEWRANGE[3]} =~ ^[-+]?[0-9]*.*[0-9]+$ ]] || usenewrange=0
    # # [[ $(echo "${NEWRANGE[0]} < ${NEWRANGE[1]}" | bc -l) -eq 1 ]] || usenewrange=0
    # # [[ $(echo "${NEWRANGE[2]} < ${NEWRANGE[3]}" | bc -l) -eq 1 ]] || usenewrange=0

    # This newrange needs to take into account longitudes below -180 and above 180...

    if [[ $usenewrange -eq 1 ]]; then
      info_msg "Updating AOI to new map extent: ${NEWRANGE[0]}/${NEWRANGE[1]}/${NEWRANGE[2]}/${NEWRANGE[3]}"
      MINLON=${NEWRANGE[0]}
      MAXLON=${NEWRANGE[1]}
      MINLAT=${NEWRANGE[2]}
      MAXLAT=${NEWRANGE[3]}
    else
      info_msg "Could not update AOI based on map extent."
    fi
fi

NEWRANGECM=($(gmt mapproject ${RJSTRING[@]} -WjCM ${VERBOSE}))

CENTERLON=${NEWRANGECM[0]}
CENTERLAT=${NEWRANGECM[1]}

##### Define the output filename for the map, in PDF
if [[ $outflag == 0 ]]; then
	MAPOUT="tectomap_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON
  MAPOUTLEGEND="tectomap_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON"_legend.pdf"
  info_msg "Output file is $MAPOUT, legend is $MAPOUTLEGEND"
else
  info_msg "Output file is $MAPOUT, legend is legend.pdf"
  MAPOUTLEGEND="legend.pdf"
fi

info_msg "RJSTRING: ${RJSTRING[@]}"

##### If we are adding a region code to the custom regions file, do it now #####

if [[ $addregionidflag -eq 1 ]]; then
  #REGIONTOADD
  awk -v id=${REGIONTOADD} < $CUSTOMREGIONS '{
    if ($1 != id) {
      print
    }
  }' > ./regions.tmp
  echo "${REGIONTOADD} ${MINLON} ${MAXLON} ${MINLAT} ${MAXLAT} ${RJSTRING[@]}" >> ./regions.tmp
  mv ./regions.tmp ${CUSTOMREGIONS}
fi

if [[ $usecustomregionrjstringflag -eq 1 ]]; then
  unset RJSTRING
  ind=0
  while ! [[ -z ${CUSTOMREGIONRJSTRING[$ind]} ]]; do
    RJSTRING+=("${CUSTOMREGIONRJSTRING[$ind]}")
    ind=$(echo "$ind+1" | bc)
  done
  info_msg "[-r]: Using customID RJSTRING: ${RJSTRING[@]}"
fi

################################################################################
#####          Create and change into the temporary directory              #####
################################################################################

# Delete and remake the temporary directory where interim files will be stored
# Only delete the temporary directory if it is a subdirectory of the current
# directory to prevent accidents

# First copy the .ps base file, which can be in an already existing temporary
# folder that is doomed to be overwritten.

OVERLAY=""
if [[ $overplotflag -eq 1 ]]; then
   info_msg "Overplotting onto ${PLOTFILE} as copy. Ensure base ps is not closed using --keepopenps"
   cp "${PLOTFILE}" "${THISDIR}"/tmpmap.ps
   OVERLAY="-O"
fi


if [[ ${TMP::1} == "/" ]]; then
  info_msg "Temporary directory path ${TMP} is an absolute path from root."
  if [[ -d $TMP ]]; then
    info_msg "Not deleting absolute path ${TMP}. Using ${DEFAULT_TMP}"
    TMP="${DEFAULT_TMP}"
  fi
else
  if [[ -d $TMP ]]; then
    info_msg "Temp dir $TMP exists. Deleting."
    rm -rf "${TMP}"
  fi
  info_msg "Creating temporary directory $TMP."
fi

# Make the main directory

mkdir -p "${TMP}"

# Move some leftover files before cd to tmp

[[ -e tectoplot.info_msg ]] && mv tectoplot.info_msg ${TMP}
[[ -e tectoplot.sources ]] && mv tectoplot.sources ${TMP}
[[ -e tectoplot.shortsources ]] && mv tectoplot.shortsources ${TMP}
if [[ $overplotflag -eq 1 ]]; then
   info_msg "Copying basemap ps into temporary directory"
   mv "${THISDIR}"/tmpmap.ps "${TMP}map.ps"
fi

cd "${TMP}"

# Make subdirectories
mkdir -p "${F_MAPELEMENTS}"

echo "${RJSTRING[@]}" > ${F_MAPELEMENTS}rjstring.txt

mkdir -p "${F_SEIS}"
mkdir -p "${F_CPTS}"     # Defined in tectoplot.cpts

[[ -d ../tmpcpts ]] && mv ../tmpcpts/* ${F_CPTS} && rmdir ../tmpcpts/


mkdir -p "${F_TOPO}"
mkdir -p "${F_VOLC}"
mkdir -p "${F_GRAV}"
mkdir -p "${F_SLAB}"
mkdir -p "${F_PROFILES}"

mkdir -p "${F_KIN}"
mkdir -p "${F_CMT}"

[[ -e ../aprof_profs.txt ]] && mv ../aprof_profs.txt ${F_PROFILES}
[[ -e ../cprof_prep.txt ]] && mv ../cprof_prep.txt ${F_PROFILES}

[[ -e ../bounds.txt ]] && mv ../bounds.txt ${F_MAPELEMENTS}
[[ -e ../projbounds.txt ]] && mv ../projbounds.txt ${F_MAPELEMENTS}

mkdir -p "${F_PLATES}"

mkdir -p "rasters/"

# Determine the range of projected coordinates for the bounding box and save them
XYRANGE=($(xy_range ${F_MAPELEMENTS}projbounds.txt))
echo ${XYRANGE[@]} > ${F_MAPELEMENTS}projxyrange.txt

gawk -v minlon=${XYRANGE[0]} -v maxlon=${XYRANGE[1]} -v minlat=${XYRANGE[2]} -v maxlat=${XYRANGE[3]} '
BEGIN {
    row[1]="AFKPU"
    row[2]="BGLQV"
    row[3]="CHMRW"
    row[4]="DINSX"
    row[5]="EJOTY"
    difflat=maxlat-minlat
    difflon=maxlon-minlon

    newdifflon=difflon*8/10
    newminlon=minlon+difflon*1/10
    newmaxlon=maxlon-difflon*1/10

    newdifflat=difflat*8/10
    newminlat=minlat+difflat*1/10
    newmaxlat=maxlat-difflat*1/10

    minlon=newminlon
    maxlon=newmaxlon
    minlat=newminlat
    maxlat=newmaxlat
    difflat=newdifflat
    difflon=newdifflon

    for(i=1;i<=5;i++) {
      for(j=1; j<=5; j++) {
        char=toupper(substr(row[i],j,1))
        lats[char]=minlat+(i-1)/4*difflat
        lons[char]=minlon+(j-1)/4*difflon
        print lons[char], lats[char], char
      }
    }
}' > ${F_MAPELEMENTS}aprof_database_proj.txt

# Project aprof_database.txt back to geographic coordinates and rearrange
gmt mapproject ${F_MAPELEMENTS}aprof_database_proj.txt ${RJSTRING[@]} -I ${VERBOSE} | tr '\t' ' ' > ${F_MAPELEMENTS}aprof_database.txt

# Extract the aprof list to make the profiles
for code in ${aproflist[@]}; do
  p1=($(grep "[${code:0:1}]" ${F_MAPELEMENTS}aprof_database.txt))
  p2=($(grep "[${code:1:1}]" ${F_MAPELEMENTS}aprof_database.txt))
  if [[ ${#p1[@]} -eq 3 && ${#p2[@]} -eq 3 ]]; then
    echo "P P_${code} black 0 N ${p1[0]} ${p1[1]} ${p2[0]} ${p2[1]}" >> ${F_PROFILES}aprof_profs.txt
  fi
done

# Build the cprof profiles

if [[ -s ${F_PROFILES}cprof_prep.txt ]]; then
  while read pin; do
    p=(${pin})
    CPAZ=${p[0]}
    CPLON=${p[1]}
    if [[ ${CPLON} =~ "eqlon" ]]; then
      CPLON=$REGION_EQ_LON
    fi
    CPLAT=${p[2]}
    if [[ ${CPLAT} =~ "eqlat" ]]; then
      CPLAT=$REGION_EQ_LAT
    fi
    CPHALFLEN=${p[3]}


    if [[ $CPAZ =~ "slab2" ]]; then
    # Check for Slab2 strike here
      shift
      info_msg "[-cprof]: Querying Slab2 to determine azimuth of profile."
      numslab2inregion=0
      echo $CPLON $CPLAT > inpoint.file
      cleanup inpoint.file
      for slabcfile in $(ls -1a ${SLAB2_CLIPDIR}*.csv); do
        # echo "Looking at file $slabcfile"
        gawk < $slabcfile '{
          if ($1 > 180) {
            print $1-360, $2
          } else {
            print $1, $2
          }
        }' > tmpslabfile.dat
        numinregion=$(gmt select inpoint.file -Ftmpslabfile.dat ${VERBOSE} | wc -l)
        if [[ $numinregion -ge 1 ]]; then
          numslab2inregion=$(echo "$numslab2inregion+1" | bc)
          slab2inregion[$numslab2inregion]=$(basename -s .csv $slabcfile)
        fi
      done
      if [[ $numslab2inregion -eq 0 ]]; then
        info_msg "[-b]: No slabs beneath the CPROF point. Using default azimuth of 90 degrees."
        CPAZ=90
      else
        for i in $(seq 1 $numslab2inregion); do
          info_msg "[-b]: Found slab2 slab ${slab2inregion[$i]} beneath the CPROF point. Querying strike raster"
          gridfile=$(echo ${SLAB2_GRIDDIR}${slab2inregion[$i]}.grd | sed 's/clp/str/')
          # Query the grid file at the profile center location, add 90 degrees to get cross-strike profile
          CPAZ=$(echo "${CPLON} ${CPLAT}" | gmt grdtrack -G$gridfile ${VERBOSE} | awk '{print $3 + 90}')
        done
      fi
   fi

   ANTIAZ=$(echo "${CPAZ}" | bc -l)
   FOREAZ=$(echo "${CPAZ}+180" | bc -l)

   POINT1=($(gmt project -C${CPLON}/${CPLAT} -A${FOREAZ} -Q -G${CPHALFLEN}k -L0/${CPHALFLEN} ${VERBOSE} | tail -n 1 | gawk  '{print $1, $2}'))
   POINT2=($(gmt project -C${CPLON}/${CPLAT} -A${ANTIAZ} -Q -G${CPHALFLEN}k -L0/${CPHALFLEN} ${VERBOSE} | tail -n 1 | gawk  '{print $1, $2}'))

   echo "P C_${cprofnum} black 0 N ${POINT1[0]} ${POINT1[1]} ${POINT2[0]} ${POINT2[1]}" >> ${F_PROFILES}cprof_profs.txt
   cprofnum=$(echo "${cprofnum} + 1" | bc)

   info_msg "[-cprof]: Added profile ${CPLON}/${CPLAT}/${CPROFAZ}/${CPHALFLEN}; Updated width/res to ${SPROFWIDTH}/${SPROF_RES}"

  done < ${F_PROFILES}cprof_prep.txt
fi


################################################################################
#####          Manage grid spacing and style                               #####
################################################################################

##### Create the grid of lat/lon points to resolve as plate motion vectors
# Default is a lat/lon spaced grid

##### MAKE FIBONACCI GRID POINTS
if [[ $gridfibonacciflag -eq 1 ]]; then
  FIB_PHI=1.618033988749895
  echo "" | gawk  -v n=$FIB_N  -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '
  @include "tectoplot_functions.awk"
  # function asin(x) { return atan2(x, sqrt(1-x*x)) }
  BEGIN {
    phi=1.618033988749895;
    pi=3.14159265358979;
    phi_inv=1/phi;
    ga = 2 * phi_inv * pi;
  } END {
    for (i=-n; i<=n; i++) {
      longitude = ((ga * i)*180/pi)%360;

      latitude = asin((2 * i)/(2*n+1))*180/pi;
      # LON EDIT TAG - TEST
      if ( (latitude <= maxlat) && (latitude >= minlat)) {
        if (test_lon(minlon, maxlon, longitude)==1) {
          if (longitude < -180) {
            longitude=longitude+360;
          }
          if (longitude > 180) {
            longitude=longitude-360
          }
          print longitude, latitude
        }
      }
      # if (((longitude <= maxlon && longitude >= minlon) || (longitude+360 <= maxlon && longitude+360 >= minlon)) && {
      #   print longitude, latitude
      # }
    }
  }' > gridfile.txt
  gawk < gridfile.txt '{print $2, $1}' > gridswap.txt
fi

##### MAKE LAT/LON REGULAR GRID
if [[ $makelatlongridflag -eq 1 ]]; then
  for i in $(seq $MINLAT $GRIDSTEP $MAXLAT); do
  	for j in $(seq $MINLON $GRIDSTEP $MAXLON); do
  		echo $j $i >> gridfile.txt
  		echo $i $j >> gridswap.txt
  	done
  done
fi

################################################################################
##### Check if the reference point is within the data frame

if [[ $(echo "$REFPTLAT > $MINLAT && $REFPTLAT < $MAXLAT && $REFPTLON < $MAXLON && $REFPTLON > $MINLON" | bc -l) -eq 0 ]]; then
  info_msg "Reference point $REFPTLON $REFPTLAT falls outside the frame. Moving to center of frame."
	REFPTLAT=$(echo "($MINLAT + $MAXLAT) / 2" | bc -l)
	REFPTLON=$(echo "($MINLON + $MAXLON) / 2" | bc -l)
  info_msg "Reference point moved to $REFPTLON $REFPTLAT"
fi


GRIDSP=$(echo "($MAXLON - $MINLON)/6" | bc -l)

info_msg "Initial grid spacing = $GRIDSP"

if [[ $(echo "$GRIDSP > 30" | bc) -eq 1 ]]; then
  GRIDSP=30
elif [[ $(echo "$GRIDSP > 10" | bc) -eq 1 ]]; then
  GRIDSP=10
elif [[ $(echo "$GRIDSP > 5" | bc) -eq 1 ]]; then
	GRIDSP=5
elif [[ $(echo "$GRIDSP > 2" | bc) -eq 1 ]]; then
	GRIDSP=2
elif [[ $(echo "$GRIDSP > 1" | bc) -eq 1 ]]; then
	GRIDSP=1
elif [[ $(echo "$GRIDSP > 0.5" | bc) -eq 1 ]]; then
	GRIDSP=0.5
elif [[ $(echo "$GRIDSP > 0.2" | bc) -eq 1 ]]; then
	GRIDSP=0.2
elif [[ $(echo "$GRIDSP > 0.1" | bc) -eq 1 ]]; then
	GRIDSP=0.1
elif [[ $(echo "$GRIDSP > 0.05" | bc) -eq 1 ]]; then
  GRIDSP=0.05
elif [[ $(echo "$GRIDSP > 0.02" | bc) -eq 1 ]]; then
  GRIDSP=0.02
elif [[ $(echo "$GRIDSP > 0.01" | bc) -eq 1 ]]; then
  GRIDSP=0.01
else
	GRIDSP=0.005
fi

info_msg "updated grid spacing = $GRIDSP"

if [[ $overridegridlinespacing -eq 1 ]]; then
  GRIDSP=$OVERRIDEGRID
  info_msg "Override spacing of map grid is $GRIDSP"
fi

if [[ $GRIDLINESON -eq 1 ]]; then
  GRIDSP_LINE="g${GRIDSP}"
else
  GRIDSP_LINE=""
fi

# DEFINE BSTRING

if [[ $PLOTTITLE == "" ]]; then
  TITLE=""
else
  TITLE="+t\"${PLOTTITLE}\""
fi
if [[ $usecustombflag -eq 0 ]]; then
  bcmds+=("-Bxa${GRIDSP}${GRIDSP_LINE}")
  bcmds+=("-Bya${GRIDSP}${GRIDSP_LINE}")
  bcmds+=("-B${GRIDCALL}${TITLE}")
  BSTRING=("${bcmds[@]}")
fi

# If grid isn't explicitly turned on but is also not turned off, add it to plots
for plot in ${plots[@]}; do
  [[ $plot == "graticule" ]] && gridisonflag=1
done
if [[ $dontplotgridflag -eq 0 && $gridisonflag -eq 0 ]]; then
  plots+=("graticule")
fi

# Add the inset on top of everything else so the grid won't ever cover it
if [[ $addinsetplotflag -eq 1 ]]; then
  plots+=("inset")
fi

MSG=$(echo ">>>>>>>>> Plotting order is ${plots[@]} <<<<<<<<<<<<<")
# echo $MSG
[[ $narrateflag -eq 1 ]] && echo $MSG

legendwords=${plots[@]}
MSG=$(echo ">>>>>>>>> Legend order is ${legendwords[@]} <<<<<<<<<<<<<")
[[ $narrateflag -eq 1 ]] && echo $MSG


################################################################################
#####         Download Sentinel image                                      #####
################################################################################


if [[ $sentineldownloadflag -eq 1 ]]; then
  SENT_RES=4096
  LONDIFF=$(echo "${MAXLON} - ${MINLON}" | bc -l)
  LATDIFF=$(echo "${MAXLAT} - ${MINLAT}" | bc -l)

  if [[ $(echo "${LATDIFF} > ${LONDIFF}" | bc) -eq 1 ]]; then
    # Taller than wide
    SENT_YRES=$SENT_RES
    SENT_XRES=$(echo $SENT_RES ${LATDIFF} ${LONDIFF} | gawk '
      {
        printf("%d", $1*$3/$2)
      }
      ')
  else
    # Wider than tall
    SENT_XRES=$SENT_RES
    SENT_YRES=$(echo $SENT_RES ${LATDIFF} ${LONDIFF} | gawk '
      {
        printf("%d", $1*$2/$3)
      }
      ')
  fi

  SENT_FNAME="sentinel_${MINLON}_${MAXLON}_${MINLAT}_${MAXLAT}_${SENT_XRES}_${SENT_YRES}.tif"

  if ! [[ -d ${SENT_DIR} ]]; then
    mkdir -p ${SENT_DIR}
  fi

  if [[ -e ${SENT_DIR}${SENT_FNAME} ]]; then
    info_msg "Sentinel imagery $SENT_FNAME exists. Not redownloading."
    cp ${SENT_DIR}${SENT_FNAME} sentinel.tif
  else

    curl "https://tiles.maps.eox.at/wms?service=wms&request=getmap&version=1.1.1&layers=${SENTINEL_TYPE}&bbox=${MINLON},${MINLAT},${MAXLON},${MAXLAT}&width=$SENT_XRES&height=$SENT_YRES&srs=epsg:4326" > sentinel.jpg

    # Create world file for JPG
    echo "$LONDIFF / $SENT_XRES" | bc -l > sentinel.jgw
    echo "0" >> sentinel.jgw
    echo "0" >> sentinel.jgw
    echo "- (${LATDIFF}) / $SENT_YRES" | bc -l >> sentinel.jgw
    echo "$MINLON" >> sentinel.jgw
    echo "$MAXLAT" >> sentinel.jgw

    gdal_translate -projwin ${MINLON} ${MAXLAT} ${MAXLON} ${MINLAT} -of GTiff sentinel.jpg sentinel.tif
    cp sentinel.tif ${SENT_DIR}${SENT_FNAME}
  fi

  echo $SENTINEL_SOURCESTRING >> tectoplot.sources
  echo $SENTINEL_SHORT_SOURCESTRING >> tectoplot.shortsources

fi

################################################################################
#####          Manage SLAB2 data                                           #####
################################################################################

if [[ $plotslab2 -eq 1 ]]; then
  numslab2inregion=0
  echo $CENTERLON $CENTERLAT > inpoint.file
  cleanup inpoint.file
  for slabcfile in $(ls -1a ${SLAB2_CLIPDIR}*.csv); do
    # echo "Looking at file $slabcfile"
    gawk < $slabcfile '{
      if ($1 > 180) {
        print $1-360, $2
      } else {
        print $1, $2
      }
    }' > tmpslabfile.dat
    numinregion=$(gmt select tmpslabfile.dat -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} ${VERBOSE} | wc -l)
    if [[ $numinregion -ge 1 ]]; then
      numslab2inregion=$(echo "$numslab2inregion+1" | bc)
      slab2inregion[$numslab2inregion]=$(basename -s .csv $slabcfile)
    else
      numinregion=$(gmt select inpoint.file -Ftmpslabfile.dat ${VERBOSE} | wc -l)
      # echo $numinregion
      if [[ $numinregion -eq 1 ]]; then
        numslab2inregion=$(echo "$numslab2inregion+1" | bc)
        slab2inregion[$numslab2inregion]=$(basename -s .csv $slabcfile)
      fi
    fi
  done
  if [[ $numslab2inregion -eq 0 ]]; then
    info_msg "[-b]: No slabs within AOI"
  else
    for i in $(seq 1 $numslab2inregion); do
      info_msg "[-b]: Found slab2 slab ${slab2inregion[$i]}"
      echo ${slab2inregion[i]} | cut -f 1 -d '_' > ${F_SLAB}"slab_ids.txt"
    done
  fi
fi

################################################################################
#####          Manage topography/bathymetry data                           #####
################################################################################

# Change to use DEM_MAXLON and allow -tclip to set, to avoid downloading too much data
# when we are clipping the DEM anyway.

DEM_MINLON=${MINLON}
DEM_MAXLON=${MAXLON}
DEM_MINLAT=${MINLAT}
DEM_MAXLAT=${MAXLAT}

if [[ $plottopo -eq 1 ]]; then
  info_msg "Making basemap $BATHYMETRY"

  if [[ $besttopoflag -eq 1 ]]; then
    bestname=$BESTDIR"best_${DEM_MINLON}_${DEM_MAXLON}_${DEM_MINLAT}_${DEM_MAXLAT}.nc"
    if [[ -e $bestname ]]; then
      info_msg "Best topography already exists."
      BATHY=$bestname
      bestexistsflag=1
    fi
  fi

  if [[ $BATHYMETRY =~ "GMRT" || $besttopoflag -eq 1 && $bestexistsflag -eq 0 ]]; then   # We manage GMRT tiling ourselves

    minlon360=$(echo $DEM_MINLON | gawk  '{ if ($1<0) {print $1+360} else {print $1} }')
    maxlon360=$(echo $DEM_MAXLON | gawk  '{ if ($1<0) {print $1+360} else {print $1} }')

    minlonfloor=$(echo $minlon360 | cut -f1 -d".")
    maxlonfloor=$(echo $maxlon360 | cut -f1 -d".")

    if [[ $(echo "$DEM_MINLAT < 0" | bc -l) -eq 1 ]]; then
      minlatfloor1=$(echo $DEM_MINLAT | cut -f1 -d".")
      minlatfloor=$(echo "$minlatfloor1 - 1" | bc)
    else
      minlatfloor=$(echo $DEM_MINLAT | cut -f1 -d".")
    fi

    maxlatfloor=$(echo $DEM_MAXLAT | cut -f1 -d".")
    maxlatceil=$(echo "$maxlatfloor + 1" | bc)

    #echo $MINLON $MAXLON "->" $minlonfloor $maxlonfloor
    #echo $MINLAT $MAXLAT "->" $minlatfloor $maxlatfloor

    maxlonceil=$(echo "$maxlonfloor + 1" | bc)

    if [[ $(echo "$minlonfloor > 180" | bc) -eq 1 ]]; then
      minlonfloor=$(echo "$minlonfloor-360" | bc -l)
    fi
    if [[ $(echo "$maxlonfloor > 180" | bc) -eq 1 ]]; then
      maxlonfloor=$(echo "$maxlonfloor-360" | bc -l)
      maxlonceil=$(echo "$maxlonfloor + 1" | bc)
    fi

    # How many tiles is this?
    GMRTTILENUM=$(echo "($maxlonfloor - $minlonfloor + 1) * ($maxlatfloor - $minlatfloor + 1)" | bc)
    tilecount=1
    for i in $(seq $minlonfloor $maxlonfloor); do
      for j in $(seq $minlatfloor $maxlatfloor); do
        iplus=$(echo "$i + 1" | bc)
        jplus=$(echo "$j + 1" | bc)
        if [[ ! -e $GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.nc" ]]; then

          info_msg "Downloading GMRT_${i}_${iplus}_${j}_${jplus}.nc ($tilecount out of $GMRTTILENUM)"
          curl "https://www.gmrt.org:443/services/GridServer?minlongitude=${i}&maxlongitude=${iplus}&minlatitude=${j}&maxlatitude=${jplus}&format=netcdf&resolution=max&layer=topo" > $GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.nc"
          # We have to set the coordinate system information ourselves
          # This command was for when we downloaded GeoTiff tiles and is no longer needed (we get NC now)
          # gdal_edit.py -a_srs "+proj=longlat +datum=WGS84 +no_defs" $GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.tif"
          #
          # Test whether the file was correctly downloaded
          fsize=$(wc -c < $GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.nc")
          if [[ $(echo "$fsize < 12000000" | bc) -eq 1 ]]; then
            info_msg "File GMRT_${i}_${iplus}_${j}_${jplus}.nc was not properly downloaded: too small ($fsize bytes). Removing."
            rm -f $GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.nc"
          fi

        else
          info_msg "File GMRT_${i}_${iplus}_${j}_${jplus}.nc exists ($tilecount out of $GMRTTILENUM)"
        fi
        filelist+=($GMRTDIR"GMRT_${i}_${iplus}_${j}_${jplus}.nc")
        tilecount=$(echo "$tilecount + 1" | bc)
      done
    done

    # We apparently need to fill NaNs when making the GMRT mosaic grid with gdal_merge.py...
    if [[ ! -e $GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc" ]]; then
      info_msg "Merging tiles to form GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc: " ${filelist[@]}
      echo gdal_merge.py -o tmp.nc -of "NetCDF" ${filelist[@]} -q > ./merge.sh
      echo gdal_fillnodata.py  -of NetCDF tmp.nc $GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc" >> ./merge.sh
      echo rm -f ./tmp.nc >> ./merge.sh
      . ./merge.sh
      # gdal_merge.py -o $GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc" ${filelist[@]}

    else
      info_msg "GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc exists"
    fi
    name=$GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc"

    if [[ $BATHYMETRY =~ "GMRT" ]]; then
      BATHY=$name
    elif [[ $besttopoflag -eq 1 ]]; then
      NEGBATHYGRID=$name
    fi
  fi

  if [[ ! $BATHYMETRY =~ "GMRT" && $bestexistsflag -eq 0 ]]; then

    if [[ $plotcustomtopo -eq 1 ]]; then
      name="${F_TOPO}dem.nc"
      info_msg "Custom topo: NOT filling NaNs"
      gmt grdcut ${GRIDFILE} -G${name} -R${DEM_MINLON}/${DEM_MAXLON}/${DEM_MINLAT}/${DEM_MAXLAT} $VERBOSE
      BATHY=$name
    else
      info_msg "Using grid $GRIDFILE"

      # Output is a NetCDF format grid
    	name=$GRIDDIR"${BATHYMETRY}_${DEM_MINLON}_${DEM_MAXLON}_${DEM_MINLAT}_${DEM_MAXLAT}.nc"

    	if [[ -e $name ]]; then
    		info_msg "DEM file $name already exists"
    	else
        case $BATHYMETRY in
          SRTM30|GEBCO20|GEBCO1|01d|30m|20m|15m|10m|06m|05m|04m|03m|02m|01m|15s|03s|01s)
          gmt grdcut ${GRIDFILE} -G${name} -R${DEM_MINLON}/${DEM_MAXLON}/${DEM_MINLAT}/${DEM_MAXLAT} $VERBOSE
          demiscutflag=1
          ;;
        esac
    	fi
    	BATHY=$name
    fi
  fi
fi

# At this point, if best topo flag is set, combine POSBATHYGRID and BATHY into one grid and make it the new BATHY grid

if [[ $besttopoflag -eq 1 && $bestexistsflag -eq 0 ]]; then
  info_msg "Combining GMRT ($NEGBATHYGRID) and 01s ($BATHY) grids to form best topo grid"
  # grdsample might return NaN?
  # gmt grdsample -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -I2s $NEGBATHYGRID -Gneg.nc -fg ${VERBOSE}
  gdalwarp -q -dstnodata NaN -te $MINLON $MINLAT $MAXLON $MAXLAT -tr .00055555555 .00055555555 -of NetCDF $NEGBATHYGRID neggdal.nc
  gdalwarp -q -dstnodata NaN -te $MINLON $MINLAT $MAXLON $MAXLAT -tr .00055555555 .00055555555 -of NetCDF $BATHY posgdal.nc
  gdal_calc.py --overwrite --type=Float32 --format=NetCDF --quiet -A posgdal.nc -B neggdal.nc --calc="((A>=0)*A + (B<=0)*B)" --outfile=merged.nc
  # gmt grdsample -Rneg.nc $BATHY -Gpos.nc -fg ${VERBOSE}
  # gmt grdclip -Sb0/0 pos.nc -Gposclip.nc ${VERBOSE}
  # gmt grdclip -Si0/10000000/0 neg.nc -Gnegclip.nc ${VERBOSE}
  # gmt grdmath posclip.nc negclip.nc ADD = merged.nc ${VERBOSE}
  mv merged.nc $bestname
  BATHY=$bestname
fi

if [[ $tflatflag -eq 1 ]]; then
  clipdemflag=1
fi

if [[ $clipdemflag -eq 1 && -e $BATHY ]]; then
  info_msg "[-clipdem]: saving DEM as ${F_TOPO}dem.nc"
  if [[ $demiscutflag -eq 1 ]]; then
    if [[ $tflatflag -eq 1 ]]; then
      flatten_sea ${BATHY} ${F_TOPO}dem.nc
    else
      cp $BATHY ${F_TOPO}dem.nc
    fi
  else
    if [[ $tflatflag -eq 1 ]]; then
      gmt grdcut ${BATHY} -G${F_TOPO}dem_preflat.nc -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} $VERBOSE
      flatten_sea ${F_TOPO}dem_preflat.nc ${F_TOPO}dem.nc
      cleanup ${F_TOPO}dem_preflat.nc
    else
      # echo gmt grdcut ${BATHY} -G${F_TOPO}dem.nc -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} $VERBOSE
      gmt grdcut ${BATHY} -G${F_TOPO}dem.nc -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} $VERBOSE
    fi
  fi
fi

# If the grid has longitudes greater than 180 or less than -180, shift it into the -180:180 range.
# This happens for some GMT EarthRelief DEMs for rotated globes

# This might still be necessary for some plots but messes up plots crossing the dateline!!!
# Leaving here for now in case the issue arises again

# if [[ -e ${F_TOPO}dem.nc ]]; then
#   GRDINFO=($(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE}))
#   GRDMINLON=${GRDINFO[1]}
#   GRDMAXLON=${GRDINFO[2]}
#
#   if [[ $(echo "(${GRDINFO[1]} < -180) || (${GRDINFO[2]} > 180)" | bc ) -eq 1 ]]; then
#     info_msg "Topo raster has coordinates outside of [-180:180] range. Rotating."
#     XRES=${GRDINFO[7]}
#     YRES=${GRDINFO[8]}
#     gdalwarp -s_srs "+proj=longlat +ellps=WGS84" -t_srs WGS84 ${F_TOPO}dem.nc dem180.nc -if "netCDF" -of "netCDF" -tr $XRES $YRES --config CENTER_LONG 0 -q
#     mv dem180.nc ${F_TOPO}dem.nc
#   fi
# fi

################################################################################
#####          Grid contours                                               #####
################################################################################

# Contour interval for grid if not specified using -cn
if [[ $gridcontourcalcflag -eq 1 ]]; then
  zrange=$(grid_zrange $CONTOURGRID -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
  MINCONTOUR=$(echo $zrange | gawk  '{print $1}')
  MAXCONTOUR=$(echo $zrange | gawk  '{print $2}')
  CONTOURINTGRID=$(echo "($MAXCONTOUR - $MINCONTOUR) / $CONTOURNUMDEF" | bc -l)
  if [[ $(echo "$CONTOURINTGRID > 1" | bc -l) -eq 1 ]]; then
    CONTOURINTGRID=$(echo "$CONTOURINTGRID / 1" | bc)
  fi
fi

# Contour interval for grid if not specified using -cn
if [[ $topocontourcalcflag -eq 1 ]]; then
  zrange=$(grid_zrange $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
  MINCONTOUR=$(echo $zrange | gawk  '{print $1}')
  MAXCONTOUR=$(echo $zrange | gawk  '{print $2}')
  TOPOCONTOURINT=$(echo "($MAXCONTOUR - $MINCONTOUR) / $TOPOCONTOURNUMDEF" | bc -l)
  if [[ $(echo "$TOPOCONTOURINT > 1" | bc -l) -eq 1 ]]; then
    TOPOCONTOURINT=$(echo "$TOPOCONTOURINT / 1" | bc)
  fi
fi

################################################################################
#####           Manage volcanoes                                           #####
################################################################################

if [[ $volcanoesflag -eq 1 ]]; then
  echo gmt select $SMITHVOLC -: -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE
  gmt select $SMITHVOLC -: -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE >> ${F_VOLC}volctmp.dat
  gmt select $WHELLEYVOLC  -: -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE  >> ${F_VOLC}volctmp.dat
  gmt select $JAPANVOLC -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE  >> ${F_VOLC}volctmp.dat
  gawk < ${F_VOLC}volctmp.dat '{
    printf "%s %s ", $2, $1
    for (i=3; i<=NF; i++) {
      printf "%s ", $(i)
    }
    printf("\n")
  }' > ${F_VOLC}volcanoes.dat
  cleanup ${F_VOLC}volctmp.dat
fi

if [[ $resgravflag -eq 1 ]]; then
  info_msg "Making residual gravity along ${GRAVXYFILE}"
  mkdir -p ./resgrav
  cd ./resgrav
  # smart_swath.sh profile_width[km] along_profile_dist_ave[km] cross_profile_dist_ave[km] xyfile gridfile resampleres[deg]
  smart_swath_update.sh ${GRAVWIDTHKM} ${GRAVALONGAVKM} ${GRAVACROSSAVKM} ${GRAVXYFILE} ${GRAVDATA} 0.1
  cd ..
fi

################################################################################
#####           Manage earthquake hypocenters                              #####
################################################################################

if [[ $plotseis -eq 1 ]]; then

  ##############################################################################
  # Initial select of seismicity based on geographic coords, mag, and depth
  # Takes into account crossing of antimeridian (e.g lon in range [120 220])

  # Data are selected from either ANSS or ISC tiles generated be -scrapedata

  # This is for the ANSS catalog
  if [[ $EQ_CATALOG_TYPE =~ "ANSS" ]]; then
    F_SEIS_FULLPATH=$(abs_path ${F_SEIS})
    info_msg "[-z]: $EXTRACT_ANSS_TILES $ANSSTILEDIR $MINLON $MAXLON $MINLAT $MAXLAT $STARTTIME $ENDTIME $EQ_MINMAG $EQ_MAXMAG $EQCUTMINDEPTH $EQCUTMAXDEPTH ${F_SEIS_FULLPATH}anss_extract_tiles.cat"
    $EXTRACT_ANSS_TILES $ANSSTILEDIR $MINLON $MAXLON $MINLAT $MAXLAT $STARTTIME $ENDTIME $EQ_MINMAG $EQ_MAXMAG $EQCUTMINDEPTH $EQCUTMAXDEPTH ${F_SEIS_FULLPATH}anss_extract_tiles.cat

    # ANSS CSV format is:
    # 1    2        3         4     5   6       7   8   9    10  11  12 13      14    15   16              17         18       19     20     21             22
    # time,latitude,longitude,depth,mag,magType,nst,gap,dmin,rms,net,id,updated,place,type,horizontalError,depthError,magError,magNst,status,locationSource,magSource

    # Tectoplot catalog is Lon,Lat,Depth,Mag,Timecode,ID,epoch (or -1)
    awk -F, < ${F_SEIS}anss_extract_tiles.cat '{
      type=tolower(substr($6,1,2))
      if (tolower(type) == "mb" && $5 >= 3.5 && $5 <=7.0) {
        oldval=$5
        $5 = 1.159 * $5 - 0.659
        print $12, type "=", oldval, "to Mw=", $5 >> "./mag_conversions.dat"
      }
      else if (tolower(type) == "ms") {
        oldval=$5
        if (tolower(substr($6,1,3))=="msz") {
          if ($5 >= 3.5 && $5 <= 6.47) {
              $5 = 0.707 * $5 + 19.33
              print $12, "Msz=", oldval, "to Mw=", $5 >> "./mag_conversions.dat"
          }
          if ($5 > 6.47 && $5 <= 8.0) { # Msz > Mw Weatherill, 2016, NEIC
            $5 = 0.950 * $5 + 0.359
            print $12, "Msz=", oldval, "to Mw=", $5 >> "./mag_conversions.dat"
          }
          print $1, tolower(substr($6,1,3)) "=" oldval, "to Mw=", $5 >> "./mag_conversions.dat"
        } else {  # Ms > Mw Weatherill, 2016, NEIC
          if ($5 >= 3.5 && $5 <= 6.47) {
              $5 = 0.723 * $5 + 1.798
              print $12, type "=", oldval, "to Mw=", $5 >> "./mag_conversions.dat"
          }
          if ($5 > 6.47 && $5 <= 8.0) { # Weatherill, 2016, NEIC
            $5 = 1.005 * $5 - 0.026
            print $12, type "=", oldval, "to Mw=", $5 >> "./mag_conversions.dat"
          }
        }
      }
      else if (tolower(type) == "ml") { # Mereu, 2019
        oldval=$5
        $5 = 0.62 * $5 + 1.09
        print $12, type "=" oldval, "to Mw=", $5 >> "./mag_conversions.dat"
      }
      print $3, $2, $4, $5, substr($1,1,19), $12, -1
    }' > ${F_SEIS}eqs.txt
  elif [[ $EQ_CATALOG_TYPE =~ "ISC" ]]; then
    F_SEIS_FULLPATH=$(abs_path ${F_SEIS})
    info_msg "[-z]: $EXTRACT_ISC_TILES $ISCTILEDIR $MINLON $MAXLON $MINLAT $MAXLAT $STARTTIME $ENDTIME $EQ_MINMAG $EQ_MAXMAG $EQCUTMINDEPTH $EQCUTMAXDEPTH ${F_SEIS_FULLPATH}isc_extract_tiles.cat"
    $EXTRACT_ISC_TILES $ISCTILEDIR $MINLON $MAXLON $MINLAT $MAXLAT $STARTTIME $ENDTIME $EQ_MINMAG $EQ_MAXMAG $EQCUTMINDEPTH $EQCUTMAXDEPTH ${F_SEIS_FULLPATH}isc_extract_tiles.cat

    # 1       2         3           4          5        6         7     8      9         10     11   12+
    # EVENTID,AUTHOR   ,DATE      ,TIME       ,LAT     ,LON      ,DEPTH,DEPFIX,AUTHOR   ,TYPE  ,MAG  [, extra...]
    #  752622,ISC      ,1974-01-14,03:59:31.48, 28.0911, 131.4943, 10.0,TRUE  ,ISC      ,mb    , 4.3

    # Tectoplot catalog is Lon,Lat,Depth,Mag,Timecode,ID,epoch (or -1)

    awk -F, < ${F_SEIS}isc_extract_tiles.cat '{
      type=tolower(substr($10,1,2))
      if (tolower(type) == "mb" && $11 >= 3.5 && $11 <=7.0) {
        oldval=$11
        $11 = 1.048 * $11 - 0.142
        print $1, type "=" oldval, "to Mw=", $11 >> "./mag_conversions.dat"
      }
      else if (tolower(type) == "ms") {  # Weatherill, 2016, ISC
        oldval=$11
        if ($11 >= 3.5 && $11 <= 6.0) {
            $11 = 0.616 * $11 + 2.369
            print $1, type "=" oldval, "to Mw=", $11 >> "./mag_conversions.dat"

        }
        if ($11 > 6.0 && $11 <= 8.0) { # Weatherill, 2016, ISC
          $11 = 0.994 * $11 + 0.1
        }
        print $1, type "=" oldval, "to Mw=", $11 >> "./mag_conversions.dat"
      }
      else if (tolower(type) == "ml") { # Mereu, 2019
        oldval=$11
        $11 = 0.62 * $11 + 1.09
        print $1, type "=" oldval, "to Mw=", $11 >> "./mag_conversions.dat"
      }
      print $6, $5, $7, $11, sprintf("%sT%s", $3, substr($4, 1, 8)), $1, -1
    }' > ${F_SEIS}eqs.txt
  elif [[ $EQ_CATALOG_TYPE =~ "NONE" ]]; then
    touch ${F_SEIS}eqs.txt
  fi

  [[ -e ./mag_conversions.dat ]] && mv ./mag_conversions.dat ${F_SEIS}

  ##############################################################################
  # Add additional user-specified seismicity files. This needs to be expanded
  # to import from various common formats. Currently needs tectoplot format data
  # and only ingests lines with exactly 7 fields.

  # Since catalog select above includes time, should filter by epoch here as well

  if [[ $suppseisflag -eq 1 ]]; then
    info_msg "Concatenating supplementary earthquake file $SUPSEISFILE"
    if [[ $eqcatalogreplaceflag -eq 1 ]]; then
      rm ${F_SEIS}eqs.txt
    fi
    info_msg "First selection: $(wc -l < ${F_SEIS}eqs.txt)"
    # Do the selection using the mag and depth criteria to be consistent with catalogs.
    # EQs outside the map AOI will be removed subsequently.
    for i in $(seq 1 $seisfilenumber); do
      gawk < ${SEISADDFILE[$i]} -v mindepth=${EQCUTMINDEPTH} -v maxdepth=${EQCUTMAXDEPTH} -v minmag=${EQ_MINMAG} -v maxmag=${EQ_MAXMAG} '
        (NF==7) { print }                                 # Full record exists
        ((NF < 7) && (NF >=4)) {
          if ($5=="") { $5=0 }                            # Patch entries to ensure same column number
          if ($6=="") { $6=0 }
          if ($7=="") { $7="none" }
          if ($3 >= mindepth && $3 <= maxdepth && $4 <= maxmag && $4 >= minmag)
            print $1, $2, $3, $4, $5, $6, $7
          }
      ' >> ${F_SEIS}eqs.txt
    done
  fi

  # Secondary select of combined seismicity using the actual AOI polygon which
  # may differ from the lat/lon box.

  # In most cases this won't be necessary so maybe we should move into if-fi above?
  info_msg "Selecting seismicity within AOI polygon"
  mv ${F_SEIS}eqs.txt ${F_SEIS}eqs_aoipreselect.txt

  gmt select ${F_SEIS}eqs_aoipreselect.txt -R -J -Vn | tr '\t' ' ' > ${F_SEIS}eqs.txt

  # Alternative method using the bounding box which really doesn't work with global extents
  # gmt select ${F_SEIS}eqs_aoipreselect.txt -F${F_MAPELEMENTS}bounds.txt -Vn | tr '\t' ' ' > ${F_SEIS}eqs.txt
  cleanup ${F_SEIS}eqs_aoipreselect.txt
  info_msg "AOI selection: $(wc -l < ${F_SEIS}eqs.txt)"

  ##############################################################################
  # Select seismicity that falls within a specified polygon.

  if [[ $polygonselectflag -eq 1 ]]; then
    info_msg "Selecting seismicity within AOI polygon ${POLYGONAOI}"
    mv ${F_SEIS}eqs.txt ${F_SEIS}eqs_preselect.txt
    gmt select ${F_SEIS}eqs_preselect.txt -F${POLYGONAOI} -Vn | tr '\t' ' ' > ${F_SEIS}eqs.txt
    cleanup ${F_SEIS}eqs_preselect.txt
  fi
  info_msg "Polygon selection: $(wc -l < ${F_SEIS}eqs.txt)"


  ##############################################################################
  # Sort seismicity file so that certain events plot on top of / below others

  if [[ $dozsortflag -eq 1 ]]; then
    info_msg "Sorting earthquakes by $ZSORTTYPE"
    case $ZSORTTYPE in
      "depth")
        SORTFIELD=3
      ;;
      "time")
        SORTFIELD=7
      ;;
      "mag")
        SORTFIELD=4
      ;;
      *)
        info_msg "[-zsort]: Sort field $ZSORTTYPE not recognized. Using depth."
        SORTFIELD=3
      ;;
    esac
    [[ $ZSORTDIR =~ "down" ]] && sort -n -k $SORTFIELD,$SORTFIELD ${F_SEIS}eqs.txt > ${F_SEIS}eqsort.txt
    [[ $ZSORTDIR =~ "up" ]] && sort -n -r -k $SORTFIELD,$SORTFIELD ${F_SEIS}eqs.txt > ${F_SEIS}eqsort.txt
    [[ -e ${F_SEIS}eqsort.txt ]] && cp ${F_SEIS}eqsort.txt ${F_SEIS}eqs.txt
  fi
fi # if [[ $plotseis -eq 1 ]]


################################################################################
#####           Manage focal mechanisms and hypocenters                    #####
################################################################################

# Fixed scaling of the kinematic vectors from size of focal mechanisms

# Length of slip vector azimuth
SYMSIZE1=$(echo "${KINSCALE} * 3.5" | bc -l)
# Length of dip line
SYMSIZE2=$(echo "${KINSCALE} * 1" | bc -l)
# Length of strike line
SYMSIZE3=$(echo "${KINSCALE} * 3.5" | bc -l)

##### FOCAL MECHANISMS
if [[ $calccmtflag -eq 1 ]]; then

  # If we are plotting from a global database
  if [[ $plotcmtfromglobal -eq 1 ]]; then
    echo "CMT/$CMTTYPE" >> tectoplot.shortsources
    # Use an existing database file in tectoplot format
    [[ $CMTFILE == "DefaultNOCMT" ]]    && CMTFILE=$FOCALCATALOG
    [[ $CMTFORMAT =~ "GlobalCMT" ]]     && CMTLETTER="c"
    [[ $CMTFORMAT =~ "MomentTensor" ]]  && CMTLETTER="m"
    [[ $CMTFORMAT =~ "TNP" ]] && CMTLETTER="y"

    # Do the initial AOI scrape

    gawk < $CMTFILE -v orig=$ORIGINFLAG -v cent=$CENTROIDFLAG -v mindepth="${EQCUTMINDEPTH}" -v maxdepth="${EQCUTMAXDEPTH}" -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '
    @include "tectoplot_functions.awk"
    {
      if (cent==1) {
        lon=$5
        lat=$6
        depth=$7
      } else {
        lon=$8
        lat=$9
        depth=$10
      }
      if ((depth >= mindepth && depth <= maxdepth) && (lat >= minlat && lat <= maxlat)) {
        if (test_lon(minlon, maxlon, lon) == 1) {
          print
        }
      }
    }' > ${F_CMT}cmt_global_aoi.dat
    CMTFILE=$(abs_path ${F_CMT}cmt_global_aoi.dat)
  fi


# (minlon < -180 && (minlon <= lon-360 || lon-360 <= maxlon)))
# [-190 -170]        [-190 <= -181   ]
  # if (cent==1) {
  #   lon=$5
  #   lat=$6
  #   depth=$7
  # } else {
  #   lon=$8
  #   lat=$9
  #   depth=$10
  # }
  # if ((depth >= mindepth && depth <= maxdepth) && (lat >= minlat && lat <= maxlat)) {
  #   if ((maxlon <= 180 && (minlon <= $3 && $3 <= maxlon)) || (maxlon > 180 && (minlon <= $3+360 || $3+360 <= maxlon)) || (minlon < -180 && (minlon <= $3-360 || $3-360 <= maxlon))) {
 #
  #     print
  #   }
  # }

  # Perform an AOI scrape of any custom CMT databases

  touch ${F_CMT}cmt_local_aoi.dat

  if [[ $addcustomcmtsflag -eq 1 ]]; then
    echo "CMT/$CMTTYPE" >> tectoplot.shortsources
    for i in $(seq 1 $cmtfilenumber); do
      info_msg "Slurping custom CMTs from ${CMTADDFILE[$i]} and appending to CMT file"
      info_msg "${CMTSLURP} ${CMTADDFILE[$i]} ${CMTFORMATCODE[$i]} ${CMTIDCODE[$i]}"
      source ${CMTSLURP} ${CMTADDFILE[$i]} ${CMTFORMATCODE[$i]} ${CMTIDCODE[$i]} | gawk -v orig=$ORIGINFLAG -v cent=$CENTROIDFLAG -v mindepth="${EQCUTMINDEPTH}" -v maxdepth="${EQCUTMAXDEPTH}" -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '
      {
        if (cent==1) {
          lon=$5
          lat=$6
          depth=$7
        } else {
          lon=$8
          lat=$9
          depth=$10
        }
        if ((depth >= mindepth && depth <= maxdepth) && (lat >= minlat && lat <= maxlat)) {
          if (test_lon(minlon, maxlon, lon) == 1) {
            print
          }
        }
      }' >> ${F_CMT}cmt_local_aoi.dat
      highlightCMTs+=("${CMTIDCODE[$i]}")
    done

    # Concatenate the data and apply the eqselect selection
    if [[ $cmtreplaceflag -eq 0 ]]; then
      cat ${F_CMT}cmt_global_aoi.dat ${F_CMT}cmt_local_aoi.dat > ${F_CMT}cmt_combined_aoi.dat
      CMTFILE=$(abs_path ${F_CMT}cmt_combined_aoi.dat)
    fi
  fi

  # We don't usually keep the individually selected data
  cleanup ${F_CMT}cmt_global_aoi.dat ${F_CMT}cmt_local_aoi.dat

  gawk < $CMTFILE -v dothrust=$cmtthrustflag -v donormal=$cmtnormalflag -v doss=$cmtssflag '{
    if (substr($1,2,1) == "T" && dothrust == 1) {
      print
    } else if (substr($1,2,1) == "N" && donormal == 1) {
      print
    } else if (substr($1,2,1) == "S" && doss == 1) {
      print
    } else {
      # Catch all case
      print
    }
  }' > ${F_CMT}cmt_typefilter.dat
  CMTFILE=$(abs_path ${F_CMT}cmt_typefilter.dat)

  if [[ $eqlistselectflag -eq 1 ]]; then
    info_msg "Selecting focal mechanisms from eqlist"
    for i in ${!eqlistarray[@]}; do
      grep -- "${eqlistarray[$i]}" ${CMTFILE} >> ${F_CMT}cmt_eqlistsel.dat
    done
    CMTFILE=$(abs_path ${F_CMT}cmt_eqlistsel.dat)
  fi


  # if [[ $globalextentflag -ne 1  ]]; then
  #   info_msg "Selecting focal mechanisms within non-global map AOI using ${CMTTYPE} location"
  #
  #   case $CMTTYPE in
  #     CENTROID)  # Lon=Column 5, Lat=Column 6
  #       gawk < $CMTFILE '{
  #         for (i=5; i<=NF; i++) {
  #           printf "%s ", $(i) }
  #           print $1, $2, $3, $4;
  #         }' | gmt select -F${F_MAPELEMENTS}bounds.txt ${VERBOSE} | tr '\t' ' ' | gawk  '{
  #         printf "%s %s %s %s", $(NF-3), $(NF-2), $(NF-1), $(NF);
  #         for (i=1; i<=NF-4; i++) {
  #           printf " %s", $(i)
  #         }
  #         printf "\n";
  #       }' > ${F_CMT}cmt_aoipolygonselect.dat
  #       ;;
  #     ORIGIN)  # Lon=Column 8, Lat=Column 9
  #       gawk < $CMTFILE '{
  #         for (i=8; i<=NF; i++) {
  #           printf "%s ", $(i) }
  #           print $1, $2, $3, $4, $5, $6, $7;
  #         }' > ${F_CMT}tmp.dat
  #         gmt select ${F_CMT}tmp.dat -F${F_MAPELEMENTS}bounds.txt ${VERBOSE} | tr '\t' ' ' | gawk  '{
  #         printf "%s %s %s %s %s %s %s", $(NF-6), $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $(NF);
  #         for (i=1; i<=NF-6; i++) {
  #           printf " %s", $(i)
  #         } printf "\n";
  #       }' > ${F_CMT}cmt_aoipolygonselect.dat
  #       ;;
  #   esac
  #   CMTFILE=$(abs_path ${F_CMT}cmt_aoipolygonselect.dat)
  # fi

  # This abomination of a command is because I don't know how to use gmt select
  # to print the full record based only on the lon/lat in specific columns.

  if [[ $polygonselectflag -eq 1 ]]; then
    info_msg "Selecting focal mechanisms within user polygon ${POLYGONAOI} using ${CMTTYPE} location"

    case $CMTTYPE in
      CENTROID)  # Lon=Column 5, Lat=Column 6
        gawk < $CMTFILE '{
          for (i=5; i<=NF; i++) {
            printf "%s ", $(i) }
            print $1, $2, $3, $4;
          }' | gmt select -F${POLYGONAOI} ${VERBOSE} | tr '\t' ' ' | gawk  '{
          printf "%s %s %s %s", $(NF-3), $(NF-2), $(NF-1), $(NF);
          for (i=1; i<=NF-4; i++) {
            printf " %s", $(i)
          }
          printf "\n";
        }' > ${F_CMT}cmt_polygonselect.dat
        ;;
      ORIGIN)  # Lon=Column 8, Lat=Column 9
        gawk < $CMTFILE '{
          for (i=8; i<=NF; i++) {
            printf "%s ", $(i) }
            print $1, $2, $3, $4, $5, $6, $7;
          }' > ${F_CMT}tmp.dat
          gmt select ${F_CMT}tmp.dat -F${POLYGONAOI} ${VERBOSE} | tr '\t' ' ' | gawk  '{
          printf "%s %s %s %s %s %s %s", $(NF-6), $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $(NF);
          for (i=1; i<=NF-6; i++) {
            printf " %s", $(i)
          } printf "\n";
        }' > ${F_CMT}cmt_polygonselect.dat
        ;;
    esac
    CMTFILE=$(abs_path ${F_CMT}cmt_polygonselect.dat)
  fi

  info_msg "Selecting focal mechanisms and kinematic mechanisms based on magnitude constraints"

  gawk < $CMTFILE -v kminmag="${KIN_MINMAG}" -v kmaxmag="${KIN_MAXMAG}" -v minmag="${CMT_MINMAG}" -v maxmag="${CMT_MAXMAG}" '{
    mw=$13
    if (mw < maxmag && mw > minmag) {
      print > "cmt_orig.dat"
    }
    if (mw < kmaxmag && mw > kminmag) {
      print > "kin_orig.dat"
    }
  }'
  [[ -e cmt_orig.dat ]] && mv cmt_orig.dat ${F_CMT}
  [[ -e kin_orig.dat ]] && mv kin_orig.dat ${F_KIN}
  CMTFILE=$(abs_path ${F_CMT}cmt_orig.dat)

  # Select CMT data between start and end times
  if [[ $timeselectflag -eq 1 ]]; then
    STARTSECS=$(echo "${STARTTIME}" | gawk  '{
      split($1, a, "-")
      year=a[1]
      month=a[2]
      split(a[3],b,"T")
      day=b[1]
      split(b[2],c,":")
      hour=c[1]
      minute=c[2]
      second=c[3]
      the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
      epoch=mktime(the_time);
      print epoch;
    }')

    ENDSECS=$(echo "${ENDTIME}" | gawk  '{
      split($1, a, "-")
      year=a[1]
      month=a[2]
      split(a[3],b,"T")
      day=b[1]
      split(b[2],c,":")
      hour=c[1]
      minute=c[2]
      second=c[3]
      the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
      epoch=mktime(the_time);
      print epoch;
    }')

    gawk < $CMTFILE -v ss=$STARTSECS -v es=$ENDSECS '{
      if (($4 >= ss) && ($4 <= es)) {
        print
      }
    }' > ${F_CMT}cmt_timesel.dat
    CMTFILE=$(abs_path ${F_CMT}cmt_timesel.dat)
    echo "Seismic/CMT [${STARTTIME} to ${ENDTIME}]" >> tectoplot.shortsources
  fi

  ##### EQUIVALENT EARTHQUAKES

  # If the REMOVE_EQUIVS variable is set, compare eqs.txt with cmt.dat to remove
  # earthquakes that have a focal mechanism equivalent, using a spatiotemporal
  # proximity metric

  # If CMTFILE exists but we aren't plotting CMT's this will really cull a lot of EQs! Careful!
  # CMTFILE should arguably be AOI selected by now in all cases (can we check?)

  # NOTE: The method of pasting files to compare across lines is computationally
  # dumb and should ideally be replaced by some kind of line-by-line comparison.

  # This section is very sensitive to file formats and any change will break it.

  if [[ $REMOVE_EQUIVS -eq 1 && -e $CMTFILE && -e ${F_SEIS}eqs.txt ]]; then

    info_msg "Removing earthquake origins that have equivalent CMT..."

    before_e=$(wc -l < ${F_SEIS}eqs.txt)
    # epoch is field 4 for CMTS
    gawk < $CMTFILE '{
      if ($10 != "none") {                       # Use origin location
        print "O", $8, $9, $4, $10, $13, $3, $2
      } else if ($11 != "none") {                # Use centroid location for events without origin
        print "C", $5, $6, $4, $7, $13, $3, $2
      }
    }' > ${F_SEIS}eq_comp.dat

    # Currently we only use the first 6 columns of the EQ data. Commented code
    # indicates how to add more/pad if necessary
    # A LON LAT DEPTH MAG TIMECODE ID EPOCH

    # We need to first add a buffer of fake EQs to avoid problems with grep -A -B
    gawk < ${F_SEIS}eqs.txt '{
      print "EQ", $1, $2, $7, $3, $4, $5, $6
    }' >> ${F_SEIS}eq_comp.dat

    sort ${F_SEIS}eq_comp.dat -n -k 4,4 > ${F_SEIS}eq_comp_sort.dat

    # If we don't do a cycle shift here, the earliest event can fall away and be lost!
    sed '1d' ${F_SEIS}eq_comp_sort.dat > ${F_SEIS}eq_comp_sort_m1.dat
    head -n 1 ${F_SEIS}eq_comp_sort.dat >> ${F_SEIS}eq_comp_sort_m1.dat  # Add removed EQ to end of file
    sed '1d' ${F_SEIS}eq_comp_sort_m1.dat > ${F_SEIS}eq_comp_sort_m2.dat
    head -n 1 ${F_SEIS}eq_comp_sort_m1.dat >> ${F_SEIS}eq_comp_sort_m2.dat # Add removed EQ to end of file

    paste ${F_SEIS}eq_comp_sort.dat ${F_SEIS}eq_comp_sort_m1.dat ${F_SEIS}eq_comp_sort_m2.dat > ${F_SEIS}3comp.txt

    # We want to remove from A any A event that is "close" to a C event
    # This currently only compares the events closest in time to a CMT event, so
    # it will not remove equivalent seismicity or equivalents separated by other
    # events in the catalog.

    # We  output a fused ID : IDA/IDB to allow grep to find events that have
    # been culled.

    # IDs are at field numbers 8,16,24

    gawk < ${F_SEIS}3comp.txt -v secondlimit=5 -v deglimit=2 -v maglimit=0.3 '
    @include "tectoplot_functions.awk"
    {
      if ($9 == "EQ") { # Only examine non-CMT events
        if ($14 > 7.5) {
          deglimit=3
          secondlimit=120
        }
        printme = 1
          if (($1 == "C" || $1 == "O") && abs($12-$4) < secondlimit && abs($10-$2) < deglimit && abs($11-$3) < deglimit && abs($14-$6) < maglimit) {
              printme = 0
              mixedid = sprintf("'s/%s/%s+%s/'",$8,$8,$16)
          } else if (($17 == "C" || $17 == "O") && abs($20-$12) < secondlimit && abs($18-$10) < 2 && abs($19-$11) < 2 && abs($22-$14) < maglimit) {
              printme = 0
              mixedid = sprintf("'s/%s/%s+%s/'",$24,$24,$16)
          }
        if (printme == 1) {
            print $10, $11, $13, $14, $15, $16, $12
        } else {
            print $10, $11, $13, $14, $15, $16, $12 > "eq_culled.txt"
            print mixedid > "eq_idcull.sed"
            mixedid=""
        }
      }
    }' > ${F_SEIS}eqs.txt
    after_e=$(wc -l < ${F_SEIS}eqs.txt)
    [[ -e ./eq_culled.txt ]] && mv ./eq_culled.txt ${F_SEIS}

    info_msg "Before equivalent EQ culling: $before_e events ; after culling: $after_e events."

    info_msg "Replacing IDs in CMT catalog with combined CMT/Seis IDs"
    [[ -e ./eq_idcull.sed ]] && sed -f eq_idcull.sed -i '' ${CMTFILE}
    # cleanup ${F_SEIS}eq_comp.dat ${F_SEIS}eq_comp_sort.dat ${F_SEIS}eq_comp_sort_m1.dat ${F_SEIS}eq_comp_sort_m2.dat ${F_SEIS}3comp.txt
  fi

  # Now sort the remaining focal mechanisms in the same manner as the seismicity

  if [[ $dozsortflag -eq 1 ]]; then
    info_msg "Sorting focal mechanisms by $ZSORTTYPE"
      case $ZSORTTYPE in
        "depth")
          case $CMTTYPE in
            CENTROID) SORTFIELD=7;;
            ORIGIN) SORTFIELD=10;;
          esac
        ;;
        "time")
          SORTFIELD=4
        ;;
        "mag")
          SORTFIELD=13
        ;;
        *)
          info_msg "[-zsort]: Sort field $ZSORTTYPE not recognized. Using depth."
          SORTFIELD=3
        ;;
      esac
    [[ $ZSORTDIR =~ "down" ]] && sort -n -k $SORTFIELD,$SORTFIELD $CMTFILE > ${F_CMT}cmt_sort.dat
    [[ $ZSORTDIR =~ "up" ]] && sort -n -r -k $SORTFIELD,$SORTFIELD $CMTFILE > ${F_CMT}cmt_sort.dat
    CMTFILE=$(abs_path ${F_CMT}cmt_sort.dat)
  fi

  # Rescale CMT magnitudes to match rescaled seismicity, if that option is set
  # This function assumed that the CMT file included the seconds in the last field

  # Ideally we would do the rescaling at the moment of plotting and not make new
  # files, but I'm not sure how to do that with psmeca

  CMTRESCALE=$(echo "$CMTSCALE * $SEISSCALE " | bc -l)  # * $SEISSCALE

  if [[ $SCALEEQS -eq 1 ]]; then
    info_msg "Scaling CMT earthquake magnitudes for display only"
    gawk < $CMTFILE -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
      mw=$13
      mwmod = (mw^str)/(sref^(str-1))
      a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
      split(a,b,"+")  # mantissa
      split(a,c,"E")  # exponent
      print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, c[1], b[2], $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39
    }' > ${F_CMT}cmt_scale.dat
    CMTFILE=$(abs_path ${F_CMT}cmt_scale.dat)
  fi

  # (This section is for a very specific application and probably should be removed)
  ##############################################################################
  # Rotate PTN axes based on back-azimuth to a pole (-cr)

  if [[ $cmtrotateflag -eq 1 && -e $CMTFILE ]]; then
    info_msg "Rotating principal axes by back azimuth to ${CMT_ROTATELON}/${CMT_ROTATELAT}"
    case $CMTTYPE in
      ORIGIN)
        gawk < $CMTFILE '{ print $8, $9 }' | gmt mapproject -Ab${CMT_ROTATELON}/${CMT_ROTATELAT} ${VERBOSE} > ${F_CMT}cmt_backaz.txt
      ;;
      CENTROID)
        gawk < $CMTFILE '{ print $5, $6 }' | gmt mapproject -Ab${CMT_ROTATELON}/${CMT_ROTATELAT} ${VERBOSE} > ${F_CMT}cmt_backaz.txt
      ;;
    esac
    paste $CMTFILE ${F_CMT}cmt_backaz.txt > ${F_CMT}cmt_backscale.txt
    gawk < ${F_CMT}cmt_backscale.txt -v refaz=$CMT_REFAZ '{ for (i=1; i<=22; i++) { printf "%s ", $(i) }; printf "%s %s %s %s %s %s %s %s %s", $23, ($24-$42+refaz)%360, $25, $26, ($27-$42+refaz)%360, $28, $29,($30-$40+refaz)%360, $31;  for(i=32;i<=39;i++) {printf " %s", $(i)}; printf("\n");  }' > ${F_CMT}cmt_rotated.dat
    CMTFILE=$(abs_path ${F_CMT}cmt_rotated.dat)
 fi

  ##############################################################################
  # Save focal mechanisms in a psmeca+ format based on the selected format type
  # so that we can plot them with psmeca.
  # Also calculate and save focal mechanism axes, nodal planes, and slip vectors

  touch ${F_CMT}cmt_thrust.txt ${F_CMT}cmt_normal.txt ${F_CMT}cmt_strikeslip.txt
  touch ${F_KIN}t_axes_thrust.txt ${F_KIN}n_axes_thrust.txt ${F_KIN}p_axes_thrust.txt  \
        ${F_KIN}t_axes_normal.txt ${F_KIN}n_axes_normal.txt ${F_KIN}p_axes_normal.txt \
        ${F_KIN}t_axes_strikeslip.txt ${F_KIN}n_axes_strikeslip.txt ${F_KIN}p_axes_strikeslip.txt

  #   1             	2	 3      4 	          5	           6              	7	         8	         9	          10	             11	           12 13        14	      15	     16	  17	   18	     19  	20	   21	      22	  23	 24 	25	 26 	 27	  28	  29	 30	  31	      32	 33 34	 35  36	 37	 38	         39
  # idcode	event_code	id	epoch	lon_centroid	lat_centroid	depth_centroid	lon_origin	lat_origin	depth_origin	author_centroid	author_origin	MW	mantissa	exponent	strike1	dip1	rake1	strike2	dip2	rake2	exponent	Tval	Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc	exponent	Mrr	Mtt	Mpp	Mrt	Mrp	Mtp	centroid_dt

  # This should go into an external utility script that converts from tectoplot->psmeca format

  cd ${F_KIN}
  gawk < $CMTFILE -v fmt=$CMTFORMAT -v cmttype=$CMTTYPE -v minmag="${CMT_MINMAG}" -v maxmag="${CMT_MAXMAG}" '
    @include "tectoplot_functions.awk"
    # function abs(v) { return (v>0)?v:-v}
    BEGIN { pi=atan2(0,-1) }
    {
      event_code=$2
      Mw=$13
      mantissa=$14;exponent=$15
      strike1=$16;dip1=$17;rake1=$18;strike2=$19;dip2=$20;rake2=$21
      Mrr=$33; Mtt=$34; Mpp=$35; Mrt=$36; Mrp=$37; Mtp=$38
      Tval=$23; Taz=$24; Tinc=$25; Nval=$26; Naz=$27; Ninc=$28; Pval=$29; Paz=$30; Pinc=$31;

      timecode=$3
      if (cmttype=="CENTROID") {
        lon=$5; lat=$6; depth=$7;
        altlon=$8; altlat=$9; altdepth=$10;
      } else {
        lon=$8; lat=$9; depth=$10;
        altlon=$5; altlat=$6; altdepth=$7;
      }

      if (lon != "none" && lat != "none") {

        if (fmt == "GlobalCMT") {
          #  lon lat depth strike1 dip1 rake1 aux_strike dip2 rake2 moment altlon altlat [event_title] altdepth [timecode]
          if (substr($1,2,1) == "T") {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "cmt_thrust.txt"
          } else if (substr($1,2,1) == "N") {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "cmt_normal.txt"
          } else {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "cmt_strikeslip.txt"
          }
          print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "cmt.dat"

        } else if (fmt == "MomentTensor") {
          # lon lat depth mrr mtt mff mrt mrf mtf exp altlon altlat [event_title] altdepth [timecode]
            if (substr($1,2,1) == "T") {
              print lon, lat, depth, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, exponent, altlon, altlat, event_code, altdepth, id > "cmt_thrust.txt"
            } else if (substr($1,2,1) == "N") {
              print lon, lat, depth, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, exponent, altlon, altlat, event_code, altdepth, id  > "cmt_normal.txt"
            } else {
              print lon, lat, depth, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, exponent, altlon, altlat, event_code, altdepth, id  > "cmt_strikeslip.txt"
            }
            print lon, lat, depth, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, exponent, altlon, altlat, event_code, altdepth, id  > "cmt.dat"
        } else if (fmt == "TNP") {
           # y  Best double couple defined from principal axis:
  	       # X Y depth T_value T_azim T_plunge N_value N_azim N_plunge P_value P_azim P_plunge exp [newX newY] [event_title]
          if (substr($1,2,1) == "T") {
            print lon, lat, depth, Tval, Taz, Tinc, Nval, Naz, Ninc, Pval, Paz, Pinc, exponent, altlon, altlat, event_code, altdepth, id > "cmt_thrust.txt"
          } else if (substr($1,2,1) == "N") {
            print lon, lat, depth, Tval, Taz, Tinc, Nval, Naz, Ninc, Pval, Paz, Pinc, exponent, altlon, altlat, event_code, altdepth, id  > "cmt_normal.txt"
          } else {
            print lon, lat, depth, Tval, Taz, Tinc, Nval, Naz, Ninc, Pval, Paz, Pinc, exponent, altlon, altlat, event_code, altdepth, id  > "cmt_strikeslip.txt"
          }
          print lon, lat, depth, Tval, Taz, Tinc, Nval, Naz, Ninc, Pval, Paz, Pinc, exponent, altlon, altlat, event_code, altdepth, id   > "cmt.dat"
        }

        if (substr($1,2,1) == "T") {
          print lon, lat, Taz, Tinc > "t_axes_thrust.txt"
          print lon, lat, Naz, Ninc > "n_axes_thrust.txt"
          print lon, lat, Paz, Pinc > "p_axes_thrust.txt"
        } else if (substr($1,2,1) == "N") {
          print lon, lat, Taz, Tinc> "t_axes_normal.txt"
          print lon, lat, Naz, Ninc > "n_axes_normal.txt"
          print lon, lat, Paz, Pinc > "p_axes_normal.txt"
        } else if (substr($1,2,1) == "S") {
          print lon, lat, Taz, Tinc > "t_axes_strikeslip.txt"
          print lon, lat, Naz, Ninc > "n_axes_strikeslip.txt"
          print lon, lat, Paz, Pinc > "p_axes_strikeslip.txt"
        }

        if (Mw >= minmag && Mw <= maxmag) {
          if (substr($1,2,1) == "T") {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "kin_thrust.txt"
          } else if (substr($1,2,1) == "N") {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "kin_normal.txt"
          } else {
            print lon, lat, depth, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, altlon, altlat, event_code, altdepth, id > "kin_strikeslip.txt"
          }
        }
      }
    }'
  touch kin_thrust.txt kin_normal.txt kin_strikeslip.txt

	# Generate the kinematic vectors
	# For thrust faults, take the slip vector associated with the shallower dipping nodal plane

  gawk < kin_thrust.txt -v symsize=$SYMSIZE1 '{if($8 > 45) print $1, $2, ($7+270) % 360, symsize; else print $1, $2, ($4+270) % 360, symsize;  }' > thrust_gen_slip_vectors_np1.txt
  gawk < kin_thrust.txt -v symsize=$SYMSIZE2 '{if($8 > 45) print $1, $2, ($4+90) % 360, symsize; else print $1, $2, ($7+90) % 360, symsize;  }' > thrust_gen_slip_vectors_np1_downdip.txt
  gawk < kin_thrust.txt -v symsize=$SYMSIZE3 '{if($8 > 45) print $1, $2, ($4) % 360, symsize / 2; else print $1, $2, ($7) % 360, symsize / 2;  }' > thrust_gen_slip_vectors_np1_str.txt

  gawk 'NR > 1' kin_thrust.txt | gawk  -v symsize=$SYMSIZE1 '{if($8 > 45) print $1, $2, ($4+270) % 360, symsize; else print $1, $2, ($7+270) % 360, symsize;  }' > thrust_gen_slip_vectors_np2.txt
  gawk 'NR > 1' kin_thrust.txt | gawk  -v symsize=$SYMSIZE2 '{if($8 > 45) print $1, $2, ($7+90) % 360, symsize; else print $1, $2, ($4+90) % 360, symsize ;  }' > thrust_gen_slip_vectors_np2_downdip.txt
  gawk 'NR > 1' kin_thrust.txt | gawk  -v symsize=$SYMSIZE3 '{if($8 > 45) print $1, $2, ($7) % 360, symsize / 2; else print $1, $2, ($4) % 360, symsize / 2;  }' > thrust_gen_slip_vectors_np2_str.txt

  gawk 'NR > 1' kin_strikeslip.txt | gawk  -v symsize=$SYMSIZE1 '{ print $1, $2, ($7+270) % 360, symsize }' > strikeslip_slip_vectors_np1.txt
  gawk 'NR > 1' kin_strikeslip.txt | gawk  -v symsize=$SYMSIZE1 '{ print $1, $2, ($4+270) % 360, symsize }' > strikeslip_slip_vectors_np2.txt

  gawk 'NR > 1' kin_normal.txt | gawk  -v symsize=$SYMSIZE1 '{ print $1, $2, ($7+270) % 360, symsize }' > normal_slip_vectors_np1.txt
  gawk 'NR > 1' kin_normal.txt | gawk  -v symsize=$SYMSIZE1 '{ print $1, $2, ($4+270) % 360, symsize }' > normal_slip_vectors_np2.txt

[[ -e cmt_thrust.txt ]] && mv cmt_thrust.txt ../${F_CMT}
[[ -e cmt_normal.txt ]] && mv cmt_normal.txt ../${F_CMT}
[[ -e cmt_strikeslip.txt ]] && mv cmt_strikeslip.txt ../${F_CMT}
[[ -e cmt.dat ]] && mv cmt.dat ../${F_CMT}

  cd ..
fi


#### Back to seismicity for some reason



if [[ $REMOVE_DEFAULTDEPTHS -eq 1 && -e ${F_SEIS}eqs.txt ]]; then
  info_msg "Removing earthquakes with poorly determined origin depths"
  [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && info_msg "Plotting removed events separately"
  # Plotting in km instead of in map geographic coords.
  gawk < ${F_SEIS}eqs.txt '{
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
  ' > ${F_SEIS}tmp.dat 2>${F_SEIS}removed_eqs.txt
  mv ${F_SEIS}tmp.dat ${F_SEIS}eqs.txt
fi

if [[ $SCALEEQS -eq 1 && -e ${F_SEIS}eqs.txt ]]; then
  [[ -e ${F_SEIS}removed_eqs.txt ]] && gawk < ${F_SEIS}removed_eqs.txt -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1)), $5, $6, $7}' > ${F_SEIS}removed_eqs_scaled.txt
  gawk < ${F_SEIS}eqs.txt -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1)), $5, $6, $7}' > ${F_SEIS}eqs_scaled.txt
fi


################################################################################
#####           Calculate plate motions                                    #####
################################################################################

if [[ $plotplates -eq 1 ]]; then

  # Calculates relative plate motion along plate boundaries - most time consuming!
  # Calculates plate edge midpoints and plate edge azimuths
  # Calculates relative motion of grid points within plates
  # Calculates reference plate from reference point location
  # Calculates small circle rotations for display

  # MORVEL, GBM, and GSRM plate data are sanitized for CW polygons cut at the anti-meridian and
  # with pole cap plates extended to 90 latitude. TDEFNODE plates are expected to
  # satisfy the same criteria but can be CCW oriented; we cut the plates by the ROI
  # and then change their CW/CCW direction anyway.

  # Euler poles are searched for using the ID component of any plate called ID_N.
  # This allows us to have multiple clean polygons for a given Euler pole.

  # We calculate plate boundary segment azimuths on the fly to infer tectonic setting

  # We should probably pre-process things because global datasets can have a lot of points
  # and take up a lot of time to determine plate pairs, etc. But exactly how to deal with
  # clipped data is a problem.

  # STEP 1: Identify the plates that fall within the AOI and extract their polygons and Euler poles

  # Cut the plate file by the ROI.

  # This step FAILS to select plates on the other side of the dateline...
  echo gmt spatial $PLATES -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C $VERBOSE
  gmt spatial $PLATES -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C $VERBOSE | gawk  '{print $1, $2}' > ${F_PLATES}map_plates_clip_a.txt

  # Stupid test for []
  if [[ $(echo "$MINLON < -180 && $MAXLON > -180" | bc) -eq 1 ]]; then
    echo "Also cutting on other side of dateline neg:"
    MINLONCUT=$(echo "${MINLON}+360" | bc -l)
    echo gmt spatial $PLATES -R${MINLONCUT}/180/$MINLAT/$MAXLAT -C
    gmt spatial $PLATES -R${MINLONCUT}/180/$MINLAT/$MAXLAT -C $VERBOSE | gawk  '{print $1, $2}' >> ${F_PLATES}map_plates_clip_a.txt
  elif [[ $(echo "$MINLON < 180 && $MAXLON > 180" | bc) -eq 1 ]]; then
    echo "Also cutting on other side of dateline pos:"
    MAXLONCUT=$(echo "${MAXLON}-360" | bc -l)
    echo gmt spatial $PLATES -R-180/${MAXLONCUT}/$MINLAT/$MAXLAT -C
    gmt spatial $PLATES -R-180/${MAXLONCUT}/$MINLAT/$MAXLAT -C $VERBOSE | gawk  '{print $1, $2}' >> ${F_PLATES}map_plates_clip_a.txt
  fi

  # Ensure CW orientation of clipped polygons.
  # GMT spatial strips out the header labels for some reason.
  gmt spatial ${F_PLATES}map_plates_clip_a.txt -E+n $VERBOSE > ${F_PLATES}map_plates_clip_orient.txt

  # Check the special case that there are no polygon boundaries within the region
  numplates=$(grep ">" ${F_PLATES}map_plates_clip_a.txt | wc -l)
  numplatesorient=$(grep ">" ${F_PLATES}map_plates_clip_orient.txt | wc -l)

  if [[ $numplates -eq 1 && $numplatesorient -eq 0 ]]; then
    grep ">" ${F_PLATES}map_plates_clip_a.txt > ${F_PLATES}new.txt
    cat ${F_PLATES}map_plates_clip_orient.txt >> ${F_PLATES}new.txt
    cp ${F_PLATES}new.txt ${F_PLATES}map_plates_clip_orient.txt
  fi

  grep ">" ${F_PLATES}map_plates_clip_a.txt > ${F_PLATES}map_plates_clip_ids.txt

  IFS=$'\n' read -d '' -r -a pids < ${F_PLATES}map_plates_clip_ids.txt
  i=0

  # Now read through the file and replace > with the next value in the pids array. This replaces names that GMT spatial stripped out for no good reason at all...
  while read p; do
    if [[ ${p:0:1} == '>' ]]; then
      printf  "%s\n" "${pids[i]}" >> ${F_PLATES}map_plates_clip.txt
      i=$i+1
    else
      printf "%s\n" "$p" >> ${F_PLATES}map_plates_clip.txt
    fi
  done < ${F_PLATES}map_plates_clip_orient.txt

  grep ">" ${F_PLATES}map_plates_clip.txt | uniq | gawk  '{print $2}' > ${F_PLATES}plate_id_list.txt

  if [[ $outputplatesflag -eq 1 ]]; then
    echo "Plates in model:"
    gawk < $POLES '{print $1}' | tr '\n' '\t'
    echo ""
    echo "Plates within AOI":
    gawk < ${F_PLATES}plate_id_list.txt '{
      split($1, v, "_");
      for(i=1; i<length(v); i++) {
        printf "%s\n", v[i]
      }
    }' | tr '\n' '\t'
    echo ""
    exit
  fi

  info_msg "Found plates ..."
  [[ $narrateflag -eq 1 ]] && cat ${F_PLATES}plate_id_list.txt
  info_msg "Extracting the full polygons of intersected plates..."

  v=($(cat ${F_PLATES}plate_id_list.txt | tr ' ' '\n'))
  i=0
  j=1;
  rm -f ${F_PLATES}plates_in_view.txt
  echo "> END" >> ${F_PLATES}map_plates_clip.txt

  # STEP 2: Calculate midpoint locations and azimuth of segment for plate boundary segments

	# Calculate the azimuth between adjacent line segment points (assuming clockwise oriented polygons)
	rm -f ${F_PLATES}plateazfile.txt

  # We are too clever by half and just shift the whole plate file one line down and then calculate the azimuth between points:
	sed 1d < ${F_PLATES}map_plates_clip.txt > ${F_PLATES}map_plates_clip_shift1.txt
	paste ${F_PLATES}map_plates_clip.txt ${F_PLATES}map_plates_clip_shift1.txt | grep -v "\s>" > ${F_PLATES}geodin.txt

  # Script to return azimuth and midpoint between a pair of input points.
  # Comes within 0.2 degrees of geod() results over large distances, while being symmetrical which geod isn't
  # We need perfect symmetry in order to create exact point pairs in adjacent polygons

  gawk < ${F_PLATES}geodin.txt '{print $1, $2, $3, $4}' | gawk  '
  @include "tectoplot_functions.awk"
  # function acos(x) { return atan2(sqrt(1-x*x), x) }
      {
        if ($1 == ">") {
          print $1, $2;
        }
        else {
          lon1 = $1*3.14159265358979/180;
          lat1 = $2*3.14159265358979/180;
          lon2 = $3*3.14159265358979/180;
          lat2 = $4*3.14159265358979/180;
          Bx = cos(lat2)*cos(lon2-lon1);
          By = cos(lat2)*sin(lon2-lon1);
          latMid = atan2(sin(lat1)+sin(lat2), sqrt((cos(lat1)+Bx)*(cos(lat1)+Bx)+By*By));
          lonMid = lon1+atan2(By, cos(lat1)+Bx);
          theta = atan2(sin(lon2-lon1)*cos(lat2), cos(lat1)*sin(lat2)-sin(lat1)*cos(lat2)*cos(lon2-lon1));
          d = acos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(lon2-lon1) ) * 6371;
          printf "%.5f %.5f %.3f %.3f\n", lonMid*180/3.14159265358979, latMid*180/3.14159265358979, (theta*180/3.14159265358979+360-90)%360, d;
        };
      }' > ${F_PLATES}plateazfile.txt

  # plateazfile.txt now contains midpoints with azimuth and distance of segments. Multiple
  # headers per plate are possible if multiple disconnected lines were generated
  # outfile is midpointlon midpointlat azimuth

  cat ${F_PLATES}plateazfile.txt | gawk  '{if (!/^>/) print $1, $2}' > ${F_PLATES}halfwaypoints.txt
  # output is lat1 lon1 midlat1 midlon1 az backaz distance

	cp ${F_PLATES}plate_id_list.txt ${F_PLATES}map_ids_end.txt
	echo "END" >> ${F_PLATES}map_ids_end.txt

  # Extract the Euler poles for the map_ids.txt plates
  # We need to match XXX from XXX_N
  v=($(cat ${F_PLATES}plate_id_list.txt | tr ' ' '\n'))
  i=0
  while [[ $i -lt ${#v[@]} ]]; do
      pid="${v[$i]%_*}"
      repid="${v[$i]}"
      info_msg "Looking for pole $pid and replacing with $repid"
      grep "$pid\s" < $POLES | sed "s/$pid/$repid/" >> ${F_PLATES}polesextract_init.txt
      i=$i+1
  done

  # Extract the unique Euler poles
  gawk '!seen[$1]++' ${F_PLATES}polesextract_init.txt > ${F_PLATES}polesextract.txt

  # Define the reference plate (zero motion plate) either manually or using reference point (reflon, reflat)
  if [[ $manualrefplateflag -eq 1 ]]; then
    REFPLATE=$(grep ^$MANUALREFPLATE ${F_PLATES}polesextract.txt | head -n 1 | gawk  '{print $1}')
    info_msg "Manual reference plate is $REFPLATE"
  else
    # We use a tiny little polygon to clip the map_plates and determine the reference polygon.
    # Not great but GMT spatial etc don't like the map polygon data...
    REFWINDOW=0.001

    Y1=$(echo "$REFPTLAT-$REFWINDOW" | bc -l)
    Y2=$(echo "$REFPTLAT+$REFWINDOW" | bc -l)
    X1=$(echo "$REFPTLON-$REFWINDOW" | bc -l)
    X2=$(echo "$REFPTLON+$REFWINDOW" | bc -l)

    nREFPLATE=$(gmt spatial ${F_PLATES}map_plates_clip.txt -R$X1/$X2/$Y1/$Y2 -C $VERBOSE  | grep "> " | head -n 1 | gawk  '{print $2}')
    info_msg "Automatic reference plate is $nREFPLATE"

    if [[ -z "$nREFPLATE" ]]; then
        info_msg "Could not determine reference plate from reference point"
        REFPLATE=$DEFREF
    else
        REFPLATE=$nREFPLATE
    fi
  fi

  # Set Euler pole for reference plate
  if [[ $defaultrefflag -eq 1 ]]; then
    info_msg "Using Euler pole $DEFREF = [0 0 0]"
    reflat=0
    reflon=0
    refrate=0
  else
  	info_msg "Defining reference pole from $POLESRC | $REFPLATE vs $DEFREF pole"
  	info_msg "Looking for reference plate $REFPLATE in pole file $POLES"

  	# Have to search for lines beginning with REFPLATE with a space after to avoid matching e.g. both Burma and BurmanRanges
  	reflat=`grep "^$REFPLATE\s" < ${F_PLATES}polesextract.txt | gawk  '{print $2}'`
  	reflon=`grep "^$REFPLATE\s" < ${F_PLATES}polesextract.txt | gawk  '{print $3}'`
  	refrate=`grep "^$REFPLATE\s" < ${F_PLATES}polesextract.txt | gawk  '{print $4}'`

  	info_msg "Found reference plate Euler pole $REFPLATE vs $DEFREF $reflat $reflon $refrate"
  fi

	# Set the GPS to the reference plate if not overriding it from the command line

	if [[ $gpsoverride -eq 0 ]]; then
    echo "GPS dir is ${GPSDIR}"
    if [[ $defaultrefflag -eq 1 ]]; then
      # ITRF08 is likely similar to other reference frames.
      GPS_FILE=$(echo ${GPSDIR}"/GPS_ITRF08.gmt")
    else
      # REFPLATE now ends in a _X code to accommodate multiple subplates with the same pole.
      # This will break if _X becomes _XX (10 or more sub-plates)
      RGP=${REFPLATE::${#REFPLATE}-2}
      if [[ -e ${GPSDIR}"/GPS_${RGP}.gmt" ]]; then
        GPS_FILE=$(echo ${GPSDIR}"/GPS_${RGP}.gmt")
      else
        info_msg "No GPS file ${GPSDIR}/GPS_${RGP}.gmt exists. Keeping default"
      fi
    fi
  fi

  # Iterate over the plates. We create plate polygons, identify Euler poles, etc.

  # Slurp the plate IDs from map_plates_clip.txt
  v=($(grep ">" ${F_PLATES}map_plates_clip.txt | gawk  '{print $2}' | tr ' ' '\n'))
	i=0
	j=1
	while [[ $i -lt ${#v[@]}-1 ]]; do

    # Create plate files .pldat
    info_msg "Extracting between ${v[$i]} and ${v[$j]}"
		sed -n '/^> '${v[$i]}'$/,/^> '${v[$j]}'$/p' ${F_PLATES}map_plates_clip.txt | sed '$d' > "${F_PLATES}${v[$i]}.pldat"
		echo " " >> "${F_PLATES}${v[$i]}.pldat"
		# PLDAT files now contain the X Y coordinates and segment azimuth with a > PL header line and a single empty line at the end

		# Calculate the true centroid of each polygon and output it to the label file
		sed -e '2,$!d' -e '$d' "${F_PLATES}${v[$i]}.pldat" | gawk  '{
			x[NR] = $1;
			y[NR] = $2;
		}
		END {
		    x[NR+1] = x[1];
		    y[NR+1] = y[1];

			  SXS = 0;
		    SYS = 0;
		    AS = 0;
		    for (i = 1; i <= NR; ++i) {
		    	J[i] = (x[i]*y[i+1]-x[i+1]*y[i]);
		    	XS[i] = (x[i]+x[i+1]);
		    	YS[i] = (y[i]+y[i+1]);
		    }
		    for (i = 1; i <= NR; ++i) {
		    	SXS = SXS + (XS[i]*J[i]);
		    	SYS = SYS + (YS[i]*J[i]);
		    	AS = AS + (J[i]);
			}
			AS = 1/2*AS;
			CX = 1/(6*AS)*SXS;
			CY = 1/(6*AS)*SYS;
			print CX "," CY
		}' > "${F_PLATES}${v[$i]}.centroid"
    cat "${F_PLATES}${v[$i]}.centroid" >> ${F_PLATES}map_centroids.txt

    # Calculate Euler poles relative to reference plate
    pllat=`grep "^${v[$i]}\s" < ${F_PLATES}polesextract.txt | gawk  '{print $2}'`
    pllon=`grep "^${v[$i]}\s" < ${F_PLATES}polesextract.txt | gawk  '{print $3}'`
    plrate=`grep "^${v[$i]}\s" < ${F_PLATES}polesextract.txt | gawk  '{print $4}'`
    # Calculate resultant Euler pole
    info_msg "Euler poles ${v[$i]} vs $DEFREF: $pllat $pllon $plrate vs $reflat $reflon $refrate"

    echo $pllat $pllon $plrate $reflat $reflon $refrate | gawk  -f $EULERADD_AWK  > ${F_PLATES}${v[$i]}.pole

    # Calculate motions of grid points from their plate's Euler pole

    if [[ $makegridflag -eq 1 ]]; then
    	# gridfile is in lat lon
    	# gridpts are in lon lat
      # Select the grid points within the plate amd calculate plate velocities at the grid points

      cat gridfile.txt | gmt select -: -F${F_PLATES}${v[$i]}.pldat $VERBOSE | gawk  '{print $2, $1}' > ${F_PLATES}${v[$i]}_gridpts.txt
      gawk -f $EULERVEC_AWK -v eLat_d1=$pllat -v eLon_d1=$pllon -v eV1=$plrate -v eLat_d2=$reflat -v eLon_d2=$reflon -v eV2=$refrate ${F_PLATES}${v[$i]}_gridpts.txt > ${F_PLATES}${v[$i]}_velocities.txt
    	paste -d ' ' ${F_PLATES}${v[$i]}_gridpts.txt ${F_PLATES}${v[$i]}_velocities.txt | gawk  '{print $2, $1, $3, $4, 0, 0, 1, "ID"}' > ${F_PLATES}${v[$i]}_platevecs.txt
    fi

    # Small circles for showing plate relative motions. Not the greatest or worst concept.

    if [[ $platerotationflag -eq 1 ]]; then

      polelat=$(cat ${F_PLATES}${v[$i]}.pole | gawk '{print $1}')
      polelon=$(cat ${F_PLATES}${v[$i]}.pole | gawk '{print $2}')
      polerate=$(cat ${F_PLATES}${v[$i]}.pole | gawk '{print $3}')

      if [[ $(echo "$polerate == 0" | bc -l) -eq 1 ]]; then
        info_msg "Not generating small circles for reference plate"
        touch ${F_PLATES}${v[$i]}.smallcircles
      else
        centroidlat=`cat ${F_PLATES}${v[$i]}.centroid | gawk  -F, '{print $1}'`
        centroidlon=`cat ${F_PLATES}${v[$i]}.centroid | gawk  -F, '{print $2}'`
        info_msg "Generating small circles around pole $polelat $polelon"

        # Calculate the minimum and maximum colatitudes of points in .pldat file relative to Euler Pole
        #cos(AOB)=cos(latA)cos(latB)cos(lonB-lonA)+sin(latA)sin(latB)
        grep -v ">" ${F_PLATES}${v[$i]}.pldat | grep "\S" | gawk  -v plat=$polelat -v plon=$polelon '
        @include "tectoplot_functions.awk"
        # function acos(x) { return atan2(sqrt(1-x*x), x) }
          BEGIN {
            maxdeg=0; mindeg=180;
          }
          {
            lon1 = plon*3.14159265358979/180;
            lat1 = plat*3.14159265358979/180;
            lon2 = $1*3.14159265358979/180;
            lat2 = $2*3.14159265358979/180;

            degd = 180/3.14159265358979*acos( cos(lat1)*cos(lat2)*cos(lon2-lon1)+sin(lat1)*sin(lat2) );
            if (degd < mindeg) {
              mindeg=degd;
            }
            if (degd > maxdeg) {
              maxdeg=degd;
            }
          }
          END {
            maxdeg=maxdeg+1;
            if (maxdeg >= 179) { maxdeg=179; }
            mindeg=mindeg-1;
            if (mindeg < 1) { mindeg=1; }
            printf "%.0f %.0f\n", mindeg, maxdeg
        }' > ${F_PLATES}${v[$i]}.colatrange.txt
        colatmin=$(cat ${F_PLATES}${v[$i]}.colatrange.txt | gawk  '{print $1}')
        colatmax=$(cat ${F_PLATES}${v[$i]}.colatrange.txt | gawk  '{print $2}')

        # Find the antipode for GMT project
        poleantilat=$(echo "0 - (${polelat})" | bc -l)
        poleantilon=$(echo "$polelon" | gawk  '{if ($1 < 0) { print $1+180 } else { print $1-180 } }')
        info_msg "Pole $polelat $polelon has antipode $poleantilat $poleantilon"

        # Generate small circle paths in colatitude range of plate
        rm -f ${F_PLATES}${v[$i]}.smallcircles
        for j2 in $(seq $colatmin $LATSTEPS $colatmax); do
          echo "> -Z${j2}" >> ${F_PLATES}${v[$i]}.smallcircles
          gmt project -T${polelon}/${polelat} -C${poleantilon}/${poleantilat} -G0.5/${j2} -L-360/0 $VERBOSE | gawk  '{print $1, $2}' >> ${F_PLATES}${v[$i]}.smallcircles
        done

        # Clip the small circle paths by the plate polygon
        gmt spatial ${F_PLATES}${v[$i]}.smallcircles -T${F_PLATES}${v[$i]}.pldat $VERBOSE | gawk  '{print $1, $2}' > ${F_PLATES}${v[$i]}.smallcircles_clip_1

        # We have trouble with gmt spatial giving us two-point lines segments. Remove all two-point segments by building a sed script
        grep -n ">" ${F_PLATES}${v[$i]}.smallcircles_clip_1 | gawk  -F: 'BEGIN { oldval=0; oldline=""; }
        {
          val=$1;
          diff=val-oldval;
          if (NR>1) {
            if (diff != 3) {
              print oldval ", " val-1 " p";
            }
          }
          oldval=val;
          oldline=$0
        }' > ${F_PLATES}lines_to_extract.txt

        # Execute sed commands to build sanitized small circle file
        sed -n -f ${F_PLATES}lines_to_extract.txt < ${F_PLATES}${v[$i]}.smallcircles_clip_1 > ${F_PLATES}${v[$i]}.smallcircles_clip

        # GMT plot command that exports label locations for points at a specified interval distance along small circles.
        # These X,Y locations are used as inputs to the vector arrowhead locations.
        cat ${F_PLATES}${v[$i]}.smallcircles_clip | gmt psxy -O -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -W0p -Sqd0.25i:+t"${F_PLATES}${v[$i]}labels.txt"+l" " $VERBOSE >> /dev/null

        # Reformat points
        gawk < ${F_PLATES}${v[$i]}labels.txt '{print $2, $1}' > ${F_PLATES}${v[$i]}_smallcirc_gridpts.txt

        # Calculate the plate velocities at the points
        gawk -f $EULERVEC_AWK -v eLat_d1=$pllat -v eLon_d1=$pllon -v eV1=$plrate -v eLat_d2=$reflat -v eLon_d2=$reflon -v eV2=$refrate ${F_PLATES}${v[$i]}_smallcirc_gridpts.txt > ${F_PLATES}${v[$i]}_smallcirc_velocities.txt

        # Transform to psvelo format for later plotting
        paste -d ' ' ${v[$i]}_smallcirc_gridpts.txt ${v[$i]}_smallcirc_velocities.txt | gawk  '{print $1, $2, $3*100, $4*100, 0, 0, 1, "ID"}' > ${F_PLATES}${v[$i]}_smallcirc_platevecs.txt
      fi # small circles
    fi

	  i=$i+1
	  j=$j+1
  done # while (Iterate over plates calculating pldat, centroids, and poles

  # Create the plate labels at the centroid locations
	paste -d ',' ${F_PLATES}map_centroids.txt ${F_PLATES}plate_id_list.txt > ${F_PLATES}map_labels.txt

  # EDGE CALCULATIONS. Determine the relative motion of each plate pair for each plate edge segment
  # by extracting the two Euler poles and calculating predicted motions at the segment midpoint.
  # This calculation is time consuming for large areas because my implementation is... algorithmically
  # poor. So, intead we load the data from a pre-calculated results file if it already exists.

  if [[ $doplateedgesflag -eq 1 ]]; then
    # Load pre-calculated data if it exists - MUCH faster but may need to recalc if things change
    # To re-build, use a global region -r -180 180 -90 90 and copy id_pts_euler.txt to $MIDPOINTS file

    if [[ -e $MIDPOINTS ]]; then
      gawk < $MIDPOINTS -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
        # LON EDIT TEST
        if ((($1 <= maxlon && $1 >= minlon) || ($1+360 <= maxlon && $1+360 >= minlon)) && $2 >= minlat && $2 <= maxlat) {
          print
        }
      }' > ${F_PLATES}id_pts_euler.txt
    else
      echo "Midpoints file $MIDPOINTS does not exist"
      if [[ $MINLAT -eq "-90" && $MAXLAT -eq "90" && $MINLON -eq "-180" && $MAXLON -eq "180" ]]; then
        echo "Your region is global. After this script ends, you can copy id_pts_euler.txt and define it as a MIDPOINT file."
      fi

    	# Create a file with all points one one line beginning with the plate ID only
      # The sed '$d' deletes the 'END' line
      gawk < ${F_PLATES}plateazfile.txt '{print $1, $2 }' | tr '\n' ' ' | sed -e $'s/>/\\\n/g' | grep '\S' | tr -s '\t' ' ' | sed '$d' > ${F_PLATES}map_plates_oneline.txt

    	# Create a list of unique block edge points.  Not sure I actually need this
      gawk -F" " '!_[$1][$2]++' ${F_PLATES}plateazfile.txt | gawk  '($1 != ">") {print $1, $2}' > ${F_PLATES}map_plates_uniq.txt

      # Primary output is id_pts.txt, containing properties of segment midpoints
      # id_pts.txt
      # lon lat seg_az seg_dist plate1_id plate2_id p1lat p1lon p1rate p2lat p2lon p2rate
      # > nba_1
      # -0.23807 -54.76466 322.920 32.154 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 0.20267 -54.56424 321.234 39.964 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 0.70278 -54.64178 51.803 54.065 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 1.33194 -54.61605 314.609 67.286 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 2.02896 -54.21846 317.316 59.072 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 2.69403 -53.84446 315.736 61.200 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 3.19663 -53.74262 42.110 30.427 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292
      # 3.66147 -53.98086 40.562 50.346 nba_1 an_1 65.42 -118.11 0.25 47.68 -68.44 0.292

      while read p; do
        if [[ ${p:0:1} == '>' ]]; then  # We encountered a plate segment header. All plate pairs should be referenced to this plate
          curplate=$(echo $p | gawk  '{print $2}')
          echo $p >> ${F_PLATES}id_pts.txt
          pole1=($(grep "${curplate}\s" < ${F_PLATES}polesextract.txt))
          info_msg "Current plate is $curplate with pole ${pole1[1]} ${pole1[2]} ${pole1[3]}"
        else
          q=$(echo $p | gawk '{print $1, $2}')
          resvar=($(grep -n -- "${q}" < ${F_PLATES}map_plates_oneline.txt | gawk  -F" " '{printf "%s\n", $2}'))
          numres=${#resvar[@]}
          if [[ $numres -eq 2 ]]; then   # Point is between two plates
            if [[ ${resvar[0]} == $curplate ]]; then
              plate1=${resvar[0]}
              plate2=${resvar[1]}
            else
              plate1=${resvar[1]} # $curplate
              plate2=${resvar[0]}
            fi
          else                          # Point is not between plates or is triple point
              plate1=${resvar[0]}
              plate2=${resvar[0]}
          fi
          pole2=($(grep "${plate2}\s" < ${F_PLATES}polesextract.txt))
          info_msg " Plate 2 is $plate2 with pole ${pole2[1]} ${pole2[2]} ${pole2[3]}"
          echo -n "${p} " >> ${F_PLATES}id_pts.txt
          echo ${plate1} ${plate2} ${pole2[1]} ${pole2[2]} ${pole2[3]} ${pole1[1]} ${pole1[2]} ${pole1[3]} | gawk  '{printf "%s %s ", $1, $2; print $3, $4, $5, $6, $7, $8}' >> ${F_PLATES}id_pts.txt
        fi
      done < ${F_PLATES}plateazfile.txt

      # Do the plate relative motion calculations all at once.
      gawk -f $EULERVECLIST_AWK ${F_PLATES}id_pts.txt > ${F_PLATES}id_pts_euler.txt

    fi

  	grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '{print $1, $2, $3, 0.5}' >  ${F_PLATES}paz1.txt
  	grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '{print $1, $2, $15, 0.5}' >  ${F_PLATES}paz2.txt

    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '{print $1, $2, $3-$15}' >  ${F_PLATES}azdiffpts.txt
    #grep "^[^>]" < id_pts_euler.txt | gawk  '{print $1, $2, $3-$15, $4}' >  azdiffpts_len.txt

    # Right now these values don't go from -180:180...
    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '{
        val = $3-$15
        if (val > 180) { val = val - 360 }
        if (val < -180) { val = val + 360 }
        print $1, $2, val, $4
      }' >  ${F_PLATES}azdiffpts_len.txt

  	# currently these kinematic arrows are all the same scale. Can scale to match psvelo... but how?

    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '
      @include "tectoplot_functions.awk"
      # function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u}
      {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff >= 20 && diff <= 70) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' >  ${F_PLATES}paz1thrust.txt

    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '
      @include "tectoplot_functions.awk"
      # function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u}
      {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff > 70 && diff < 110) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' >  ${F_PLATES}paz1ss1.txt

    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '
      @include "tectoplot_functions.awk"
      # function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u}
      {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff > -90 && diff < -70) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' > ${F_PLATES}paz1ss2.txt

    grep "^[^>]" < ${F_PLATES}id_pts_euler.txt | gawk  '
      @include "tectoplot_functions.awk"
      # function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u}
      {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff >= 110 || diff <= -110) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' > ${F_PLATES}paz1normal.txt
  fi #  if [[ $doplateedgesflag -eq 1 ]]; then
fi # if [[ $plotplates -eq 1 ]]


if [[ $sprofflag -eq 1 || $cprofflag -eq 1 ]]; then
  plots+=("mprof")
fi

################################################################################
################################################################################
#####           Create CPT files for coloring grids and data               #####
################################################################################
################################################################################

# These are a series of fixed CPT files that we can refer to when we wish. They
# are not modified and don't need to be copied to tempdir.

[[ ! -e $CPTDIR"grayhs.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cgray,gray -T-10000/10000/10000 ${VERBOSE} > $CPTDIR"grayhs.cpt"
[[ ! -e $CPTDIR"whitehs.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cwhite,white -T-10000/10000/10000 ${VERBOSE} > $CPTDIR"whitehs.cpt"
[[ ! -e $CPTDIR"cycleaz.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cred,green,blue,yellow,red -T-180/180/1 -Z $VERBOSE > $CPTDIR"cycleaz.cpt"
[[ ! -e $CPTDIR"defaultpt.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cred,yellow,green,blue,orange,purple,brown -T0/2000/1 -Z $VERBOSE > $CPTDIR"defaultpt.cpt"
[[ ! -e $CPTDIR"platevel_one.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Chaxby -T0/1/0.05 -Z $VERBOSE > $CPTDIR"platevel_one.cpt"

################################################################################
##### Create required CPT files in the temporary directory

for cptfile in ${cpts[@]} ; do
	case $cptfile in

    faultslip)
      gmt makecpt -Chot -I -Do -T$SLIPMINIMUM/$SLIPMAXIMUM/0.1 -N $VERBOSE > $FAULTSLIP_CPT
      ;;

    gcdm) # Global Curie Depth Map
      touch $GCDM_CPT
      GCDM_CPT=$(abs_path $GDCM_CPT)
      gmt makecpt -Cseis -T$GCDMMIN/$GCDMMAX -Z > $GCDM_CPT
      ;;

    grav) # WGM gravity maps
      touch $GRAV_CPT
      GRAV_CPT=$(abs_path $GRAV_CPT)
      if [[ $rescalegravflag -eq 1 ]]; then
        # gmt grdcut $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -Ggravtmp.nc
        zrange=$(grid_zrange $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
        info_msg "Grav raster range is: $zrange"
        MINZ=$(echo $zrange | gawk  '{print int($1/100)*100}')
        MAXZ=$(echo $zrange | gawk  '{print int($2/100)*100}')
        # GRAVCPT is set by the type of gravity we selected (BG, etc) and is not the same as GRAV_CPT
        info_msg "Rescaling gravity CPT to $MINZ/$MAXZ"
        gmt makecpt -C$GRAVCPT -T$MINZ/$MAXZ $VERBOSE > $GRAV_CPT
      else
        gmt makecpt -C$GRAVCPT -T-500/500 $VERBOSE > $GRAV_CPT
      fi
      ;;

    resgrav)
      gmt makecpt -C$GRAVCPT -T-145/145 -Z $VERBOSE > $RESGRAV_CPT
      ;;

    litho1)

      gmt makecpt -T${LITHO1_MIN_DENSITY}/${LITHO1_MAX_DENSITY}/10 -C${LITHO1_DENSITY_BUILTIN} -Z $VERBOSE > $LITHO1_DENSITY_CPT
      gmt makecpt -T${LITHO1_MIN_VELOCITY}/${LITHO1_MAX_VELOCITY}/10 -C${LITHO1_VELOCITY_BUILTIN} -Z $VERBOSE > $LITHO1_VELOCITY_CPT
      ;;

    mag) # EMAG_V2
      touch $MAG_CPT
      MAG_CPT=$(abs_path $MAG_CPT)
      gmt makecpt -Crainbow -Z -Do -T-250/250/10 $VERBOSE > $MAG_CPT
      ;;

    oceanage)
      if [[ $stretchoccptflag -eq 1 ]]; then
        # The ocean CPT has a long 'purple' tail that isn't useful when stretching the CPT
        gawk < $OC_AGE_CPT '{ if ($1 < 180) print }' > ./oceanage_cut.cpt
        printf "B\twhite\n" >> ./oceanage_cut.cpt
        printf "F\tblack\n" >> ./oceanage_cut.cpt
        printf "N\t128\n" >> ./oceanage_cut.cpt
        gmt makecpt -C./oceanage_cut.cpt -T0/$OC_MAXAGE/10 $VERBOSE > ./oceanage.cpt
        OC_AGE_CPT="./oceanage.cpt"
      fi
      ;;

    platevel)
    # Don't do anything until we move the calculation from the plotting section to above
      ;;

    population)
      touch $POPULATION_CPT
      POPULATION_CPT=$(abs_path $POPULATION_CPT)
      gmt makecpt -C${CITIES_CPT} -I -Do -T0/1000000/100000 -N $VERBOSE > $POPULATION_CPT
      ;;

    slipratedeficit)
      gmt makecpt -Cseis -Do -I -T0/1/0.01 -N > $SLIPRATE_DEF_CPT
      ;;

    topo)


      if [[ $useowntopoctrlflag -eq 0 ]]; then
        topoctrlstring=$DEFAULT_TOPOCTRL
      fi
      if [[ $dontcolortopoflag -eq 0 ]]; then
        info_msg "Adding color stretch to topoctrlstring"
        topoctrlstring=${topoctrlstring}"c"
      fi

      info_msg "Plotting topo from $BATHY: control string is ${topoctrlstring}"
      touch $TOPO_CPT
      TOPO_CPT=$(abs_path $TOPO_CPT)
      if [[ $customgridcptflag -eq 1 ]]; then
        info_msg "Copying custom CPT file $CUSTOMCPT to temporary directory"
        cp $CUSTOMCPT $TOPO_CPT
      else
        info_msg "Building default TOPO CPT file from $TOPO_CPT_DEF"
        gmt makecpt -Fr -C${TOPO_CPT_DEF} -T${TOPO_CPT_DEF_MIN}/${TOPO_CPT_DEF_MAX}/${TOPO_CPT_DEF_STEP}  $VERBOSE > $TOPO_CPT
      fi
      if [[ $rescaletopoflag -eq 1 ]]; then
        zrange=$(grid_zrange $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
        MINZ=$(echo $zrange | gawk  '{printf "%d\n", $1}')
        MAXZ=$(echo $zrange | gawk  '{printf "%d\n", $2}')
        info_msg "Rescaling topo $BATHY with CPT to $MINZ/$MAXZ with hinge at 0"
        gmt makecpt -Fr -C$TOPO_CPT_DEF -T$MINZ/$MAXZ/${TOPO_CPT_DEF_STEP}  ${VERBOSE} > topotmp.cpt
        mv topotmp.cpt $TOPO_CPT
        GDIFFZ=$(echo "($MAXZ - $MINZ) > 4000" | bc)  # Scale range is greater than 4 km
        # Set the interval value for the legend scale based on the range of the data
        if [[ $GDIFFZ -eq 1 ]]; then
          BATHYXINC=2
        else
          BATHYXINC=$(echo "($MAXZ - $MINZ) / 6 / 1000" | bc -l | gawk  '{ print int($1/0.1)*0.1}')
        fi
        GDIFFZ=$(echo "($MAXZ - $MINZ) < 1000" | bc) # Scale range is lower than 1 km
        # Set the interval value for the legend scale based on the range of the data
        if [[ $GDIFFZ -eq 1 ]]; then # Just use 100 meters for now
          BATHYXINC=0.1
        fi
        GDIFFZ=$(echo "($MAXZ - $MINZ) < 100" | bc) # Scale range is lower than 1 km
        # Set the interval value for the legend scale based on the range of the data
        if [[ $GDIFFZ -eq 1 ]]; then # Just use 100 meters for now
          BATHYXINC=0.01
        fi
      else
        BATHYXINC=2
      fi
    ;;

    seisdepth)
      info_msg "Making seismicity vs depth CPT: maximum depth EQs at ${EQMAXDEPTH_COLORSCALE}"
      touch $SEISDEPTH_CPT
      # Make a constant color CPT
      if [[ $seisfillcolorflag -eq 1 ]]; then
        gmt makecpt -C${ZSFILLCOLOR} -Do -T0/6371 -Z $VERBOSE > $SEISDEPTH_CPT
      else
        # Make a color stretch CPT
        SEISDEPTH_CPT=$(abs_path $SEISDEPTH_CPT)
        gmt makecpt -Cseis -Do -T"${EQMINDEPTH_COLORSCALE}"/"${EQMAXDEPTH_COLORSCALE}" -Z $VERBOSE > $SEISDEPTH_CPT
        cp $SEISDEPTH_CPT $SEISDEPTH_NODEEPEST_CPT
        echo "${EQMAXDEPTH_COLORSCALE}	0/17.937/216.21	6370	0/0/255" >> $SEISDEPTH_CPT
      fi

    ;;

  esac
done

if [[ $noplotflag -eq 1 ]]; then
  info_msg "[-noplot]: Exiting"
  exit
fi


################################################################################
################################################################################
##### Plot the postscript file by calling the sections listed in $plots[@] #####
################################################################################
################################################################################

# Add a PS comment with the command line used to invoke tectoplot. Use >> as we might
# be adding this line onto an already existing PS file

echo "#!/bin/bash" >> makemap.sh
echo "" >> makemap.sh

echo "echo \"%TECTOPLOT: ${COMMAND}\" >> map.ps" >> makemap.sh
echo "%TECTOPLOT: ${COMMAND}" >> map.ps

# Before we plot anything but after we have done the data processing, set any
# GMT variables that are given on the command line using -gmtvars { A val ... }

################################################################################
#####          GMT media and map style management                          #####
################################################################################

# Page options
# Just make a giant page and trim it later using gmt psconvert -A+m

echo "gmt gmtset PS_PAGE_ORIENTATION portrait PS_MEDIA 100ix100i" >> makemap.sh
gmt gmtset PS_PAGE_ORIENTATION portrait PS_MEDIA 100ix100i

# Map frame options

echo "gmt gmtset MAP_FRAME_TYPE fancy MAP_FRAME_WIDTH 0.12c MAP_FRAME_PEN 0.5p,black" >> makemap.sh
echo "gmt gmtset FORMAT_GEO_MAP=D" >> makemap.sh

gmt gmtset MAP_FRAME_TYPE fancy MAP_FRAME_WIDTH 0.12c MAP_FRAME_PEN 0.5p,black
gmt gmtset FORMAT_GEO_MAP=D


if [[ $tifflag -eq 1 ]]; then
  echo "gmtset MAP_FRAME_TYPE inside" >> makemap.sh
  gmt gmtset MAP_FRAME_TYPE inside
fi

if [[ $kmlflag -eq 1 ]]; then
  echo "gmtset MAP_FRAME_TYPE inside" >> makemap.sh
  gmt gmtset MAP_FRAME_TYPE inside
fi

# Font options
echo "gmt gmtset FONT_ANNOT_PRIMARY 10 FONT_LABEL 10 FONT_TITLE 12p,Helvetica,black" >> makemap.sh
gmt gmtset FONT_ANNOT_PRIMARY 10 FONT_LABEL 10 FONT_TITLE 12p,Helvetica,black

# Symbol options
echo "gmt gmtset FONT_ANNOT_PRIMARY 10 FONT_LABEL 10 FONT_TITLE 12p,Helvetica,black" >> makemap.sh
gmt gmtset MAP_VECTOR_SHAPE 0.5 MAP_TITLE_OFFSET 24p

if [[ $usecustomgmtvars -eq 1 ]]; then
  info_msg "gmt gmtset ${GMTVARS[@]}"
echo "gmt gmtset ${GMTVARS[@]}" >> makemap.sh
  gmt gmtset ${GMTVARS[@]}
fi

# The strategy for adding items to the legend is to make little baby EPS files
# and then place them onto the master PS using gmt psimage. We initialize these
# files here and then we have to keep track of whether to close the master PS
# file or keep it open for subsequent plotting (--keepopenps)

# The frame presents a bit of a problem as we have to manage different calls to
# psbasemap based on a range of options (title, no title, grid, no grid, etc.)

# cleanup base_fake.ps base_fake.eps base_fake_nolabels.ps base_fake_nolabels.eps

# gmt psbasemap ${BSTRING[@]} ${SCALECMD} $RJOK $VERBOSE >> map.ps

# Note that BSTRING needs to be quoted as it has a title with spaces...

gmt psbasemap ${RJSTRING[@]} $VERBOSE -Btlbr > base_fake_nolabels.ps
gmt psbasemap ${RJSTRING[@]} "${BSTRING[@]}" $VERBOSE > base_fake.ps
gmt psxy -T -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} >> map.ps

gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > kinsv.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > plate.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > mecaleg.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > seissymbol.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > volcanoes.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > eqlabel.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > velarrow.ps
gmt psxy -T -X0i -Yc $OVERLAY $VERBOSE -K ${RJSTRING[@]} > velgps.ps


cleanup kinsv.ps eqlabel.ps plate.ps mecaleg.ps seissymbol.ps volcanoes.ps velarrow.ps velgps.ps

# Something about map labels messes up the psconvert call making the bounding box wrong.
# So check the label-free width and if it is significantly less than the with-label
# width, use it instead. Shouldn't change too much honestly.

MAP_PS_DIM=$(gmt psconvert base_fake.ps -Te -A0.01i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
MAP_PS_NOLABELS_DIM=$(gmt psconvert base_fake_nolabels.ps -Te -A0.01i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
# MAP_PS_NOLABELS_BB=($(gmt psconvert base_fake_nolabels.ps -Te -A0.01i 2> >(grep -v Processing | grep -v Find | grep -v Figure | grep -v Format | head -n 1) | awk -F'[[]' '{print $3}' | awk -F '[]]' '{print $1}'))
# MAP_PS_WITHLABELS_BB=($(gmt psconvert base_fake.ps -Te -A0.01i 2> >(grep -v Processing | grep -v Find | grep -v Figure | grep -v Format | head -n 1) | awk -F'[[]' '{print $3}' | awk -F '[]]' '{print $1}'))
# MAP_ANNOT_VDIFF=$(echo )

MAP_PS_WIDTH_IN=$(echo $MAP_PS_DIM | gawk  '{print $1/2.54}')
MAP_PS_HEIGHT_IN=$(echo $MAP_PS_DIM | gawk  '{print $2/2.54}')
MAP_PS_WIDTH_NOLABELS_IN=$(echo $MAP_PS_NOLABELS_DIM | gawk  '{print $1/2.54}')
MAP_PS_HEIGHT_NOLABELS_IN=$(echo $MAP_PS_NOLABELS_DIM | gawk  '{print $2/2.54}')
info_msg "Map dimensions (in) are W: $MAP_PS_WIDTH_IN, H: $MAP_PS_HEIGHT_IN"
info_msg "No label map dimensions (in) are W: $MAP_PS_WIDTH_NOLABELS_IN, H: $MAP_PS_HEIGHT_NOLABELS_IN"

# If difference is more than 50% of map width
if [[ $(echo "$MAP_PS_WIDTH_IN - $MAP_PS_WIDTH_NOLABELS_IN > $MAP_PS_WIDTH_IN/2" | bc) -eq 1 ]]; then
  if [[ $(echo "$MAP_PS_WIDTH_NOLABELS_IN > 1" | bc) -eq 1 ]]; then
    info_msg "Using label-free width instead."
    MAP_PS_WIDTH_IN=$MAP_PS_WIDTH_NOLABELS_IN
  else
    info_msg "Width of label free PS is 0... not using as alternative."
  fi
fi

MAP_PS_HEIGHT_IN_plus=$(echo "$MAP_PS_HEIGHT_IN+12/72" | bc -l )

# cleanup base_fake.ps base_fake.eps

######
# These variables are array indices and must be zero at start. They allow multiple
# instances of various commands.

current_userpointfilenumber=1
current_usergridnumber=1
current_userlinefilenumber=1

# Print the author information, date, and command used to generate the map,
# beneath the map.
# There are options for author only, command only, and author+command

# Honestly, it is a bit strange to do this here as we haven't plotted anything
# including the profile. So our text will overlap the profile. We can fix this
# by calling the profile psbasemap to add onto base_fake.ps and moving this
# section to AFTER the plotting commands. But that happens in multi_profile_tectoplot.sh...
# Currently there is no solution except pushing the profile downward

# We need to SUBTRACT the AUTHOR_YSHIFT as we are SUBTRACTING $OFFSETV

if [[ $printcommandflag -eq 1 || $authorflag -eq 1 ]]; then
  OFFSETV=$(echo $COMMAND_FONTSIZE $AUTHOR_YSHIFT | awk '{print ($1+8)/72 - $2}')
  OFFSETV_M=$(echo $OFFSETV | awk '{print 0-$1}')

  if [[ $printcommandflag -eq 1 ]]; then
    echo "T $COMMAND" >> command.txt
  fi

  gmt psxy -T -Y${OFFSETV_M}i $RJOK $VERBOSE >> map.ps

  if [[ $authorflag -eq 1 && $printcommandflag -eq 1 ]]; then
    echo "T ${AUTHOR_ID}" >> author.txt
    echo "G 1l" >> author.txt
    echo "T ${DATE_ID}" >> author.txt
    # Offset the plot down from the map lower left corner
    AUTHOR_W=$(echo "$MAP_PS_WIDTH_IN / 4" | bc -l)
    COMMAND_W=$(echo "$MAP_PS_WIDTH_IN * (3/4 - 2/10)" | bc -l)
    COMMAND_S=$(echo "$MAP_PS_WIDTH_IN * (1/4 + 1/10)" | bc -l)
    COMMAND_M=$(echo "0 - $COMMAND_S" | bc -l)
    # Make the paragraph with the author info first (using 1/4 of the space)
    gmt pslegend author.txt -Dx0/0+w${AUTHOR_W}i+jTL+l1.1 $RJOK $VERBOSE >> map.ps
    # Move to the right
    gmt psxy -T -X${COMMAND_S}i $RJOK $VERBOSE >> map.ps
    gmt pslegend command.txt -DjBL+w${COMMAND_W}i+jTL+l1.1 $RJOK $VERBOSE >> map.ps
    # Return to original location
    gmt psxy -T -Y${OFFSETV}i -X${COMMAND_M}i $RJOK $VERBOSE >> map.ps
  elif [[ $authorflag -eq 1 && $printcommandflag -eq 0 ]]; then
    echo "T ${AUTHOR_ID} | ${DATE_ID}" >> author.txt
    AUTHOR_W=$(echo "$MAP_PS_WIDTH_IN * 8 / 10" | bc -l)
    gmt pslegend author.txt -Dx0/0+w${AUTHOR_W}i+jTL+l1.1 $RJOK $VERBOSE >> map.ps
    gmt psxy -T -Y${OFFSETV}i $RJOK $VERBOSE >> map.ps
  elif [[ $authorflag -eq 0 && $printcommandflag -eq 1 ]]; then
    COMMAND_W=$(echo "$MAP_PS_WIDTH_IN * 9 / 10" | bc -l)
    gmt pslegend command.txt -Dx0/0+w${COMMAND_W}i+jTL+l1.1 $RJOK $VERBOSE >> map.ps
    gmt psxy -T -Y${OFFSETV}i $RJOK $VERBOSE >> map.ps
  fi
fi

##### DO PLOTTING
# SECTION PLOT

for plot in ${plots[@]} ; do
	case $plot in
    caxes)
      if [[ $axescmtthrustflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_thrust.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_thrust.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue   -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_thrust.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green  -Gblack $RJOK $VERBOSE >> map.ps
      fi
      if [[ $axescmtnormalflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_normal.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_normal.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue   -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_normal.txt     -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green  -Gblack $RJOK $VERBOSE >> map.ps
      fi
      if [[ $axescmtssflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_strikeslip.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_strikeslip.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue   -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_strikeslip.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green  -Gblack $RJOK $VERBOSE >> map.ps
      fi
      ;;

    cities)
      info_msg "Plotting cities with minimum population ${CITIES_MINPOP}"
      gawk < $CITIES -F, -v minpop=${CITIES_MINPOP} -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON"  '
        BEGIN{OFS=","}
        # LON EDIT TEST
        ((($1 <= maxlon && $1 >= minlon) || ($1+360 <= maxlon && $1+360 >= minlon)) && $2 >= minlat && $2 <= maxlat && $4>=minpop) {
            print $1, $2, $3, $4
        }' | sort -n -k 3 > cities.dat

      # Sort the cities so that dense areas plot on top of less dense areas
      # Could also do some kind of symbol scaling
      gawk < cities.dat -F, '{print $1, $2, $4}' | sort -n -k 3 | gmt psxy -S${CITIES_SYMBOL}${CITIES_SYMBOL_SIZE} -W${CITIES_SYMBOL_LINEWIDTH},${CITIES_SYMBOL_LINECOLOR} -C$POPULATION_CPT $RJOK $VERBOSE >> map.ps
      if [[ $citieslabelflag -eq 1 ]]; then
        gawk < cities.dat -F, '{print $1, $2, $3}' | sort -n -k 3 | gmt pstext -F+f${CITIES_LABEL_FONTSIZE},${CITIES_LABEL_FONT},${CITIES_LABEL_FONTCOLOR}+jLM $RJOK $VERBOSE >> map.ps
      fi
      ;;

    clipon)
echo "gmt psclip ${CLIP_POLY_FILE} ${CLIP_POLY_PEN} ${RJOK} ${VERBOSE} >> map.ps" >> makemap.sh
      gmt psclip ${CLIP_POLY_FILE} ${CLIP_POLY_PEN} ${RJOK} ${VERBOSE} >> map.ps
      ;;

    clipoff)
echo "gmt psclip -C -K -O ${VERBOSE} >> map.ps" >> makemap.sh
      gmt psclip -C -K -O ${VERBOSE} >> map.ps
      ;;

    cmt)
      info_msg "Plotting focal mechanisms"

      if [[ $connectalternatelocflag -eq 1 ]]; then
        gawk < ${F_CMT}cmt_thrust.txt '{
          # If the event has an alternative position
          if ($12 != "none" && $13 != "none")  {
            print ">:" $1, $2, $3 ":" $12, $13, $15 >> "./cmt_alt_lines_thrust.xyz"
            print $12, $13, $15 >> "./cmt_alt_pts_thrust.xyz"
          } else {
          # Print the same start and end locations so that we don not mess up the number of lines in the file
            print ">:" $1, $2, $3 ":" $1, $2, $3  >> "./cmt_alt_lines_thrust.xyz"
            print $1, $2, $3 >> "./cmt_alt_pts_thrust.xyz"
          }
        }'
        gawk < ${F_CMT}cmt_normal.txt '{
          if ($12 != "none" && $13 != "none")  {  # Some events have no alternative position depending on format
            print ">:" $1, $2, $3 ":" $12, $13, $15 >> "./cmt_alt_lines_normal.xyz"
            print $12, $13, $15 >> "./cmt_alt_pts_normal.xyz"
          } else {
          # Print the same start and end locations so that we don not mess up the number of lines in the file
            print ">:" $1, $2, $3 ":" $1, $2, $3 >> "./cmt_alt_lines_normal.xyz"
            print $1, $2, $3 >> "./cmt_alt_pts_normal.xyz"
          }
        }'
        gawk < ${F_CMT}cmt_strikeslip.txt '{
          if ($12 != "none" && $13 != "none")  {  # Some events have no alternative position depending on format
            print ">:" $1, $2, $3 ":" $12, $13, $15 >> "./cmt_alt_lines_strikeslip.xyz"
            print $12, $13, $15 >> "./cmt_alt_pts_strikeslip.xyz"
          } else {
          # Print the same start and end locations so that we don not mess up the number of lines in the file
            print ">:" $1, $2, $3 ":" $1, $2, $3 >> "./cmt_alt_lines_strikeslip.xyz"
            print $1, $2, $3 >> "./cmt_alt_pts_strikeslip.xyz"
          }
        }'
        [[ -e cmt_alt_pts_thrust.xyz ]] && mv cmt_alt_pts_thrust.xyz ${F_CMT}
        [[ -e cmt_alt_pts_normal.xyz ]] && mv cmt_alt_pts_normal.xyz ${F_CMT}
        [[ -e cmt_alt_pts_strikeslip.xyz ]] && mv cmt_alt_pts_strikeslip.xyz ${F_CMT}

        [[ -e cmt_alt_lines_thrust.xyz ]] && mv cmt_alt_lines_thrust.xyz ${F_CMT}
        [[ -e cmt_alt_lines_normal.xyz ]] && mv cmt_alt_lines_normal.xyz ${F_CMT}
        [[ -e cmt_alt_lines_strikeslip.xyz ]] && mv cmt_alt_lines_strikeslip.xyz ${F_CMT}

        # Confirmed that the X,Y plot works with the .xyz format
        cat ${F_CMT}cmt_alt_lines_thrust.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps
        cat ${F_CMT}cmt_alt_lines_normal.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps
        cat ${F_CMT}cmt_alt_lines_strikeslip.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps

        gmt psxy ${F_CMT}cmt_alt_pts_thrust.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps
        gmt psxy ${F_CMT}cmt_alt_pts_normal.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps
        gmt psxy ${F_CMT}cmt_alt_pts_strikeslip.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps

      fi

      if [[ cmtthrustflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_THRUSTCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 ${F_CMT}cmt_thrust.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
      fi
      if [[ cmtnormalflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_NORMALCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 ${F_CMT}cmt_normal.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
      fi
      if [[ cmtssflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_SSCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 ${F_CMT}cmt_strikeslip.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
      fi
      ;;

    coasts)
      info_msg "Plotting coastlines"
      gmt pscoast $COAST_QUALITY -W1/$COAST_LINEWIDTH,$COAST_LINECOLOR $FILLCOASTS -A$COAST_KM2 $RJOK $VERBOSE >> map.ps
      # [[ $coastplotbordersflag -eq 1 ]] &&
      ;;

    contours)
      # Exclude options that are contained in the ${CONTOURGRIDVARS[@]} array
      AFLAG=-A$TOPOCONTOURINT
      CFLAG=-C$TOPOCONTOURINT
      SFLAG=-S$TOPOCONTOURSMOOTH

      for i in ${TOPOCONTOURVARS[@]}; do
        if [[ ${i:0:2} =~ "-A" ]]; then
          AFLAG=""
        fi
        if [[ ${i:0:2} =~ "-C" ]]; then
          CFLAG=""
        fi
        if [[ ${i:0:2} =~ "-S" ]]; then
          SFLAG=""
        fi
      done
      info_msg "Plotting topographic contours using $BATHY and contour options ${CONTOUROPTSTRING[@]}"
      gmt grdcontour $BATHY $AFLAG $CFLAG $SFLAG -W$TOPOCONTOURWIDTH,$TOPOCONTOURCOLOUR ${TOPOCONTOURVARS[@]} -Q${TOPOCONTOURMINPTS} $RJOK ${VERBOSE} >> map.ps

      ;;

    countries)
      gmt pscoast -E+l -Vn | gawk -F'\t' '{print $1}' > ${F_MAPELEMENTS}countries.txt
      NUMCOUNTRIES=$(wc -l < ${F_MAPELEMENTS}countries.txt | gawk '{print $1+0}')
      gmt makecpt -N -T0/${NUMCOUNTRIES}/1 -Cwysiwyg -Vn  | gawk '{print $2}' | sort -R > ${F_MAPELEMENTS}country_colors.txt
      paste ${F_MAPELEMENTS}countries.txt ${F_MAPELEMENTS}country_colors.txt | gawk '{printf("-E%s+g%s ", $1, $2)}' > ${F_MAPELEMENTS}combined.txt
      string=($(cat ${F_MAPELEMENTS}combined.txt))
      gmt pscoast ${string[@]} ${RJOK} ${VERBOSE} -t${COUNTRIES_TRANS} >> map.ps

      ;;

    countryborders)
      gmt pscoast ${BORDER_QUALITY} -N1/${BORDER_LINEWIDTH},${BORDER_LINECOLOR} $RJOK $VERBOSE >> map.ps
      ;;

    countrylabels)
      gawk -F, < $COUNTRY_CODES '{ print $3, $2, $4}' | gmt pstext -F+f${COUNTRY_LABEL_FONTSIZE},${COUNTRY_LABEL_FONT},${COUNTRY_LABEL_FONTCOLOR}+jLM $RJOK ${VERBOSE} >> map.ps
      ;;

    customtopo)
      if [[ $dontplottopoflag -eq 0 ]]; then
        info_msg "Plotting custom topography $CUSTOMBATHY"
        gmt grdimage $CUSTOMBATHY $GRID_PRINT_RES ${ILLUM} -C$TOPO_CPT -t$TOPOTRANS $RJOK $VERBOSE >> map.ps
        # -I+d
      else
        info_msg "Custom topo image plot suppressed using -ts"
      fi
      ;;

    eqlabel)

      # The goal is to create labels for selected events that don't extend off the
      # map area. Currently, the labels will overlap for closely spaced events.
      # There may be space for a more intelligent algorithm that tries to
      # avoid conflicts by limiting the number of events at the same 'latitude'

      FONTSTR=$(echo "${EQ_LABEL_FONTSIZE},${EQ_LABEL_FONT},${EQ_LABEL_FONTCOLOR}")

      if [[ -e $CMTFILE ]]; then
        if [[ $labeleqlistflag -eq 1 && ${#eqlistarray[@]} -ge 1 ]]; then
          for i in ${!eqlistarray[@]}; do
            grep -- "${eqlistarray[$i]}" $CMTFILE >> ${F_CMT}cmtlabel.sel
          done
        fi

        if [[ $labeleqmagflag -eq 1 ]]; then
          gawk < $CMTFILE -v minmag=$labeleqminmag '($13>=minmag) {print}'  >> ${F_CMT}cmtlabel.sel
        fi

        # 39 fields in cmt file. NR=texc NR-1=font

        gawk < ${F_CMT}cmtlabel.sel -v clon=$CENTERLON -v clat=$CENTERLAT -v font=$FONTSTR -v ctype=$CMTTYPE '{
          if (ctype=="ORIGIN") { lon=$8; lat=$9; depth=$10 } else { lon=$5; lat=$6; depth=$7 }
          id=$2
          timecode=$3
          mag=int($13*10)/10
          epoch=$4
          if (lon > clon) {
            hpos="R"
          } else {
            hpos="L"
          }
          if (lat < clat) {
            vpos="B"
          } else {
            vpos="T"
          }
          print lon, lat, depth, mag, timecode, id, epoch, font, vpos hpos
        }' > ${F_CMT}cmtlabel_pos.sel


        cat ${F_CMT}cmtlabel_pos.sel >> ${F_PROFILES}profile_labels.dat

        # GT Z112377A+usp0000rp1 1977-11-23T09:26:24 249098184 -67.69 -31.22 20.8 -67.77 -31.03 13 GCMT MLI 7.47968 3.059403 33 183 44 90 4 46 90 27 1.860 289 89 0.020 184 0 -1.870 94 1 27 1.855 0.008 -1.863 0.013 0.065 -0.119 23.7 10p,Helvetica,black TR

        # idcode event_code timecode epoch lon_centroid lat_centroid depth_centroid lon_origin lat_origin depth_origin author_centroid author_origin magnitude mantissa exponent strike1 dip1 rake1 strike2 dip2 rake2 exponent tval taz tinc nval naz ninc pval paz pinc exponent mrr mtt mpp mrt mrp mtp centroid_dt
        # GT S201509162318A+us20003k7w 2015-09-16T23:18:41 1442416721 -71.95 -31.79 35.7 -71.43 -31.56 28.4 GCMT PDEW 7.13429 1.513817 31 349 30 87 173 60 92 26 5.912 87 75 -0.538 352 1 -5.371 261 15 26 5.130 -0.637 -4.490 0.265 -2.850 0.641 10.3 10p,Helvetica,black TL

        # Lon lat depth mag timecode ID epoch font just
        # -72.105 -35.155 35 7.7 1928-12-01T04:06:17 iscgem908986 -1296528823 10p,Helvetica,black BL

        # lon lat font 0 just ID
        # -67.69	-31.22	10p,Helvetica,black	0	TR	Z112377A+usp0000rp1(7.5)

        # -67.69	-31.22	10p,Helvetica,black	0	TR	Z112377A+usp0000rp1(7.5)

        [[ $EQ_LABELFORMAT == "idmag" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, $6, $4 }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "datemag" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, tmp[1], $4 }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "dateid" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, $2, $8, 0, $9, tmp[1], $6 }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "id" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, $6 }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "date" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, tmp[1] }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "year" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, tmp2[1] }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "yearmag" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, $2, $8, 0, $9, tmp2[1], $4 }' >> ${F_CMT}cmt.labels
        [[ $EQ_LABELFORMAT == "mag" ]] && gawk  < ${F_CMT}cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n", $1, $2, $8, 0, $9, $4  }' >> ${F_CMT}cmt.labels

        uniq -u ${F_CMT}cmt.labels | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite -F+f+a+j -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      if [[ -e ${F_SEIS}eqs.txt ]]; then
        if [[ $labeleqlistflag -eq 1 && ${#eqlistarray[@]} -ge 1 ]]; then
          for i in ${!eqlistarray[@]}; do
            grep -- "${eqlistarray[$i]}" ${F_SEIS}eqs.txt >> ${F_SEIS}eqlabel.sel
          done
        fi
        if [[ $labeleqmagflag -eq 1 ]]; then
          gawk < ${F_SEIS}eqs.txt -v minmag=$labeleqminmag '($4>=minmag) {print}'  >> ${F_SEIS}eqlabel.sel
        fi

        # eqlabel_pos.sel is in the format:
        # lon lat depth mag timecode ID epoch font justification
        # -70.3007 -33.2867 108.72 4.1 2021-02-19T11:49:05 us6000diw5 1613706545 10p,Helvetica,black TL

        gawk < ${F_SEIS}eqlabel.sel -v clon=$CENTERLON -v clat=$CENTERLAT -v font=$FONTSTR '{
          if ($1 > clon) {
            hpos="R"
          } else {
            hpos="L"
          }
          if ($2 < clat) {
            vpos="B"
          } else {
            vpos="T"
          }
          print $1, $2, $3, int($4*10)/10, $5, $6, $7, font, vpos hpos
        }' > ${F_SEIS}eqlabel_pos.sel

        cat ${F_SEIS}eqlabel_pos.sel >> ${F_PROFILES}profile_labels.dat

        # eq.labels is in the format:
        # lon lat font 0 justification labeltext
        # -70.3007	-33.2867	10p,Helvetica,black	0	TL	us6000diw5(4.1)


        [[ $EQ_LABELFORMAT == "idmag"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, $6, $4  }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "datemag" ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, tmp[1], $4 }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "dateid"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, $2, $8, 0, $9, tmp[1], $6 }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "id"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, $6  }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "date"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, tmp[1] }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "year"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, tmp2[1] }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "yearmag"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ split($5,tmp,"T"); split(tmp[1],tmp2,"-"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, $2, $8, 0, $9, tmp2[1], $4 }' >> ${F_SEIS}eq.labels
        [[ $EQ_LABELFORMAT == "mag"   ]] && gawk  < ${F_SEIS}eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n", $1, $2, $8, 0, $9, $4  }' >> ${F_SEIS}eq.labels
        uniq -u ${F_SEIS}eq.labels | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite  -F+f+a+j -W0.5p,black $RJOK $VERBOSE >> map.ps

      fi
      ;;

    eqslip)
      gmt makecpt -T10/500/10 -Clajolla -Z ${VERBOSE} > ${F_CPT}slip.cpt
      EQSLIPTRANS=50
      # Find the maximum slip value in the submitted grid files
      cur_zmax=0
      for eqindex in $(seq 1 $numeqslip); do
        zrange=($(grid_zrange ${E_GRDLIST[$eqindex]} -C -Vn))
        cur_zmax=$(echo ${zrange[1]} $cur_zmax | gawk '{print ($1>$2)?$1:$2}')
      done

      for eqindex in $(seq 1 $numeqslip); do
        gmt grdclip ${E_GRDLIST[$eqindex]} -Sb10/NaN -Geqslip_${eqindex}.grd ${VERBOSE}
        gmt psclip ${E_CLIPLIST[$eqindex]} $RJOK ${VERBOSE} >> map.ps
        gmt grdimage -C${F_CPT}slip.cpt eqslip_${eqindex}.grd -t${EQSLIPTRANS} -Q $RJOK ${VERBOSE} >> map.ps
        gmt grdcontour eqslip_${eqindex}.grd -C50 -L50/${cur_zmax} -W0.35p,black  $RJOK ${VERBOSE} >> map.ps
        gmt psxy ${E_CLIPLIST[$eqindex]} -W0.2p,black,- ${RJOK} ${VERBOSE} >> map.ps
        gmt psclip -C $RJOK ${VERBOSE} >> map.ps
      done

      ;;

    execute)
      info_msg "Executing script $EXECUTEFILE. Be Careful!"
      source $EXECUTEFILE
      ;;

    extragps)
      info_msg "Plotting extra GPS dataset $EXTRAGPS"
      gmt psvelo $EXTRAGPS -W${EXTRAGPS_LINEWIDTH},${EXTRAGPS_LINECOLOR} -G${EXTRAGPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
      # Generate XY data for reference
      gawk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' $EXTRAGPS > extragps.xy
      ;;

    euler)
      info_msg "Plotting Euler pole derived velocities"

      # Plots Euler Pole velocities as requested. Either on the XY spaced grid or at GPS points.
      # Requires polesextract.txt to be present.
      # Requires gridswap.txt if we are not plotting at GPS stations
      # eulergrid.txt needs to be in lat lon order
      # currently uses full global datasets?

      if [[ $euleratgpsflag -eq 1 ]]; then    # If we are looking at GPS data (-wg)
        if [[ $plotgps -eq 1 ]]; then         # If the GPS data are regional
          cat $GPS_FILE | gawk  '{print $2, $1}' > ${F_PLATES}eulergrid.txt   # lon lat -> lat lon
          cat $GPS_FILE > gps.obs
        fi
        if [[ $tdefnodeflag -eq 1 ]]; then    # If the GPS data are from a TDEFNODE model
          gawk '{ if ($5==1 && $6==1) print $8, $9, $12, $17, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.obs   # lon lat order
          gawk '{ if ($5==1 && $6==1) print $9, $8 }' ${TDPATH}${TDMODEL}.vsum > ${F_PLATES}eulergrid.txt  # lat lon order
          cat ${TDMODEL}.obs > gps.obs
        fi
      else
        cp gridswap.txt ${F_PLATES}eulergrid.txt  # lat lon order
      fi

      if [[ $eulervecflag -eq 1 ]]; then   # If we specified our own Euler Pole on the command line
        gawk -f $EULERVEC_AWK -v eLat_d1=$eulerlat -v eLon_d1=$eulerlon -v eV1=$euleromega -v eLat_d2=0 -v eLon_d2=0 -v eV2=0 ${F_PLATES}eulergrid.txt > ${F_PLATES}gridvelocities.txt
      fi
      if [[ $twoeulerflag -eq 1 ]]; then   # If we specified two plates (moving plate vs ref plate) via command line
        lat1=`grep "^$eulerplate1\s" < ${F_PLATES}polesextract.txt | gawk  '{print $2}'`
      	lon1=`grep "^$eulerplate1\s" < ${F_PLATES}polesextract.txt | gawk  '{print $3}'`
      	rate1=`grep "^$eulerplate1\s" < ${F_PLATES}polesextract.txt | gawk  '{print $4}'`

        lat2=`grep "^$eulerplate2\s" < ${F_PLATES}polesextract.txt | gawk  '{print $2}'`
      	lon2=`grep "^$eulerplate2\s" < ${F_PLATES}polesextract.txt | gawk  '{print $3}'`
      	rate2=`grep "^$eulerplate2\s" < ${F_PLATES}polesextract.txt | gawk  '{print $4}'`
        [[ $narrateflag -eq 1 ]] && echo Plotting velocities of $eulerplate1 [ $lat1 $lon1 $rate1 ] relative to $eulerplate2 [ $lat2 $lon2 $rate2 ]
        # Should add some sanity checks here?
        gawk -f $EULERVEC_AWK -v eLat_d1=$lat1 -v eLon_d1=$lon1 -v eV1=$rate1 -v eLat_d2=$lat2 -v eLon_d2=$lon2 -v eV2=$rate2 ${F_PLATES}eulergrid.txt > ${F_PLATES}gridvelocities.txt
      fi

      # If we are plotting only the residuals of GPS velocities vs. estimated site velocity from Euler pole (gridvelocities.txt)
      if [[ $ploteulerobsresflag -eq 1 ]]; then
         info_msg "plotting residuals of block motion and gps velocities"
         paste gps.obs ${F_PLATES}gridvelocities.txt | gawk  '{print $1, $2, $10-$3, $11-$4, 0, 0, 1, $8 }' > gpsblockres.txt   # lon lat order, mm/yr
         # Scale at print is OK
         gawk -v gpsscalefac=$(echo "$VELSCALE * $WRESSCALE" | bc -l) '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' gpsblockres.txt > grideulerres.pvec
         gmt psxy -SV$ARROWFMT -W0p,green -Ggreen grideulerres.pvec $RJOK $VERBOSE >> map.ps  # Plot the residuals
      fi

      paste -d ' ' ${F_PLATES}eulergrid.txt ${F_PLATES}gridvelocities.txt | gawk  '{print $2, $1, $3, $4, 0, 0, 1, "ID"}' > ${F_PLATES}gridplatevecs.txt
      cat ${F_PLATES}gridplatevecs.txt | gawk  -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }'  > ${F_PLATES}grideuler.pvec
      gmt psxy -SV$ARROWFMT -W0p,red -Gred ${F_PLATES}grideuler.pvec $RJOK $VERBOSE >> map.ps
      ;;

    gcdm)
      gmt grdimage $GCDMDATA $GRID_PRINT_RES -C$GCDM_CPT $RJOK $VERBOSE >> map.ps
      ;;

    gebcotid)
      gmt makecpt -Ccategorical -T1/100/1 > gebco_tid.cpt
      gmt grdimage $GEBCO20_TID $GRID_PRINT_RES -t50 -Cgebco_tid.cpt $RJOK $VERBOSE >> map.ps

      ;;
    gemfaults)
      info_msg "Plotting GEM active faults"
      gmt psxy $GEMFAULTS -W$AFLINEWIDTH,$AFLINECOLOR $RJOK $VERBOSE >> map.ps
      ;;

    userline)
      info_msg "Plotting line dataset $current_userlinefilenumber"
      # gmt psxy ${USERLINEDATAFILE[$current_userlinefilenumber]} $RJOK $VERBOSE >> map.ps
      gmt psxy ${USERLINEDATAFILE[$current_userlinefilenumber]} -W${USERLINEWIDTH_arr[$current_userlinefilenumber]},${USERLINECOLOR_arr[$current_userlinefilenumber]} $RJOK $VERBOSE >> map.ps
      current_userlinefilenumber=$(echo "$current_userlinefilenumber + 1" | bc -l)
      ;;
      #
      #
      #
      # info_msg "Plotting GIS line data $GISLINEFILE"
      # gmt psxy $GISLINEFILE -W$GISLINEWIDTH,$GISLINECOLOR $RJOK $VERBOSE >> map.ps

    gps)
      info_msg "Plotting GPS"
		  ##### Plot GPS velocities if possible (requires Kreemer plate to have same ID as model reference plate, or manual specification)
      if [[ $tdefnodeflag -eq 0 ]]; then
  			if [[ -e $GPS_FILE ]]; then
  				info_msg "GPS data is taken from $GPS_FILE and are plotted relative to plate $REFPLATE in that model"

          gawk < $GPS_FILE -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
            if ($1>180) { lon=$1-360 } else { lon=$1 }
            if (((lon <= maxlon && lon >= minlon) || (lon+360 <= maxlon && lon+360 >= minlon)) && $2 >= minlat && $2 <= maxlat) {
              print
            }
          }' > gps.txt
  				gmt psvelo gps.txt -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
          # generate XY data
          gawk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' < gps.txt > gps.xy
          GPSMAXVEL=$(gawk < gps.xy 'BEGIN{ maxv=0 } {if ($4>maxv) { maxv=$4 } } END {print maxv}')
    		else
  				info_msg "No relevant GPS data available for given plate model ($GPS_FILE)"
  				GPS_FILE="None"
  			fi
      fi
			;;

    graticule)
      gmt psbasemap "${BSTRING[@]}" ${SCALECMD} $RJOK $VERBOSE >> map.ps
      ;;

    grav)
      if [[ $clipgravflag -eq 1 ]]; then
        gmt grdcut $GRAVDATA -G${F_GRAV}grav.nc -R -J $VERBOSE
      fi
      gmt grdimage $GRAVDATA $GRID_PRINT_RES -C$GRAV_CPT -t$GRAVTRANS $RJOK $VERBOSE >> map.ps
      ;;

    resgrav)
      if [[ -e ./resgrav/grid_residual.nc ]]; then
        gmt grdimage ./resgrav/grid_residual.nc $GRID_PRINT_RES -Q -C${TECTOPLOTDIR}"CPT/grav2.cpt" $RJOK $VERBOSE >> map.ps
        [[ $GRAVCONTOURFLAG -eq 1 ]] && gmt grdcontour ./resgrav/grid_residual.nc -W0.3p,white,- -C50 $RJOK ${VERBOSE} >> map.ps
      fi
      ;;

#### CHECK CAREFULLY
    grid)
      # Plot the gridded plate velocity field
      # Requires *_platevecs.txt to plot velocity field
      # Input data are in mm/yr
      info_msg "Plotting grid arrows"

      LONDIFF=$(echo "$MAXLON - $MINLON" | bc -l)
      pwnum=$(echo "5p" | gawk  '{print $1+0}')
      POFFS=$(echo "$LONDIFF/8*1/72*$pwnum*3/2" | bc -l)
      GRIDMAXVEL=0

# Works with ${F_PLATES}?
      if [[ $plotplates -eq 1 ]]; then
        for i in ${F_PLATES}*_platevecs.txt; do
          # Use azimuth/velocity data in platevecs.txt to infer VN/VE
          gawk < $i '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' > ${i}.pvec
          GRIDMAXVEL=$(gawk < ${i}.pvec -v prevmax=$GRIDMAXVEL 'BEGIN {max=prevmax} {if ($4 > max) {max=$4} } END {print max}' )
          gmt psvelo ${i} -W0p,$PLATEVEC_COLOR@$PLATEVEC_TRANS -G$PLATEVEC_COLOR@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
          [[ $PLATEVEC_TEXT_PLOT -eq 1 ]] && gawk  < ${i}.pvec -v poff=$POFFS '($4 != 0) { print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, sprintf("%d", $4) }' | gmt pstext -F+f${PLATEVEC_TEXT_SIZE},${PLATEVEC_TEXT_FONT},${PLATEVEC_TEXT_COLOR}+jCM $RJOK $VERBOSE  >> map.ps
        done
      fi
      ;;

    gridcontour)

      # Exclude options that are contained in the ${CONTOURGRIDVARS[@]} array
      AFLAG=-A$CONTOURINTGRID
      CFLAG=-C$CONTOURINTGRID
      SFLAG=-S$GRIDCONTOURSMOOTH

      for i in ${CONTOURGRIDVARS[@]}; do
        if [[ ${i:0:2} =~ "-A" ]]; then
          AFLAG=""
        fi
        if [[ ${i:0:2} =~ "-C" ]]; then
          CFLAG=""
        fi
        if [[ ${i:0:2} =~ "-S" ]]; then
          SFLAG=""
        fi
      done

      gmt grdcontour $CONTOURGRID $AFLAG $CFLAG $SFLAG -W$GRIDCONTOURWIDTH,$GRIDCONTOURCOLOUR ${CONTOURGRIDVARS[@]} $RJOK ${VERBOSE} >> map.ps
      ;;

    image)
      gdal_translate -q -of GTiff -co COMPRESS=JPEG -co TILED=YES ${IMAGENAME} im.tiff
      # gdal_translate -b 1 -of GMT im.tiff im_red.grd
      # gdal_translate -b 2 -of GMT im.tiff im_green.grd
      # gdal_translate -b 3 -of GMT im.tiff im_blue.grd

      info_msg "gmt im.tiff "${IMAGEARGS}" $RJOK $VERBOSE >> map.ps"
      # gmt image "$IMAGENAME" "${IMAGEARGS}" $RJOK $VERBOSE >> map.ps

      gmt grdimage im.tiff -Q $RJOK $VERBOSE >> map.ps

      ;;

    inset)
        # echo "$MINLON $MINLAT" > aoi_box.txt
        # echo "$MINLON $MAXLAT" >> aoi_box.txt
        # echo "$MAXLON $MAXLAT" >> aoi_box.txt
        # echo "$MAXLON $MINLAT" >> aoi_box.txt
        # echo "$MINLON $MINLAT" >> aoi_box.txt

        gmt_init_tmpdir
        gmt pscoast -Rg -JG${CENTERLON}/${CENTERLAT}/${INSET_DEGWIDTH}/${INSET_SIZE} -Xa${INSET_XOFF} -Ya${INSET_YOFF} -Bg -Df -A5000 -Ggray -Swhite -O -K ${VERBOSE} >> map.ps
        gmt psxy ${F_MAPELEMENTS}"bounds.txt" -W${INSET_AOI_LINEWIDTH},${INSET_AOI_LINECOLOR} -Xa${INSET_XOFF} -Ya${INSET_YOFF} ${VERBOSE} $RJOK >> map.ps
        gmt_remove_tmpdir
        ;;

    kinsv)
      # Plot the slip vectors for focal mechanism nodal planes
      info_msg "Plotting kinematic slip vectors"

      if [[ kinthrustflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.4p,${NP1_COLOR} -G${NP1_COLOR} ${F_KIN}thrust_gen_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.4p,${NP2_COLOR} -G${NP2_COLOR} ${F_KIN}thrust_gen_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      if [[ kinnormalflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.7p,green -Ggreen ${F_KIN}normal_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.5p,green -Ggreen ${F_KIN}normal_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      if [[ kinssflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.7p,blue -Gblue ${F_KIN}strikeslip_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.5p,blue -Gblue ${F_KIN}strikeslip_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      ;;

    kingeo)
      info_msg "Plotting kinematic data"
      # Currently only plotting strikes and dips of thrust mechanisms
      if [[ kinthrustflag -eq 1 ]]; then
        # Plot dip line of NP1
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite ${F_KIN}thrust_gen_slip_vectors_np1_downdip.txt $RJOK $VERBOSE >> map.ps
        # Plot strike line of NP1
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite ${F_KIN}thrust_gen_slip_vectors_np1_str.txt $RJOK $VERBOSE >> map.ps
        # Plot dip line of NP2
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray ${F_KIN}thrust_gen_slip_vectors_np2_downdip.txt $RJOK $VERBOSE >> map.ps
        # Plot strike line of NP2
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray ${F_KIN}thrust_gen_slip_vectors_np2_str.txt $RJOK $VERBOSE >> map.ps
      fi
      plottedkinsd=1
      ;;

    litho1_depth)
      # This is super slow and annoying.
      deginc=0.1
      rm -f litho1_${LITHO1_DEPTH}.xyz
      info_msg "Plotting LITHO1.0 depth slice (0.1 degree resolution) at depth=$LITHO1_DEPTH"
      for lat in $(seq $MINLAT $deginc $MAXLAT); do
        echo $MINLAT - $lat - $MAXLAT
        for lon in $(seq $MINLON $deginc $MAXLON); do
          access_litho -p $lat $lon -d $LITHO1_DEPTH  -l ${LITHO1_LEVEL} 2>/dev/null | gawk  -v lat=$lat -v lon=$lon -v extfield=$LITHO1_FIELDNUM '{
            print lon, lat, $(extfield)
          }' >> litho1_${LITHO1_DEPTH}.xyz
        done
      done
      gmt_init_tmpdir
      gmt xyz2grd litho1_${LITHO1_DEPTH}.xyz -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -fg -I${deginc}d -Glitho1_${LITHO1_DEPTH}.nc $VERBOSE
      gmt_remove_tmpdir
      gmt grdimage litho1_${LITHO1_DEPTH}.nc $GRID_PRINT_RES -C${LITHO1_CPT} $RJOK $VERBOSE >> map.ps
      ;;

    mag)
      info_msg "Plotting magnetic data"
      gmt grdimage $EMAG_V2 $GRID_PRINT_RES -C$MAG_CPT -t$MAGTRANS $RJOK -Q $VERBOSE >> map.ps
      ;;

    mapscale)
      # The values of SCALECMD will be set by the scale) section
      SCALECMD="-Lg${SCALEREFLON}/${SCALEREFLAT}+c${SCALELENLAT}+w${SCALELEN}+l+at+f"
      ;;

    aprofcodes)
      grep "[$APROFCODES]" ${F_MAPELEMENTS}aprof_database.txt > ${F_MAPELEMENTS}aprof_codes.txt
      gmt pstext ${F_MAPELEMENTS}aprof_codes.txt -F+f14p,Helvetica,black $RJOK $VERBOSE >> map.ps
      ;;

    mprof)

      if [[ $sprofflag -eq 1 || $aprofflag -eq 1 || $cprofflag -eq 1 ]]; then
        info_msg "Updating mprof to use a newly generated sprof.control file"
        PROFILE_WIDTH_IN="7i"
        PROFILE_HEIGHT_IN="2i"
        PROFILE_X="0"
        PROFILE_Y="-3i"
        MPROFFILE="sprof.control"

        echo "@ auto auto ${SPROF_MINELEV} ${SPROF_MAXELEV} ${ALIGNXY_FILE}" > sprof.control
        if [[ $plotcustomtopo -eq 1 ]]; then
          info_msg "Adding custom topo grid to sprof"
          echo "S $CUSTOMGRIDFILE 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES}" >> sprof.control
        elif [[ -e $BATHY ]]; then
          info_msg "Adding topography/bathymetry from map to sprof as swath and top tile"
          echo "S ${F_TOPO}dem.nc 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES}" >> sprof.control
          echo "G ${F_TOPO}dem.nc 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES} ${TOPO_CPT}" >> sprof.control
        fi
        if [[ -e ${F_GRAV}grav.nc ]]; then
          info_msg "Adding gravity grid to sprof as swath"
          echo "S ${F_GRAV}grav.nc 1 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES}" >> sprof.control
        fi
        if [[ -e ${F_SEIS}eqs.txt ]]; then
          info_msg "Adding eqs to sprof as seis-xyz"
          echo "E ${F_SEIS}eqs.txt ${SPROFWIDTH} -1 -W0.2p,black -C$SEISDEPTH_CPT" >> sprof.control
        fi
        if [[ -e ${F_CMT}cmt.dat ]]; then
          info_msg "Adding cmt to sprof"
          echo "C ${F_CMT}cmt.dat ${SPROFWIDTH} -1 -L0.25p,black -Z$SEISDEPTH_CPT" >> sprof.control
        fi
        if [[ -e ${F_VOLC}volcanoes.dat ]]; then
          # We need to sample the DEM at the volcano point locations, or else use 0 for elevation.
          info_msg "Adding volcanoes to sprof as xyz"
          echo "X ${F_VOLC}volcanoes.dat ${SPROFWIDTH} 0.001 -St0.1i -W0.1p,black -Gred" >> sprof.control
        fi
        if [[ -e ${F_PROFILES}profile_labels.dat ]]; then
          info_msg "Adding profile labels to sprof as xyz [lon/lat/km]"
          echo "B ${F_PROFILES}profile_labels.dat ${SPROFWIDTH} 1 ${FONTSTR}"  >> sprof.control
        fi

        if [[ $plotslab2 -eq 1 ]]; then
          if [[ ! $numslab2inregion -eq 0 ]]; then
            for i in $(seq 1 $numslab2inregion); do
              info_msg "Adding slab grid ${slab2inregion[$i] to sprof}"
              gridfile=$(echo ${SLAB2_GRIDDIR}${slab2inregion[$i]}.grd | sed 's/clp/dep/')
              echo "T $gridfile -1 5k -W1p+cl -C$SEISDEPTH_CPT" >> sprof.control
            done
          fi
        fi
        if [[ $sprofflag -eq 1 ]]; then
          echo "P P1 black N N ${SPROFLON1} ${SPROFLAT1} ${SPROFLON2} ${SPROFLAT2}" >> sprof.control
        fi
        if [[ $cprofflag -eq 1 ]]; then
          cat ${F_PROFILES}cprof_profs.txt >> sprof.control
        fi
        if [[ $aprofflag -eq 1 ]]; then
          cat ${F_PROFILES}aprof_profs.txt >> sprof.control
        fi
      fi

      info_msg "Drawing profile(s)"

      PSFILE=$(abs_path map.ps)

      cp gmt.history gmt.history.preprofile
      . $MPROFILE_SH_SRC
      cp gmt.history.preprofile gmt.history

      # Plot the profile lines with the assigned color on the map
      # echo TRACKFILE=...$TRACKFILE

      k=$(wc -l < $TRACKFILE | gawk  '{print $1}')
      for ind in $(seq 1 $k); do
        FIRSTWORD=$(head -n ${ind} $TRACKFILE | tail -n 1 | gawk  '{print $1}')
        # echo FIRSTWORD all=${FIRSTWORD}
        # if [[ ${FIRSTWORD:0:1} != "#" && ${FIRSTWORD:0:1} != "$" && ${FIRSTWORD:0:1} != "%" && ${FIRSTWORD:0:1} != "^" && ${FIRSTWORD:0:1} != "@"  && ${FIRSTWORD:0:1} != ":"  && ${FIRSTWORD:0:1} != ">" ]]; then

        if [[ ${FIRSTWORD:0:1} == "P" ]]; then
          # echo FIRSTWORD=${FIRSTWORD}
          COLOR=$(head -n ${ind} $TRACKFILE | tail -n 1 | gawk  '{print $3}')
          # echo $FIRSTWORD $ind $k
          head -n ${ind} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 | gmt psxy $RJOK -W${PROFILE_TRACK_WIDTH},${COLOR} >> map.ps
          # info_msg "is it this"
          head -n ${ind} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 | head -n 1 | gmt psxy -Si0.1i -W0.5p,${COLOR} -G${COLOR} -Si0.1i $RJOK  >> map.ps
          head -n ${ind} $TRACKFILE | tail -n 1 | cut -f 6- -d ' ' | xargs -n 2 | sed '1d' | gmt psxy -Si0.1i -W0.5p,${COLOR} -Si0.1i $RJOK  >> map.ps
          # info_msg "here"
        fi
      done

      # Plot the gridtrack tracks, for debugging
      # for track_file in *_profiletable.txt; do
      #    # echo $track_file
      #   gmt psxy $track_file -W0.15p,black $RJOK $VERBOSE >> map.ps
      # done

      # for proj_pts in projpts*;  do
      #   gmt psxy $proj_pts -Sc0.03i -Gred -W0.15p,black $RJOK $VERBOSE >> map.ps
      # done


      # Plot the buffers around the polylines, for debugging
      # if [[ -e buf_poly.txt ]]; then
      #   info_msg "Plotting buffers"
      #   gmt psxy buf_poly.txt -W0.5p,red $RJOK $VERBOSE >> map.ps
      # fi

      # end_points.txt contains lines with the origin point and azimuth of each plotted profile
      # 110 -2 281.365 0.909091 0/0/0
      # Lon Lat Azimuth Width(deg) R/G/Bcolor  ID

      # If we have plotted profiles, we need to plot decorations that accurately
      # show the maximum swath width. This could be extended to plot multiple
      # swath widths if they exist, but for now we go with the maximum one.

      if [[ -e ${F_PROFILES}end_points.txt ]]; then
        while read d; do
          p=($(echo $d))
          # echo END POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} - 90" | bc -l)
          WIDTHKM=$(echo "${p[3]} / 2" | bc -l) # Half width
          SUBWIDTH=$(echo "${p[3]} / 110 * 0.1" | bc -l)
          echo ">" >> ${F_PROFILES}end_profile_lines.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}k > endpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}k > endpoint2.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${WIDTHKM}k -L0/${WIDTHKM} | tail -n 1 | gawk  '{print $1, $2}' > ${F_PROFILES}endpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${WIDTHKM}k -L0/${WIDTHKM} | tail -n 1 | gawk  '{print $1, $2}' > ${F_PROFILES}endpoint2.txt
          cat ${F_PROFILES}endpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >> ${F_PROFILES}end_profile_lines.txt
          cat ${F_PROFILES}endpoint1.txt >> ${F_PROFILES}end_profile_lines.txt
          echo "${p[0]} ${p[1]}" >> ${F_PROFILES}end_profile_lines.txt
          cat ${F_PROFILES}endpoint2.txt >> ${F_PROFILES}end_profile_lines.txt
          cat ${F_PROFILES}endpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >> ${F_PROFILES}end_profile_lines.txt
        done < ${F_PROFILES}end_points.txt

        while read d; do
          p=($(echo $d))
          # echo START POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} + 90" | bc -l)
          WIDTHKM=$(echo "${p[3]} / 2" | bc -l) # Half width
          SUBWIDTH=$(echo "${p[3]}/110 * 0.1" | bc -l)
          echo ">" >>  ${F_PROFILES}start_profile_lines.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${WIDTHKM}k -L0/${WIDTHKM}k | tail -n 1 | gawk  '{print $1, $2}' > ${F_PROFILES}startpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${WIDTHKM}k -L0/${WIDTHKM}k | tail -n 1 | gawk  '{print $1, $2}' > ${F_PROFILES}startpoint2.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}d >  startpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}d >  startpoint2.txt
          cat  ${F_PROFILES}startpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  ${F_PROFILES}start_profile_lines.txt
          cat  ${F_PROFILES}startpoint1.txt >>  ${F_PROFILES}start_profile_lines.txt
          echo "${p[0]} ${p[1]}" >> ${F_PROFILES}start_profile_lines.txt
          cat  ${F_PROFILES}startpoint2.txt >>  ${F_PROFILES}start_profile_lines.txt
          cat  ${F_PROFILES}startpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  ${F_PROFILES}start_profile_lines.txt
        done < ${F_PROFILES}start_points.txt

        gmt psxy ${F_PROFILES}end_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
        gmt psxy ${F_PROFILES}start_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      if [[ -e ${F_PROFILES}mid_points.txt ]]; then
        while read d; do
          p=($(echo $d))
          # echo MID POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} + 90" | bc -l)
          FOREAZ2=$(echo "${p[2]} - 90" | bc -l)
          WIDTHKM=$(echo "${p[3]} / 2" | bc -l) # Half width
          SUBWIDTH=$(echo "${p[3]}/110 * 0.1" | bc -l)
          echo ">" >>  ${F_PROFILES}mid_profile_lines.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${WIDTHKM}k -L0/${WIDTHKM}k | tail -n 1 | gawk  '{print $1, $2}' >  ${F_PROFILES}midpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${WIDTHKM}k -L0/${WIDTHKM}k | tail -n 1 | gawk  '{print $1, $2}' > ${F_PROFILES}midpoint2.txt

          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}d >  midpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}d >  midpoint2.txt

          cat  ${F_PROFILES}midpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  ${F_PROFILES}mid_profile_lines.txt
          cat  ${F_PROFILES}midpoint1.txt | gmt vector -Tt${FOREAZ2}/${SUBWIDTH}d >>  ${F_PROFILES}mid_profile_lines.txt
          cat  ${F_PROFILES}midpoint1.txt >>  ${F_PROFILES}mid_profile_lines.txt
          echo "${p[0]} ${p[1]}" >>  ${F_PROFILES}mid_profile_lines.txt
          cat  ${F_PROFILES}midpoint2.txt >>  ${F_PROFILES}mid_profile_lines.txt
          cat  ${F_PROFILES}midpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  ${F_PROFILES}mid_profile_lines.txt
          cat  ${F_PROFILES}midpoint2.txt | gmt vector -Tt${FOREAZ2}/${SUBWIDTH}d >>  ${F_PROFILES}mid_profile_lines.txt
        done <  ${F_PROFILES}mid_points.txt

        gmt psxy ${F_PROFILES}mid_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      # Plot the intersection point of the profile with the 0-distance datum line as triangle
      if [[ -e ${F_PROFILES}all_intersect.txt ]]; then
        info_msg "Plotting intersection of tracks with zeroline"
        gmt psxy ${F_PROFILES}xy_intersect.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
        gmt psxy ${F_PROFILES}all_intersect.txt -St0.1i -Gwhite -W0.7p,black $RJOK $VERBOSE >> map.ps
      fi

      # This is used to offset the profile name so it doesn't overlap the track line
      PTEXT_OFFSET=$(echo ${PROFILE_TRACK_WIDTH} | gawk  '{ print ($1+0)*2 "p" }')

      if [[ $plotprofiletitleflag -eq 1 ]]; then
        while read d; do
          p=($(echo $d))
          # echo "${p[0]},${p[1]},${p[5]}  angle ${p[2]}"
          echo "${p[0]},${p[1]},${p[5]}" | gmt pstext -A -Dj${PTEXT_OFFSET} -F+f${PROFILE_FONT_LABEL_SIZE},Helvetica+jRB+a$(echo "${p[2]}-90" | bc -l) $RJOK $VERBOSE >> map.ps
        done < ${F_PROFILES}start_points.txt
      fi
      ;;

    oceanage)
      gmt grdimage $OC_AGE $GRID_PRINT_RES -C$OC_AGE_CPT -Q -t$OC_TRANS $RJOK $VERBOSE >> map.ps
      ;;

    plateazdiff)
      info_msg "Drawing plate azimuth differences"

      # This should probably be changed to obliquity
      # Plot the azimuth of relative plate motion across the boundary
      # azdiffpts_len.txt should be replaced with id_pts_euler.txt
      [[ $plotplates -eq 1 ]] && gawk  < ${F_PLATES}azdiffpts_len.txt -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
        if ($1 != minlon && $1 != maxlon && $2 != minlat && $2 != maxlat) {
          print $1, $2, $3
        }
      }' | gmt psxy -C$CPTDIR"cycleaz.cpt" -t0 -Sc${AZDIFFSCALE}/0 $RJOK $VERBOSE >> map.ps

# Break this for now as it is secondary and should be a different option
      # mkdir az_histogram
      # cd az_histogram
      #   gawk < ../azdiffpts_len.txt '{print $3, $4}' | gmt pshistogram -C$CPTDIR"cycleaz.cpt" -JX5i/2i -R-180/180/0/1 -Z0+w -T2 -W0.1p -I -Ve > azdiff_hist_range.txt
      #   ADR4=$(gawk < azdiff_hist_range.txt '{print $4*1.1}')
      #   gawk < ../azdiffpts_len.txt '{print $3, $4}' | gmt pshistogram -C$CPTDIR"cycleaz.cpt" -JX5i/2i -R-180/180/0/$ADR4 -BNESW+t"$POLESRC $MINLON/$MAXLON/$MINLAT/$MAXLAT" -Bxa30f10 -Byaf -Z0+w -T2 -W0.1p > ../az_histogram.ps
      # cd ..
      # gmt psconvert -Tf -A0.3i az_histogram.ps
      ;;

    platediffv)
      # Plot velocity across plate boundaries
      # Excludes plotting of adjacent points closer than a cutoff distance (Degrees).
      # Plots any point with [lat,lon] values that have already been plotted.
      # input data are in what m/yr
      # Convert to PSVELO?

      info_msg "Drawing plate relative velocities"
      info_msg "velscale=$VELSCALE"
      MINVV=0.15

        gawk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
          # If we haven not seen this point before
          if (seenx[$1,$2] == 0) {
              seenx[$1,$2]=1
              newdist = ($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty);
              if (newdist > cutoff) {
                lastx=$1
                lasty=$2
                doprint[$1,$2]=1
                print
              }
            } else {   # print any point that we have already printed
              if (doprint[$1,$2]==1) {
                print
              }
            }
          }' < ${F_PLATES}paz1normal.txt > ${F_PLATES}paz1normal_cutoff.txt

        gawk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
          # If we haven not seen this point before
          if (seenx[$1,$2] == 0) {
              seenx[$1,$2]=1
              newdist = ($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty);
              if (newdist > cutoff) {
                lastx=$1
                lasty=$2
                doprint[$1,$2]=1
                print
              }
            } else {   # print any point that we have already printed
              if (doprint[$1,$2]==1) {
                print
              }
            }
          }' < ${F_PLATES}paz1thrust.txt > ${F_PLATES}paz1thrust_cutoff.txt

          gawk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
            # If we haven not seen this point before
            if (seenx[$1,$2] == 0) {
                seenx[$1,$2]=1
                newdist = ($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty);
                if (newdist > cutoff) {
                  lastx=$1
                  lasty=$2
                  doprint[$1,$2]=1
                  print
                }
              } else {   # print any point that we have already printed
                if (doprint[$1,$2]==1) {
                  print
                }
              }
            }' < ${F_PLATES}paz1ss1.txt > ${F_PLATES}paz1ss1_cutoff.txt

            gawk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
              # If we haven not seen this point before
              if (seenx[$1,$2] == 0) {
                  seenx[$1,$2]=1
                  newdist = ($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty);
                  if (newdist > cutoff) {
                    lastx=$1
                    lasty=$2
                    doprint[$1,$2]=1
                    print
                  }
                } else {   # print any point that we have already printed
                  if (doprint[$1,$2]==1) {
                    print
                  }
                }
              }' < ${F_PLATES}paz1ss2.txt > ${F_PLATES}paz1ss2_cutoff.txt

        # If the scale is too small, normal opening will appear to be thrusting due to arrowhead offset...!
        # Set a minimum scale for vectors to avoid improper plotting of arrowheads

        LONDIFF=$(echo "$MAXLON - $MINLON" | bc -l)
        pwnum=$(echo $PLATELINE_WIDTH | gawk '{print $1+0}')
        POFFS=$(echo "$LONDIFF/8*1/72*$pwnum*3/2" | bc -l)

        # Old formatting works but isn't exactly great

        # We plot the half-velocities across the plate boundaries instead of full relative velocity for each plate

        gawk < ${F_PLATES}paz1normal_cutoff.txt -v poff=$POFFS -v minv=$MINVV -v gpsscalefac=$VELSCALE '{ if ($4<minv && $4 != 0) {print $1 + sin($3*3.14159265358979/180)*poff, $2 + cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2} else {print $1 + sin($3*3.14159265358979/180)*poff, $2 + cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2}}' | gmt psxy -SV"${PVFORMAT}" -W0p,$PLATEARROW_COLOR@$PLATEARROW_TRANS -G$PLATEARROW_COLOR@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
        gawk < ${F_PLATES}paz1thrust_cutoff.txt -v poff=$POFFS -v minv=$MINVV -v gpsscalefac=$VELSCALE '{ if ($4<minv && $4 != 0) {print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2} else {print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2}}' | gmt psxy -SVh"${PVFORMAT}" -W0p,$PLATEARROW_COLOR@$PLATEARROW_TRANS -G$PLATEARROW_COLOR@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps

        # Shift symbols based on azimuth of line segment to make nice strike-slip half symbols
        gawk < ${F_PLATES}paz1ss1_cutoff.txt -v poff=$POFFS -v gpsscalefac=$VELSCALE '{ if ($4!=0) { print $1 + cos($3*3.14159265358979/180)*poff, $2 - sin($3*3.14159265358979/180)*poff, $3, 0.1/2}}' | gmt psxy -SV"${PVHEAD}"+r+jb+m+a33+h0 -W0p,red@$PLATEARROW_TRANS -Gred@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
        gawk < ${F_PLATES}paz1ss2_cutoff.txt -v poff=$POFFS -v gpsscalefac=$VELSCALE '{ if ($4!=0) { print $1 - cos($3*3.14159265358979/180)*poff, $2 - sin($3*3.14159265358979/180)*poff, $3, 0.1/2 }}' | gmt psxy -SV"${PVHEAD}"+l+jb+m+a33+h0 -W0p,yellow@$PLATEARROW_TRANS -Gyellow@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
      ;;

    plateedge)
      info_msg "Drawing plate edges"

      # Plot edges of plates
      gmt psxy $EDGES -W$PLATELINE_WIDTH,$PLATELINE_COLOR@$PLATELINE_TRANS $RJOK $VERBOSE >> map.ps
      ;;

    platelabel)
      info_msg "Labeling plates"

      # Label the plates if we calculated the centroid locations
      # Remove the trailing _N from all plate labels
      [[ $plotplates -eq 1 ]] && gawk  < ${F_PLATES}map_labels.txt -F, '{print $1, $2, substr($3, 1, length($3)-2)}' | gmt pstext -C0.1+t -F+f$PLATELABEL_SIZE,Helvetica,$PLATELABEL_COLOR+jCB $RJOK $VERBOSE  >> map.ps
      ;;

    platepolycolor_all)
        plate_files=($(ls ${F_PLATES}*.pldat 2>/dev/null))
        if [[ ${#plate_files} -gt 0 ]]; then
          gmt makecpt -T0/${#plate_files[@]}/1 -Cwysiwyg ${VERBOSE} | awk '{print $2}' | head -n ${#plate_files[@]} > ${F_PLATES}platecolor.dat
          P_COLORLIST=($(cat ${F_PLATES}platecolor.dat))
          this_index=0
          for p_example in ${plate_files[@]}; do
            # echo gmt psxy ${p_example} -G"${P_COLORLIST[$this_index]}" -t${P_POLYTRANS} $RJOK ${VERBOSE}
            gmt psxy ${p_example} -G"${P_COLORLIST[$this_index]}" -t${P_POLYTRANS} $RJOK ${VERBOSE} >> map.ps
            this_index=$(echo "$this_index + 1" | bc)
          done
        else
          info_msg "[-pc]: No plate files found."
        fi
      ;;

    platepolycolor_list)
      numplatepoly=$(echo "${#P_POLYLIST[@]}-1" | bc)
      for p_index in $(seq 0 $numplatepoly); do
        plate_files=($(ls ${F_PLATES}${P_POLYLIST[$p_index]}_*.pldat 2>/dev/null))
        if [[ ${#plate_files} -gt 0 ]]; then
          for p_example in ${plate_files[@]}; do
            gmt psxy ${p_example} -G${P_COLORLIST[$p_index]} -t${P_POLYTRANS[$p_index]} $RJOK ${VERBOSE} >> map.ps
          done
        else
          info_msg "Plate file ${P_POLYLIST[$p_index]} does not exist."
        fi
      done
      ;;

    platerelvel)
      gmt makecpt -T0/100/1 -C$CPTDIR"platevel_one.cpt" -Z ${VERBOSE} > $PLATEVEL_CPT
      cat ${F_PLATES}paz1*.txt > ${F_PLATES}all.txt
      gmt psxy ${F_PLATES}all.txt -Sc0.1i -C$PLATEVEL_CPT -i0,1,3 $RJOK >> map.ps

      # gmt psxy paz1ss2.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      # gmt psxy paz1normal.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      # gmt psxy paz1thrust.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      ;;

    platerotation)
      info_msg "Plotting small circle rotations"

      # Plot small circles and little arrows for plate rotations
      for i in ${F_PLATES}*_smallcirc_platevecs.txt; do
        cat $i | gawk -v scalefac=0.01 '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, scalefac; else print $1, $2, az+360, scalefac; }' > ${i}.pvec
        gmt psxy -SV0.0/0.12/0.06 -: -W0p,$PLATEVEC_COLOR@70 -G$PLATEVEC_COLOR@70 ${i}.pvec -t70 $RJOK $VERBOSE >> map.ps
      done
      for i in ${F_PLATES}*smallcircles_clip; do
       info_msg "Plotting small circle file ${i}"
       cat ${i} | gmt psxy -W1p,${PLATEVEC_COLOR}@50 -t70 $RJOK $VERBOSE >> map.ps
      done
      ;;

    platevelgrid)
      # Probably should move the calculation to the calculation zone of the script
      # Plot a colored plate velocity grid
      info_msg "Calculating plate velocity grids"
      mkdir -p pvdir
      mkdir -p pvdir/${F_PLATES}

      MAXV_I=0
      MINV_I=99999

      for i in ${F_PLATES}*.pole; do
        LEAD=${i%.pole*}
        # info_msg "i is $i LEAD is $LEAD"
        info_msg "Calculating $LEAD velocity raster"
        gawk < $i '{print $2, $1}' > pvdir/pole.xy
        POLERATE=$(gawk < $i '{print $3}')
        cat "$LEAD.pldat" | sed '1d' > pvdir/plate.xy

        cd pvdir
        # # Determine the extent of the polygon within the map extent
        pl_max_x=$(grep "^[-*0-9]" plate.xy | sort -n -k 1 | tail -n 1 | gawk  -v mx=$MAXLON '{print ($1>mx)?mx:$1}')
        pl_min_x=$(grep "^[-*0-9]" plate.xy | sort -n -k 1 | head -n 1 | gawk  -v mx=$MINLON '{print ($1<mx)?mx:$1}')
        pl_max_y=$(grep "^[-*0-9]" plate.xy | sort -n -k 2 | tail -n 1 | gawk  -v mx=$MAXLAT '{print ($2>mx)?mx:$2}')
        pl_min_y=$(grep "^[-*0-9]" plate.xy | sort -n -k 2 | head -n 1 | gawk  -v mx=$MINLAT '{print ($2<mx)?mx:$2}')
        info_msg "Polygon region $pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y"
        # this approach requires a final GMT grdblend command
        # echo platevelres=$PLATEVELRES
        gmt grdmath ${VERBOSE} -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y -fg -I$PLATEVELRES pole.xy PDIST 6378.13696669 DIV SIN $POLERATE MUL 6378.13696669 MUL .01745329251944444444 MUL = "$LEAD"_velraster.nc
        gmt grdmask plate.xy ${VERBOSE} -R"$LEAD"_velraster.nc -fg -NNaN/1/1 -Gmask.nc
        info_msg "Calculating $LEAD masked raster"
        gmt grdmath -fg ${VERBOSE} "$LEAD"_velraster.nc mask.nc MUL = "$LEAD"_masked.nc
        # zrange=$(grid_zrange ${LEAD}_velraster.nc -C -Vn)
        # MINZ=$(echo $zrange | gawk  '{print $1}')
        # MAXZ=$(echo $zrange | gawk  '{print $2}')
        # MAXV_I=$(echo $MAXZ | gawk  -v max=$MAXV_I '{ if ($1 > max) { print $1 } else { print max } }')
        # MINV_I=$(echo $MINZ | gawk  -v min=$MINV_I '{ if ($1 < min) { print $1 } else { print min } }')
        # unverified code above...
        # MAXV_I=$(gmt grdinfo ${LEAD}_velraster.nc 2>/dev/null | grep "z_max" | gawk  -v max=$MAXV_I '{ if ($5 > max) { print $5 } else { print max } }')
        # MINV_I=$(gmt grdinfo ${LEAD}_velraster.nc 2>/dev/null | grep "z_max" | gawk  -v min=$MINV_I '{ if ($3 < min) { print $3 } else { print min } }')
        # # gmt grdedit -fg -A -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y "$LEAD"_masked.nc -G"$LEAD"_masked_edit.nc
        # echo "${LEAD}_masked_edit.nc -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y 1" >> grdblend.cmd
        cd ../
      done

      info_msg "Merging velocity rasters"

      PVRESNUM=$(echo "" | gawk -v v=$PLATEVELRES 'END {print v+0}')
      info_msg "gdal_merge.py -o plate_velocities.nc -of NetCDF -ps $PVRESNUM $PVRESNUM -ul_lr $MINLON $MAXLAT $MAXLON $MINLAT ${F_PLATES}*_masked.nc"
      cd pvdir
        gdal_merge.py -o plate_velocities.nc -q -of NetCDF -ps $PVRESNUM $PVRESNUM -ul_lr $MINLON $MAXLAT $MAXLON $MINLAT ${F_PLATES}*_masked.nc
        # Fill NaNs with nearest neighbor
        info_msg "Filling NaN values in plate velocity raster"
        gmt grdfill plate_velocities.nc -An -Gfilled_plate_velocities.nc ${VERBOSE}
        mv filled_plate_velocities.nc plate_velocities.nc
        zrange=$(grid_zrange plate_velocities.nc -C -Vn)
      cd ..

      info_msg "Velocities range: $zrange"
      # info_msg "Creating zero raster"
      # gmt grdmath ${VERBOSE} -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -fg -I$PLATEVELRES 0 = plate_velocities.nc
      # for i in pvdir/*_masked.nc; do
      #   info_msg "Adding $LEAD to plate velocity raster"
      #   gmt grdmath ${VERBOSE} -fg plate_velocities.nc $i 0 AND ADD = plate_velocities.nc
      # done

      # cd pvdir
      # echo blending
      # gmt grdblend grdblend.cmd -fg -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -Gplate_velocities.nc -I$PLATEVELRES ${VERBOSE}

      # This isn't working because I can't seem to read the max values from this raster this way or with gdalinfo
      if [[ $rescaleplatevecsflag -eq 1 ]]; then
        MINV=$(echo $zrange | gawk  '{ print int($1/10)*10 }')
        MAXV=$(echo $zrange | gawk  '{ print int($2/10)*10 +10 }')
        echo MINV MAXV $MINV $MAXV
        gmt makecpt -C$CPTDIR"platevel_one.cpt" -T0/$MAXV -Z > $PLATEVEL_CPT
      else
        gmt makecpt -T0/100/1 -C$CPTDIR"platevel_one.cpt" -Z ${VERBOSE} > $PLATEVEL_CPT
      fi

      # cd ..
      info_msg "Plotting velocity raster."

      gmt grdimage ./pvdir/plate_velocities.nc -C$PLATEVEL_CPT $GRID_PRINT_RES $RJOK $VERBOSE >> map.ps
      info_msg "Plotted velocity raster."
      ;;

    points)
      info_msg "Plotting point dataset $current_userpointfilenumber: ${POINTDATAFILE[$current_userpointfilenumber]}"
      if [[ ${pointdatacptflag[$current_userpointfilenumber]} -eq 1 ]]; then
        gmt psxy ${POINTDATAFILE[$current_userpointfilenumber]} -W$POINTLINEWIDTH,$POINTLINECOLOR -C${POINTDATACPT[$current_userpointfilenumber]} -G+z -S${POINTSYMBOL_arr[$current_userpointfilenumber]}${POINTSIZE_arr[$current_userpointfilenumber]} $RJOK $VERBOSE >> map.ps
      else
        gmt psxy ${POINTDATAFILE[$current_userpointfilenumber]} -G$POINTCOLOR -W$POINTLINEWIDTH,$POINTLINECOLOR -S${POINTSYMBOL_arr[$current_userpointfilenumber]}${POINTSIZE_arr[$current_userpointfilenumber]} $RJOK $VERBOSE >> map.ps
      fi
      current_userpointfilenumber=$(echo "$current_userpointfilenumber + 1" | bc -l)
      ;;

    polygonaoi)
      info_msg "Plotting polygon AOI"
      gmt psxy ${POLYGONAOI} -L -W0.5p,black $RJOK ${VERBOSE} >> map.ps
      ;;

    refpoint)
      info_msg "Plotting reference point"

      if [[ $refptflag -eq 1 ]]; then
      # Plot the reference point as a circle around a triangle
        echo $REFPTLON $REFPTLAT| gmt psxy -W0.1,black -Gblack -St0.05i $RJOK $VERBOSE >> map.ps
        echo $REFPTLON $REFPTLAT| gmt psxy -W0.1,black -Sc0.1i $RJOK $VERBOSE >> map.ps
      fi
      ;;

    seis)
      if [[ $dontplotseisflag -eq 0 ]]; then

        info_msg "Plotting seismicity; should include options for CPT/fill color"
        OLD_PROJ_LENGTH_UNIT=$(gmt gmtget PROJ_LENGTH_UNIT -Vn)
        gmt gmtset PROJ_LENGTH_UNIT p

        EQLWNUM=$(echo $EQLINEWIDTH | awk '{print $1 + 0}')
        if [[ $(echo "${EQLWNUM} == 0" | bc) -eq 1 ]]; then
          EQWCOM=""
        else
          EQWCOM="-W${EQLINEWIDTH},${EQLINECOLOR}"
        fi


        if [[ $SCALEEQS -eq 1 ]]; then
          # the -Cwhite option here is so that we can pass the removed EQs in the same file format as the non-scaled events
          # [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && [[ -e ${F_SEIS}removed_eqs_scaled.txt ]] && gmt psxy ${F_SEIS}removed_eqs_scaled.txt -Cwhite -W${EQLINEWIDTH},${EQLINECOLOR} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          # gmt psxy ${F_SEIS}eqs_scaled.txt -C$SEISDEPTH_CPT -i0,1,2,3+s${SEISSCALE} -W${EQLINEWIDTH},${EQLINECOLOR} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && [[ -e ${F_SEIS}removed_eqs_scaled.txt ]] && gmt psxy ${F_SEIS}removed_eqs_scaled.txt -Cwhite ${EQWCOM} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          gmt psxy ${F_SEIS}eqs_scaled.txt -C$SEISDEPTH_CPT -i0,1,2,3+s${SEISSCALE} ${EQWCOM} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
        else
          # [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && [[ -e ${F_SEIS}removed_eqs_scaled.txt ]] && gmt psxy ${F_SEIS}removed_eqs.txt -Gwhite -W${EQLINEWIDTH},${EQLINECOLOR} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          # gmt psxy ${F_SEIS}eqs.txt -C$SEISDEPTH_CPT -i0,1,2 -W${EQLINEWIDTH},${EQLINECOLOR} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && [[ -e ${F_SEIS}removed_eqs_scaled.txt ]] && gmt psxy ${F_SEIS}removed_eqs.txt -Gwhite ${EQWCOM} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
          gmt psxy ${F_SEIS}eqs.txt -C$SEISDEPTH_CPT -i0,1,2 ${EQWCOM} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
        fi
        gmt gmtset PROJ_LENGTH_UNIT $OLD_PROJ_LENGTH_UNIT
      fi
			;;

    # seisrake1)
    #   info_msg "Plotting rake of N1 nodal planes"
    #   # Plot the rake of the N1 nodal plane
    #   # lonc latc depth str1 dip1 rake1 str2 dip2 rake2 M lon lat ID
    #   gawk < $CMTFILE '($6 > 45 && $6 < 135) { print $1, $2, $4-($6-180) }' | gawk  '{ if ($3 > 180) { print $1, $2, $3-360;} else {print $1,$2,$3} }' > eqaz1.txt
    #   gmt psxy -C$CPTDIR"cycleaz.cpt" -St${RAKE1SCALE}/0 eqaz1.txt $RJOK $VERBOSE >> map.ps
    #   ;;
    #
    # seisrake2)
    #   ;;

    seissum)
      # Convert Mw to M0 and sum within grid nodes, then take the log10 and plot.
      gawk < ${F_SEIS}eqs.txt '{print $1, $2, 10^(($4+10.7)*3/2)}' | gmt blockmean -Ss -R${F_TOPO}dem.nc ${SSRESC} -Gseissum.nc ${VERBOSE}
      gmt grdmath ${VERBOSE} seissum.nc LOG10 = seisout.nc
      gmt grd2cpt -Qo -I -Cseis seisout.nc ${VERBOSE} > ${CPTDIR}seisout.cpt
      gmt grdimage seisout.nc -C${CPTDIR}seisout.cpt -Q $RJOK ${VERBOSE} -t${SSTRANS} >> map.ps
      ;;

    slab2)

      if [[ ${SLAB2STR} =~ .*d.* ]]; then
        info_msg "Plotting SLAB2 depth grids"
        SLAB2_CONTOUR_BLACK=1
        for i in $(seq 1 $numslab2inregion); do
          gridfile=$(echo ${SLAB2_GRIDDIR}${slab2inregion[$i]}.grd | sed 's/clp/dep/')
          if [[ -e $gridfile ]]; then
            gmt grdmath ${VERBOSE} $gridfile -1 MUL = tmpgrd.grd
            gmt grdimage tmpgrd.grd -Q -t${SLAB2GRID_TRANS} -C$SEISDEPTH_CPT $RJOK $VERBOSE >> map.ps
            rm -f tmpgrd.grd
          fi
        done
      else
        SLAB2_CONTOUR_BLACK=0
      fi

			if [[ ${SLAB2STR} =~ .*c.* ]]; then
				info_msg "Plotting SLAB2 contours"
        for i in $(seq 1 $numslab2inregion); do
          # echo "Slab contour file ${slab2inregion[$i]}"
          if [[ -s ${SLAB2_CONTOURDIR}${slab2inregion[$i]}_contours.in ]]; then
            clipfile=$(echo ${SLAB2_CONTOURDIR}${slab2inregion[$i]}_contours.in | sed 's/clp/dep/')
            gawk < $clipfile '{
              if ($1 == ">") {
                print $1, "-Z" 0-$2
              } else {
                print $1, $2, 0 - $3
              }
            }' > contourtmp.dat
            if [[ -s contourtmp.dat ]]; then
              if [[ SLAB2_CONTOUR_BLACK -eq 0 ]]; then
                gmt psxy contourtmp.dat -C$SEISDEPTH_CPT -W0.5p+z $RJOK $VERBOSE >> map.ps
              else
                gmt psxy contourtmp.dat -W0.5p,black+z $RJOK $VERBOSE >> map.ps
              fi
            fi
          fi
        done
        rm -f contourtmp.dat
			fi
			;;

    slipvecs)
      info_msg "Slip vectors"
      # Plot a file containing slip vector azimuths
      gawk < ${SVDATAFILE} '($1 != "end") {print $1, $2, $3, 0.2}' | gmt psxy -SV0.05i+jc -W1.5p,red $RJOK $VERBOSE >> map.ps
      ;;

		srcmod)
      info_msg "SRCMOD"

			##########################################################################################
			# Calculate and plot a 'fused' large earthquake slip distribution from SRCMOD events
			# We need to determine a resolution for gmt surface, but in km. Use width of image
			# in degrees

			# NOTE that SRCMODFSPLOCATIONS needs to be generated using extract_fsp_locations.sh

      # ALSO NOTE that this doesn't really work well right now...

			if [[ -e $SRCMODFSPLOCATIONS ]]; then
				info_msg "SRCMOD FSP data file exists"
			else
				# Extract locations of earthquakes and output filename,Lat,Lon to a text file
				info_msg "Building SRCMOD FSP location file"
				comeback=$(pwd)
				cd ${SRCMODFSPFOLDER}
				eval "grep -H 'Loc  :' *" | gawk  -F: '{print $1, $3 }' | gawk  '{print $7 "	" $4 "	" $1}' > $SRCMODFSPLOCATIONS
				cd $comeback
			fi

			info_msg "Identifying SRCMOD results falling within the AOI"
      # LON EDIT
		    gawk < $SRCMODFSPLOCATIONS -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '((($1 <= (maxlon+1) && $1 >= (minlon-1) || ($1+360 <= (maxlon+1) && $1+360 >= (minlon-1))) && $2 < maxlat-1 && $2 > minlat+1) {print $3}' > srcmod_eqs.txt
			[[ $narrateflag -eq 1 ]] && cat srcmod_eqs.txt

			SLIPRESOL=300

			LONDIFF=$(echo $MAXLON - $MINLON | bc -l)
			LONKM=$(echo "$LONDIFF * 110 * c( ($MAXLAT - $MINLAT) * 3.14159265358979 / 180 / 2)"/$SLIPRESOL | bc -l)
			info_msg "LONDIFF is $LONDIFF"
			info_msg "LONKM is $LONKM"

			# Add all earthquake model slips together into a fused slip raster.
			# Create an empty 0 raster with a resolution of LONKM
			#echo | gmt xyz2grd -di0 -R -I"$LONKM"km -Gzero.nc

			gmt grdmath $VERBOSE -R -I"$LONKM"km 0 = slip.nc
			#rm -f slip2.nc

			NEWR=$(echo $MINLON-1|bc -l)"/"$(echo $MAXLON+1|bc -l)"/"$(echo $MINLAT-1|bc -l)"/"$(echo $MAXLAT+1|bc -l)

			v=($(cat srcmod_eqs.txt | tr ' ' '\n'))
			i=0
			while [[ $i -lt ${#v[@]} ]]; do
				info_msg "Plotting points from EQ ${v[$i]}"
				grep "^[^%;]" "$SRCMODFSPFOLDER"${v[$i]} | gawk  '{print $2, $1, $6}' > temp1.xyz
				gmt blockmean temp1.xyz -I"$LONKM"km $VERBOSE -R > temp.xyz
				gmt triangulate temp.xyz -I"$LONKM"km -Gtemp.nc -R $VERBOSE
				gmt grdmath $VERBOSE temp.nc ISNAN 0 temp.nc IFELSE = slip2.nc
				gmt grdmath $VERBOSE slip2.nc slip.nc MAX = slip3.nc
				mv slip3.nc slip.nc
				i=$i+1
			done

			if [[ -e slip2.nc ]]; then
				gmt grdmath $VERBOSE slip.nc $SLIPMINIMUM GT slip.nc MUL = slipfinal.grd
				gmt grdmath $VERBOSE slip.nc $SLIPMINIMUM LE 1 NAN = mask.grd
				#This takes the logical grid file from the previous step (mask.grd)
				#and replaces all of the 1s with the original conductivies from interpolated.grd
				gmt grdmath $VERBOSE slip.nc mask.grd OR = slipfinal.grd
				gmt grdimage slipfinal.grd -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C$FAULTSLIP_CPT -t40 -Q -J -O -K $VERBOSE >> map.ps
				gmt grdcontour slipfinal.grd -C$SLIPCONTOURINTERVAL $RJOK $VERBOSE >> map.ps
			fi
			;;

		tdefnode)
			info_msg "TDEFNODE folder is at $TDPATH"
			TDMODEL=$(echo $TDPATH | xargs -n 1 basename | gawk  -F. '{print $1}')
			info_msg "$TDMODEL"

      if [[ ${TDSTRING} =~ .*a.* ]]; then
        # BLOCK LABELS
        info_msg "TDEFNODE block labels"
        gawk < ${TDPATH}${TDMODEL}_blocks.out '{ print $2,$3,$1 }' | gmt pstext -F+f8,Helvetica,orange+jBL $RJOK $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*b.* ]]; then
        # BLOCKS ############
        info_msg "TDEFNODE blocks"
        gmt psxy ${TDPATH}${TDMODEL}_blk.gmt -W1p,black -L $RJOK $VERBOSE >> map.ps 2>/dev/null
      fi

      if [[ ${TDSTRING} =~ .*g.* ]]; then
        # Faults, nodes, etc.
        # Find the number of faults in the model
        info_msg "TDEFNODE faults, nodes, etc"
        numfaults=$(gawk 'BEGIN {min=0} { if ($1 == ">" && $3 > min) { min = $3} } END { print min }' ${TDPATH}${TDMODEL}_flt_atr.gmt)
        gmt makecpt -Ccategorical -T0/$numfaults/1 $VERBOSE > faultblock.cpt
        gawk '{ if ($1 ==">") printf "%s %s%f\n",$1,$2,$3; else print $1,$2 }' ${TDPATH}${TDMODEL}_flt_atr.gmt | gmt psxy -L -Cfaultblock.cpt $RJOK $VERBOSE >> map.ps
        gmt psxy ${TDPATH}${TDMODEL}_blk3.gmt -Wfatter,red,solid $RJOK $VERBOSE >> map.ps
        gmt psxy ${TDPATH}${TDMODEL}_blk3.gmt -Wthickest,black,solid $RJOK $VERBOSE >> map.ps
        #gmt psxy ${TDPATH}${TDMODEL}_blk.gmt -L -R -J -Wthicker,black,solid -O -K $VERBOSE  >> map.ps
        gawk '{if ($4==1) print $7, $8, $2}' ${TDPATH}${TDMODEL}.nod | gmt pstext -F+f10p,Helvetica,lightblue $RJOK $VERBOSE >> map.ps
        gawk '{print $7, $8}' ${TDPATH}${TDMODEL}.nod | gmt psxy -Sc.02i -Gblack $RJOK $VERBOSE >> map.ps
      fi
			# if [[ ${TDSTRING} =~ .*l.* ]]; then
      #   # Coupling. Not sure this is the best way, but it seems to work...
      #   info_msg "TDEFNODE coupling"
			# 	gmt makecpt -Cseis -Do -I -T0/1/0.01 -N > $SLIPRATE_DEF_CPT
			# gawk '{ if ($1 ==">") print $1 $2 $5; else print $1, $2 }' ${TDPATH}${TDMODEL}_flt_atr.gmt | gmt psxy -L -C$SLIPRATE_DEF_CPT $RJOK $VERBOSE >> map.ps
			# fi
      if [[ ${TDSTRING} =~ .*l.* || ${TDSTRING} =~ .*c.* ]]; then
        # Plot a dashed line along the contour of coupling = 0
        info_msg "TDEFNODE coupling"
        gawk '{
          if ($1 ==">") {
            carat=$1
            faultid=$3
            z=$2
            val=$5
            getline
            p1x=$1; p1y=$2
            getline
            p2x=$1; p2y=$2
            getline
            p3x=$1; p3y=$2
            geline
            p4x=$1; p4y=$2
            xav=(p1x+p2x+p3x+p4x)/4
            yav=(p1y+p2y+p3y+p4y)/4
            print faultid, xav, yav, val
          }
        }' ${TDPATH}${TDMODEL}_flt_atr.gmt > tdsrd_faultids.xyz

        if [[ $tdeffaultlistflag -eq 1 ]]; then
          echo $FAULTIDLIST | gawk  '{
            n=split($0,groups,":");
            for(i=1; i<=n; i++) {
               print groups[i]
            }
          }' | tr ',' ' ' > faultid_groups.txt
        else # Extract all fault IDs as Group 1 if we don't specify faults/groups
          gawk < tdsrd_faultids.xyz '{
            seen[$1]++
            } END {
              for (key in seen) {
                printf "%s ", key
            }
          } END { printf "\n"}' > faultid_groups.txt
        fi

        groupd=1
        while read p; do
          echo "Processing fault group $groupd"
          gawk < tdsrd_faultids.xyz -v idstr="$p" 'BEGIN {
              split(idstr,idarray," ")
              for (i in idarray) {
                idcheck[idarray[i]]
              }
            }
            {
              if ($1 in idcheck) {
                print $2, $3, $4
              }
          }' > faultgroup_$groupd.xyz
          # May wish to process grouped fault data here

          mkdir tmpgrd
          cd tmpgrd
            gmt nearneighbor ../faultgroup_$groupd.xyz -S0.2d -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -I0.1d -Gout.grd
          cd ..

          if [[ ${TDSTRING} =~ .*c.* ]]; then
            gmt psxy faultgroup_$groupd.xyz -Sc0.015i -C$SLIPRATE_DEF_CPT $RJOK $VERBOSE >> map.ps
          fi

          if [[ ${TDSTRING} =~ .*l.* ]]; then
            gmt grdcontour tmpgrd/out.grd -S5 -C+0.7 -W0.1p,black,- $RJOK $VERBOSE >> map.ps
          fi
          # gmt contour faultgroup_$groupd.xyz -C+0.1 -W0.25p,black,- $RJOK $VERBOSE >> map.ps

          # May wish to process grouped fault data here
          groupd=$(echo "$groupd+1" | bc)
        done < faultid_groups.txt
      fi

			if [[ ${TDSTRING} =~ .*X.* ]]; then
				# FAULTS ############
        info_msg "TDEFNODE faults"
				gmt psxy ${TDPATH}${TDMODEL}_blk0.gmt -R -J -W1p,red -O -K $VERBOSE >> map.ps 2>/dev/null
		  	gawk < ${TDPATH}${TDMODEL}_blk0.gmt '{ if ($1 == ">") print $3,$4, $5 " (" $2 ")" }' | gmt pstext -F+f8,Helvetica,black+jBL $RJOK $VERBOSE >> map.ps

				# PSUEDOFAULTS ############
				gmt psxy ${TDPATH}${TDMODEL}_blk1.gmt -R -J -W1p,green -O -K $VERBOSE >> map.ps 2>/dev/null
			  gawk < ${TDPATH}${TDMODEL}_blk1.gmt '{ if ($1 == ">") print $3,$4,$5 }' | gmt pstext -F+f8,Helvetica,brown+jBL $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*s.* ]]; then
				# SLIP VECTORS ######
        legendwords+=("slipvectors")
        info_msg "TDEFNODE slip vectors (observed and predicted)"
			  gawk < ${TDPATH}${TDMODEL}.svs -v size=$SVBIG '(NR > 1) {print $1, $2, $3, size}' > ${TDMODEL}.svobs
		  	gawk < ${TDPATH}${TDMODEL}.svs -v size=$SVSMALL '(NR > 1) {print $1, $2, $5, size}' > ${TDMODEL}.svcalc
				gmt psxy -SV"${PVHEAD}"+jc -W"${SVBIGW}",black ${TDMODEL}.svobs $RJOK $VERBOSE >> map.ps
				gmt psxy -SV"${PVHEAD}"+jc -W"${SVSMALLW}",lightgreen ${TDMODEL}.svcalc $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*o.* ]]; then
				# GPS ##############
				# observed vectors
        # lon, lat, ve, vn, sve, svn, xcor, site
        # gmt psvelo $GPS_FILE -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        info_msg "TDEFNODE observed GPS velocities"
        legendwords+=("TDEFobsgps")
				echo "" | gawk  '{ if ($5==1 && $6==1) print $8, $9, $12, $17, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.obs
				gmt psvelo ${TDMODEL}.obs -W${TD_OGPS_LINEWIDTH},${TD_OGPS_LINECOLOR} -G${TD_OGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        # gawk  -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.obs > ${TDMODEL}.xyobs
        # gmt psxy -SV$ARROWFMT -W0.25p,white -Gblack ${TDMODEL}.xyobs $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*v.* ]]; then
				# calculated vectors  UPDATE TO PSVELO
        info_msg "TDEFNODE modeled GPS velocities"
        legendwords+=("TDEFcalcgps")
			gawk '{ if ($5==1 && $6==1) print $8, $9, $13, $18, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.vec
        gmt psvelo ${TDMODEL}.vec -W${TD_VGPS_LINEWIDTH},${TD_VGPS_LINECOLOR} -D0 -G${TD_VGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        #  Generate AZ/VEL data
        echo "" | gawk  '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.vec > ${TDMODEL}.xyvec
        # gawk  '(sqrt($3*$3+$4*$4) <= 5) { print $1, $2 }' ${TDMODEL}.vec > ${TDMODEL}_smallcalc.xyvec
        # gmt psxy -SV$ARROWFMT -W0.25p,black -Gwhite ${TDMODEL}.xyvec $RJOK $VERBOSE >> map.ps
        # gmt psxy -SC$SMALLRES -W0.25p,black -Gwhite ${TDMODEL}_smallcalc.xyvec $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*r.* ]]; then
        legendwords+=("TDEFresidgps")
				#residual vectors UPDATE TO PSVELO
        info_msg "TDEFNODE residual GPS velocities"
			  gawk '{ if ($5==1 && $6==1) print $8, $9, $14, $19, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.res
        # gmt psvelo ${TDMODEL}.res -W${TD_VGPS_LINEWIDTH},${TD_VGPS_LINECOLOR} -G${TD_VGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        gmt psvelo ${TDMODEL}.obs -W${TD_OGPS_LINEWIDTH},${TD_OGPS_LINECOLOR} -G${TD_OGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        #  Generate AZ/VEL data
        echo "" | gawk  '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.res > ${TDMODEL}.xyres
        # gmt psxy -SV$ARROWFMT -W0.1p,black -Ggreen ${TDMODEL}.xyres $RJOK $VERBOSE >> map.ps
        # gawk  '(sqrt($3*$3+$4*$4) <= 5) { print $1, $2 }' ${TDMODEL}.res > ${TDMODEL}_smallres.xyvec
        # gmt psxy -SC$SMALLRES -W0.25p,black -Ggreen ${TDMODEL}_smallres.xyvec $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*f.* ]]; then
        # Fault segment midpoint slip rates
        # CONVERT TO PSVELO ONLY
        info_msg "TDEFNODE fault midpoint slip rates - all "
        legendwords+=("TDEFsliprates")
			  gawk '{ print $1, $2, $3, $4, $5, $6, $7, $8 }' ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvec
        # gmt psvelo ${TDMODEL}.midvec -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        gmt psvelo ${TDMODEL}.midvec -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        # Generate AZ/VEL data
        gawk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.midvec > ${TDMODEL}.xymidvec

        # Label
        gawk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvec > ${TDMODEL}.fsliplabel

		  	gmt pstext -F+f"${SLIP_FONTSIZE}","${SLIP_FONT}","${SLIP_FONTCOLOR}"+jBM $RJOK ${TDMODEL}.fsliplabel $VERBOSE >> map.ps
			fi
      if [[ ${TDSTRING} =~ .*q.* ]]; then
        # Fault segment midpoint slip rates, only plot when the "distance" between the point and the last point is larger than a set value
        # CONVERT TO PSVELO ONLY
        info_msg "TDEFNODE fault midpoint slip rates - near cutoff = ${SLIP_DIST} degrees"
        legendwords+=("TDEFsliprates")

        gawk -v cutoff=${SLIP_DIST} 'BEGIN {dist=0;lastx=9999;lasty=9999} {
            newdist = sqrt(($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty));
            if (newdist > cutoff) {
              lastx=$1
              lasty=$2
              print $1, $2, $3, $4, $5, $6, $7, $8
            }
        }' < ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvecsel
        gmt psvelo ${TDMODEL}.midvecsel -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        # Generate AZ/VEL data
        gawk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.midvecsel > ${TDMODEL}.xymidvecsel
        gawk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvecsel > ${TDMODEL}.fsliplabelsel
        gmt pstext -F+f${SLIP_FONTSIZE},${SLIP_FONT},${SLIP_FONTCOLOR}+jCM $RJOK ${TDMODEL}.fsliplabelsel $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*y.* ]]; then
        # Fault segment midpoint slip rates, text on fault only, only plot when the "distance" between the point and the last point is larger than a set value
        info_msg "TDEFNODE fault midpoint slip rates, label only - near cutoff = 2"
        gawk -v cutoff=${SLIP_DIST} 'BEGIN {dist=0;lastx=9999;lasty=9999} {
            newdist = sqrt(($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty));
            if (newdist > cutoff) {
              lastx=$1
              lasty=$2
              print $1, $2, $3, $4, $5, $6, $7, $8
            }
        }' < ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvecsel
        gawk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvecsel > ${TDMODEL}.fsliplabelsel
        gmt pstext -F+f6,Helvetica-Bold,white+jCM $RJOK ${TDMODEL}.fsliplabelsel $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*e.* ]]; then
        # elastic component of velocity CONVERT TO PSVELO
        info_msg "TDEFNODE elastic component of velocity"
        legendwords+=("TDEFelasticvelocity")

        gawk '{ if ($5==1 && $6==1) print $8, $9, $28, $29, 0, 0, 1, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.elastic
        gawk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.elastic > ${TDMODEL}.xyelastic
        gmt psxy -SV$ARROWFMT -W0.1p,black -Gred ${TDMODEL}.xyelastic  $RJOK $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*t.* ]]; then
        # rotation component of velocity; CONVERT TO PSVELO
        info_msg "TDEFNODE block rotation component of velocity"
        legendwords+=("TDEFrotationvelocity")

        gawk '{ if ($5==1 && $6==1) print $8, $9, $38, $39, 0, 0, 1, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.block
        gawk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.block > ${TDMODEL}.xyblock
        gmt psxy -SV$ARROWFMT -W0.1p,black -Ggreen ${TDMODEL}.xyblock $RJOK $VERBOSE >> map.ps
      fi
			;;

    topo)

   # This section should probably be outsourced to a separate script or function
   # to allow equivalent DEM visualization for along-profile DEMs, etc.
   # Requires: dem.nc sentinel.tif TOPO_CPT
   # Variables: topoctrlstring MINLON/MAXLON/MINLAT/MAXLAT P_IMAGE F_TOPO *_FACT
   # Flags: FILLGRIDNANS SMOOTHGRID ZEROHINGE

      plottedtopoflag=1
      if [[ $fasttopoflag -eq 0 ]]; then   # If we are doing more complex topo visualization
        if [[ $FILLGRIDNANS -eq 1 ]]; then
          # cp ${F_TOPO}dem.nc olddem.nc
          info_msg "Filling grid file NaN values with nearest non-NaN value"
          gmt grdfill ${F_TOPO}dem.nc -An -Gdem_no_nan.nc ${VERBOSE}
          mv dem_no_nan.nc ${F_TOPO}dem.nc
        fi

        # If we are visualizing Sentinel imagery, resample DEM to match the resolution of sentinel.tif
        if [[ ${topoctrlstring} =~ .*p.* && ${P_IMAGE} =~ "sentinel.tif" ]]; then
            # Absolute path is needed here as GMT 6.1.1 breaks for a relative path... BUG
            sentinel_dim=($(gmt grdinfo ./sentinel.tif -C -L -Vn))
            sent_dimx=${sentinel_dim[9]}
            sent_dimy=${sentinel_dim[10]}
            info_msg "Resampling DEM to match downloaded Sentinel image size"
            gdalwarp -r bilinear -of NetCDF -q -te ${DEM_MINLON} ${DEM_MINLAT} ${DEM_MAXLON} ${DEM_MAXLAT} -ts ${sent_dimx} ${sent_dimy} ${F_TOPO}dem.nc ${F_TOPO}dem_warp.nc

            # gdalwarp nukes the z values for some stupid reason leaving a raster that GMT interprets as all 0s
            cp ${F_TOPO}dem.nc ${F_TOPO}demold.nc
            gmt grdcut ${F_TOPO}dem_warp.nc -R${F_TOPO}dem_warp.nc -G${F_TOPO}dem.nc ${VERBOSE}

            # If we have set a specific flag, then calculate the average color of areas at or below zero
            # elevation and set all cells in sentinel.tif to that color (to make a uniform ocean color?)
            if [[ $sentinelrecolorseaflag -eq 1 ]]; then
              info_msg "Recoloring sea areas of Sentinel image"
              recolor_sea ${F_TOPO}dem.nc ./sentinel.tif 24 44 77 ./sentinel_recolor.tif
              mv ./sentinel_recolor.tif ./sentinel.tif
            fi
        fi

        if [[ $SMOOTHGRID -eq 1 ]]; then
          info_msg "Smoothing grid before DEM calculations"
          # Not implemented
        fi

        CELL_SIZE=$(gmt grdinfo -C ${F_TOPO}dem.nc -Vn | awk '{print $8}')
        info_msg "Grid cell size = ${CELL_SIZE}"
        # We now do all color ramps via gdaldem and derive intensity maps from
        # the selected procedures. We fuse them using gdal_calc.py. This gives us
        # a more streamlined process for managing CPTs, etc.

        if [[ $ZEROHINGE -eq 1 ]]; then
          # We need to make a gdal color file that respects the CPT hinge value (usually 0)
          # gdaldem is a bit funny about coloring around the hinge, so do some magic to make
          # the color from land not bleed to the hinge elevation.
          # CPTHINGE=0

          gawk < $TOPO_CPT -v hinge=$CPTHINGE '{
            if ($1 != "B" && $1 != "F" && $1 != "N" ) {
              if (count==1) {
                print $1+0.01, $2
                count=2
              } else {
                print $1, $2
              }

              if ($3 == hinge) {
                if (count==0) {
                  print $3-0.0001, $4
                  count=1
                }
              }
            }
          }' | tr '/' ' ' | awk '{
            if ($2==255) {$2=254.9}
            if ($3==255) {$3=254.9}
            if ($4==255) {$4=254.9}
            print
          }' > ${F_CPTS}topocolor.dat
        else
          gawk < $TOPO_CPT '{ print $1, $2 }' | tr '/' ' ' > ${F_CPTS}topocolor.dat
        fi

        # ########################################################################
        # Create and render a colored shaded relief map using a topoctrlstring
        # command string = "csmhvdtg"
        #

        # c = color stretch  [ DEM_ALPHA CPT_NAME HINGE_VALUE HIST_EQ ]    [MULTIPLY]
        # s = slope map                                                    [WEIGHTED AVE]
        # m = multiple hillshade (gdaldem)  [ SUN_ELEV ]                   [WEIGHTED AVE]
        # h = unidirectional hillshade (gdaldem)  [ SUN_ELEV SUN_AZ ]      [WEIGHTED AVE]
        # v = sky view factor                                              [WEIGHTED AVE]
        # i = terrain ruggedness index                                     [WEIGHTED AVE]
        # d = cast shadows [ SUN_ELEV SUN_AZ ]                             [MULTIPLY]
        # t = texture shade [ TFRAC TSTRETCH ]                             [WEIGHTED AVE]
        # g = stretch/gamma on intensity [ HS_GAMMA ]                      [DIRECT]
        # p = use TIFF image instead of color stretch
        # w = clip to alternative AOI

        while read -n1 character; do
          case $character in

          w)
            info_msg "Clipping DEM to new AOI"

            gdal_translate -q -of NetCDF -projwin ${CLIP_MINLON} ${CLIP_MAXLAT} ${CLIP_MAXLON} ${CLIP_MINLAT} ${F_TOPO}dem.nc ${F_TOPO}dem_clip.nc
            DEM_MINLON=${CLIP_MINLON}
            DEM_MAXLON=${CLIP_MAXLON}
            DEM_MINLAT=${CLIP_MINLAT}
            DEM_MAXLAT=${CLIP_MAXLAT}
            # mkdir -p ./tmpcut
            # cd ./tmpcut
            # gmt grdcut ../${F_TOPO}dem.nc -R${CLIP_MINLON}/${CLIP_MAXLON}/${CLIP_MINLAT}/${CLIP_MAXLAT} -G../${F_TOPO}clip.nc ${VERBOSE}
            # cd ..
            cp ${F_TOPO}dem_clip.nc ${F_TOPO}dem.nc
          ;;

          i)
            info_msg "Calculating terrain ruggedness index"
            gdaldem TRI -q -of NetCDF ${F_TOPO}dem.nc ${F_TOPO}tri.nc
            zrange=$(grid_zrange ${F_TOPO}tri.nc -C -Vn)
            gdal_translate -of GTiff -ot Byte -a_nodata 0 -scale ${zrange[0]} ${zrange[1]} 254 1 ${F_TOPO}tri.nc ${F_TOPO}tri.tif -q
            weighted_average_combine ${F_TOPO}tri.tif ${F_TOPO}intensity.tif ${TRI_FACT} ${F_TOPO}intensity.tif
          ;;

          t)
            demwidth=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $10}')
            demheight=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $11}')
            demxmin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $2}')
            demxmax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $3}')
            demymin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $4}')
            demymax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $5}')

            info_msg "Calculating and rendering texture map"

            # Calculate the texture shade
            # Project from WGS1984 to Mercator / HDF format
            # The -dstnodata option is a kluge to get around unknown NaNs in dem.flt even if ${F_TOPO}dem.nc has NaNs filled.
            [[ ! -e ${F_TOPO}dem.flt ]] && gdalwarp -dstnodata -9999 -t_srs EPSG:3395 -s_srs EPSG:4326 -r bilinear -if netCDF -of EHdr -ot Float32 -ts $demwidth $demheight ${F_TOPO}dem.nc ${F_TOPO}dem.flt -q

            # texture the DEM. Pipe output to /dev/null to silence the program
            if [[ $(echo "$DEM_MAXLAT >= 90" | bc) -eq 1 ]]; then
              MERCMAXLAT=89.999
            else
              MERCMAXLAT=$DEM_MAXLAT
            fi
            if [[ $(echo "$DEM_MINLAT <= -90" | bc) -eq 1 ]]; then
              MERCMINLAT=-89.999
            else
              MERCMINLAT=$DEM_MINLAT
            fi

            ${TEXTURE} ${TS_FRAC} ${F_TOPO}dem.flt ${F_TOPO}texture.flt -mercator ${MERCMINLAT} ${MERCMAXLAT} > /dev/null
            # make the image. Pipe output to /dev/null to silence the program
            ${TEXTURE_IMAGE} +${TS_STRETCH} ${F_TOPO}texture.flt ${F_TOPO}texture_merc.tif > /dev/null
            # project back to WGS1984

            gdalwarp -s_srs EPSG:3395 -t_srs EPSG:4326 -r bilinear  -ts $demwidth $demheight -te $demxmin $demymin $demxmax $demymax ${F_TOPO}texture_merc.tif ${F_TOPO}texture_2byte.tif -q

            # Change to 8 bit unsigned format
            gdal_translate -of GTiff -ot Byte -scale 0 65535 0 255 ${F_TOPO}texture_2byte.tif ${F_TOPO}texture.tif -q
            cleanup ${F_TOPO}texture_2byte.tif ${F_TOPO}texture_merc.tif ${F_TOPO}dem.flt ${F_TOPO}dem.hdr ${F_TOPO}dem.flt.aux.xml ${F_TOPO}dem.prj ${F_TOPO}texture.flt ${F_TOPO}texture.hdr ${F_TOPO}texture.prj ${F_TOPO}texture_merc.prj ${F_TOPO}texture_merc.tfw

            # Combine it with the existing intensity
            weighted_average_combine ${F_TOPO}texture.tif ${F_TOPO}intensity.tif ${TS_FACT} ${F_TOPO}intensity.tif
          ;;

          m)
            info_msg "Creating multidirectional hillshade"
            gdaldem hillshade -multidirectional -compute_edges -alt ${HS_ALT} -s $MULFACT ${F_TOPO}dem.nc ${F_TOPO}multiple_hillshade.tif -q
            weighted_average_combine ${F_TOPO}multiple_hillshade.tif ${F_TOPO}intensity.tif ${MULTIHS_FACT} ${F_TOPO}intensity.tif
          ;;

          # Compute and render a one-sun hillshade
          h)
            info_msg "Creating unidirectional hillshade"
            gdaldem hillshade -compute_edges -alt ${HS_ALT} -az ${HS_AZ} -s $MULFACT ${F_TOPO}dem.nc ${F_TOPO}single_hillshade.tif -q
            weighted_average_combine ${F_TOPO}single_hillshade.tif ${F_TOPO}intensity.tif ${UNI_FACT} ${F_TOPO}intensity.tif
          ;;

          # Compute and render the slope map
          s)
            info_msg "Creating slope map"
            gdaldem slope -compute_edges -s $MULFACT ${F_TOPO}dem.nc ${F_TOPO}slopedeg.tif -q
            echo "5 254 254 254" > ${F_TOPO}slope.txt
            echo "80 30 30 30" >> ${F_TOPO}slope.txt
            gdaldem color-relief ${F_TOPO}slopedeg.tif ${F_TOPO}slope.txt ${F_TOPO}slope.tif -q
            weighted_average_combine ${F_TOPO}slope.tif ${F_TOPO}intensity.tif ${SLOPE_FACT} ${F_TOPO}intensity.tif
          ;;

          # Compute and render the sky view factor
          v)

            demwidth=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $10}')
            demheight=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $11}')
            demxmin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $2}')
            demxmax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $3}')
            demymin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $4}')
            demymax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $5}')

            info_msg "Creating sky view factor"

            [[ ! -e ${F_TOPO}dem.flt ]] && gdalwarp -dstnodata -9999 -t_srs EPSG:3395 -s_srs EPSG:4326 -r bilinear -if netCDF -of EHdr -ot Float32 -ts $demwidth $demheight ${F_TOPO}dem.nc ${F_TOPO}dem.flt -q

            # texture the DEM. Pipe output to /dev/null to silence the program
            if [[ $(echo "$DEM_MAXLAT >= 90" | bc) -eq 1 ]]; then
              MERCMAXLAT=89.999
            else
              MERCMAXLAT=$DEM_MAXLAT
            fi
            if [[ $(echo "$DEM_MINLAT <= -90" | bc) -eq 1 ]]; then
              MERCMINLAT=-89.999
            else
              MERCMINLAT=$DEM_MINLAT
            fi

            # start_time=`date +%s`
            ${SVF} ${NUM_SVF_ANGLES} ${F_TOPO}dem.flt ${F_TOPO}svf.flt -mercator ${MERCMINLAT} ${MERCMAXLAT} > /dev/null
            # echo run time is $(expr `date +%s` - $start_time) s
            # project back to WGS1984
            gdalwarp -s_srs EPSG:3395 -t_srs EPSG:4326 -r bilinear  -ts $demwidth $demheight -te $demxmin $demymin $demxmax $demymax ${F_TOPO}svf.flt ${F_TOPO}svf_back.tif -q

            zrange=($(grid_zrange ${F_TOPO}svf_back.tif -Vn))
            gdal_translate -of GTiff -ot Byte -a_nodata 255 -scale ${zrange[1]} ${zrange[0]} 1 254 ${F_TOPO}svf_back.tif ${F_TOPO}svf.tif -q

            # Combine it with the existing intensity
            weighted_average_combine ${F_TOPO}svf.tif ${F_TOPO}intensity.tif ${SKYVIEW_FACT} ${F_TOPO}intensity.tif
          ;;

          # Compute and render the cast shadows
          d)
            info_msg "Creating cast shadow map"

            demwidth=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $10}')
            demheight=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $11}')
            demxmin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $2}')
            demxmax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $3}')
            demymin=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $4}')
            demymax=$(gmt grdinfo -C ${F_TOPO}dem.nc ${VERBOSE} | awk '{print $5}')


            [[ ! -e ${F_TOPO}dem.flt ]] && gdalwarp -dstnodata -9999 -t_srs EPSG:3395 -s_srs EPSG:4326 -r bilinear -if netCDF -of EHdr -ot Float32 -ts $demwidth $demheight ${F_TOPO}dem.nc ${F_TOPO}dem.flt -q

            # texture the DEM. Pipe output to /dev/null to silence the program
            if [[ $(echo "$MAXLAT >= 90" | bc) -eq 1 ]]; then
              MERCMAXLAT=89.999
            else
              MERCMAXLAT=$MAXLAT
            fi
            if [[ $(echo "$MINLAT <= -90" | bc) -eq 1 ]]; then
              MERCMINLAT=-89.999
            else
              MERCMINLAT=$MINLAT
            fi

            ${SHADOW} ${SUN_AZ} ${SUN_EL} ${F_TOPO}dem.flt ${F_TOPO}shadow.flt -mercator ${MERCMINLAT} ${MERCMAXLAT} > /dev/null
            # project back to WGS1984

            gdalwarp -s_srs EPSG:3395 -t_srs EPSG:4326 -r bilinear  -ts $demwidth $demheight -te $demxmin $demymin $demxmax $demymax ${F_TOPO}shadow.flt ${F_TOPO}shadow_back.tif -q

            MAX_SHADOW=$(grep "max_value" ${F_TOPO}shadow.hdr | gawk '{print $2}')

            # Change to 8 bit unsigned format
            gdal_translate -of GTiff -ot Byte -a_nodata 255 -scale $MAX_SHADOW 0 1 254 ${F_TOPO}shadow_back.tif ${F_TOPO}shadow.tif -q
            # Combine it with the existing intensity
            alpha_value ${F_TOPO}shadow.tif ${SHADOW_ALPHA} ${F_TOPO}shadow_alpha.tif

            multiply_combine ${F_TOPO}shadow_alpha.tif ${F_TOPO}intensity.tif ${F_TOPO}intensity.tif
          ;;

          # Rescale and gamma correct the intensity layer
          g)
            info_msg "Rescale stretching and gamma correcting intensity layer"
            zrange=$(grid_zrange ${F_TOPO}intensity.tif -C -Vn)
            histogram_rescale_stretch ${F_TOPO}intensity.tif ${zrange[0]} ${zrange[1]} 1 254 $HS_GAMMA ${F_TOPO}intensity_cor.tif
            mv ${F_TOPO}intensity_cor.tif ${F_TOPO}intensity.tif
          ;;

          # Percent cut the intensity layer
          x)
            info_msg "Executing percent cut on intensity layer"
            histogram_percentcut_byte ${F_TOPO}intensity.tif $TPCT_MIN $TPCT_MAX ${F_TOPO}intensity_percentcut.tif
            cp ${F_TOPO}intensity_percentcut.tif ${F_TOPO}intensity.tif
          ;;

          # Set intensity of DEM values with elevation=0 to 254
          u)
            info_msg "Resetting 0 elevation cells to white"
            image_setval ${F_TOPO}intensity.tif ${F_TOPO}dem.nc 0 254 ${F_TOPO}unset.tif
            cp ${F_TOPO}unset.tif ${F_TOPO}intensity.tif
          ;;

          esac
        done < <(echo -n "$topoctrlstring")

        INTENSITY_RELIEF=${F_TOPO}intensity.tif

        if [[ ${topoctrlstring} =~ .*p.* ]]; then

            # if [[ $demisclippedflag -eq 1 ]]; then
            #   P_MAXLON=${CLIP_MAXLON}
            #   P_MINLON=${CLIP_MINLON}
            #   P_MAXLAT=${CLIP_MAXLAT}
            #   P_MINLAT=${CLIP_MINLAT}
            # else
            #   P_MAXLON=${MAXLON}
            #   P_MINLON=${MINLON}
            #   P_MAXLAT=${MAXLAT}
            #   P_MINLAT=${MINLAT}
            # fi
            dem_dim=($(gmt grdinfo ${F_TOPO}dem.nc -C -L -Vn))
            dem_dimx=${dem_dim[9]}
            dem_dimy=${dem_dim[10]}
            info_msg "Rendering georeferenced RGB image ${P_IMAGE} as colored texture."
            if [[ ${P_IMAGE} =~ "sentinel.tif" ]]; then
              info_msg "Rendering Sentinel image"
              gdalwarp -q -te ${DEM_MINLON} ${DEM_MINLAT} ${DEM_MAXLON} ${DEM_MAXLAT} -ts ${dem_dimx} ${dem_dimy} sentinel.tif ${F_TOPO}image_pre.tif
              histogram_rescale_stretch ${F_TOPO}image_pre.tif 1 180 1 254 ${SENTINEL_GAMMA} ${F_TOPO}image.tif
            else
              gdalwarp -q -te ${DEM_MINLON} ${DEM_MINLAT} ${DEM_MAXLON} ${DEM_MAXLAT} -ts ${dem_dimx} ${dem_dimy} ${P_IMAGE} ${F_TOPO}image.tif
            fi
            # weighted_average_combine ${F_TOPO}image.tif ${F_TOPO}intensity.tif ${IMAGE_FACT} ${F_TOPO}intensity.tif
            multiply_combine ${F_TOPO}image.tif $INTENSITY_RELIEF ${F_TOPO}colored_intensity.tif
            INTENSITY_RELIEF=${F_TOPO}colored_intensity.tif
        fi

        if [[ ${topoctrlstring} =~ .*c.* && ! ${topoctrlstring} =~ .*p.* ]]; then
          info_msg "Creating and blending color stretch (alpha=$DEM_ALPHA)."
          gdaldem color-relief ${F_TOPO}dem.nc ${F_CPTS}topocolor.dat ${F_TOPO}colordem.tif -q
          alpha_value ${F_TOPO}colordem.tif ${DEM_ALPHA} ${F_TOPO}colordem_alpha.tif
          multiply_combine ${F_TOPO}colordem_alpha.tif $INTENSITY_RELIEF ${F_TOPO}colored_intensity.tif
          COLORED_RELIEF=${F_TOPO}colored_intensity.tif
        else
          COLORED_RELIEF=$INTENSITY_RELIEF
        fi
        BATHY=${F_TOPO}dem.nc
      fi  # fasttopoflag

      if [[ $dontplottopoflag -eq 0 ]]; then
        if [[ $fasttopoflag -eq 0 ]]; then   # If we are doing more complex topo visualization
          gmt grdimage ${COLORED_RELIEF} $GRID_PRINT_RES -t$TOPOTRANS $RJOK ${VERBOSE} >> map.ps
        else # If we are doing fast topo visualization
          gmt grdimage ${BATHY} ${ILLUM} -C${TOPO_CPT} $GRID_PRINT_RES -t$TOPOTRANS $RJOK ${VERBOSE} >> map.ps
        fi
      else
        info_msg "Plotting of topo shaded relief suppressed by -ts"
      fi
      ;;

    usergrid)
      # Each time usergrid) is called, plot the grid and increment to the next
      info_msg "Plotting user grid $current_usergridnumber: ${GRIDADDFILE[$current_usergridnumber]} with CPT ${GRIDADDCPT[$current_usergridnumber]}"
      gmt grdimage ${GRIDADDFILE[$current_usergridnumber]} -Q -I+d -C${GRIDADDCPT[$current_usergridnumber]} $GRID_PRINT_RES -t${GRIDADDTRANS[$current_usergridnumber]} $RJOK ${VERBOSE} >> map.ps
      current_usergridnumber=$(echo "$current_usergridnumber + 1" | bc -l)
      ;;

    volcanoes)
      info_msg "Volcanoes"
      gmt psxy ${F_VOLC}volcanoes.dat -W0.25p,"${V_LINEW}" -G"${V_FILL}" -St"${V_SIZE}"/0  $RJOK $VERBOSE >> map.ps
      ;;

	esac
done

current_usergridnumber=1

##### PLOT LEGEND
if [[ $makelegendflag -eq 1 ]]; then
  gmt gmtset MAP_TICK_LENGTH_PRIMARY 0.5p MAP_ANNOT_OFFSET_PRIMARY 1.5p MAP_ANNOT_OFFSET_SECONDARY 2.5p MAP_LABEL_OFFSET 2.5p FONT_LABEL 6p,Helvetica,black

  if [[ $legendovermapflag -eq 1 ]]; then
    LEGMAP="map.ps"
  else
    info_msg "Plotting legend in its own file"
    LEGMAP="maplegend.ps"
    gmt psxy -T -JX20ix20i -R0/10/0/10 -X$PLOTSHIFTX -Y$PLOTSHIFTY -K $VERBOSE > maplegend.ps
  fi

  MSG="Updated legend commands are >>>>> ${legendwords[@]} <<<<<"
  [[ $narrateflag -eq 1 ]] && echo $MSG

  echo "# Legend " > legendbars.txt
  barplotcount=0
  plottedneiscptflag=0

  info_msg "Plotting colorbar legend items"

  # First, plot the color bars in a column. How many could you possibly have anyway?
  # We should probably be using -Bxaf for everything instead of overthinking things

  for plot in ${legendwords[@]} ; do
  	case $plot in
      cities)
          echo "G 0.2i" >> legendbars.txt
          echo "B $POPULATION_CPT 0.2i 0.1i+malu -W0.00001 -Bxa10f1+l\"City population (100k)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        ;;

      cmt|seis|slab2)
        # Don't plot a color bar if we already have plotted one OR the seis CPT is a solid color
        if [[ $plottedneiscptflag -eq 0 && ! $seisfillcolorflag -eq 1 ]]; then
          plottedneiscptflag=1
          # if [[ $(echo "$EQMAXDEPTH_COLORSCALE > 1000" | bc) -eq 1 ]]; then
          #   EQXINT=500
          # elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 500" | bc) -eq 1 ]]; then
          #   EQXINT=250
          # elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 100" | bc) -eq 1 ]]; then
          #   EQXINT=50
          # elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 50" | bc) -eq 1 ]]; then
          #   EQXINT=10
          # elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 25" | bc) -eq 1 ]]; then
          #   EQXINT=5
          # elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 5" | bc) -eq 1 ]]; then
          #   EQXINT=1
          # fi
          echo "G 0.2i" >> legendbars.txt
          echo "B $SEISDEPTH_NODEEPEST_CPT 0.2i 0.1i+malu+e -Bxaf+l\"Earthquake / slab depth (km)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        fi
        ;;

  		grav)
        if [[ -e $GRAV_CPT ]]; then
          echo "G 0.2i" >> legendbars.txt
          echo "B $GRAV_CPT 0.2i 0.1i+malu -Bxa100f50+l\"$GRAVMODEL gravity (mgal)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        fi
  			;;

      litho1)
        if [[ $LITHO1_TYPE == "density" ]]; then
          echo "G 0.2i" >> legendbars.txt
          echo "B $LITHO1_DENSITY_CPT 0.2i 0.1i+malu -Bxa500f50+l\"LITHO1.0 density (kg/m^3)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        elif [[ $LITHO1_TYPE == "Vp" ]]; then
          echo "G 0.2i" >> legendbars.txt
          echo "B $LITHO1_VELOCITY_CPT 0.2i 0.1i+malu -Bxa1000f250+l\"LITHO1.0Vp velocity (m/s)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        elif [[ $LITHO_TYPE == "Vs" ]]; then
          echo "G 0.2i" >> legendbars.txt
          echo "B $LITHO1_VELOCITY_CPT 0.2i 0.1i+malu -Bxa1000f250+l\"LITHO1.0 Vs velocity (m/s)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        fi
        ;;

  		mag)
        echo "G 0.2i" >> legendbars.txt
        echo "B $MAG_CPT 0.2i 0.1i+malu -Bxa100f50+l\"Magnetization (nT)\"" >> legendbars.txt
        barplotcount=$barplotcount+1
  			;;

      oceanage)
        echo "G 0.2i" >> legendbars.txt
        echo "B $OC_AGE_CPT 0.2i 0.1i+malu -Bxa50+l\"Ocean crust age (Ma)\"" >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

      plateazdiff)
        echo "G 0.2i" >> legendbars.txt
        echo "B ${CPTDIR}cycleaz.cpt 0.2i 0.1i+malu -Bxa90f30+l\"Azimuth difference (°)\"" >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

      platevelgrid)
        echo "G 0.2i" >> legendbars.txt
        echo "B $PLATEVEL_CPT 0.2i 0.1i+malu -Bxa50f10+l\"Plate velocity (mm/yr)\"" >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

      # seis)
      #   if [[ $plottedneiscptflag -eq 0 ]]; then
      #     plottedneiscptflag=1
      #     echo "G 0.2i" >> legendbars.txt
      #     echo "B $SEISDEPTH_NODEEPEST_CPT 0.2i 0.1i+malu -Bxa100f50+l\"Earthquake / slab depth (km)\"" >> legendbars.txt
      #     barplotcount=$barplotcount+1
      #   fi
  		# 	;;

  		# slab2)
      #   if [[ $plottedneiscptflag -eq 0 ]]; then
      #     plottedneiscptflag=1
      #     echo "G 0.2i" >> legendbars.txt
      #     echo "B ${SEISDEPTH_NODEEPEST_CPT} 0.2i 0.1i+malu -Bxa100f50+l\"Earthquake / slab depth (km)\"" >> legendbars.txt
      #     barplotcount=$barplotcount+1
      #   fi
  		# 	;;

      seissum)
        echo "G 0.2i" >> legendbars.txt
        echo "B ${CPTDIR}seisout.cpt 0.2i 0.1i+malu -Bxaf+l\"M0 (x10^N)\"" -W0.001 >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

      topo)
        echo "G 0.2i" >> legendbars.txt
        echo "B ${TOPO_CPT} 0.2i 0.1i+malu -Bxa${BATHYXINC}f1+l\"Elevation (km)\"" -W0.001 >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

      usergrid)
        echo "G 0.2i" >> legendbars.txt
        echo "B ${GRIDADDCPT[$current_usergridnumber]} 0.2i 0.1i+malu -Bxaf+l\"$(basename ${GRIDADDFILE[$current_usergridnumber]})\"" >> legendbars.txt
        barplotcount=$barplotcount+1
        current_usergridnumber=$(echo "$current_usergridnumber + 1" | bc -l)
        ;;

  	esac
  done

  velboxflag=0
  [[ $barplotcount -eq 0 ]] && LEGEND_WIDTH=0.01
  LEG2_X=$(echo "$LEGENDX $LEGEND_WIDTH 0.1i" | gawk  '{print $1+$2+$3 }' )
  LEG2_Y=${MAP_PS_HEIGHT_IN_plus}

  # The non-colobar plots come next. pslegend can't handle a lot of things well,
  # and scaling is difficult. Instead we make small eps files and plot them,
  # keeping track of their size to allow relative positioning
  # Not sure how robust this is... but it works...

  # NOTE: Velocities need to be scaled by gpsscalefactor to fit with the map

  # We will plot items vertically in increments of 3, and then add an X_INC and send Y to MAP_PS_HEIGHT_IN
  count=0
  # Keep track of the largest width we have used and make next column not overlap it.
  NEXTX=0
  GPS_ELLIPSE_TEXT=$(gawk -v c=0.95 'BEGIN{print c*100 "%" }')

  info_msg "Plotting non-colorbar legend items"

  for plot in ${plots[@]} ; do
  	case $plot in
      cmt)
        info_msg "Legend: cmt"

        MEXP_TRIPLE=$(awk < $CMTFILE '
          @include "tectoplot_functions.awk"
          # function ceil(x){return int(x)+(x>int(x))}
          BEGIN {
            getline;
            maxmag=$13
          }
          {
            maxmag=($13>maxmag)?$13:maxmag
          }
          END {
            if (maxmag>9) {
              maxmag=9
            }
            printf "%0.1d %0.1d %0.1d", ceil(maxmag)-2, ceil(maxmag)-1, ceil(maxmag)
          }')

        MEXP_ARRAY=($(echo $MEXP_TRIPLE))
        MEXP_V_N=${MEXP_ARRAY[0]}
        MEXP_V_S=${MEXP_ARRAY[1]}
        MEXP_V_T=${MEXP_ARRAY[2]}

        MEXP_N=$(stretched_m0_from_mw $MEXP_V_N)
        MEXP_S=$(stretched_m0_from_mw $MEXP_V_S)
        MEXP_T=$(stretched_m0_from_mw $MEXP_V_T)

        if [[ $CMTLETTER == "c" ]]; then
          echo "$CENTERLON $CENTERLAT 15 322 39 -73 121 53 -104 $MEXP_N 126.020000 13.120000 C021576A" | gmt psmeca -E"${CMT_NORMALCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtnormalflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 220 0.99" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 342 0.23" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 129 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT N/${MEXP_V_N}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.14i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 14 92 82 2 1 88 172 $MEXP_S 125.780000 8.270000 B082783A" | gmt psmeca -E"${CMT_SSCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK -X0.35i -Y-0.15i ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtssflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 316 0.999" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 47 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 167 0.14" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT SS/${MEXP_V_S}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 33 321 35 92 138 55 89 $MEXP_T 123.750000 7.070000 M081676B" | gmt psmeca -E"${CMT_THRUSTCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 -X0.35i -Y-0.15i -R -J -O -K ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtthrustflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 42 0.17" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 229 0.999" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 139 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT R/${MEXP_V_T}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.16i -O >> mecaleg.ps
        fi
        if [[ $CMTLETTER == "m" ]]; then
          echo "$CENTERLON $CENTERLAT 10 -3.19 1.95 1.24 -0.968 -0.425 $MEXP_N 0 0 " | gmt psmeca -E"${CMT_NORMALCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtnormalflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 220 0.99" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 342 0.23" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 129 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT N/${MEXP_V_N}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.14i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 10 0.12 -1.42 1.3 0.143 -0.189 $MEXP_S 0 0 " | gmt psmeca -E"${CMT_SSCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK -X0.35i -Y-0.15i ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtssflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 316 0.999" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 47 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 167 0.14" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT SS/${MEXP_V_S}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 15 2.12 -1.15 -0.97 0.54 -0.603 $MEXP_T 0 0 2016-12-08T17:38:46" | gmt psmeca -E"${CMT_THRUSTCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 -X0.35i -Y-0.15i -R -J -O -K ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtthrustflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 42 0.17" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 229 0.999" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 139 0.96" | gawk  -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT R/${MEXP_V_T}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.16i -O >> mecaleg.ps
        fi

        PS_DIM=$(gmt psconvert mecaleg.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i mecaleg.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      eqlabel)
        info_msg "Legend: eqlabel"

        [[ $EQ_LABELFORMAT == "idmag"   ]]  && echo "$CENTERLON $CENTERLAT ID Mw" | gawk  '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'      > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "datemag" ]]  && echo "$CENTERLON $CENTERLAT Date Mw" | gawk  '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'    > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "dateid"  ]]  && echo "$CENTERLON $CENTERLAT Date ID" | gawk  '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'    > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "id"      ]]  && echo "$CENTERLON $CENTERLAT ID" | gawk  '{ printf "%s %s %s\n", $1, $2, $3 }'                 > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "date"    ]]  && echo "$CENTERLON $CENTERLAT Date" | gawk  '{ printf "%s %s %s\n", $1, $2, $3 }'               > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "year"    ]]  && echo "$CENTERLON $CENTERLAT Year" | gawk  '{ printf "%s %s %s\n", $1, $2, $3 }'               > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "yearmag" ]]  && echo "$CENTERLON $CENTERLAT Year Mw" | gawk  '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'    > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "mag"     ]]  && echo "$CENTERLON $CENTERLAT Mw" | gawk  '{ printf "%s %s %s\n", $1, $2, $3 }'                 > eqlabel.legend.txt

        cat eqlabel.legend.txt | gmt pstext -Gwhite -W0.5p,black -F+f${EQ_LABEL_FONTSIZE},${EQ_LABEL_FONT},${EQ_LABEL_FONTCOLOR}+j${EQ_LABEL_JUST} -R -J -O ${VERBOSE} >> eqlabel.ps
        PS_DIM=$(gmt psconvert eqlabel.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i eqlabel.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      grid)
        info_msg "Legend: grid"

        GRIDMAXVEL_INT=$(echo "scale=0;($GRIDMAXVEL+5)/1" | bc)
        V100=$(echo "$GRIDMAXVEL_INT" | bc -l)
        if [[ $PLATEVEC_COLOR =~ "white" ]]; then
          echo "$CENTERLON $CENTERLAT $GRIDMAXVEL_INT 0 0 0 0 0 ID" | gmt psvelo -W0p,gray@$PLATEVEC_TRANS -Ggray@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velarrow.ps 2>/dev/null
        else
          echo "$CENTERLON $CENTERLAT $GRIDMAXVEL_INT 0 0 0 0 0 ID" | gmt psvelo -W0p,$PLATEVEC_COLOR@$PLATEVEC_TRANS -G$PLATEVEC_COLOR@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velarrow.ps 2>/dev/null
        fi
        echo "$CENTERLON $CENTERLAT Plate velocity ($GRIDMAXVEL_INT mm/yr)" | gmt pstext -F+f6p,Helvetica,black+jLB $VERBOSE -J -R -Y0.1i -O >> velarrow.ps
        PS_DIM=$(gmt psconvert velarrow.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i velarrow.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      gps)
        info_msg "Legend: gps"

        GPSMAXVEL_INT=$(echo "scale=0;($GPSMAXVEL+5)/1" | bc)
        echo "$CENTERLON $CENTERLAT $GPSMAXVEL_INT 0 5 5 0 ID" | gmt psvelo -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velgps.ps 2>/dev/null
        GPSMESSAGE="GPS: $GPSMAXVEL_INT mm/yr (${GPS_ELLIPSE_TEXT})"
        echo "$CENTERLON $CENTERLAT $GPSMESSAGE" | gmt pstext -F+f6p,Helvetica,black+jLB -J -R -Y0.1i -O ${VERBOSE} >> velgps.ps
        PS_DIM=$(gmt psconvert velgps.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i velgps.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      kinsv)
        info_msg "Legend: kinsv"
        echo "$CENTERLON $CENTERLAT" |  gmt psxy -Sc0.01i -W0p,white -Gwhite $RJOK $VERBOSE >> kinsv.ps
        echo "$CENTERLON $CENTERLAT" |  gmt psxy -Ss0.4i -W0p,lightblue -Glightblue $RJOK -X0.4i $VERBOSE >> kinsv.ps
        KINMESSAGE=" EQ kinematic vectors "
        echo "$CENTERLON $CENTERLAT $KINMESSAGE" | gmt pstext -F+f6p,Helvetica,black+jLB $VERBOSE -J -R -Y0.2i -X-0.35i -O -K >> kinsv.ps
        echo "$CENTERLON $CENTERLAT 31 .35" |  gmt psxy -SV0.05i+jb+e -W0.4p,${NP1_COLOR} -G${NP1_COLOR} $RJOK -X0.35i  -Y-0.2i $VERBOSE >> kinsv.ps

        if [[ $plottedkinsd -eq 1 ]]; then # Don't close
          echo "$CENTERLON $CENTERLAT 235 .35" | gmt psxy -SV0.05i+jb+e -W0.4p,${NP2_COLOR} -G${NP2_COLOR} $RJOK $VERBOSE >> kinsv.ps
        else
          echo "$CENTERLON $CENTERLAT 235 .35" | gmt psxy -SV0.05i+jb+e -W0.4p,${NP2_COLOR} -G${NP2_COLOR} -R -J -O $VERBOSE >> kinsv.ps
        fi
        if [[ $plottedkinsd -eq 1 ]]; then
          echo "$CENTERLON $CENTERLAT 55 .1" | gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite $RJOK $VERBOSE >> kinsv.ps
          echo "$CENTERLON $CENTERLAT 325 0.175" |  gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite $RJOK $VERBOSE >> kinsv.ps
          echo "$CENTERLON $CENTERLAT 211 .1" | gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray $RJOK $VERBOSE >> kinsv.ps
          echo "$CENTERLON $CENTERLAT 121 0.175" | gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray -R -J -O $VERBOSE >> kinsv.ps
        fi
        PS_DIM=$(gmt psconvert kinsv.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i kinsv.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
       ;;

      # Strike and dip of nodal planes is plotted using kinsv above
      # kingeo)
      #
      #   ;;

      plate)
        # echo "$CENTERLON $CENTERLAT 90 1" | gmt psxy -SV$ARROWFMT -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} $RJOK $VERBOSE >> plate.ps
        # echo "$CENTERLON $CENTERLAT Kinematics stuff" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -X0.2i -Y0.1i -O >> plate.ps
        # PS_DIM=$(gmt psconvert plate.ps -Te -A0.05i 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        # PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        # PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        # gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i plate.ps $RJOK >> $LEGMAP
        # LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        # count=$count+1
        # NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      seis)
        info_msg "Legend: seis"

        if [[ -e $CMTFILE ]]; then
          # Get magnitude range from CMT
          SEIS_QUINT=$(awk < $CMTFILE '
            @include "tectoplot_functions.awk"
            # function ceil(x){return int(x)+(x>int(x))}
            BEGIN {
              getline;
              maxmag=$13
            }
            {
              maxmag=($13>maxmag)?$13:maxmag
            }
            END {
              if (maxmag>9) {
                maxmag=9
              }
              print (maxmag>8)?"5.0 6.0 7.0 8.0 9.0":(maxmag>7)?"4.0 5.0 6.0 7.0 8.0":(maxmag>6)?"3.0 4.0 5.0 6.0 7.0":(maxmag>5)?"2.0 3.0 4.0 5.0 6.0":"1.0 2.0 3.0 4.0 5.0"
            }')
        else  # Get magnitude range from seismicity
          SEIS_QUINT=$(awk < ${F_SEIS}eqs.txt '
            BEGIN {
              getline;
              maxmag=$4
            }
            {
              maxmag=($4>maxmag)?$4:maxmag
            }
            END {
              print (maxmag>8)?"5.0 6.0 7.0 8.0 9.0":(maxmag>7)?"4.0 5.0 6.0 7.0 8.0":(maxmag>6)?"3.0 4.0 5.0 6.0 7.0":(maxmag>5)?"2.0 3.0 4.0 5.0 6.0":"1.0 2.0 3.0 4.0 5.0"
            }')
        fi

        SEIS_ARRAY=($(echo $SEIS_QUINT))

        MW_A=$(stretched_mw_from_mw ${SEIS_ARRAY[0]})
        MW_B=$(stretched_mw_from_mw ${SEIS_ARRAY[1]})
        MW_C=$(stretched_mw_from_mw ${SEIS_ARRAY[2]})
        MW_D=$(stretched_mw_from_mw ${SEIS_ARRAY[3]})
        MW_E=$(stretched_mw_from_mw ${SEIS_ARRAY[4]})

        OLD_PROJ_LENGTH_UNIT=$(gmt gmtget PROJ_LENGTH_UNIT -Vn)
        gmt gmtset PROJ_LENGTH_UNIT p

        echo "$CENTERLON $CENTERLAT $MW_A DATESTR ID" | gmt psxy -W0.5p,black -G${ZSFILLCOLOR} -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT ${SEIS_ARRAY[0]}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_B DATESTR ID" | gmt psxy -W0.5p,black -G${ZSFILLCOLOR} -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT ${SEIS_ARRAY[1]}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_C DATESTR ID" | gmt psxy -W0.5p,black -G${ZSFILLCOLOR} -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT ${SEIS_ARRAY[2]}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.14i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_D DATESTR ID" | gmt psxy -W0.5p,black -G${ZSFILLCOLOR} -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT ${SEIS_ARRAY[3]}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_E DATESTR ID" | gmt psxy -W0.5p,black -G${ZSFILLCOLOR} -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.3i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT ${SEIS_ARRAY[4]}" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.16i -O >> seissymbol.ps

        gmt gmtset PROJ_LENGTH_UNIT $OLD_PROJ_LENGTH_UNIT

        PS_DIM=$(gmt psconvert seissymbol.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i seissymbol.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      srcmod)
  			# echo 0 0.1 "Slip magnitudes from: $SRCMODFSPLOCATIONS"  | gmt pstext $VERBOSE -F+f8,Helvetica,black+jBL -Y$YADD $RJOK >> maplegend.ps
        # YADD=0.2
  			;;

      tdefnode)
        info_msg "Legend: tdefnode"

        velboxflag=1
        # echo 0 0.1 "TDEFNODE: $TDPATH"  | gmt pstext $VERBOSE -F+f8,Helvetica,black+jBL -Y$YADD  $RJOK >> maplegend.ps
        # YADD=0.15
        ;;

      volcanoes)
        info_msg "Legend: volcanoes"

        echo "$CENTERLON $CENTERLAT" | gmt psxy -W0.25p,"${V_LINEW}" -G"${V_FILL}" -St"${V_SIZE}"/0 $RJOK ${VERBOSE} >> volcanoes.ps
        echo "$CENTERLON $CENTERLAT Volcano" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.1i -O >> volcanoes.ps

        PS_DIM=$(gmt psconvert volcanoes.ps -Te -A0.05i -V 2> >(grep Width) | gawk  -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | gawk  '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | gawk  '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i volcanoes.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | gawk  '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;
    esac
    if [[ $count -eq 3 ]]; then
      count=0
      LEG2_X=$(echo "$LEG2_X + $NEXTX" | bc -l)
      # echo "Updated LEG2_X to $LEG2_X"
      LEG2_Y=${MAP_PS_HEIGHT_IN}
    fi
  done

  info_msg "Legend: printing data sources"
  # gmt pstext tectoplot.shortplot -F+f6p,Helvetica,black $KEEPOPEN $VERBOSE >> map.ps
  # x y fontinfo angle justify linespace parwidth parjust
  echo "> 0 0 9p Helvetica,black 0 l 0.1i ${INCH}i l" > datasourceslegend.txt
  uniq tectoplot.shortsources | gawk  'BEGIN {printf "T Data sources: "} {print}'  | tr '\n' ' ' >> datasourceslegend.txt

  # gmt gmtset FONT_ANNOT_PRIMARY 8p,Helvetica-bold,black

  # NUMLEGBAR=$(wc -l < legendbars.txt)
  # if [[ $NUMLEGBAR -eq 1 ]]; then
  #   gmt pslegend datasourceslegend.txt -Dx0.0i/${MAP_PS_HEIGHT_IN_minus}i+w${LEGEND_WIDTH}+w${INCH}i+jBL -C0.05i/0.05i -J -R -O $KEEPOPEN ${VERBOSE} >> $LEGMAP
  # else

  gmt pslegend datasourceslegend.txt -Dx0.0i/${MAP_PS_HEIGHT_IN}i+w${LEGEND_WIDTH}+w${INCH}i+jBL -C0.05i/0.05i -J -R -O -K ${VERBOSE} >> $LEGMAP
  gmt pslegend legendbars.txt -Dx0i/${MAP_PS_HEIGHT_IN_plus}i+w${LEGEND_WIDTH}+jBL -C0.05i/0.05i -J -R -O -K ${VERBOSE} >> $LEGMAP
  # fi

  # If we are closing the separate legend file, PDF it
  if [[ $keepopenflag -eq 0 && $legendovermapflag -eq 0 ]]; then
    gmt psconvert -Tf -A0.5i  maplegend.ps
    mv maplegend.pdf $THISDIR"/"$MAPOUTLEGEND
    info_msg "Map legend is at $THISDIR/$MAPOUTLEGEND"
    [[ $openflag -eq 1 ]] && open -a $OPENPROGRAM $THISDIR"/"$MAPOUTLEGEND
  fi

fi  # [[ $makelegendflag -eq 1 ]]

# Export TECTOPLOT call and GMT command history from PS file to .history file

# Close the PS if we need to
gmt psxy -T -R -J -O $KEEPOPEN $VERBOSE >> map.ps

echo "${COMMAND}" > "$MAPOUT.history"
echo "${COMMAND}" >> $TECTOPLOTDIR"tectoplot.history"

grep "%@GMT:" map.ps | sed -e 's/%@GMT: //' >> "$MAPOUT.history"

##### MAKE PDF OF MAP
# Requires gs 9.26 and not later as they nuked transparency in later versions
if [[ $keepopenflag -eq 0 ]]; then
   if [[ $epsoverlayflag -eq 1 ]]; then
     gmt psconvert -Tf -A0.5i -Mf${EPSOVERLAY} $VERBOSE map.ps
   else
     gmt psconvert -Tf -A0.5i $VERBOSE map.ps
  fi
  mv map.pdf "${THISDIR}/${MAPOUT}.pdf"
  mv "$MAPOUT.history" $THISDIR"/"$MAPOUT".history"
  info_msg "Map is at $THISDIR/$MAPOUT.pdf"
  [[ $openflag -eq 1 ]] && open -a $OPENPROGRAM "$THISDIR/$MAPOUT.pdf"
fi

##### MAKE GEOTIFF OF MAP
if [[ $tifflag -eq 1 ]]; then
  gmt psconvert map.ps -Tt -A -W -E${GEOTIFFRES} ${VERBOSE}

  mv map.tif "${THISDIR}/${MAPOUT}.tif"
  mv map.tfw "${THISDIR}/${MAPOUT}.tfw"

  [[ $openflag -eq 1 ]] && open -a $OPENPROGRAM "${THISDIR}/${MAPOUT}.tif"
fi

##### Make script to plot oblique view of topography, execute if option is set
#     If we are
if [[ $plottedtopoflag -eq 1 ]]; then
  info_msg "Oblique map (${OBLIQUEAZ}/${OBLIQUEINC})"
  PSSIZENUM=$(echo $PSSIZE | gawk  '{print $1+0}')

  # if [[ $demisclippedflag -eq 1 ]]; then
  #   P_MAXLON=${CLIP_MAXLON}
  #   P_MINLON=${CLIP_MINLON}
  #   P_MAXLAT=${CLIP_MAXLAT}
  #   P_MINLAT=${CLIP_MINLAT}
  # else
  #   P_MAXLON=${MAXLON}
  #   P_MINLON=${MINLON}
  #   P_MAXLAT=${MAXLAT}
  #   P_MINLAT=${MINLAT}
  # fi


  # zrange is the elevation change across the DEM
  zrange=($(grid_zrange $BATHY -R${DEM_MINLON}/${DEM_MAXLON}/${DEM_MINLAT}/${DEM_MAXLAT} -C -Vn))

  if [[ $obplotboxflag -eq 1 ]]; then
    OBBOXCMD="-N${OBBOXLEVEL}+gwhite"
    # If the box goes upward for some reason???
    if [[ $(echo "${zrange[1]} < $OBBOXLEVEL" | bc -l) -eq 1 ]]; then
      zrange[1]=$OBBOXLEVEL;
    elif [[ $(echo "${zrange[0]} > $OBBOXLEVEL" | bc -l) -eq 1 ]]; then
      # The box base falls below the zrange minimum (typical example)
      zrange[0]=$OBBOXLEVEL
    fi
  else
    OBBOXCMD=""
  fi

  # make_oblique.sh takes up to three arguments: vertical exaggeration, azimuth, inclination

  echo "#!/bin/sh" >> ./make_oblique.sh
  echo "if [[ \$# -ge 1 ]]; then" >> ./make_oblique.sh
  echo "  OBLIQUE_VEXAG=\${1}" >> ./make_oblique.sh
  echo "else" >> ./make_oblique.sh
  echo "  OBLIQUE_VEXAG=${OBLIQUE_VEXAG}"  >> ./make_oblique.sh
  echo "fi" >> ./make_oblique.sh

  echo "if [[ \$# -ge 2 ]]; then" >> ./make_oblique.sh
  echo "  OBLIQUEAZ=\${2}" >> ./make_oblique.sh
  echo "else" >> ./make_oblique.sh
  echo "  OBLIQUEAZ=${OBLIQUEAZ}"  >> ./make_oblique.sh
  echo "fi" >> ./make_oblique.sh

  echo "if [[ \$# -ge 3 ]]; then" >> ./make_oblique.sh
  echo "  OBLIQUEINC=\${3}" >> ./make_oblique.sh
  echo "else" >> ./make_oblique.sh
  echo "  OBLIQUEINC=${OBLIQUEINC}"  >> ./make_oblique.sh
  echo "fi" >> ./make_oblique.sh

  echo "if [[ \$# -ge 4 ]]; then" >> ./make_oblique.sh
  echo "  OBLIQUERES=\${4}" >> ./make_oblique.sh
  echo "else" >> ./make_oblique.sh
  echo "  OBLIQUERES=${OBLIQUERES}"  >> ./make_oblique.sh
  echo "fi" >> ./make_oblique.sh

  echo "DELTAZ_IN=\$(echo \"\${OBLIQUE_VEXAG} * ${PSSIZENUM} * (${zrange[1]} - ${zrange[0]})/ ( (${DEM_MAXLON} - ${DEM_MINLON}) * 111000 )\"  | bc -l)"  >> ./make_oblique.sh

  # echo "gmt grdview $BATHY -G${COLORED_RELIEF} -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JM${MINLON}/${PSSIZENUM}i -JZ\${DELTAZ_IN}i ${OBBOXCMD} -Qi${OBLIQUERES} ${OBBCOMMAND} -p\${OBLIQUEAZ}/\${OBLIQUEINC} --GMT_HISTORY=false --MAP_FRAME_TYPE=$OBBAXISTYPE ${VERBOSE} > oblique.ps" >> ./make_oblique.sh
  if [[ $plotimageflag -eq 1 ]]; then
    echo "gmt grdimage im.tiff ${RJSTRING[@]} ${OBBOXCMD} -Qi\${OBLIQUERES} ${OBBCOMMAND} -p\${OBLIQUEAZ}/\${OBLIQUEINC} --GMT_HISTORY=false --MAP_FRAME_TYPE=$OBBAXISTYPE ${VERBOSE} > ob2.ps" >> ./make_oblique.sh
  fi
  echo "gmt grdview $BATHY -G${COLORED_RELIEF} ${RJSTRING[@]} -JZ\${DELTAZ_IN}i ${OBBOXCMD} -Qi\${OBLIQUERES} ${OBBCOMMAND} -p\${OBLIQUEAZ}/\${OBLIQUEINC} --GMT_HISTORY=false --MAP_FRAME_TYPE=$OBBAXISTYPE ${VERBOSE} > oblique.ps" >> ./make_oblique.sh
  echo "gmt psconvert oblique.ps -Tf -A0.5i --GMT_HISTORY=false ${VERBOSE}" >> ./make_oblique.sh
  chmod a+x ./make_oblique.sh

  if [[ $obliqueflag -eq 1 ]]; then
    ./make_oblique.sh
  fi
fi

##### MAKE KML OF MAP
if [[ $kmlflag -eq 1 ]]; then
  gmt psconvert map.ps -Tt -A -W+k -E${KMLRES} ${VERBOSE}
  ncols=$(gmt grdinfo map.tif -C ${VERBOSE} | gawk  '{print $10}')
  nrows=$(gmt grdinfo map.tif -C ${VERBOSE} | gawk  '{print $11}')
  echo "($MAXLON - $MINLON) / $ncols" | bc -l > map.tfw
  echo "0" >> map.tfw
  echo "0" >> map.tfw
  echo "- ($MAXLAT - $MINLAT) / $nrows" | bc -l >> map.tfw
  echo "$MINLON" >> map.tfw
  echo "$MAXLAT" >> map.tfw
  [[ $openflag -eq 1 ]] && open -a $OPENPROGRAM "${THISDIR}/${MAPOUT}.tif"
fi

##### PLOT STEREONET OF FOCAL MECHANISM PRINCIPAL AXES
if [[ $caxesstereonetflag -eq 1 ]]; then
  echo "Making stereonet of focal mechanism axes"
  gmt psbasemap -JA0/-89.999/3i -Rg -Bxa10fg10 -Bya10fg10 -K ${VERBOSE} > stereo.ps
  gmt makecpt -Cwysiwyg -T$MINLAT/$MAXLAT/1 > lon.cpt
  if [[ $axescmtthrustflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  if [[ $axescmtnormalflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  if [[ $axescmtssflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && gawk  < ${F_KIN}t_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && gawk  < ${F_KIN}p_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && gawk  < ${F_KIN}n_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  gmt psxy -T -R -J -O ${VERBOSE} >> stereo.ps
  gmt psconvert stereo.ps -Tf -A0.5i ${VERBOSE}
fi

# Create header / metadata information for all files, using a control file in $DEFDIR

if [[ $scripttimeflag -eq 1 ]]; then
  SCRIPT_END_TIME="$(date -u +%s)"
  elapsed="$(($SCRIPT_END_TIME - $SCRIPT_START_TIME))"
  echo "Script run time was $elapsed seconds"
fi

# # Create a utility data projection script matching the current map setup
# # Will take a whitespace delimited text file and the numbers of the lon/lat
# # columns and will output the same file with projected coordinates
#
# # data_project.sh lon_col_num lat_col_num
# echo "#!/bin/bash" > ${F_MAPELEMENTS}data_project.sh
# for element in ${RJSTRING[@]}; do
#   echo "RJSTRING+=(\"$element\")" >> ${F_MAPELEMENTS}data_project.sh
# done
# echo "echo \${RJSTRING[@]}"  >> ${F_MAPELEMENTS}data_project.sh
# echo ""
exit 0
