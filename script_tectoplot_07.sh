#!/bin/bash
TECTOPLOT_VERSION="TECTOPLOT 0.2, November 2020"
#
# Script to make seismotectonic plots with integrated plate motions and
# earthquake kinematics, plus cross sections, primarily using GMT.
#
# Kyle Bradley, Nanyang Technological University (kbradley@ntu.edu.sg)
# Prefers GS 9.26 (and no later) for transparency

# brew update
# brew install gmt
# brew


# As of December 2020, this will install GS9.26 on OSX
#
#brew unlink ghostscript
#cd /usr/local/Homebrew/Library/Taps/homebrew/homebrew-core/Formula
#git checkout 6ec0c1a03ad789b6246bfbbf4ee0e37e9f913ee0 ghostscript.rb
#brew install ghostscript
#brew pin ghostscript

# CHANGELOG

# December 13, 2020: Added -zcat option to select ANSS/ISC seismicity catalog
#  Note that earthquake culling may not work well for ISC due to so many events?
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
# October  20, 2020: Added -clipdem to save a dem.nc file in the temporary data folder, mainly for in-place profile control
# October  19, 2020: Initial git commit at kyleedwardbradley/tectoplot
# October  10, 2020: Added code to avoid double plotting of XYZ and CMT data on overlapping profiles.
# October   9, 2020: Project data only onto the closest profile from the whole collection.
# October   9, 2020: Add a date range option to restrict seismic/CMT data
# October   9, 2020: Add option to rotate CMTs based on back azimuth to a specified lon/lat point
# October   9, 2020: Update seismicity for legend plot using SEISSTRETCH

# FUN FACTS:
# You can make a Minecraft landscape in oblique perspective diagrams if you oversample the grid.
#
# # KNOWN BUGS:
# tectoplot remake seems broken?
#
# DREAM LEVEL:
# Generate a map_plot.sh script that contains all GMT/etc commands needed to replicate the plot.
# This script would be editable and would quite quickly rerun the plotting as the
# relevant data files would already be generated.
# Not 100% sure that the script is linear enough to do this without high complexity...

# TO DO:
#
# HIGHER PRIORITY:

# !! Add magnitude type to seismicity catalog to allow future conversion (e.g. Wetherill et al. 2017)
# !! Remove anthropogenic earthquakes from catalog (e.g. Wetherill et al. 2017)

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


################################################################################
# Messaging and debugging routines

# Uncomment the above line for the ultimate debugging experience.
#

_ERR_HDR_FMT="%.23s %s[%s]: "
_ERR_MSG_FMT="${_ERR_HDR_FMT}%s\n"

function error_msg() {
  printf "$_ERR_MSG_FMT" $(date +%F.%T.%N) ${BASH_SOURCE[1]##*/} ${BASH_LINENO[0]} "${@}"
  exit 1
}

function info_msg() {
  if [[ $narrateflag -eq 1 ]]; then
    printf "TECTOPLOT %05s: " ${BASH_LINENO[0]}
    printf "${@}\n"
  fi
}

# Exit cleanup code from Mitch Frazier
# https://www.linuxjournal.com/content/use-bash-trap-statement-cleanup-temporary-files

declare -a on_exit_items

function cleanup_on_exit()
{
    for i in "${on_exit_items[@]}"
    do
        info_msg "rm -f $i"
        rm -f $i
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

# Grid z range query function. Try to avoid querying the full grid when determining the range of Z values

function grid_zrange() {
   output=$(gmt grdinfo -C $1 -Vn)
   zmin=$(echo $output | awk '{print $6}')
   zmax=$(echo $output | awk '{print $7}')
   if [[ $(echo "$zmin == 0 && $zmax == 0" | bc) -eq 1 ]]; then
      # echo "Querying full grid as zrange is 0"
      output=$(gmt grdinfo -C -L $1 -Vn)
   fi
   echo $output | awk '{print $6, $7}'
}

##### A first step toward portability. Credit Jordan@StackExchange

case "$OSTYPE" in
   cygwin*)
      alias open="cmd /c start"
      ;;
   linux*)
      alias start="xdg-open"
      alias open="xdg-open"
      ;;
   darwin*)
      alias start="open"
      ;;
esac

################################################################################
# GMT shell functions
. gmt_shell_functions.sh

################################################################################
# These variables are array indices and must be equal to ZERO at start

plotpointnumber=0
cmtfilenumber=0

################################################################################
# Define paths and defaults

THISDIR=$(pwd)

GMTREQ="6"
RJOK="-R -J -O -K"

# TECTOPLOTDIR is where the actual script resides
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
TECTOPLOTDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"/

echo "Running script from $TECTOPLOTDIR"

DEFDIR=$TECTOPLOTDIR"tectoplot_defs/"

# These files are sourced using the . command, so they should be valid bash
# scripts but without #!/bin/bash

TECTOPLOT_DEFAULTS_FILE=$DEFDIR"tectoplot.defaults"
TECTOPLOT_PATHS_FILE=$DEFDIR"tectoplot.paths"
TECTOPLOT_PATHS_MESSAGE=$DEFDIR"tectoplot.paths.message"
TECTOPLOT_COLORS=$DEFDIR"tectoplot.gmtcolors"
TECTOPLOT_CPTDEFS=$DEFDIR"tectoplot.cpts"

################################################################################
# Load default file stored in the same directory as tectoplot

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

##### FORMATS MESSAGE is now in a file in tectoplot_defs

function formats() {
echo $TECTOPLOT_VERSION
cat $TECTOPLOT_FORMATS
}

##### USAGE MESSAGES

function print_help_header() {
  cat <<-EOF

  -----------------------------------------------------------------------------

  $TECTOPLOT_VERSION
  Kyle Bradley, Nanyang Technological University
  kbradley@ntu.edu.sg

  This script uses GMT, gdal, and geod to make seismotectonic maps, cross
  sections, and oblique block diagrams. It is basically a collection of tools
  and methods I have personally used to make maps/figures.

  Developed for OSX Catalina, minimal testing indicates works with Fedora linux

  USAGE: tectoplot -opt1 arg1 -opt2 arg2 arg3 ...

  Map layers are generally plotted in the order they are specified.

  HELP and INSTALLATION: tectoplot -setup
  OPTIONS:               tectoplot -options
  VARIABLES:             tectoplot -variables
  LONG HELP:             tectoplot  or tectoplot -h|-help|--help

  -----------------------------------------------------------------------------

EOF
}

function print_options() {
cat <<-EOF
    Optional arguments:
    [opt] is required if the flag is present
    [[opt]] if not specified will assume a default value or will not be used

  Data control, installation, information
    -addpath                                             add the tectoplot source directory to your ~.profile
    -getdata                                             download and validate builtin datasets
    -setopenprogram                                      configure program to open PDFs

    --data                                               list data sources and exit
    --defaults                                           print default values and exit (Can edit and load using -setvars)
    --formats                                            print information on data formats and exit
    -h|--help                                            print this message and exit
    -megadebug                                           turn on hyper-verbose shell debugging
    -n|--narrate                                         echo a lot of information during processing
    --verbose                                            set gmt -V flag for all calls

  Low-level control
    -gmtvars         [{VARIABLE value ...}]              set GMT internal variables
    -pos X Y         Set X Y position of plot origin     (GMT format -X$VAL -Y$VAL; e.g -Xc -Y1i etc)
    -pss             [size]                              PS page size in inches (8)
    -psr             [0-1]                               scale factor of map ofs pssize
    -psm             [size]                              PS margin in inches (0.5)
    -cpts                                                remake default CPT files
    -setvars         { VAR1 VAL1 VAR2 VAL2 }             set bash variable values
    -vars            [variables file]                    set bash variable values by sourcing file
    -ob
    -tm|--tempdir    [tempdir]                           use tempdir as temporary directory
    -e|--execute     [bash script file]                  runs a script using source command
    -i|--vecscale    [value]                             scale all vectors (0.02)

  Map projection and Area of Interest options
    -r|--range       [MinLon MaxLon MinLat MaxLat]       area of interest, degrees
                     [g]                                 global domain
                     [ID]                                AOI of 2 character country code, breaks if crosses dateline!
                     [raster_file]                       take the limits of the given raster file
    -RJ              [{ -Retc -Jetc }]                   provide custom R, J GMT strings
                      UTM [[zone]]                        plot UTM, zone is defined by mid longitude (-r) or specified
    -rect                                                use rectangular map frame (UTM projection only)

  Output map format options
    -geotiff                                             output GeoTIFF and .tfw, frame inside
    -kml                                                 output KML, frame inside
    --keepopenps                                         don't close the PS file
    -ips             [filename]                          plot on top of an unclosed .ps file
    -op|--overplot   [X Y]                               plot over previous output (save map.ps only)
                      X,Y are horizontal and vertical offset in inches
    --open           [[program]]                         open PDF file at end
    -o|--out         [filename]                          name of output file
    --inset          [[size]]                            plot a globe with AOI polygon
    --legend         [[width]]                           plot legend above the map area (color bar width=2i)

  Grid/gratiucle and map frame options
    -B               [{ -Betc -Betc }]                   provide custom B strings for map in GMT argument format
    -pgs             [gridline spacing]                  override map gridline spacing
    -pgo                                                 turn grid lines off
    -scale           [length] [lon] [lat]                plot a scale bar. length needs suffix (e.g. 100k).

  Plotting/control commands:

  Profiles and oblique block diagrams:
    -mprof           [control_file] [[A B X Y]]          plot multiple swath profile
                     A=width (7i) B=height (2i) X,Y=offset relative to current origin (0i -3i)
    -sprof           [lon1] [lat1] [lon2] [lat2] [width] [res]   plot an automatic profile using data on map
                     width has units in format, e.g. 100k and is full width of profile
                     res is the resolution at which we resample grids to make top tile grid (e.g. 1k)
    -oto             adjust vertical scale (after all other options) to set V:H ratio at 1 (no exaggeration)
    -psel            [PID1] [[PID2...]]                  only plot profiles with specified PID from control file
    -mob             [[Azimuth(deg)]] [[Inclination(deg)]] [[VExagg(factor)]] [[Resolution(m)]]
                            create oblique perspective diagrams for profiles
    -msd             Use a signed distance formulation for profiling to generate DEM for display (for kinked profiles)
    -msl             Display only the left side of the profile so that the cut is exactly on-profile
    -litho1 [type]   Plot LITHO1.0 data for each profile. Allowed types are: density Vp Vs

  Topography/bathymetry:
    -t|--topo        [[ SRTM30 | GEBCO20 | GEBCO1 | ERCODE | GMRT | BEST | custom_grid_file ]] [[cpt]]
                     plot shaded relief (including a custom grid)
                     ERCODE: GMT Earth Relief Grids, dynamically downloaded and stored locally:
                     01d ~100km | 30m ~55 km | 20m ~37km | 15m ~28km | 10m ~18 km | 06m ~10km
                     05m ~9km | 04m ~7.5km | 03m ~5.6km | 02m ~3.7km | 01m ~1.9km | 15s ~500m
                     03s ~100m | 01s ~30m
                     BEST uses GMRT for elev < 0 and 01s for elev >= 0 (resampled to match GMRT)
    -ts                                                  don't plot shaded relief/topo grid
    -ti              [off] | [azimuth (°)]               set parameters for grid illumination (GMT shading, not gdalt)
    -tn              [interval (m)]                      plot topographic contours
    -tr              [[minelev maxelev]]                 rescale CPT using data range or specified limits
    -tc|--cpt        [cptfile]                           use custom cpt file for topo grid
    -tt|--topotrans  [transparency%]                     transparency of topo grid
    -clipdem                                             save terrain as dem.nc in temporary directory
    -gebcotid                                            plot GEBCO TID raster
    -gdalt           [[gamma (0-1)]] [[% HS (0-1)]]      render colored multiple hillshade using gdal

  Additional map layers from downloadable data:
    -a|--coast       [[quality]] [[a,b]] { gmtargs }     plot coastlines [[a]] and borders [[b]]
                     quality = a,f,h,i,l,c
    -ac              [[LANDCOLOR]] [[SEACOLOR]]          fill coastlines/sea (requires subsequent -a command)
    -acb                                                 plot country borders
    -acl                                                 label country centroids
    -af              [[AFLINEWIDTH]] [[AFLINECOLOR]]     plot active fault traces
    -b|--slab2       [[layers string: c]]                plot Slab2 data; default is c
          c: slab contours
    -g|--gps         [[RefPlateID]]                      plot GPS data from Kreemer 2014 / rel. to RefPlateID
    -gcdm                                                plot Global Curie Depth Map
    -litho1_depth    [type] [depth]                      plot litho1 depth slice (positive depth in km)
    -m|--mag         [[transparency%]]                   plot crustal magnetization
    -oca             [[trans%]] [[MaxAge]]               oceanic crust age
    -s|--srcmod                                          plot fused SRCMOD EQ slip distributions
    -v|--gravity     [[FA | BG | IS]] [transparency%] [rescale]            rescale=rescale colors to min/max
                      plot WGM12 gravity. FA = free air | BG == Bouguer | IS = Isostatic
    -vc|--volc                                           plot Pleistocene volcanoes
    -pp|--cities     [[min population]]                  plot cities with minimum population, color by population
    -ppl             [[min population]]                  label cities with a minimum population

  Seismicity:
    -z|--seis        [[scale]]                           plot seismic epicenters (from scraped earthquake data)
  ! -zd              [[scale]] [STARTTIME ENDTIME]       plot seismic epicenters (new download from ANSS for AOI)
    --time           [STARTTIME ENDTIME]                 select EQ/CMT between dates (midnight AM), format YYYY-MM-DD
    -zsort           [date|depth|mag] [up|down]          sort earthquake data before plotting
    -zs              [file]                              add supplemental seismicity file [lon lat depth mag]
    -zmag            [minmag] [maxmag]                   set minimum and maximum magnitude
    -zcat            [ANSS or ISC]                       select the scraped EQ catalog to use

  Seismicity/focal mechanism data control:
    -reportdates                                         print date range of seismic, focal mechanism catalogs and exit
    -scrapedata                                          run the GCMT/ISC/ANSS scraper scripts and exit
    -recenteq                                            run scraper and plot recent earthquakes. Need to specify -c, -z, -r options.
    -eqlist          [[file]] { event1 event2 event3 ... }  highlight focal mechanisms/hypocenters with ID codes in file or list
    -eqlabel         [list] [[minmag]] [format      ]    label earthquakes in eqlist or within magnitude range
    -pg|--polygon    [polygon_file.xy] [[show]]          use a closed polygon to select data instead of AOI; show prints to map

  Focal mechanisms:
    -c|--cmt         [[source]] [[scale]]                plot focal mechanisms from global databases
    -cx              [file]                              plot additional focal mechanisms, format matches -cf option
    -ca              [nts] [tpn]                         plot selected P/T/N axes for selected EQ types
    -cc                                                  plot dot and line connecting to alternative position (centroid/origin)
    -cd|--cmtdepth   [depth]                             maximum depth of CMTs, km
    -cf              [GlobalCMT | MomentTensor | TNP]    choose the format of focal mechanism to plot
    -cm|--cmtmag     [minmag maxmag]                     magnitude bounds for cmt
    -cr|--cmtrotate) [lon] [lat]                         rotate CMTs based on back-azimuth to a point
    -cw                                                  plot CMTs with white compressive quads
    -ct|--cmttype    [nts | nt | ns | n | t | s]         sets earthquake types to plot CMTs
    -zr1|--eqrake1   [[scale]]                           color focal mechs by N1 rake
    -zr2|--eqrake2   [[scale]]                           color focal mechs by N2 rake
    -cs                                                  plot TNP axes on a stereonet (output to stereo.pdf)
    -cadd            [file] [a,c]                        plot focal mechanisms from local data in psmeca format
                             a=Aki/Richard format c=GCMT

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
    -pe|--plateedge  [[GBM | MORVEL | GSRM]]             plot plate model polygons
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
    -pvg             [rescale]                           plots a plate motion velocity grid. rescale=rescale colors to min/max

  User specified GIS datasets:
    -im|--image      [filename] { gmtargs }              plot a RGB GeoTiff file
    -pt|--point      [filename] [[symbol]] [[size]] [[cptfile]]    data: x y z
    -l|--line        [filename] [[color]] [[width]]                data: > ID (z)\n x y\n x y\n > ID2 (z) x y\n ...
    -sv|--slipvector [filename]                          plot data file of slip vector azimuths [Lon Lat Az]
    -gg|--extragps   [filename]                          plot an additional GPS / psvelo format file
    -cn              [gridfile] [interval] { gmtargs }   plot contours of a gridded dataset
                                            gmtargs for -A -S and -C will replace defaults

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
                REMOVE_EQUIVS [$REMOVE_EQUIVS] - USEANSS_DATABASE [$USEANSS_DATABASE]

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
    Unix commands: awk, bc, cat, curl, date, grep, sed

  Installation and setup:

  1. First, clone into a new folder from Github, or unzip a Github ZIP file

  ~/# git clone https://github.com/kyleedwardbradley/tectoplot.git tectoplot

  2. cd into the script folder and add its path to ~/.profile, and then source
    the ~/.profile file to update your current shell environment

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

# This function will check for and attempt to download data.

DELETEZIPFLAG=0

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

  info_msg "Checking ${DOWNLOADNAME}..."
  if [[ ! -d ${DOWNLOADDIR} ]]; then
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} does not exist. Creating."
    mkdir -p ${DOWNLOADDIR}
  else
    info_msg "${DOWNLOADNAME} directory ${DOWNLOADDIR} exists."
  fi

  if [[ ! -e ${DOWNLOADFILE} ]]; then         # If the file doesn't already exist
    if [[ $DOWNLOADGETZIP =~ "yes" ]]; then   # If we need to download a ZIP file
      if [[ -e ${DOWNLOADZIP} ]]; then        # If we already have a ZIP file
        filebytes=$(wc -c < ${DOWNLOADZIP})
        if [[ $(echo "$filebytes == ${DOWNLOADZIP_BYTES}" | bc) -eq 1 ]]; then       # If the ZIP file is complete
           info_msg "${DOWNLOADNAME} archive file exists and is complete"
        else                                                      # Continue the ZIP file download
           info_msg "Trying to resume ${DOWNLOADZIP} download. If this doesn't work, delete ${DOWNLOADZIP} and retry."
           if ! curl --fail -L -C - ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADZIP}; then
             info_msg "Attempted resumption of ${DOWNLOAD_SOURCEURL} download failed."
             echo "${DOWNLOADNAME}_resume" >> tectoplot.failed
           fi
        fi
      fi
      if [[ ! -e ${DOWNLOADZIP} ]]; then
        info_msg "${DOWNLOADNAME} file ${DOWNLOADFILE} and ZIP do not exist. Downloading ZIP from source URL into ${DOWNLOADDIR}."
        if ! curl --fail -L ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADZIP}; then
          info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
          echo "${DOWNLOADNAME}" >> tectoplot.failed
        fi
      fi
      if [[ -e ${DOWNLOADZIP} ]]; then
        if [[ ${DOWNLOADZIP: -4} == ".zip" ]]; then
           unzip ${DOWNLOADZIP} -d ${DOWNLOADDIR}
        elif [[ ${DOWNLOADZIP: -6} == "tar.gz" ]]; then
           mkdir -p ${DOWNLOADDIR}
           tar -xf ${DOWNLOADZIP} -C ${DOWNLOADDIR}
        fi
      fi
    else  # We don't need to download a ZIP - just download the file directly
      if ! curl --fail -L ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADFILE}; then
        info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
        echo "${DOWNLOADNAME}" >> tectoplot.failed
      fi
    fi
  else
    info_msg "${DOWNLOADNAME} raster ${DOWNLOADFILE} already exists."
  fi

  filebytes=$(wc -c < ${DOWNLOADFILE})
  if [[ $(echo "$filebytes == ${DOWNLOADFILE_BYTES}" | bc) -eq 1 ]]; then
    info_msg "${DOWNLOADNAME} file size is verified."
    [[ ${DOWNLOADGETZIP} =~ "yes" && ${DELETEZIPFLAG} -eq 1 ]] && echo "Deleting zip archive" && rm -f ${DOWNLOADZIP}
  else
    info_msg "File size mismatch for ${DOWNLOADFILE} ($filebytes should be $DOWNLOADFILE_BYTES). Trying to continue download."
    if ! curl --fail -L -C - ${DOWNLOAD_SOURCEURL} -o ${DOWNLOADFILE}; then
      info_msg "Download of ${DOWNLOAD_SOURCEURL} failed."
      echo "${DOWNLOADNAME}" >> tectoplot.failed
    fi
  fi
}

function interval_and_subinterval_from_minmax_and_number () {
  local vmin=$1
  local vmax=$2
  local numint=$3
  local subval=$4
  local diffval=$(echo "($vmax - $vmin) / $numint" | bc -l)
  #
  #
  # echo $INTERVALS_STRING | awk -v s=$diffval -v md=$subval 'function abs(a) { return (a<0)?-a:a }{
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
  plotgrav=0
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
  isdefaultregionflag=1
  kinnormalflag=1
  kinssflag=1
  kinthrustflag=1
  normalstyleflag=1
  np1flag=1
  np2flag=1
  platediffvcutoffflag=1   # If can be collapsed in Atom
fi

###### The list of things to plot starts empty

plots=()

# Argument arrays that are slurped

customtopoargs=()
imageargs=()
topoargs=()

# The full command is output into the ps file and .history file
COMMAND="${0} ${@}"

# Exit if no arguments are given
if [[ $# -eq 0 ]]; then
  print_usage
  exit 1
fi

# If only one argument is given and it is '-remake', rerun command in file
# tectoplot.last and exit
if [[ $# -eq 1 && ${1} =~ "-remake" ]]; then
  info_msg "Rerunning last tectoplot command executed in this directory"
  cat tectoplot.last
  . tectoplot.last
  exit 1
fi

if [[ $# -eq 2 && ${1} =~ "-remake" ]]; then
  if [[ ! -e ${2} ]]; then
    error_msg "Error: no file ${2}"
  fi
  head -n 1 ${2} > tectoplot.cmd
  info_msg "Rerunning last tectoplot command from first line in file ${2}"
  cat tectoplot.cmd
  . tectoplot.cmd
  exit 1
fi

echo $COMMAND > tectoplot.last
rm -f tectoplot.sources
rm -f tectoplot.shortsources

##### PARSE ARGUMENTS FROM COMMAND LINE
while [[ $# -gt 0 ]]
do
  key="${1}"
  case ${key} in

  -a) # args: none || string
    plotcoastlines=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
			info_msg "[-a]: No quality specified. Using a"
			COAST_QUALITY="-Da"
		else
			COAST_QUALITY="-D${2}"
			shift
		fi
    # if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-ac]: No land/sea color specified. Using defaults"
      FILLCOASTS="-G${LANDCOLOR} -S${SEACOLOR}"
    else
      LANDCOLOR="${2}"
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-ac]: No sea color specified. Not filling sea areas"
        FILLCOASTS="-G${LANDCOLOR}"
      else
        SEACOLOR="${2}"
        shift
        FILLCOASTS="-G$LANDCOLOR -S$SEACOLOR"
      fi
    fi
    ;;

  -acb)
    plots+=("countryborders")
    ;;

  -acl)
    plots+=("countrylabels")
    ;;

  -addpath)   # Add tectoplot source directory to ~/.profile and exit
      if [[ ! -e ~/.profile ]]; then
        info_msg "[-addpath]: ~/.profile does not exist. Creating."
      else
        val=$(grep "tectoplot" ~/.profile | awk 'END{print NR}')
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-af]: No line width specified. Using $AFLINEWIDTH"
    else
      AFLINEWIDTH="${2}"
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-af]: No line color specified. Using $AFLINECOLOR"
      else
        AFLINECOLOR="${2}"
        shift
      fi
    fi
    plots+=("gemfaults")
    ;;

	-b|--slab2) # args: none || strong
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      CENTROIDFLAG=1
      ORIGINFLAG=1
      CMTTYPE="CENTROID"
      echo $ISC_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $ISC_SOURCESTRING >> tectoplot.sources
      echo $GCMT_SHORT_SOURCESTRING >> tectoplot.shortsources
      echo $GCMT_SOURCESTRING >> tectoplot.sources
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
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-c]: No scaling for CMTs specified... using default $CMTSCALE"
      else
        CMTSCALE="${2}"
        info_msg "[-c]: CMT scale updated to $CMTSCALE"
        shift
      fi
    fi
		plots+=("cmt")
    cpts+=("seisdepth")
	  ;;

  -ca) #  [nts] [tpn] plot selected P/T/N axes for selected EQ types
    calccmtflag=1
    cmtsourcesflag=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-ca]: CMT axes eq type not specified. Using default ($CMTAXESSTRING)"
    else
      CMTAXESSTRING="${2}"
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    CMTADDFILE[$cmtfilenumber]=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    CMTFORMATCODE[$cmtfilenumber]="${2}"
    shift
    CMTIDCODE[$cmtfilenumber]="C"
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-cf]: CMT format must be specified"
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

  # -cm|--cmtmag) # args: number number
  #   CMT_MINMAG="${2}"
  #   CMT_MAXMAG="${3}"
  #   shift
  #   shift
  #   ;;

  -cn)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-cn]: Grid file not specified"
    else
      CONTOURGRID=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    EXECUTEFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    plots+=("execute")
    ;;

  -eps)
    epsoverlayflag=1
    EPSOVERLAY=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    ;;

  -eqlabel)
      while [[ ${2:0:1} != [-] && ! -z $2 ]]; do
        if [[ $2 == "list" ]]; then
          labeleqlistflag=1
          shift
        elif [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ ]]; then
          labeleqmagflag=1
          labeleqminmag="${2}"
          shift
        elif [[ $2 == "idmag" || $2 == "datemag" || $2 == "dateid" || $2 == "id" || $2 == "date" || $2 == "mag" ]]; then
          EQ_LABELFORMAT="${2}"
          echo "fmt $EQ_LABELFORMAT"
          shift
        else
          info_msg "[-eqlabel]: Label class $2 not recognized."
        fi
      done
      plots+=("eqlabel")
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
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-eqlist]: Specify a file or { list } of events"
      else
        EQLISTFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
        shift
        while read p; do
          pq=$(echo "${p}" | awk '{print $1}')
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
			info_msg "[-g]: No override GPS reference plate specified"
		else
			GPSID="${2}"
			info_msg "[-g]: Ovveriding GPS plate ID = ${GPSID}"
			gpsoverride=1
			GPS_FILE=`echo $GPS"/GPS_$GPSID.gmt"`
			shift
      echo $GPS_SOURCESTRING >> tectoplot.sources
      echo $GPS_SHORT_SOURCESTRING >> tectoplot.shortsources
		fi
		plots+=("gps")
		;;

  -gcdm)
    plots+=("gcdm")
    cpts+=("gcdm")
    ;;

  -gdalt)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-gdalt]: No gamma value specified. Using default: ${HS_GAMMA}"
    else
      HS_GAMMA="${2}"
      info_msg "[-gdalt]: Gamma value set to ${HS_GAMMA}"
      shift
    fi
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-gdalt]: No hillshade/slope blend specified. Using default: ${HSSLOPEBLEND} "
    else
      HSSLOPEBLEND="${2}"
      info_msg "[-gdalt]: Gamma value set to ${HS_GAMMA}"
      shift
    fi
    gdemtopoplotflag=1
    clipdemflag=1
    gdaltzerohingeflag=1
    ;;

  -getdata)
    narrateflag=1
    info_msg "Checking and updating downloaded datasets: GEBCO1 GEBCO20 EMAG2 SRTM30 WGM Geonames GCDM Slab2.0 OC_AGE LITHO1.0"

    check_and_download_dataset "GEBCO1" $GEBCO1_SOURCEURL "yes" $GEBCO1DIR $GEBCO1FILE $GEBCO1DIR"data.zip" $GEBCO1_BYTES $GEBCO1_ZIP_BYTES
    check_and_download_dataset "GEBCO20" $GEBCO20_SOURCEURL "yes" $GEBCO20DIR $GEBCO20FILE $GEBCO20DIR"data.zip" $GEBCO20_BYTES $GEBCO20_ZIP_BYTES
    check_and_download_dataset "EMAG_V2" $EMAG_V2_SOURCEURL "no" $EMAG_V2_DIR $EMAG_V2 "none" $EMAG_V2_BYTES "none"
    check_and_download_dataset "SRTM30" $SRTM30_SOURCEURL "yes" $SRTM30DIR $SRTM30FILE "none" $SRTM30_BYTES "none"

    check_and_download_dataset "WGM2012-Bouguer" $WGMBOUGUER_SOURCEURL "no" $WGMDIR $WGMBOUGUER "none" $WGMBOUGUER_BYTES "none"
    check_and_download_dataset "WGM2012-Isostatic" $WGMISOSTATIC_SOURCEURL "no" $WGMDIR $WGMISOSTATIC "none" $WGMISOSTATIC_BYTES "none"
    check_and_download_dataset "WGM2012-FreeAir" $WGMFREEAIR_SOURCEURL "no" $WGMDIR $WGMFREEAIR "none" $WGMFREEAIR_BYTES "none"

    check_and_download_dataset "WGM2012-Bouguer-CPT" $WGMBOUGUER_CPT_SOURCEURL "no" $WGMDIR $WGMBOUGUER_CPT "none" $WGMBOUGUER_CPT_BYTES "none"
    check_and_download_dataset "WGM2012-Isostatic-CPT" $WGMISOSTATIC_CPT_SOURCEURL "no" $WGMDIR $WGMISOSTATIC_CPT "none" $WGMISOSTATIC_CPT_BYTES "none"
    check_and_download_dataset "WGM2012-FreeAir-CPT" $WGMFREEAIR_CPT_SOURCEURL "no" $WGMDIR $WGMFREEAIR_CPT "none" $WGMFREEAIR_CPT_BYTES "none"

    check_and_download_dataset "Geonames-Cities" $CITIES_SOURCEURL "yes" $CITIESDIR $CITIES500 $CITIESDIR"data.zip" $CITIES500_BYTES $CITIES_ZIP_BYTES
    info_msg "Processing cities data to correct format" && awk < $CITIESDIR"cities500.txt" -F'\t' '{print $6 "," $5 "," $2 "," $15}' > $CITIES

    check_and_download_dataset "GlobalCurieDepthMap" $GCDM_SOURCEURL "no" $GCDMDIR $GCDMDATA_ORIG "none" $GCDM_BYTES "none"
    [[ ! -e $GCDMDATA ]] && info_msg "Processing GCDM data to grid format" && gmt xyz2grd -R-180/180/-80/80 $GCDMDATA_ORIG -I10m -G$GCDMDATA

    check_and_download_dataset "SLAB2" $SLAB2_SOURCEURL "yes" $SLAB2_DATADIR $SLAB2_CHECKFILE $SLAB2_DATADIR"data.zip" $SLAB2_CHECK_BYTES $SLAB2_ZIP_BYTES
    [[ ! -d $SLAB2DIR ]] && [[ -e $SLAB2_CHECKFILE ]] && tar -xvf $SLAB2_DATADIR"Slab2Distribute_Mar2018.tar.gz" --directory $SLAB2_DATADIR
    # Change the format of the Slab2 grids so that longitudes go from -180:180
    # If we don't do this, some regions will have profiles/maps fail.
    for slab2file in $SLAB2DIR; do
      gmt grdedit -L $slab2file
    done

    check_and_download_dataset "OC_AGE" $OC_AGE_URL "no" $OC_AGE_DIR $OC_AGE "none" $OC_AGE_BYTES "none"
    check_and_download_dataset "OC_AGE_CPT" $OC_AGE_CPT_URL "no" $OC_AGE_DIR $OC_AGE_CPT "none" $OC_AGE_CPT_BYTES "none"

    check_and_download_dataset "LITHO1.0" $LITHO1_SOURCEURL "yes" $LITHO1DIR $LITHO1FILE $LITHO1DIR"data.tar.gz" $LITHO1_BYTES $LITHO1_ZIP_BYTES
    if [[ ! -e $LITHO1_PROG ]]; then
      echo "Compiling LITHO1 extract tool"
      ${ACCESS_LITHO_CPP} -c ${LITHO1PROGDIR}access_litho.cc -DMODELLOC=\"${LITHO1DIR_2}\" -o ${LITHO1PROGDIR}access_litho.o
      ${ACCESS_LITHO_CPP}  ${LITHO1PROGDIR}access_litho.o -lm -DMODELLOC=\"${LITHO1DIR_2}\" -o ${LITHO1_PROG}
      echo "Testing LITHO1 extract tool"
      res=$(access_litho -p 20 20 2>/dev/null | awk '(NR==1) { print $3 }')
      if [[ $(echo "$res == 8060.22" | bc) -eq 1 ]]; then
        echo "access_litho returned correct value"
      else
        echo "access_litho returned incorrect result. Deleting executable. Check compiler, paths, etc."
        rm -f ${LITHO1_PROG}
      fi
    fi

    exit 0
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

  -gebcotid)
    plots+=("gebcotid")
    clipdemflag=1
    ;;

  -gg|--extragps) # args: file
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-gg]: No extra GPS file given. Exiting"
      exit 1
    else
      EXTRAGPS=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      info_msg "[-gg]: Plotting GPS velocities from $EXTRAGPS"
      shift
    fi
    plots+=("extragps")
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

  -gridlabels) # args: string (quoted)
    GRIDCALL="${2}"
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
    IMAGENAME=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
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
    plots+=("image")
    ;;

  --inset)
    plots+=("inset")
    ;;

  -ips) # args: file
    overplotflag=1
    PLOTFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ $regionsetflag -ne 1 ]]; then
      info_msg "[-geotiff]: Region should be set with -r before -geotiff flag is set. Using default region."
    fi
    gmt gmtset MAP_FRAME_TYPE inside
    RJSTRING="-R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} -JX${PSSIZE}id"
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    echo "++++KV CMTFILE $CMTFILE"

 		svflag=1
		plots+=("kinsv")
 		;;

  -l|--line) # args: file color
      GISLINEFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      GISLINECOLOR="${3}"
      GISLINEWIDTH="${4}"
      shift
      shift
      shift
      plots+=("gisline")
    ;;

  --legend) # args: none
    makelegendflag=1
    legendovermapflag=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[--legend]: No width for color bars specified. Using $LEGEND_WIDTH"
    else
      LEGEND_WIDTH="${2}"
      shift
      info_msg "[--legend]: Legend width for color bars is $LEGEND_WIDTH"
    fi
    ;;

  -litho1)
    litho1profileflag=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-litho1_depth]: No type specified. Using default $LITHO1_TYPE and depth $LITHO1_DEPTH"
    else
      LITHO1_TYPE="${2}"
      shift
      info_msg "[-litho1_depth: Using data type $LITHO1_TYPE"
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
			info_msg "[-m]: No magnetism transparency set. Using default"
		else
			MAGTRANS="${2}"
			shift
		fi
		info_msg "[-m]: Magnetic data to plot is ${MAGMODEL}, transparency is ${MAGTRANS}"
		plots+=("mag")
    echo $MAG_SOURCESTRING >> tectoplot.sources
    echo $MAG_SHORT_SOURCESTRING >> tectoplot.shortsources
	  ;;

  -megadebug)
    set -x
    ;;

  -mob)
    clipdemflag=1
    PLOT_SECTIONS_PROFILEFLAG=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-mob]: No vertical exaggeration specified. Using $PERSPECTIVE_EXAG"
    else
      PERSPECTIVE_EXAG="${2}"
      shift
    fi
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-mob]: No resampling resolution specified. Using $PERSPECTIVE_RES"
    else
      PERSPECTIVE_RES="${2}"
      shift
    fi
    info_msg "[-mob]: az=$PERSPECTIVE_AZ, inc=$PERSPECTIVE_INC, exag=$PERSPECTIVE_EXAG, res=$PERSPECTIVE_RES"
    ;;

  -mprof)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-mprof]: No profile control file specified."
    else
      MPROFFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      shift
    fi

    # PROFILE_WIDTH_IN
    # PROFILE_HEIGHT_IN
    # PROFILE_X
    # PROFILE_Z

    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

	-n|--narrate)
		narrateflag=1
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-ob]: No azimuth/inc specified. Using default ${OBLIQUEAZ}."
    else
      OBLIQUEAZ="${2}"
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-ob]: Azimuth but no inclination specified. Using default ${OBLIQUEINC}."
      else
        OBLIQUEINC="${2}"
        shift
      fi
    fi
    ;;

  -oca)
    plots+=("oceanage")
    cpts+=("oceanage")
    echo $OC_AGE_SOURCESTRING >> tectoplot.sources
    echo $OC_AGE_SHORT_SOURCESTRING >> tectoplot.shortsources

    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-oc]: No transparency set. Using default $OC_TRANS"
    else
      OC_TRANS="${2}"
      shift
    fi
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-oc]: No maximum age set for CPT."
      stretchoccptflag=0
    else
      OC_MAXAGE="${2}"
      shift
      stretchoccptflag=1
    fi

    ;;

  --open)
    openflag=1
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

  -pe|--plateedge)  # args: none
    plots+=("plateedge")
    ;;

  -pf|--fibsp) # args: number
    gridfibonacciflag=1
    makegridflag=1
    FIB_KM="${2}"
    FIB_N=$(echo "510000000 / ( $FIB_KM * $FIB_KM - 1 ) / 2" | bc)
    shift
    plots+=("grid")
    ;;

  -pg) # args: file
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pg]: No polygon file specified."
    else
      polygonselectflag=1
      POLYGONAOI=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      shift
      if [[ ! -e $POLYGONAOI ]]; then
        info_msg "[-pg]: Polygon file $POLYGONAOI does not exist."
        exit 1
      fi
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

  -pgo)
    GRIDLINESON=0
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pr]: No colatitude step specified: using ${LATSTEPS}"
    else
      LATSTEPS="${2}"
      shift
    fi
    plots+=("platerotation")
    platerotationflag=1
    ;;

  -printcountries)
    awk -F, < $COUNTRY_CODES '{ print $1, $4 }'
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
        [[ ${2:0:1} == [-] || -z $2 ]] && break
        PSEL_LIST+=("${2}")
        shift
      done
    fi
    #
    # echo "Profile list is: ${PSEL_LIST[@]}"
    # echo ${PSEL_LIST[0]}
    ;;

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

  -pss) # args: string
    # Set size of the postscript page
    PSSIZE="${2}"
    shift
    ;;

  -pt|--point)
    # COUNTER plotpointnumber
    # Required arguments
    POINTDATAFILE[$plotpointnumber]=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    if [[ ! -e ${POINTDATAFILE[$plotpointnumber]} ]]; then
      info_msg "[-pt]: Point data file ${POINTDATAFILE[$plotpointnumber]} does not exist."
      exit 1
    fi
    # Optional arguments
    # Look for symbol code
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pt]: No symbol specified. Using $POINTSYMBOL."
      POINTSYMBOL_arr[$plotpointnumber]=$POINTSYMBOL
    else
      POINTSYMBOL_arr[$plotpointnumber]="${2:0:1}"
      shift
      info_msg "[-pt]: Point symbol specified. Using ${POINTSYMBOL_arr[$plotpointnumber]}."
    fi

    # Then look for size
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pt]: No size specified. Using $POINTSIZE."
      POINTSIZE_arr[$plotpointnumber]=$POINTSIZE
    else
      POINTSIZE_arr[$plotpointnumber]="${2}"
      shift
      info_msg "[-pt]: Point size specified. Using ${POINTSIZE_arr[$plotpointnumber]}."
    fi

    # Finally, look for CPT file
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pt]: No cpt specified. Using POINTCOLOR for -G"
      pointdatafillflag[$plotpointnumber]=1
      pointdatacptflag[$plotpointnumber]=0
    elif [[ ${2:0:1} == "@" ]]; then
      info_msg "[-pt]: No cpt specified using @. Using POINTCOLOR for -G"
      shift
      pointdatafillflag[$plotpointnumber]=1
      pointdatacptflag[$plotpointnumber]=0
    else
      POINTDATACPT[$plotpointnumber]=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      shift
      if [[ ! -e ${POINTDATACPT[$plotpointnumber]} ]]; then
        info_msg "[-pt]: CPT file $POINTDATACPT does not exist. Using default $POINTCPT"
        POINTDATACPT[$plotpointnumber]=$(echo "$(cd "$(dirname "$POINTCPT")"; pwd)/$(basename "$POINTCPT")")
      else
        info_msg "[-pt]: Using CPT file $POINTDATACPT"
      fi
      pointdatacptflag[$plotpointnumber]=1
      pointdatafillflag[$plotpointnumber]=0
    fi

    info_msg "[-pt]: PT${plotpointnumber}: ${POINTDATAFILE[$plotpointnumber]}"
    plots+=("points")
    plotpointnumber=$(echo "plotpointnumber + 1" | bc -l)
    ;;

  -pv) # args: none
    doplateedgesflag=1
    plots+=("platediffv")
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-pz]: No azimuth difference scale indicated. Using default: ${AZDIFFSCALE}"
    else
      AZDIFFSCALE="${2}"
      shift
    fi
    doplateedgesflag=1
    plots+=("plateazdiff")
    ;;

	-r|--range) # args: number number number number
	  if ! [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]]; then
      # If first argument isn't a number, it is interpreted as a global extent (g), an earthquake event, a raster file, or finally as a country code.

      # Option 1: Global extent from -180:180 longitude
      if [[ ${2} == "g" ]]; then
        MINLON=-180
        MAXLON=180
        MINLAT=-90
        MAXLAT=90
        shift

      # Option 2: Centered on an earthquake event from CMT(preferred) or seismicity(second choice) catalogs.
      # Arguments are eq Event_ID [[degwidth]]
      elif [[ "${2}" == "eq" ]]; then
        setregionbyearthquakeflag=1
        REGION_EQ=${3}
        shift
        shift
        if [[ ${2:0:1} == [-] || -z $2 ]]; then
          info_msg "[-r]: EQ region width is default"
        else
          EQ_REGION_WIDTH="${2}"
          shift
        fi
        info_msg "[-r]: Region will be centered on EQ $REGION_EQ with width $EQ_REGION_WIDTH degrees"
      # Option 3: Set region to be the same as an input raster
      elif [[ -e $(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")") ]]; then
        info_msg "[-r]: Raster file given to -r command in the form of a filename argument"

        # gmt grdinfo $(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")") > tmp.ras.data 2>/dev/null
        # MINLON=$(grep "x_min" tmp.ras.data | cut -d ":" -f 3 | awk '{print $1}')
        # MAXLON=$(grep "x_min" tmp.ras.data | cut -d ":" -f 4 | awk '{print $1}')
        # MINLAT=$(grep "y_min" tmp.ras.data | cut -d ":" -f 3 | awk '{print $1}')
        # MAXLAT=$(grep "y_min" tmp.ras.data | cut -d ":" -f 4 | awk '{print $1}')

        rasrange=$(gmt grdinfo $(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")") -C -Vn)
        MINLON=$(echo $rasrange | awk '{print $2}')
        MAXLON=$(echo $rasrange | awk '{print $3}')
        MINLAT=$(echo $rasrange | awk '{print $4}')
        MAXLAT=$(echo $rasrange | awk '{print $5}')

        if [[ $(echo "$MAXLON > $MINLON" | bc) -eq 1 ]]; then
          if [[ $(echo "$MAXLAT > $MINLAT" | bc) -eq 1 ]]; then
            info_msg "Set region to $MINLON/$MAXLON/$MINLAT/$MAXLAT to match $2"
          fi
        fi
        shift

      # Option 4: A single argument which doesn't match any of the above is a country ID
      else
        # Option 5: No arguments means no region
        if [[ ${2:0:1} == [-] || -z $2 ]]; then
          info_msg "[-r]: No country code specified."
          exit 1
        fi
        COUNTRYID=${2}
        shift
        COUNTRYNAME=$(awk -v cid="${COUNTRYID}" -F, '(index($0,cid)==1) { print $4 }' $COUNTRY_CODES)
        if [[ $COUNTRYNAME == "" ]]; then
          info_msg "Country code ${COUNTRYID} is not a valid code. Use tectoplot -printcountries"
          exit 1
        fi
        RCOUNTRY=($(gmt pscoast -E${COUNTRYID}+r1 ${VERBOSE} | awk '{v=substr($0,3,length($0)); split(v,w,"/"); print w[1], w[2], w[3], w[4]}'))

        # info_msg "RCOUNTRY=${RCOUNTRY[@]}"
        if [[ $(echo "${RCOUNTRY[0]} >= -180 && ${RCOUNTRY[1]} <= 360 && ${RCOUNTRY[2]} >= -90 && ${RCOUNTRY[3]} <= 90" | bc) -eq 1 ]]; then
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
      [[ $(echo "$MAXLON > 180 && $MAXLON <= 360" | bc -l) -eq 1 ]] && MAXLON=$(echo "$MAXLON - 360" | bc -l)
      [[ $(echo "$MINLON > 180 && $MINLON <= 360" | bc -l) -eq 1 ]] && MINLON=$(echo "$MINLON - 360" | bc -l)
      if [[ $(echo "$MAXLAT > 90 || $MAXLAT < -90 || $MINLAT > 90 || $MINLAT < -90"| bc -l) -eq 1 ]]; then
      	echo "Latitude out of range"
      	exit
      fi
      info_msg "[-r]: Range after possible rescale is $MINLON $MAXLON $MINLAT $MAXLAT"

    	if [[ $(echo "$MAXLON > 180 || $MAXLON< -180 || $MINLON > 180 || $MINLON < -180"| bc -l) -eq 1 ]]; then
      	echo "Longitude out of range"
      	exit
    	fi
    	if [[ $(echo "$MAXLON <= $MINLON"| bc -l) -eq 1 ]]; then
      	echo "Longitudes out of order"
      	exit
    	fi
    	if [[ $(echo "$MAXLAT <= $MINLAT"| bc -l) -eq 1 ]]; then
      	echo "Latitudes out of order"
      	exit
    	fi
  		info_msg "[-r]: Map region is -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT}"
      isdefaultregionflag=0

      # We apparently need to deal with maps that wrap across the antimeridian? Ugh.
      regionsetflag=1
    fi # If the region is not centered on an earthquake and still needs to be determined

    ;;

  -recenteq) # args: none | days
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-recentglobaleq]: No day number specified, using start of yesterday to end of today"
      LASTDAYNUM=1
    else
      info_msg "[-recentglobaleq]: Using start of day ${2} days ago to end of today"
      LASTDAYNUM="${2}"
      shift
    fi
    info_msg "Updating databases"
    . $SCRAPE_GCMT
    . $SCRAPE_ISCFOC
    . $SCRAPE_ANSS
    . $MERGECATS
    # Turn on time select
    timeselectflag=1
    LASTDAY=$(date +%F)
    FIRSDAY=$(date -j -v -${LASTDAYNUM}d +%F)
    STARTTIME=$(echo "${FIRSTDAY}T:00:00:00")
    ENDTIME=$(echo "${FIRSTDAY}T:00:00:00")
    # Set to global extent
    ;;

  -rect)
    MAKERECTMAP=1
    ;;

  -reportdates)
    echo -n "Focal mechanisms: "
    echo "$(head -n 1 $FOCALCATALOG | cut -d ' ' -f 3) to $(tail -n 1 $FOCALCATALOG | cut -d ' ' -f 3)"
    echo -n "Earthquake hypocenters: "
    echo "$(head -n 1 $EQCATALOG | cut -d ' ' -f 5) to $(tail -n 1 $EQCATALOG | cut -d ' ' -f 5)"
    exit
    ;;

  -RJ) # args: { ... }
    # We need to shift the automatic UTM zone section to AFTER other arguments are processed
    if [[ $2 =~ "UTM" ]]; then
      shift
      if [[ $2 =~ ^[0-9]+$ ]]; then   # Specified a UTM Zone
        UTMZONE=$2
        shift
      else
        calcutmzonelaterflag=1
      fi
      setutmrjstringfromarrayflag=1
      # RJSTRING="${rj[@]}"
    elif [[ ${2:0:1} == [{] ]]; then
      info_msg "[-RJ]: RJ argument string detected"
      shift
      while : ; do
          [[ ${2:0:1} != [}] ]] || break
          rj+=("${2}")
          shift
      done
      shift
      RJSTRING="${rj[@]}"
    fi
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      echo "[-setdatadir]: No data directory specified. Current dir is:"
      cat $DEFDIR"tectoplot.dataroot"
      exit 1
    else
      datadirpath=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
      shift
      if [[ -d ${datadirpath} ]]; then
        echo "[-setdatadir]: Data directory ${datadirpath} exists."
        echo "${datadirpath}/" > $DEFDIR"tectoplot.dataroot"
      else
        echo "[-setdatadir]: Data directory ${datadirpath} does not exist. Creating."
        mkdir -p "${datadirpath}/"
        echo "${datadirpath}/" > $DEFDIR"tectoplot.dataroot"
      fi
    fi
    ;;

  -setopenprogram)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      echo "[-setopenprogram]: PDFs are opened using: ${OPENPROGRAM}"
    else
      openapp="${2}"
      shift
      echo "${openapp}" > $DEFDIR"tectoplot.pdfviewer"
    fi
    ;;

  -scale)
    # We just use this section to create the SCALECMD values
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-scale]: No scale length specified. Using 100km"
      SCALELEN="100k"
    else
      SCALELEN="${2}"
      shift
    fi
    # Adjust position and buffering of scale bar using either letter combinations OR Lat/Lon location
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-scale]: No reference point given. Using upper left corner."
      SCALEREFLAT=$MAXLAT
      SCALEREFLON=$MINLON
      SCALELENLAT=$MAXLAT
    else
      SCALEREFLON="${2}"
      shift
      SCALEREFLAT="${2}"
      shift
      SCALELENLAT=$SCALEREFLAT
    fi
    plots+=("mapscale")
    ;;

  -scrapedata) # args: none | gia
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-scrapedata]: No datasets specified. Scraping GCMT/ISC/ANSS"
      SCRAPESTRING="giazm"
    else
      SCRAPESTRING="${2}"
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
      . $SCRAPE_ANSS
    fi
    if [[ ${SCRAPESTRING} =~ .*z.* ]]; then
      info_msg "Scraping GFZ focal mechanisms"
      . $SCRAPE_GFZ
    fi
    if [[ ${SCRAPESTRING} =~ .*m.* ]]; then
      info_msg "Merging focal catalogs"
      . $MERGECATS
    fi
    exit
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

  -sv|--slipvector) # args: filename
    plots+=("slipvecs")
    SVDATAFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    ;;

  -t|--topo) # args: ID | filename { args }
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
			info_msg "[-t]: No topo file specified: SRTM30 assumed"
			BATHYMETRY="SRTM30"
		else
			BATHYMETRY="${2}"
			shift
		fi
		case $BATHYMETRY in
      01d|30m|20m|15m|10m|06m|05m|04m|03m|02m|01m|15s|03s|01s)
        plottopo=1
        GRIDDIR=$EARTHRELIEFDIR
        GRIDFILE=${EARTHRELIEFPREFIX}${BATHYMETRY}
        plots+=("topo")
        remotetileget=1
        ;;
      BEST)
        BATHYMETRY="01s"
        plottopo=1
        GRIDDIR=$EARTHRELIEFDIR
        GRIDFILE=${EARTHRELIEFPREFIX}${BATHYMETRY}
        plots+=("topo")
        remotetileget=1
        besttopoflag=1
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
        ;;
      *)
        plottopo=1
        plotcustomtopo=1
        info_msg "Using custom grid"
        BATHYMETRY="custom"
        GRIDDIR=$(echo "$(cd "$(dirname "$1")"; pwd)/")
        GRIDFILE=$(echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")")  # We already shifted
        echo $GRIDDIR
        echo $GRIDFILE
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-t]: No topo CPT specified. Using default."
    else
      customgridcptflag=1
      CPTNAME="${2}"
      CUSTOMCPT=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
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
    ;;
  #
  # -tc|--cpt) # args: filename
  #   customgridcptflag=1
  #   CPTNAME="${2}"
  #   CUSTOMCPT=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
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
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
			cat "${BASENAME}.poles" | sed '1,/G# P# Name      Lon.      Lat.     Omega     SigOm    Emax    Emin      Az     VAR/d;/ Relative poles/,$d' | sed '$d' | awk '{print $3, $5, $4, $6}' | grep '\S' > ${TDPATH}/def2tecto_out/poles.dat
			cat "${BASENAME}_blk.gmt" | awk '{ if ($1 == ">") print $1, $6; else print $1, $2 }' > ${TDPATH}/def2tecto_out/blocks.dat
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

  -ti)
    if [[ $2 =~ ^[-+]?[0-9]*.*[0-9]+$ || $2 =~ ^[-+]?[0-9]+$ ]]; then   # first arg is a number
      ILLUM="-I+a${2}+nt1+m0"
      shift
    elif [[ ${2:0:1} == [-] || -z $2 ]]; then   # first arg doesn't exist or starts with - but isn't a number
      info_msg "[-ti]: No options specified. Ignoring."
    elif [[ ${2} =~ "off" ]]; then
      ILLUM=""
      shift
    else
      info_msg "[-ti]: option $2 not understood. Ignoring"
      shift
    fi
    ;;

  --time)
    timeselectflag=1
    STARTTIME="${2}"
    ENDTIME="${3}"
    shift
    shift
    ;;

  -title) # args: string
    PLOTTITLE="${2}"
    shift
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

	-v|--gravity) # args: string number
		plotgrav=1
		GRAVMODEL="${2}"
		GRAVTRANS="${3}"
		shift
		shift
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
				;;
			BG)
				GRAVDATA=$WGMBOUGUER
				GRAVCPT=$WGMBOUGUER_CPT
				;;
			IS)
				GRAVDATA=$WGMISOSTATIC
				GRAVCPT=$WGMISOSTATIC_CPT
				;;
			*)
				echo "Gravity model not recognized."
				exit 1
				;;
		esac

		info_msg "[-v]: Gravity data to plot is ${GRAVDATA}, transparency is ${GRAVTRANS}"
		plots+=("grav")
    cpts+=("grav")
    echo $GRAV_SHORT_SOURCESTRING >> tectoplot.shortsources
    echo $GRAV_SOURCESTRING >> tectoplot.sources
	  ;;

  -variables)
    print_help_header
    print_variables
    exit 1
    ;;

  -vars) # argument: filename
    VARFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
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

  --verbose) # args: none
    VERBOSE="-V"
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
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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
    if [[ $USEANSS_DATABASE -eq 1 ]]; then
      info_msg "[-z]: Using ANSS database $EQCATALOG"
    fi
		if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

  -zcat) #            [ANSS or ISC]
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-zcat]: No catalog specified. Using default $EQCATALOG"
    else
      EQCATNAME="${2}"
      shift
      info_msg "[-z]: Seismicity scale updated to $SEIZSIZE * $SEISSCALE"
      case $EQCATNAME in
        ISC)
          EQCATALOG=$ISC_EQ_CATALOG
          EQ_SOURCESTRING=$ISC_EQ_SOURCESTRING
          EQ_SHORT_SOURCESTRING=$ISC_EQ_SHORT_SOURCESTRING
        ;;
        ANSS0)
          EQCATALOG=$ANSS_EQ_CATALOG
          EQ_SOURCESTRING=$ANSS_EQ_SOURCESTRING
          EQ_SHORT_SOURCESTRING=$ANSS_EQ_SHORT_SOURCESTRING
        ;;
      esac
    fi

    ;;

  -zmag)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-zmax]: No limits specified [minmag] [maxmag]"
    else
      EQ_MINMAG="${2}"
      shift
      if [[ ${2:0:1} == [-] || -z $2 ]]; then
        info_msg "[-zmax]: No maximum magnitude specified. Using default."
      else
        EQ_MAXMAG="${2}"
        shift
      fi
    fi

    ;;

  -zr1|--eqrake1) # args: number
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-zr]:  No rake color scale indicated. Using default: ${RAKE1SCALE}"
    else
      RAKE1SCALE="${2}"
      shift
    fi
    plots+=("seisrake1")
    ;;

  -zr2|--eqrake2) # args: number
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-zr]:  No rake color scale indicated. Using default: ${RAKE2SCALE}"
    else
      RAKE2SCALE="${2}"
      shift
    fi
    plots+=("seisrake2")
    ;;

  -zs) # args: file   - supplemental seismicity catalog in lon lat depth mag [datestr] [id] format
    suppseisflag=1
    SUPSEISFILE=$(echo "$(cd "$(dirname "$2")"; pwd)/$(basename "$2")")
    shift
    ;;

  -zsort)
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
      info_msg "[-zsort]:  No sort dimension specified. Using depth."
      ZSORTTYPE="depth"
    else
      ZSORTTYPE="${2}"
      shift
    fi
    if [[ ${2:0:1} == [-] || -z $2 ]]; then
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

if [[ $setregionbyearthquakeflag -eq 1 ]]; then
  LOOK1=$(grep $REGION_EQ $FOCALCATALOG | head -n 1)
  if [[ $LOOK1 != "" ]]; then
    echo "Found EQ region focal mechanism $REGION_EQ"
    case $CMTTYPE in
      ORIGIN)
        REGION_EQ_LON=$(echo $LOOK1 | awk '{print $8}')
        REGION_EQ_LAT=$(echo $LOOK1 | awk '{print $9}')
        ;;
      CENTROID)
        REGION_EQ_LON=$(echo $LOOK1 | awk '{print $5}')
        REGION_EQ_LAT=$(echo $LOOK1 | awk '{print $6}')
        ;;
    esac
  else
    LOOK2=$(grep $REGION_EQ $EQCATALOG)
    if [[ $LOOK1 != "" ]]; then
      echo "Found EQ region hypocenter $REGION_EQ"
      REGION_EQ_LON=$(echo $LOOK2 | awk '{print $1}')
      REGION_EQ_LAT=$(echo $LOOK2 | awk '{print $2}')
    else
      echo "No event found"
      exit
    fi
  fi
  MINLON=$(echo "$REGION_EQ_LON - $EQ_REGION_WIDTH" | bc -l)
  MAXLON=$(echo "$REGION_EQ_LON + $EQ_REGION_WIDTH" | bc -l)
  MINLAT=$(echo "$REGION_EQ_LAT - $EQ_REGION_WIDTH" | bc -l)
  MAXLAT=$(echo "$REGION_EQ_LAT + $EQ_REGION_WIDTH" | bc -l)

  echo "Region $MINLON/$MAXLON/$MINLAT/$MAXLAT centered at $REGION_EQ_LON/$REGION_EQ_LAT"
fi


################################################################################
###### Calculate some sizes for the final map document based on AOI aspect ratio

LATSIZE=$(echo "$MAXLAT - $MINLAT" | bc -l)
LONSIZE=$(echo "$MAXLON - $MINLON" | bc -l)

# For a standard run, we want something like this. For other projections, unlikely to be sufficient
# We want a page that is PSSIZE wide with a MARGIN. It scales vertically based on the
# aspect ratio of the map region

PSSIZEH=$(echo "$PSSIZE * $PSSCALE" | bc -l)
PSSIZEV=$(echo "$LATSIZE / $LONSIZE * $PSSIZEH + 2" | bc -l)
INCH=$(echo "$PSSIZEH - $MARGIN * 2" | bc -l)

##### Define the output filename for the map, in PDF
if [[ $outflag == 0 ]]; then
	MAPOUT="tectomap_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON
  MAPOUTLEGEND="tectomap_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON"_legend.pdf"
  info_msg "Output file is $MAPOUT, legend is $MAPOUTLEGEND"
else
  info_msg "Output file is $MAPOUT, legend is legend.pdf"
  MAPOUTLEGEND="legend.pdf"
fi


# If MAKERECTMAP is set to 1, the RJSTRING will be changed to a different format
# to allow plotting of a rectangular map not bounded by parallels/meridians.
# However, data that does not fall within the AOI region given by MINLON/MAXLON/etc
# will not be processed or plotted. So we would need to recalculate these parameters
# based on the maximal range present in the final plot. I would usually do this by
# rendering the map frame as populated polylines and finding the maximal coordinates of the vertices.

# We have to set the RJ flag after setting the plot size (INCH)

if [[ $setutmrjstringfromarrayflag -eq 1 ]]; then

  if [[ $calcutmzonelaterflag -eq 1 ]]; then
    AVELONp180o6=$(echo "(($MAXLON + $MINLON) / 2 + 180)/6" | bc -l)
    # echo $AVELONp180o6
    UTMZONE=$(echo $AVELONp180o6 1 | awk '{print int($1)+($1>int($1))}')
  fi
  info_msg "Using UTM Zone $UTMZONE"

  if [[ $MAKERECTMAP -eq 1 ]]; then
    rj[1]="-R${MINLON}/${MINLAT}/${MAXLON}/${MAXLAT}r"
    rj[2]="-JU${UTMZONE}/${INCH}i"
    RJSTRING="${rj[@]}"

    gmt psbasemap -A $RJSTRING | grep -v "#" > mapoutline.txt
    MINLONNEW=$(awk < mapoutline.txt 'BEGIN {getline;min=$1} NF { min=(min>$1)?$1:min } END{print min}')
    MAXLONNEW=$(awk < mapoutline.txt 'BEGIN {getline;max=$1} NF { max=(max>$1)?max:$1 } END{print max}')
    MINLATNEW=$(awk < mapoutline.txt 'BEGIN {getline;min=$2} NF { min=(min>$2)?$2:min } END{print min}')
    MAXLATNEW=$(awk < mapoutline.txt 'BEGIN {getline;max=$2} NF { max=(max>$2)?max:$2} END{print max}')
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


CENTERLON=$(echo "($MINLON + $MAXLON) / 2" | bc -l)
CENTERLAT=$(echo "($MINLAT + $MAXLAT) / 2" | bc -l)

MSG=$(echo ">>>>>>>>> Plotting order is ${plots[@]} <<<<<<<<<<<<<")
# echo $MSG
[[ $narrateflag -eq 1 ]] && echo $MSG

legendwords=${plots[@]}
MSG=$(echo ">>>>>>>>> Legend order is ${legendwords[@]} <<<<<<<<<<<<<")
[[ $narrateflag -eq 1 ]] && echo $MSG

# Just make a giant page and trim it later using gmt psconvert -A+m

gmt gmtset PS_MEDIA 100ix100i

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
   cp "${PLOTFILE}" "${THISDIR}"tmpmap.ps
   OVERLAY="-O"
fi


if [[ ${TMP::1} == "/" ]]; then
  info_msg "Temporary directory path ${TMP} is an absolute path from root."
  if [[ -d $TMP ]]; then
    info_msg "Not deleting absolute path ${TMP}. Using ./tempfiles_to_delete/"
    TMP="tempfiles_to_delete/"
  fi
else
  if [[ -d $TMP ]]; then
    info_msg "Temp dir $TMP exists. Deleting."
    rm -rf "${TMP}"
  fi
  info_msg "Creating temporary directory $TMP."
fi
mkdir "${TMP}"

mv tectoplot.sources ${TMP}
mv tectoplot.shortsources ${TMP}

cd "${TMP}"

if [[ $overplotflag -eq 1 ]]; then
   info_msg "Copying basemap ps into temporary directory"
   mv "${THISDIR}"tmpmap.ps "${TMP}map.ps"
fi

################################################################################
#####          Manage grid spacing and style                               #####
################################################################################

# PSSIZEH=$PSSIZE
# PSSIZEV=$(echo "$LATSIZE / $LONSIZE * $PSSIZE + 2" | bc -l)
# INCH=$(echo "$PSSIZE - $MARGIN * 2" | bc -l)

##### Create the grid of lat/lon points to resolve as plate motion vectors
# Default is a lat/lon spaced grid

##### MAKE FIBONACCI GRID POINTS
if [[ $gridfibonacciflag -eq 1 ]]; then
  FIB_PHI=1.618033988749895
  echo "" | awk -v n=$FIB_N  -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" 'function asin(x) { return atan2(x, sqrt(1-x*x)) } BEGIN {
    phi=1.618033988749895;
    pi=3.14159265358979;
    phi_inv=1/phi;
    ga = 2 * phi_inv * pi;
  } END {
    for (i=-n; i<=n; i++) {
      longitude = ((ga * i)*180/pi)%360;
      if (longitude < -180) {
        longitude=longitude+360;
      }
      if (longitude > 180) {
        longitude=longitude-360
      }
      latitude = asin((2 * i)/(2*n+1))*180/pi;
      if ((longitude <= maxlon) && (longitude >= minlon) && (latitude <= maxlat) && (latitude >= minlat)) {
        print longitude, latitude
      }
    }
  }' > gridfile.txt
  awk < gridfile.txt '{print $2 $1}' > gridswap.txt
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

################################################################################
#####          GMT media and map style management                          #####
################################################################################

gmt gmtset MAP_FRAME_TYPE fancy

if [[ $tifflag -eq 1 ]]; then
  gmt gmtset MAP_FRAME_TYPE inside
fi

if [[ $kmlflag -eq 1 ]]; then
  gmt gmtset MAP_FRAME_TYPE inside
fi

gmt gmtset PS_PAGE_ORIENTATION portrait
gmt gmtset FONT_ANNOT_PRIMARY 10 FONT_LABEL 10 MAP_FRAME_WIDTH 0.12c FONT_TITLE 18p,Palatino-BoldItalic
gmt gmtset FORMAT_GEO_MAP=D

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
else
	GRIDSP=0.01
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

################################################################################
#####          Manage SLAB2 data                                           #####
################################################################################

if [[ $plotslab2 -eq 1 ]]; then
  numslab2inregion=0
  for slabcfile in $(ls -1a ${SLAB2_CLIPDIR}*.csv); do
    awk < $slabcfile '{
      if ($1 > 180) {
        print $1-360, $2
      } else {
        print $1, $2
      }
    }' > tmpslabfile.dat
    numinregion=$(gmt select tmpslabfile.dat -R$MINLON/$MAXLON/$MINLAT/$MAXLAT ${VERBOSE} | wc -l)
    if [[ $numinregion -ge 1 ]]; then
      numslab2inregion=$(echo "$numslab2inregion+1" | bc)
      slab2inregion[$numslab2inregion]=$(basename -s .csv $slabcfile)
    fi
  done
  if [[ $numslab2inregion -eq 0 ]]; then
    info_msg "[-b]: No slabs within AOI"
  else
    for i in $(seq 1 $numslab2inregion); do
      info_msg "[-b]: Found slab2 slab ${slab2inregion[$i]}"
    done
  fi
fi

################################################################################
#####          Manage topography/bathymetry data                           #####
################################################################################

if [[ $plottopo -eq 1 ]]; then
  info_msg "Making basemap $BATHYMETRY"

  if [[ $besttopoflag -eq 1 ]]; then
    bestname=$BESTDIR"best_${MINLON}_${MAXLON}_${MINLAT}_${MAXLAT}.nc"
    if [[ -e $bestname ]]; then
      info_msg "Best topography already exists."
      BATHY=$bestname
      bestexistsflag=1
    fi
  fi

  if [[ $BATHYMETRY =~ "GMRT" || $besttopoflag -eq 1 && $bestexistsflag -eq 0 ]]; then   # We manage GMRT tiling ourselves

    minlon360=$(echo $MINLON | awk '{ if ($1<0) {print $1+360} else {print $1} }')
    maxlon360=$(echo $MAXLON | awk '{ if ($1<0) {print $1+360} else {print $1} }')

    minlonfloor=$(echo $minlon360 | cut -f1 -d".")
    maxlonfloor=$(echo $maxlon360 | cut -f1 -d".")

    if [[ $(echo "$MINLAT < 0" | bc -l) -eq 1 ]]; then
      minlatfloor1=$(echo $MINLAT | cut -f1 -d".")
      minlatfloor=$(echo "$minlatfloor1 - 1" | bc)
    else
      minlatfloor=$(echo $MINLAT | cut -f1 -d".")
    fi

    maxlatfloor=$(echo $MAXLAT | cut -f1 -d".")
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

    if [[ ! -e $GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc" ]]; then
      info_msg "Merging tiles to form GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc: " ${filelist[@]}
      echo gdal_merge.py -o $GMRTDIR"GMRT_${minlonfloor}_${maxlonceil}_${minlatfloor}_${maxlatceil}.nc" -of "NetCDF" ${filelist[@]} -q > ./merge.sh
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
      name="dem.nc"
      gmt grdcut ${GRIDFILE} -G${name} -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} $VERBOSE
      BATHY=$name
    else
      info_msg "Using grid $GRIDFILE"

      # Output is a NetCDF format grid
    	name=$GRIDDIR"${BATHYMETRY}_${MINLON}_${MAXLON}_${MINLAT}_${MAXLAT}.nc"

    	if [[ -e $name ]]; then
    		info_msg "DEM file $name already exists"
    	else
        case $BATHYMETRY in
          SRTM30|GEBCO20|GEBCO1|01d|30m|20m|15m|10m|06m|05m|04m|03m|02m|01m|15s|03s|01s)
            gmt grdcut $GRIDFILE -G${name} -R${MINLON}/${MAXLON}/${MINLAT}/${MAXLAT} $VERBOSE
            demiscutflag=1
          ;;
        esac
    	fi
    	BATHY=$name
    fi
  fi
fi

##### CUSTOM TOPOGRAPHY FILE
# 	info_msg "Making custom basemap $BATHYMETRY"
#
# 	name="custom_dem.nc"
# 	hs="custom_hs.nc"
# 	hist="custom_hist.nc"
# 	int="custom_int.nc"
#
#   info_msg "Cutting ${CUSTOMGRIDFILE}"
#
#
#
# 	CUSTOMBATHY=$name
# 	CUSTOMINTN=$int
# fi

# At this point, if best topo flag is set, combine POSBATHYGRID and BATHY into one grid and make it the new BATHY grid

if [[ $besttopoflag -eq 1 && $bestexistsflag -eq 0 ]]; then
  info_msg "Combining GMRT ($NEGBATHYGRID) and 01s ($BATHY) grids to form best topo grid"
  gmt grdsample -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -I2s $NEGBATHYGRID -Gneg.nc -fg ${VERBOSE}
  gmt grdsample -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -I2s $BATHY -Gpos.nc -fg ${VERBOSE}
  gmt grdclip -Sb0/0 pos.nc -Gposclip.nc ${VERBOSE}
  gmt grdclip -Si0/10000000/0 neg.nc -Gnegclip.nc ${VERBOSE}
  gmt grdmath posclip.nc negclip.nc ADD = merged.nc ${VERBOSE}
  mv merged.nc $bestname
  BATHY=$bestname
fi

if [[ $clipdemflag -eq 1 ]]; then
  if [[ -e $BATHY ]]; then
    info_msg "[-clipdem]: saving DEM as dem.nc"
    if [[ $demiscutflag -eq 1 ]]; then
      cp $BATHY dem.nc
    else
      gmt grdcut $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -Gdem.nc ${VERBOSE}
    fi
  fi
fi

################################################################################
#####          Grid contours                                               #####
################################################################################

# Contour interval for grid if not specified using -cn
if [[ $gridcontourcalcflag -eq 1 ]]; then
  zrange=$(grid_zrange $CONTOURGRID -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
  MINCONTOUR=$(echo $zrange | awk '{print $1}')
  MAXCONTOUR=$(echo $zrange | awk '{print $2}')
  # MINCONTOUR=$(gmt grdinfo $CONTOURGRID -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep "z_min" | cut -d ":" -f 3 | awk '{print $1}')
  # MAXCONTOUR=$(gmt grdinfo $CONTOURGRID -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep "z_max" | cut -d ":" -f 4 | awk '{print $1}')
  CONTOURINTGRID=$(echo "($MAXCONTOUR - $MINCONTOUR) / $CONTOURNUMDEF" | bc -l)
  if [[ $(echo "$CONTOURINTGRID > 1" | bc -l) -eq 1 ]]; then
    CONTOURINTGRID=$(echo "$CONTOURINTGRID / 1" | bc)
  fi
fi

# Contour interval for grid if not specified using -cn
if [[ $topocontourcalcflag -eq 1 ]]; then
  zrange=$(grid_zrange $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
  MINCONTOUR=$(echo $zrange | awk '{print $1}')
  MAXCONTOUR=$(echo $zrange | awk '{print $2}')
  # MINCONTOUR=$(gmt grdinfo $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep "z_min" | cut -d ":" -f 3 | awk '{print $1}')
  # MAXCONTOUR=$(gmt grdinfo $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep "z_max" | cut -d ":" -f 4 | awk '{print $1}')
  TOPOCONTOURINT=$(echo "($MAXCONTOUR - $MINCONTOUR) / $TOPOCONTOURNUMDEF" | bc -l)
  if [[ $(echo "$TOPOCONTOURINT > 1" | bc -l) -eq 1 ]]; then
    TOPOCONTOURINT=$(echo "$TOPOCONTOURINT / 1" | bc)
  fi
fi

################################################################################
#####         Map AOI management                                           #####
################################################################################

# Set up the clipping polygon defining our AOI. Used by gmt spatial

echo $MINLON $MINLAT > clippoly.txt
echo $MINLON $MAXLAT >> clippoly.txt
echo $MAXLON $MAXLAT >> clippoly.txt
echo $MAXLON $MINLAT >> clippoly.txt
echo $MINLON $MINLAT >> clippoly.txt

echo $MINLON $MINLAT 0 > gridcorners.txt
echo $MINLON $MAXLAT 0 >> gridcorners.txt
echo $MAXLON $MAXLAT 0 >> gridcorners.txt
echo $MAXLON $MINLAT 0 >> gridcorners.txt

################################################################################
#####           Manage volcanoes                                           #####
################################################################################

if [[ $volcanoesflag -eq 1 ]]; then
  gmt select $SMITHVOLC -: -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE >> volctmp.dat
  gmt select $WHELLEYVOLC  -: -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE  >> volctmp.dat
  gmt select $JAPANVOLC -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE  >> volctmp.dat
  awk < volctmp.dat '{
    printf "%s %s ", $2, $1
    for (i=3; i<=NF; i++) {
      printf "%s ", $(i)
    }
    printf("\n")
  }' > volcanoes.dat
fi

################################################################################
#####           Manage earthquake hypocenters                              #####
################################################################################


if [[ $plotseis -eq 1 ]]; then

  # WE SHOULD REMOVE THIS CODE AS NEW EQs WONT BE ADDED TO SAVED EQS AND THE
  # TIME TO SELECT DATA FROM THE CATALOG IS ~5 seconds currently

	# # #This code downloads EQ data from ANSS catalog in the study area saves them in a file to avoid reloading
	# EQANSSFILE=$ANSSDIR"ANSS_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON".csv"
	# EQSAVED=$ANSSDIR"ANSS_"$MINLAT"_"$MAXLAT"_"$MINLON"_"$MAXLON".txt"
  #
	# QMARK="https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=1900-01-01&endtime=2020-09-14&minlatitude="$MINLAT"&maxlatitude="$MAXLAT"&minlongitude="$MINLON"&maxlongitude="$MAXLON
  #
  # if [[ $recalcdataflag -eq 1 ]]; then
  #   rm -f $EQCATALOG
  #   rm -f $EQANSSFILE
  # fi

	# if [[ -e $EQSAVED ]]; then
	# 	info_msg "Processed earthquake data already exists and recalc flag is not set, not retrieving new data"
  #   EQCATALOG=$EQSAVED
	# else
  #   if [[ $USEANSS_DATABASE -eq 1 ]]; then
  #     info_msg "Using scraped ANSS database as source of earthquake data, may not be up to date!"
  #     awk < $EQCATALOG -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON"  -v minmag=${EQ_MINMAG} -v maxmag=${EQ_MAXMAG}  '{
  #         if ($1 < maxlon && $1 > minlon && $2 < maxlat && $2 > minlat && $4 <= maxmag && $4 >= minmag ) {
  #          print
  #         }
  #       }' > $EQSAVED
  #       EQCATALOG=$EQSAVED
  #   else
  #     info_msg "Should download EQ data but currently not enabled"
  # 		# info_msg "Downloading ANSS data if possible"
  # 		# curl $QMARK > $EQANSSFILE
  #   fi
	# fi

  ##############################################################################
  # Initial select of seismicity from the catalog based on AOI and min/max depth

  awk < $EQCATALOG -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" -v mindepth=${EQCUTMINDEPTH} -v maxdepth=${EQCUTMAXDEPTH} -v minmag=${EQ_MINMAG} -v maxmag=${EQ_MAXMAG}   '{
    if ($1 < maxlon && $1 > minlon && $2 < maxlat && $2 > minlat && $3 > mindepth && $3 < maxdepth && $4 < maxmag && $4 > minmag )
    {
      print
    }
  }' > eqs.txt

  ##############################################################################
  # Add additional user-specified seismicity files. This needs to be expanded
  # to import from various common formats. Currently needs tectoplot format data
  # and only prints lines with 7 fields.

  if [[ $suppseisflag -eq 1 ]]; then
    info_msg "Concatenating supplementary earthquake file $SUPSEISFILE"
    awk < $SUPSEISFILE '(NF==7) { print } ' >> eqs.txt
  fi

  ##############################################################################
  # Select seismicity that falls within a specified polygon

  if [[ $polygonselectflag -eq 1 ]]; then
    info_msg "Selecting seismicity within AOI polygon ${POLYGONAOI}"
    mv eqs.txt eqs_preselect.txt
    gmt select eqs_preselect.txt -F${POLYGONAOI} -Vn | tr '\t' ' ' > eqs.txt
  fi

  ##############################################################################
  # Select seismicity based on time code, precision up to one second

  if [[ $timeselectflag -eq 1 ]]; then
    info_msg "Selecting seismicity between ${STARTTIME} and ${ENDTIME}"

    STARTSECS=$(echo "${STARTTIME}" | awk '{
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

    ENDSECS=$(echo "${ENDTIME}" | awk '{
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

    #LON LAT DEPTH MAG TIMECODE ID EPOCH MAGTYPE
    awk < eqs.txt -v ss=$STARTSECS -v es=$ENDSECS '{
      if (($7 >= ss) && ($7 <= es)) {
        print
      }
    }' > eq_timesel.dat
    mv eq_timesel.dat eqs.txt
  fi

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
    [[ $ZSORTDIR =~ "down" ]] && sort -n -k $SORTFIELD,$SORTFIELD eqs.txt > eqsort.txt
    [[ $ZSORTDIR =~ "up" ]] && sort -n -r -k $SORTFIELD,$SORTFIELD eqs.txt > eqsort.txt
    [[ -e eqsort.txt ]] && cp eqsort.txt eqs.txt
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

# I need an awk script that does a lot of these steps in one go (after CMT combined database generation)

  # If we are plotting from a global database
  if [[ $plotcmtfromglobal -eq 1 ]]; then

    # Use an existing database file in tectoplot format
    [[ $CMTFILE == "DefaultNOCMT" ]]    && CMTFILE=$FOCALCATALOG
    [[ $CMTFORMAT =~ "GlobalCMT" ]]     && CMTLETTER="c"
    [[ $CMTFORMAT =~ "MomentTensor" ]]  && CMTLETTER="m"
    [[ $CMTFORMAT =~ "TNP" ]] && CMTLETTER="y"

    # Do the initial AOI scrape

    awk < $CMTFILE -v orig=$ORIGINFLAG -v cent=$CENTROIDFLAG -v mindepth="${EQCUTMINDEPTH}" -v maxdepth="${EQCUTMAXDEPTH}" -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
      doprint=0
      if (cent==1) {
        if (($7 >= mindepth && $7 <= maxdepth) && ($5 >= minlon && $5 <= maxlon) && ($6 >= minlat   && $6 <= maxlat))
        {
          doprint=1
        }
      }
      if (orig==1) {
        if (($10 >= mindepth && $10 <= maxdepth) && ($8 >= minlon && $8 <= maxlon) && ($9 >= minlat && $9 <= maxlat))
        {
          doprint=1
        }
      }
      if (doprint==1) {
        print
      }
    }' > cmt_global_aoi.dat
  fi

  # Perform an AOI scrape of any custom CMT databases
  touch cmt_local_aoi.dat
  if [[ $addcustomcmtsflag -eq 1 ]]; then

    for i in $(seq 1 $cmtfilenumber); do
      info_msg "Slurping custom CMTs from $CMTADDFILE[$i] and appending to CMT file"
      ${CMTSLURP} ${CMTADDFILE[$i]} ${CMTFORMATCODE[$i]} ${CMTIDCODE[$i]} | awk < $CMTFILE -v orig=$ORIGINFLAG -v cent=$CENTROIDFLAG -v mindepth="${EQCUTMINDEPTH}" -v maxdepth="${EQCUTMAXDEPTH}" -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
          doprint=0
          if (cent==1) {
            if (($7 >= mindepth && $7 <= maxdepth) && ($5 >= minlon && $5 <= maxlon) && ($6 >= minlat   && $6 <= maxlat))
            {
              doprint=1
            }
          }
          if (orig==1) {
            if (($10 >= mindepth && $10 <= maxdepth) && ($8 >= minlon && $8 <= maxlon) && ($9 >= minlat && $9 <= maxlat))
            {
              doprint=1
            }
          }
          if (doprint==1) {
            print
          }
        }' >> cmt_local_aoi.dat
    done
  fi

  # Concatenate the data
  cat cmt_global_aoi.dat cmt_local_aoi.dat > cmt_combined_aoi.dat

  CMTFILE=$(echo "$(cd "$(dirname "cmt_combined_aoi.dat")"; pwd)/$(basename "cmt_combined_aoi.dat")")

  # We should now have a good combined CMT dataset in cmt_combined_aoi.dat
  # Everything beyond here is certainly broken as we can't generate good GMT format files right now...

  # This abomination of a command is because the CMT file's first field is an origin/type code and
  # I don't know how to use gmt select to print the full record based only on the second and third columns.

  if [[ $polygonselectflag -eq 1 ]]; then
    info_msg "Selecting focal mechanisms within AOI polygon ${POLYGONAOI} using ${CMTTYPE} location"

    case $CMTTYPE in
      CENTROID)
        awk < $CMTFILE '{
          for (i=5; i<=NF; i++) {
            printf "%s ", $(i) }
            print $1, $2, $3, $4;
          }' | gmt select -F${POLYGONAOI} ${VERBOSE} | tr '\t' ' ' | awk '{
          printf "%s %s %s %s", $(NF-3), $(NF-2), $(NF-1), $(NF);
          for (i=1; i<=NF-4; i++) {
            printf " %s", $(i)
          }
          printf "\n";
        }' > cmt_aoiselect.dat
        ;;
      ORIGIN)
        awk < $CMTFILE '{
          for (i=8; i<=NF; i++) {
            printf "%s ", $(i) }
            print $1, $2, $3, $4, $5, $6, $7;
          }' > tmp.dat
          gmt select tmp.dat -F${POLYGONAOI} ${VERBOSE} | tr '\t' ' ' | awk '{
          printf "%s %s %s %s %s %s %s", $(NF-6), $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $(NF);
          for (i=1; i<=NF-6; i++) {
            printf " %s", $(i)
          } printf "\n";
        }' > cmt_aoiselect.dat
        ;;
    esac
    CMTFILE=$(echo "$(cd "$(dirname "cmt_aoiselect.dat")"; pwd)/$(basename "cmt_aoiselect.dat")")
  fi

  info_msg "Selecting focal mechanisms and kinematic mechanisms based on magnitude constraints"

  awk < $CMTFILE -v kminmag="${KIN_MINMAG}" -v kmaxmag="${KIN_MAXMAG}" -v minmag="${EQ_MINMAG}" -v maxmag="${EQ_MAXMAG}" '{
    mw=$13
    if (mw < maxmag && mw > minmag) {
      print > "cmt_orig.dat"
    }
    if (mw < kmaxmag && mw > kminmag) {
      print > "kin_orig.dat"
    }
  }'
  CMTFILE="cmt_orig.dat"

  # Select CMT data between start and end times
  if [[ $timeselectflag -eq 1 ]]; then
    STARTSECS=$(echo "${STARTTIME}" | awk '{
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

    ENDSECS=$(echo "${ENDTIME}" | awk '{
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

    awk < $CMTFILE -v ss=$STARTSECS -v es=$ENDSECS '{
      if (($4 >= ss) && ($4 <= es)) {
        print
      }
    }' > cmt_timesel.dat
    CMTFILE="cmt_timesel.dat"
    echo "Seismic/CMT [${STARTTIME} to ${ENDTIME}]" >> tectoplot.shortsources
  fi


  #      1          	2	 3      4 	         5	            6             	7	         8	         9	           10	              11	         12 13	      mantissa	     exponent	     16	  17	   18	      19	20	   21	      22	  23	 24 	25	  26 	 27	  28	  29	  30	31	      32	 33 	34	35 36	 37	 38	         39
  # idcode	event_code	id	epoch	lon_centroid	lat_centroid	depth_centroid	lon_origin	lat_origin	depth_origin	author_centroid	author_origin	MW	mantissa	exponent	strike1	dip1	rake1	strike2	dip2	rake2	exponent	Tval	Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc	exponent	Mrr	Mtt	Mpp	Mrt	Mrp	Mtp	centroid_dt


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
    [[ $ZSORTDIR =~ "down" ]] && sort -n -k $SORTFIELD,$SORTFIELD $CMTFILE > cmt_sort.txt
    [[ $ZSORTDIR =~ "up" ]] && sort -n -r -k $SORTFIELD,$SORTFIELD $CMTFILE > cmt_sort.txt
    CMTFILE="cmt_sort.txt"
  fi



  CMTRESCALE=$(echo "$CMTSCALE * $SEISSCALE " | bc -l)  # * $SEISSCALE

  # Rescale CMT magnitudes to match rescaled seismicity, if that option is set
  # This function assumed that the CMT file included the seconds in the last field
  if [[ $SCALEEQS -eq 1 ]]; then
    info_msg "Scaling CMT earthquake magnitudes for display only"

    awk < $CMTFILE -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
      mw=$13
      mwmod = (mw^str)/(sref^(str-1))
      a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
      split(a,b,"+")  # mantissa
      split(a,c,"E")  # exponent
      print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, c[1], b[2], $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39
    }' > cmt_scale.dat
    CMTFILE="cmt_scale.dat"
  fi

  ##############################################################################
  # Rotate PTN axes if asked to (-cr)

  if [[ $cmtrotateflag -eq 1 && -e $CMTFILE ]]; then
    info_msg "Rotating principal axes by back azimuth to ${CMT_ROTATELON}/${CMT_ROTATELAT}"
    case $CMTTYPE in
      ORIGIN)
        awk < $CMTFILE '{ print $8, $9 }' | gmt mapproject -Ab${CMT_ROTATELON}/${CMT_ROTATELAT} ${VERBOSE} > cmt_backaz.txt
      ;;
      CENTROID)
        awk < $CMTFILE '{ print $5, $6 }' | gmt mapproject -Ab${CMT_ROTATELON}/${CMT_ROTATELAT} ${VERBOSE} > cmt_backaz.txt
      ;;
    esac
    paste $CMTFILE cmt_backaz.txt > cmt_backscale.txt
    awk < cmt_backscale.txt -v refaz=$CMT_REFAZ '{ for (i=1; i<=22; i++) { printf "%s ", $(i) }; printf "%s %s %s %s %s %s %s %s %s", $23, ($24-$42+refaz)%360, $25, $26, ($27-$42+refaz)%360, $28, $29,($30-$40+refaz)%360, $31;  for(i=32;i<=39;i++) {printf " %s", $(i)}; printf("\n");  }' > cmt_rotated.dat
    CMTFILE=cmt_rotated.dat
  fi

# 23
#   Tval	Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc

  #      1          	2	 3      4 	         5	            6             	7	         8	         9	           10	              11	         12 13	 14       exponent	     16	  17	   18	      19     	20	   21	      22	  23	 24 	25	  26 	 27	  28	  29	  30	31	      32	 33 	34	35 36	 37	 38	         39
  # idcode	event_code	id	epoch	lon_centroid	lat_centroid	depth_centroid	lon_origin	lat_origin	depth_origin	author_centroid	author_origin	MW	mantissa	exponent	strike1	dip1	rake1	strike2	dip2	rake2	exponent	Tval	Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc	exponent	Mrr	Mtt	Mpp	Mrt	Mrp	Mtp	centroid_dt

  ##############################################################################
  # Save focal mechanisms in a psmeca+ format based on the selected format type

  touch cmt_thrust.txt cmt_normal.txt cmt_strikeslip.txt
  touch t_axes_thrust.txt n_axes_thrust.txt p_axes_thrust.txt t_axes_normal.txt n_axes_normal.txt p_axes_normal.txt t_axes_strikeslip.txt n_axes_strikeslip.txt p_axes_strikeslip.txt

  #   1             	2	 3      4 	          5	           6              	7	         8	         9	          10	             11	           12 13        14	      15	     16	  17	   18	     19  	20	   21	      22	  23	 24 	25	 26 	 27	  28	  29	 30	  31	      32	 33 34	 35  36	 37	 38	         39
  # idcode	event_code	id	epoch	lon_centroid	lat_centroid	depth_centroid	lon_origin	lat_origin	depth_origin	author_centroid	author_origin	MW	mantissa	exponent	strike1	dip1	rake1	strike2	dip2	rake2	exponent	Tval	Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc	exponent	Mrr	Mtt	Mpp	Mrt	Mrp	Mtp	centroid_dt

  # This should go into an external utility script that converts from tectoplot->psmeca format

  awk < $CMTFILE -v fmt=$CMTFORMAT -v cmttype=$CMTTYPE -v minmag="${KIN_MINMAG}" -v maxmag="${KIN_MAXMAG}" '
    function abs(v) { return (v>0)?v:-v}
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
    }'

  touch kin_thrust.txt kin_normal.txt kin_strikeslip.txt

	# Generate the kinematic vectors
	# For thrust faults, take the slip vector associated with the shallower dipping nodal plane

	awk < kin_thrust.txt -v symsize=$SYMSIZE1 '{if($8 > 45) print $1, $2, ($7+270) % 360, symsize; else print $1, $2, ($4+270) % 360, symsize;  }' > thrust_gen_slip_vectors_np1.txt
	awk < kin_thrust.txt -v symsize=$SYMSIZE2 '{if($8 > 45) print $1, $2, ($4+90) % 360, symsize; else print $1, $2, ($7+90) % 360, symsize;  }' > thrust_gen_slip_vectors_np1_downdip.txt
	awk < kin_thrust.txt -v symsize=$SYMSIZE3 '{if($8 > 45) print $1, $2, ($4) % 360, symsize / 2; else print $1, $2, ($7) % 360, symsize / 2;  }' > thrust_gen_slip_vectors_np1_str.txt

	awk 'NR > 1' kin_thrust.txt | awk -v symsize=$SYMSIZE1 '{if($8 > 45) print $1, $2, ($4+270) % 360, symsize; else print $1, $2, ($7+270) % 360, symsize;  }' > thrust_gen_slip_vectors_np2.txt
	awk 'NR > 1' kin_thrust.txt | awk -v symsize=$SYMSIZE2 '{if($8 > 45) print $1, $2, ($7+90) % 360, symsize; else print $1, $2, ($4+90) % 360, symsize ;  }' > thrust_gen_slip_vectors_np2_downdip.txt
	awk 'NR > 1' kin_thrust.txt | awk -v symsize=$SYMSIZE3 '{if($8 > 45) print $1, $2, ($7) % 360, symsize / 2; else print $1, $2, ($4) % 360, symsize / 2;  }' > thrust_gen_slip_vectors_np2_str.txt

	awk 'NR > 1' kin_strikeslip.txt | awk -v symsize=$SYMSIZE1 '{ print $1, $2, ($7+270) % 360, symsize }' > strikeslip_slip_vectors_np1.txt
	awk 'NR > 1' kin_strikeslip.txt | awk -v symsize=$SYMSIZE1 '{ print $1, $2, ($4+270) % 360, symsize }' > strikeslip_slip_vectors_np2.txt

	awk 'NR > 1' kin_normal.txt | awk -v symsize=$SYMSIZE1 '{ print $1, $2, ($7+270) % 360, symsize }' > normal_slip_vectors_np1.txt
	awk 'NR > 1' kin_normal.txt | awk -v symsize=$SYMSIZE1 '{ print $1, $2, ($4+270) % 360, symsize }' > normal_slip_vectors_np2.txt

fi

##### EQUIVALENT EARTHQUAKES
# If the REMOVE_EQUIVS variable is set, compare with cmt.dat to remove EQs that have a focal mechanism equivalent.

# If CMTFILE exists but we aren't plotting CMT's this will really cull a lot of EQs! Careful!

if [[ $REMOVE_EQUIVS -eq 1 && -e $CMTFILE && -e eqs.txt ]]; then

  info_msg "Removing earthquake origins that have equivalent CMT"

  before_e=$(wc -l < eqs.txt)
# echo "CMTFILE=$CMTFILE"
  # epoch is field 4 for CMTS
  awk < $CMTFILE '{
    if ($10 != "none") {                       # Use origin location
      print "O", $8, $9, $4, $10, $13, $3, $2
    } else if ($11 != "none") {                # Use centroid location for events without origin
      print "C", $5, $6, $4, $7, $13, $3, $2
    }
  }' > eq_comp.dat

  # Currently we only use the first 6 columns of the EQ data. Commented code indicates how to add more/pad if necessary
  # A LON LAT DEPTH MAG TIMECODE ID EPOCH

  # We need to first add a buffer of fake EQs to avoid problems with grep -A -B
  awk < eqs.txt '{
    print "EQ", $1, $2, $7, $3, $4, $5, $6
  }' >> eq_comp.dat

  sort eq_comp.dat -n -k 4,4 > eq_comp_sort.dat

  sed '1d' eq_comp_sort.dat > eq_comp_sort_m1.dat
  sed '1d' eq_comp_sort_m1.dat > eq_comp_sort_m2.dat

  paste eq_comp_sort.dat eq_comp_sort_m1.dat eq_comp_sort_m2.dat > 3comp.txt

  # 1   2   3     4     5   6        7   8   9  10  11  12     13   14       15 16  17  18  19    20    21  22       23 24
  # C LON LAT EPOCH DEPTH MAG TIMECODE  ID   C LON LAT EPOCH DEPTH MAG TIMECODE ID   C LON LAT EPOCH DEPTH MAG TIMECODE ID

  # We want to remove from A any A event that is close to a C event
  awk < 3comp.txt -v secondlimit=5 -v deglimit=2 -v maglimit=0.3 'function abs(v) {return v < 0 ? -v : v} {
    if ($9 == "EQ") { # Only examine non-CMT events
      if ($14 > 7.5) {
        deglimit=3
        secondlimit=120
      }
      printme = 1
        if (($1 == "C" || $1 == "O") && abs($12-$4) < secondlimit && abs($10-$2) < deglimit && abs($11-$3) < deglimit && abs($14-$6) < maglimit) {
            printme = 0
        } else if (($17 == "C" || $17 == "O") && abs($20-$12) < secondlimit && abs($18-$10) < 2 && abs($19-$11) < 2 && abs($22-$14) < maglimit) {
            printme = 0
        }
      if (printme == 1) {
          print $10, $11, $13, $14, $15, $16, $12
      } else {
          print $10, $11, $13, $14, $15, $16, $12 > "eq_culled.txt"
      }
    }
  }' > eqs.txt
  after_e=$(wc -l < eqs.txt)
  info_msg "Before equivalent EQ culling: $before_e ; after culling: $after_e"
fi


if [[ $REMOVE_DEFAULTDEPTHS -eq 1 && -e eqs.txt ]]; then
  info_msg "Removing earthquakes with poorly determined origin depths"
  [[ REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && info_msg "Plotting removed events separately"
  # Plotting in km instead of in map geographic coords.
  awk < eqs.txt '{
    depth=$10
    if (depth == 10 || depth == 33 || depth == 30 || depth == 5 ||depth == 1 || depth == 6  || depth == 35 ) {
      print > "/dev/stderr"
    } else {
      print
    }
  }
  ' > tmp.dat 2>removed_eqs.txt
  mv tmp.dat eqs.txt
fi

if [[ $SCALEEQS -eq 1 && -e eqs.txt ]]; then
  awk < removed_eqs.txt -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1)), $5, $6, $7}' > removed_eqs_scaled.txt
  awk < eqs.txt -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{print $1, $2, $3, ($4^str)/(sref^(str-1)), $5, $6, $7}' > eqs_scaled.txt
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
  gmt spatial $PLATES -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C $VERBOSE | awk '{print $1, $2}' > map_plates_clip_a.txt

  # Ensure CW orientation of clipped polygons.
  # GMT spatial strips out the header labels for some reason.
  gmt spatial map_plates_clip_a.txt -E+n $VERBOSE > map_plates_clip_orient.txt

  # Check the special case that there are no polygon boundaries within the region
  numplates=$(grep ">" map_plates_clip_a.txt | wc -l)
  numplatesorient=$(grep ">" map_plates_clip_orient.txt | wc -l)

  if [[ $numplates -eq 1 && $numplatesorient -eq 0 ]]; then
    grep ">" map_plates_clip_a.txt > new.txt
    cat map_plates_clip_orient.txt >> new.txt
    cp new.txt map_plates_clip_orient.txt
  fi

  grep ">" map_plates_clip_a.txt > map_plates_clip_ids.txt

  IFS=$'\n' read -d '' -r -a pids < map_plates_clip_ids.txt
  i=0

  # Now read through the file and replace > with the next value in the pids array. This replaces names that GMT spatial stripped out for no good reason at all...
  while read p; do
    if [[ ${p:0:1} == '>' ]]; then
      printf  "%s\n" "${pids[i]}" >> map_plates_clip.txt
      i=$i+1
    else
      printf "%s\n" "$p" >> map_plates_clip.txt
    fi
  done < map_plates_clip_orient.txt

  grep ">" map_plates_clip.txt | uniq | awk '{print $2}' > plate_id_list.txt

  if [[ $outputplatesflag -eq 1 ]]; then
    echo "Plates in model:"
    awk < $POLES '{print $1}' | tr '\n' '\t'
    echo ""
    echo "Plates within AOI":
    awk < plate_id_list.txt '{
      split($1, v, "_");
      for(i=1; i<length(v); i++) {
        printf "%s\n", v[i]
      }
    }' | tr '\n' '\t'
    echo ""
    exit
  fi

  info_msg "Found plates ..."
  [[ $narrateflag -eq 1 ]] && cat plate_id_list.txt
  info_msg "Extracting the full polygons of intersected plates..."

  v=($(cat plate_id_list.txt | tr ' ' '\n'))
  i=0
  j=1;
  rm -f plates_in_view.txt
  echo "> END" >> map_plates_clip.txt

  # STEP 2: Calculate midpoint locations and azimuth of segment for plate boundary segments

	# Calculate the azimuth between adjacent line segment points (assuming clockwise oriented polygons)
	rm -f plateazfile.txt

  # We are too clever by half and just shift the whole plate file one line down and then calculate the azimuth between points:
	sed 1d < map_plates_clip.txt > map_plates_clip_shift1.txt
	paste map_plates_clip.txt map_plates_clip_shift1.txt | grep -v "\s>" > geodin.txt

  # Script to return azimuth and midpoint between a pair of input points.
  # Comes within 0.2 degrees of geod() results over large distances, while being symmetrical which geod isn't
  # We need perfect symmetry in order to create exact point pairs in adjacent polygons

  awk < geodin.txt '{print $1, $2, $3, $4}' | awk 'function acos(x) { return atan2(sqrt(1-x*x), x) }
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
      }' > plateazfile.txt

  # plateazfile.txt now contains midpoints with azimuth and distance of segments. Multiple
  # headers per plate are possible if multiple disconnected lines were generated
  # outfile is midpointlon midpointlat azimuth

  cat plateazfile.txt | awk '{if (!/^>/) print $1, $2}' > halfwaypoints.txt
  # output is lat1 lon1 midlat1 midlon1 az backaz distance

	cp plate_id_list.txt map_ids_end.txt
	echo "END" >> map_ids_end.txt

  # Extract the Euler poles for the map_ids.txt plates
  # We need to match XXX from XXX_N
  v=($(cat plate_id_list.txt | tr ' ' '\n'))
  i=0
  while [[ $i -lt ${#v[@]} ]]; do
      pid="${v[$i]%_*}"
      repid="${v[$i]}"
      info_msg "Looking for pole $pid and replacing with $repid"
      grep "$pid\s" < $POLES | sed "s/$pid/$repid/" >> polesextract_init.txt
      i=$i+1
  done

  # Extract the unique Euler poles
  awk '!seen[$1]++' polesextract_init.txt > polesextract.txt

  # Define the reference plate (zero motion plate) either manually or using reference point (reflon, reflat)
  if [[ $manualrefplateflag -eq 1 ]]; then
    REFPLATE=$(grep ^$MANUALREFPLATE polesextract.txt | head -n 1 | awk '{print $1}')
    info_msg "Manual reference plate is $REFPLATE"
  else
    # We use a tiny little polygon to clip the map_plates and determine the reference polygon.
    # Not great but GMT spatial etc don't like the map polygon data...
    REFWINDOW=0.001

    Y1=$(echo "$REFPTLAT-$REFWINDOW" | bc -l)
    Y2=$(echo "$REFPTLAT+$REFWINDOW" | bc -l)
    X1=$(echo "$REFPTLON-$REFWINDOW" | bc -l)
    X2=$(echo "$REFPTLON+$REFWINDOW" | bc -l)

    nREFPLATE=$(gmt spatial map_plates_clip.txt -R$X1/$X2/$Y1/$Y2 -C $VERBOSE  | grep "> " | head -n 1 | awk '{print $2}')
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
  	reflat=`grep "^$REFPLATE\s" < polesextract.txt | awk '{print $2}'`
  	reflon=`grep "^$REFPLATE\s" < polesextract.txt | awk '{print $3}'`
  	refrate=`grep "^$REFPLATE\s" < polesextract.txt | awk '{print $4}'`

  	info_msg "Found reference plate Euler pole $REFPLATE vs $DEFREF $reflat $reflon $refrate"
  fi

	# Set the GPS to the reference plate if not overriding it from the command line

	if [[ $gpsoverride -eq 0 ]]; then
    if [[ $defaultrefflag -eq 1 ]]; then
      # ITRF08 is likely similar to other reference frames.
      GPS_FILE=$(echo $GPS"/GPS_ITRF08.gmt")
    else
      # REFPLATE now ends in a _X code to accommodate multiple subplates with the same pole.
      # This will break if _X becomes _XX (10 or more sub-plates)
      RGP=${REFPLATE::${#REFPLATE}-2}
      if [[ -e $GPS"/GPS_${RGP}.gmt" ]]; then
        GPS_FILE=$(echo $GPS"/GPS_${RGP}.gmt")
      else
        info_msg "No GPS file $GPS/GPS_${RGP}.gmt exists. Keeping default"
      fi
    fi
  fi

  # Iterate over the plates. We create plate polygons, identify Euler poles, etc.

  # Slurp the plate IDs from map_plates_clip.txt
  v=($(grep ">" map_plates_clip.txt | awk '{print $2}' | tr ' ' '\n'))
	i=0
	j=1
	while [[ $i -lt ${#v[@]}-1 ]]; do

    # Create plate files .pldat
    info_msg "Extracting between ${v[$i]} and ${v[$j]}"
		sed -n '/^> '${v[$i]}'$/,/^> '${v[$j]}'$/p' map_plates_clip.txt | sed '$d' > "${v[$i]}.pldat"
		echo " " >> "${v[$i]}.pldat"
		# PLDAT files now contain the X Y coordinates and segment azimuth with a > PL header line and a single empty line at the end

		# Calculate the true centroid of each polygon and output it to the label file
		sed -e '2,$!d' -e '$d' "${v[$i]}.pldat" | awk '{
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
		}' > "${v[$i]}.centroid"
    cat "${v[$i]}.centroid" >> map_centroids.txt

    # Calculate Euler poles relative to reference plate
    pllat=`grep "^${v[$i]}\s" < polesextract.txt | awk '{print $2}'`
    pllon=`grep "^${v[$i]}\s" < polesextract.txt | awk '{print $3}'`
    plrate=`grep "^${v[$i]}\s" < polesextract.txt | awk '{print $4}'`
    # Calculate resultant Euler pole
    info_msg "Euler poles ${v[$i]} vs $DEFREF: $pllat $pllon $plrate vs $reflat $reflon $refrate"

    echo $pllat $pllon $plrate $reflat $reflon $refrate | awk -f $EULERADD_AWK  > ${v[$i]}.pole

    # Calculate motions of grid points from their plate's Euler pole

    if [[ $makegridflag -eq 1 ]]; then
    	# gridfile is in lat lon
    	# gridpts are in lon lat
      # Select the grid points within the plate amd calculate plate velocities at the grid points

      cat gridfile.txt | gmt select -: -F${v[$i]}.pldat $VERBOSE | awk '{print $2, $1}' > ${v[$i]}_gridpts.txt

      # COMEBACK

      awk -f $EULERVEC_AWK -v eLat_d1=$pllat -v eLon_d1=$pllon -v eV1=$plrate -v eLat_d2=$reflat -v eLon_d2=$reflon -v eV2=$refrate ${v[$i]}_gridpts.txt > ${v[$i]}_velocities.txt
    	paste -d ' ' ${v[$i]}_gridpts.txt ${v[$i]}_velocities.txt | awk '{print $2, $1, $3, $4, 0, 0, 1, "ID"}' > ${v[$i]}_platevecs.txt
    fi

    # Small circles for showing plate relative motions. Not the greatest or worst concept.

    if [[ $platerotationflag -eq 1 ]]; then

      polelat=$(cat ${v[$i]}.pole | awk '{print $1}')
      polelon=$(cat ${v[$i]}.pole | awk '{print $2}')
      polerate=$(cat ${v[$i]}.pole | awk '{print $3}')

      if [[ $(echo "$polerate == 0" | bc -l) -eq 1 ]]; then
        info_msg "Not generating small circles for reference plate"
        touch ${v[$i]}.smallcircles
      else
        centroidlat=`cat ${v[$i]}.centroid | awk -F, '{print $1}'`
        centroidlon=`cat ${v[$i]}.centroid | awk -F, '{print $2}'`
        info_msg "Generating small circles around pole $polelat $polelon"

        # Calculate the minimum and maximum colatitudes of points in .pldat file relative to Euler Pole
        #cos(AOB)=cos(latA)cos(latB)cos(lonB-lonA)+sin(latA)sin(latB)
        grep -v ">" ${v[$i]}.pldat | grep "\S" | awk -v plat=$polelat -v plon=$polelon 'function acos(x) { return atan2(sqrt(1-x*x), x) }
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
        }' > ${v[$i]}.colatrange.txt
        colatmin=$(cat ${v[$i]}.colatrange.txt | awk '{print $1}')
        colatmax=$(cat ${v[$i]}.colatrange.txt | awk '{print $2}')

        # Find the antipode for GMT project
        poleantilat=$(echo "0 - (${polelat})" | bc -l)
        poleantilon=$(echo "$polelon" | awk '{if ($1 < 0) { print $1+180 } else { print $1-180 } }')
        info_msg "Pole $polelat $polelon has antipode $poleantilat $poleantilon"

        # Generate small circle paths in colatitude range of plate
        rm -f ${v[$i]}.smallcircles
        for j2 in $(seq $colatmin $LATSTEPS $colatmax); do
          echo "> -Z${j2}" >> ${v[$i]}.smallcircles
          gmt project -T${polelon}/${polelat} -C${poleantilon}/${poleantilat} -G0.5/${j2} -L-360/0 $VERBOSE | awk '{print $1, $2}' >> ${v[$i]}.smallcircles
        done

        # Clip the small circle paths by the plate polygon
        gmt spatial ${v[$i]}.smallcircles -T${v[$i]}.pldat $VERBOSE | awk '{print $1, $2}' > ${v[$i]}.smallcircles_clip_1

        # We have trouble with gmt spatial giving us two-point lines segments. Remove all two-point segments by building a sed script
        grep -n ">" ${v[$i]}.smallcircles_clip_1 | awk -F: 'BEGIN { oldval=0; oldline=""; }
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
        }' > lines_to_extract.txt

        # Execute sed commands to build sanitized small circle file
        sed -n -f lines_to_extract.txt < ${v[$i]}.smallcircles_clip_1 > ${v[$i]}.smallcircles_clip

        # GMT plot command that exports label locations for points at a specified interval distance along small circles.
        # These X,Y locations are used as inputs to the vector arrowhead locations.
        cat ${v[$i]}.smallcircles_clip | gmt psxy -O -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -W0p -Sqd0.25i:+t"${v[$i]}labels.txt"+l" " $VERBOSE >> /dev/null

        # Reformat points
        awk < ${v[$i]}labels.txt '{print $2, $1}' > ${v[$i]}_smallcirc_gridpts.txt

        # Calculate the plate velocities at the points
        awk -f $EULERVEC_AWK -v eLat_d1=$pllat -v eLon_d1=$pllon -v eV1=$plrate -v eLat_d2=$reflat -v eLon_d2=$reflon -v eV2=$refrate ${v[$i]}_smallcirc_gridpts.txt > ${v[$i]}_smallcirc_velocities.txt

        # Transform to psvelo format for later plotting
        paste -d ' ' ${v[$i]}_smallcirc_gridpts.txt ${v[$i]}_smallcirc_velocities.txt | awk '{print $1, $2, $3*100, $4*100, 0, 0, 1, "ID"}' > ${v[$i]}_smallcirc_platevecs.txt
      fi # small circles
    fi

	  i=$i+1
	  j=$j+1
  done # while (Iterate over plates calculating pldat, centroids, and poles

  # Create the plate labels at the centroid locations
	paste -d ',' map_centroids.txt plate_id_list.txt > map_labels.txt

  # EDGE CALCULATIONS. Determine the relative motion of each plate pair for each plate edge segment
  # by extracting the two Euler poles and calculating predicted motions at the segment midpoint.
  # This calculation is time consuming for large areas because my implementation is... algorithmically
  # poor. So, intead we load the data from a global results file if it exists.

  if [[ $doplateedgesflag -eq 1 ]]; then
    # Load pre-calculated data if it exists - MUCH faster but may need to recalc if things change
    # To re-build, use a global region -r -180 180 -90 90 and copy id_pts_euler.txt to $MIDPOINTS file

    if [[ -e $MIDPOINTS ]]; then
      awk < $MIDPOINTS -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
        if ($1 >= minlon && $1 <= maxlon && $2 >= minlat && $2 <= maxlat) {
          print
        }
      }' > id_pts_euler.txt
    else
      echo "Midpoints file $MIDPOINTS does not exist"
      if [[ $MINLAT -eq "-90" && $MAXLAT -eq "90" && $MINLON -eq "-180" && $MAXLON -eq "180" ]]; then
        echo "Your region is global. After this script ends, you can copy id_pts_euler.txt and define it as a MIDPOINT file."
      fi

    	# Create a file with all points one one line beginning with the plate ID only
      # The sed '$d' deletes the 'END' line
      awk < plateazfile.txt '{print $1, $2 }' | tr '\n' ' ' | sed -e $'s/>/\\\n/g' | grep '\S' | tr -s '\t' ' ' | sed '$d' > map_plates_oneline.txt

    	# Create a list of unique block edge points.  Not sure I actually need this
    	awk -F" " '!_[$1][$2]++' plateazfile.txt | awk '($1 != ">") {print $1, $2}' > map_plates_uniq.txt

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
          curplate=$(echo $p | awk '{print $2}')
          echo $p >> id_pts.txt
          pole1=($(grep "${curplate}\s" < polesextract.txt))
          info_msg "Current plate is $curplate with pole ${pole1[1]} ${pole1[2]} ${pole1[3]}"
        else
          q=$(echo $p | awk '{print $1, $2}')
          resvar=($(grep -n -- "${q}" < map_plates_oneline.txt | awk -F" " '{printf "%s\n", $2}'))
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
          pole2=($(grep "${plate2}\s" < polesextract.txt))
          info_msg " Plate 2 is $plate2 with pole ${pole2[1]} ${pole2[2]} ${pole2[3]}"
          echo -n "${p} " >> id_pts.txt
          echo ${plate1} ${plate2} ${pole2[1]} ${pole2[2]} ${pole2[3]} ${pole1[1]} ${pole1[2]} ${pole1[3]} | awk '{printf "%s %s ", $1, $2; print $3, $4, $5, $6, $7, $8}' >> id_pts.txt
        fi
      done < plateazfile.txt

      # Do the plate relative motion calculations all at once.
      awk -f $EULERVECLIST_AWK id_pts.txt > id_pts_euler.txt

    fi

  	grep "^[^>]" < id_pts_euler.txt | awk '{print $1, $2, $3, 0.5}' >  paz1.txt
  	grep "^[^>]" < id_pts_euler.txt | awk '{print $1, $2, $15, 0.5}' >  paz2.txt

    grep "^[^>]" < id_pts_euler.txt | awk '{print $1, $2, $3-$15}' >  azdiffpts.txt
    #grep "^[^>]" < id_pts_euler.txt | awk '{print $1, $2, $3-$15, $4}' >  azdiffpts_len.txt

    # Right now these values don't go from -180:180...
    grep "^[^>]" < id_pts_euler.txt | awk '{
        val = $3-$15
        if (val > 180) { val = val - 360 }
        if (val < -180) { val = val + 360 }
        print $1, $2, val, $4
      }' >  azdiffpts_len.txt


  	# currently these kinematic arrows are all the same scale. Can scale to match psvelo... but how?

    grep "^[^>]" < id_pts_euler.txt |awk 'function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u} {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff >= 20 && diff <= 70) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' >  paz1thrust.txt

    grep "^[^>]" < id_pts_euler.txt |awk 'function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u} {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff > 70 && diff < 110) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' >  paz1ss1.txt

    grep "^[^>]" < id_pts_euler.txt |awk 'function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u} {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff > -90 && diff < -70) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' > paz1ss2.txt

    grep "^[^>]" < id_pts_euler.txt |awk 'function abs(v) {return v < 0 ? -v : v} function ddiff(u) { return u > 180 ? 360 - u : u} {
      diff=$15-$3;
      if (diff > 180) { diff = diff - 360 }
      if (diff < -180) { diff = diff + 360 }
      if (diff >= 110 || diff <= -110) { print $1, $2, $15, sqrt($13*$13+$14*$14) }}' > paz1normal.txt
  fi #  if [[ $doplateedgesflag -eq 1 ]]; then
fi # if [[ $plotplates -eq 1 ]]


if [[ $sprofflag -eq 1 ]]; then
  plots+=("mprof")
fi

################################################################################
################################################################################
################################################################################
#####           Create CPT files for coloring grids and data               #####
################################################################################
################################################################################
################################################################################

# These are a series of fixed CPT files that we can refer to when we wish. They
# are not modified and don't need to be copied to tempdir.

[[ ! -e $CPTDIR"grayhs.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cgray,gray -T-10000/10000/10000 > $CPTDIR"grayhs.cpt"
[[ ! -e $CPTDIR"whitehs.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cwhite,white -T-10000/10000/10000 > $CPTDIR"whitehs.cpt"
[[ ! -e $CPTDIR"cycleaz.cpt" || $remakecptsflag -eq 1 ]] && gmt makecpt -Cred,yellow,green,blue,orange,purple,brown,plum4,thistle1,palegreen1,cadetblue1,navajowhite1,red -T-180/180/1 -Z $VERBOSE > $CPTDIR"cycleaz.cpt"
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
      GCDM_CPT=$(echo "$(cd "$(dirname "$GDCM_CPT")"; pwd)/$(basename "$GDCM_CPT")")
      gmt makecpt -Cseis -T$GCDMMIN/$GCDMMAX -Z > $GCDM_CPT
      ;;

    grav) # WGM gravity maps
      touch $GRAV_CPT
      GRAV_CPT=$(echo "$(cd "$(dirname "$GRAV_CPT")"; pwd)/$(basename "$GRAV_CPT")")
      if [[ $rescalegravflag -eq 1 ]]; then
        # gmt grdcut $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -Ggravtmp.nc
        zrange=$(grid_zrange $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
        MINZ=$(echo $zrange | awk '{print int($1/100)*100}')
        MAXZ=$(echo $zrange | awk '{print int($2/100)*100}')
        # MINZ=$(gmt grdinfo $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep z_min | awk '{ print int($3/100)*100 }')
        # MAXZ=$(gmt grdinfo $GRAVDATA -R$MINLON/$MAXLON/$MINLAT/$MAXLAT $VERBOSE | grep z_min | awk '{print int($5/100)*100}')
        # echo MINZ MAXZ $MINZ $MAXZ
        # GRAVCPT is set by the type of gravity we selected (BG, etc) and is not the same as GRAV_CPT
        gmt makecpt -C$GRAVCPT -T$MINZ/$MAXZ $VERBOSE > $GRAV_CPT
      else
        gmt makecpt -C$GRAVCPT -T-500/500 $VERBOSE > $GRAV_CPT
      fi
      ;;

    litho1)

      gmt makecpt -T${LITHO1_MIN_DENSITY}/${LITHO1_MAX_DENSITY}/10 -C${LITHO1_DENSITY_BUILTIN} -Z $VERBOSE > $LITHO1_DENSITY_CPT
      gmt makecpt -T${LITHO1_MIN_VELOCITY}/${LITHO1_MAX_VELOCITY}/10 -C${LITHO1_VELOCITY_BUILTIN} -Z $VERBOSE > $LITHO1_VELOCITY_CPT
      ;;

    mag) # EMAG_V2
      touch $MAG_CPT
      MAG_CPT=$(echo "$(cd "$(dirname "$MAG_CPT")"; pwd)/$(basename "$MAG_CPT")")
      gmt makecpt -Crainbow -Z -Do -T-250/250/10 $VERBOSE > $MAG_CPT
      ;;

    oceanage)
      if [[ $stretchoccptflag -eq 1 ]]; then
        # The ocean CPT has a long 'purple' tail that isn't useful when stretching the CPT
        awk < $OC_AGE_CPT '{ if ($1 < 180) print }' > ./oceanage_cut.cpt
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
      POPULATION_CPT=$(echo "$(cd "$(dirname "$POPULATION_CPT")"; pwd)/$(basename "$POPULATION_CPT")")
      gmt makecpt -C${CITIES_CPT} -I -Do -T0/1000000/100000 -N $VERBOSE > $POPULATION_CPT
      ;;

    slipratedeficit)
      gmt makecpt -Cseis -Do -I -T0/1/0.01 -N > $SLIPRATE_DEF_CPT
      ;;

    topo)
      info_msg "Plotting topo from $BATHY"
      touch $TOPO_CPT
      TOPO_CPT=$(echo "$(cd "$(dirname "$TOPO_CPT")"; pwd)/$(basename "$TOPO_CPT")")
      if [[ customgridcptflag -eq 1 ]]; then
        info_msg "Copying custom CPT file $CUSTOMCPT to temporary directory"
        cp $CUSTOMCPT $TOPO_CPT
      else
        info_msg "Building default TOPO CPT file from $TOPO_CPT_DEF"
        gmt makecpt -Fr -C${TOPO_CPT_DEF} -T${TOPO_CPT_DEF_MIN}/${TOPO_CPT_DEF_MAX}/${TOPO_CPT_DEF_STEP}  $VERBOSE > $TOPO_CPT
      fi
      if [[ $rescaletopoflag -eq 1 ]]; then
        zrange=$(grid_zrange $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
        MINZ=$(echo $zrange | awk '{printf "%d\n", $1}')
        MAXZ=$(echo $zrange | awk '{printf "%d\n", $2}')
        # # MINZ=$(gmt grdinfo $BATHY ${VERBOSE} | grep z_min | awk '{ print int($3/100)*100 }')
        # # MAXZ=$(gmt grdinfo $BATHY ${VERBOSE} | grep z_min | awk '{print int($5/100)*100}')
        # MINZ=$(gmt grdinfo -L $BATHY ${VERBOSE} | grep z_min | awk '{ print $3 }')
        # MAXZ=$(gmt grdinfo -L $BATHY ${VERBOSE} | grep z_min | awk '{ print $5 }')
        info_msg "Rescaling topo $BATHY with CPT to $MINZ/$MAXZ with hinge at 0"
        gmt makecpt -Fr -C$TOPO_CPT_DEF -T$MINZ/$MAXZ/${TOPO_CPT_DEF_STEP}  ${VERBOSE} > topotmp.cpt
        mv topotmp.cpt $TOPO_CPT
        GDIFFZ=$(echo "($MAXZ - $MINZ) > 4000" | bc)  # Scale range is greater than 4 km
        # Set the interval value for the legend scale based on the range of the data
        if [[ $GDIFFZ -eq 1 ]]; then
          BATHYXINC=2
        else
          BATHYXINC=$(echo "($MAXZ - $MINZ) / 6 / 1000" | bc -l | awk '{ print int($1/0.1)*0.1}')
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
      SEISDEPTH_CPT=$(echo "$(cd "$(dirname "$SEISDEPTH_CPT")"; pwd)/$(basename "$SEISDEPTH_CPT")")
      gmt makecpt -Cseis -Do -T0/"${EQMAXDEPTH_COLORSCALE}"/10 -Z -N $VERBOSE > $SEISDEPTH_CPT
      cp $SEISDEPTH_CPT $SEISDEPTH_NODEEPEST_CPT
      echo "${EQMAXDEPTH_COLORSCALE}	0/17.937/216.21	6370	0/0/255" >> $SEISDEPTH_CPT
    ;;

  esac
done

################################################################################
################################################################################
################################################################################
##### Plot the postscript file by calling the sections listed in $plots[@] #####
################################################################################
################################################################################
################################################################################

# Add a PS comment with the command line used to invoke tectoplot. Use >> as we might
# be adding this line onto an already existing PS file

echo "%TECTOPLOT: ${COMMAND}" >> map.ps

# Set up default look of the map. This should be shipped to a configuration file.

gmt gmtset FONT_ANNOT_PRIMARY 7 FONT_LABEL 7 MAP_FRAME_WIDTH 0.15c FONT_TITLE 18p,Palatino-BoldItalic
gmt gmtset MAP_FRAME_PEN 0.5p,black

# Before we plot anything but after we have done the data processing, set any
# GMT variables that are given on the command line using -gmtvars { A val ... }

if [[ $usecustomgmtvars -eq 1 ]]; then
  info_msg "gmt gmtset ${GMTVARS[@]}"
  gmt gmtset ${GMTVARS[@]}
fi

info_msg "Plotting grid and keeping PS file open for legend"

# The strategy for adding items to the legend is to make little baby EPS files
# and then place them onto the master PS using gmt psimage. We initialize these
# files here and then we have to keep track of whether to close the master PS
# file or keep it open for subsequent plotting (--keepopenps)

##### PREPARE PS FILES
if [[ $usecustomrjflag -eq 1 ]]; then
  # Special flag to plot using a custom string containing -R -J -B
  if [[ $usecustombflag -eq 1 ]]; then
    gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY ${RJSTRING[@]} $VERBOSE ${BSTRING[@]} > base_fake.ps
  else
    if [[ $PLOTTITLE == "BlankMapTitle" ]]; then
      gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY ${RJSTRING[@]} $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}" > base_fake.ps
    else
      gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY ${RJSTRING[@]} $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}"+t"${PLOTTITLE}" > base_fake.ps
    fi
  fi
  # Probably not the best way to initialize these
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > kinsv.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > plate.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > mecaleg.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > seissymbol.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > volcanoes.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > velarrow.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} > velgps.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY $VERBOSE -K ${RJSTRING[@]} >> map.ps
else
  if [[ $usecustombflag -eq 1 ]]; then
    # SHOULD PROBABLY UPDATE TO AN AVERAGE LONGITUDE INSTEAD OF -JQ$MINLON?
    gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i  $VERBOSE ${BSTRING[@]} > base_fake.ps
  else
    if [[ $PLOTTITLE == "BlankMapTitle" ]]; then
      gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i  $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}" > base_fake.ps
    else
      gmt psbasemap -X$PLOTSHIFTX -Y$PLOTSHIFTY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i  $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}"+t"${PLOTTITLE}" > base_fake.ps
    fi
  fi
  # Probably not the best way to initialize these
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTHIFTY $OVERLAY -K $VERBOSE  > kinsv.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTHIFTY $OVERLAY -K $VERBOSE  > eqlabel.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > plate.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > mecaleg.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > seissymbol.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > volcanoes.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > velarrow.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  > velgps.ps
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JQ$MINLON/${INCH}i -X$PLOTSHIFTX -Y$PLOTSHIFTY $OVERLAY -K $VERBOSE  >> map.ps
fi

MAP_PS_DIM=$(gmt psconvert base_fake.ps -Te -A0.01i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
MAP_PS_WIDTH_IN=$(echo $MAP_PS_DIM | awk '{print $1/2.54}')
MAP_PS_HEIGHT_IN=$(echo $MAP_PS_DIM | awk '{print $2/2.54}')
# echo "Map dimensions (cm) are W: $MAP_PS_WIDTH_IN, H: $MAP_PS_HEIGHT_IN"

######
# These variables are array indices and must be zero at start. They allow multiple
# instances of various commands.

current_plotpointnumber=0

##### DO PLOTTING
for plot in ${plots[@]} ; do
	case $plot in
    caxes)
      if [[ $axescmtthrustflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && awk < t_axes_thrust.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && awk < p_axes_thrust.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && awk < n_axes_thrust.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >> map.ps
      fi
      if [[ $axescmtnormalflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && awk < t_axes_normal.txt  -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && awk < p_axes_normal.txt  -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && awk < n_axes_normal.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >> map.ps
      fi
      if [[ $axescmtssflag -eq 1 ]]; then
        [[ $axestflag -eq 1 ]] && awk < t_axes_strikeslip.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack  $RJOK $VERBOSE >> map.ps
        [[ $axespflag -eq 1 ]] && awk < p_axes_strikeslip.txt  -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >> map.ps
        [[ $axesnflag -eq 1 ]] && awk < n_axes_strikeslip.txt -v scalev=${CMTAXESSCALE} 'function abs(v) { return (v>0)?v:-v} {print $1, $2, $3, abs(cos($4*pi/180))*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >> map.ps
      fi
      ;;
    cities)
      info_msg "Plotting cities with minimum population ${CITIES_MINPOP}"
      awk < $CITIES -F, -v minpop=${CITIES_MINPOP} -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON"  'BEGIN{OFS=","}($1>=minlon && $1 <= maxlon && $2 >= minlat && $2 <= maxlat && $4>=minpop) {print $1, $2, $3, $4}' | sort -n -k 3 > cities.dat

      # Sort the cities so that dense areas plot on top of less dense areas
      # Could also do some kind of symbol scaling
      awk < cities.dat -F, '{print $1, $2, $4}' | sort -n -k 3 | gmt psxy -S${CITIES_SYMBOL}${CITIES_SYMBOL_SIZE} -W${CITIES_SYMBOL_LINEWIDTH},${CITIES_SYMBOL_LINECOLOR} -C$POPULATION_CPT $RJOK $VERBOSE >> map.ps
      if [[ $citieslabelflag -eq 1 ]]; then
        awk < cities.dat -F, '{print $1, $2, $3}' | sort -n -k 3 | gmt pstext -F+f${CITIES_LABEL_FONTSIZE},${CITIES_LABEL_FONT},${CITIES_LABEL_FONTCOLOR}+jLM $RJOK $VERBOSE >> map.ps
      fi
      ;;

    cmt)
      info_msg "Plotting focal mechanisms"

      # COMEBACK: These need to be xyz with the alternative depth given...

      if [[ $connectalternatelocflag -eq 1 ]]; then
        awk < cmt_thrust.txt '{
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
        awk < cmt_normal.txt '{
          if ($12 != "none" && $13 != "none")  {  # Some events have no alternative position depending on format
            print ">:" $1, $2, $3 ":" $12, $13, $15 >> "./cmt_alt_lines_normal.xyz"
            print $12, $13, $15 >> "./cmt_alt_pts_normal.xyz"
          } else {
          # Print the same start and end locations so that we don not mess up the number of lines in the file
            print ">:" $1, $2, $3 ":" $1, $2, $3 >> "./cmt_alt_lines_normal.xyz"
            print $1, $2, $3 >> "./cmt_alt_pts_normal.xyz"
          }
        }'
        awk < cmt_strikeslip.txt '{
          if ($12 != "none" && $13 != "none")  {  # Some events have no alternative position depending on format
            print ">:" $1, $2, $3 ":" $12, $13, $15 >> "./cmt_alt_lines_strikeslip.xyz"
            print $12, $13, $15 >> "./cmt_alt_pts_strikeslip.xyz"
          } else {
          # Print the same start and end locations so that we don not mess up the number of lines in the file
            print ">:" $1, $2, $3 ":" $1, $2, $3 >> "./cmt_alt_lines_strikeslip.xyz"
            print $1, $2, $3 >> "./cmt_alt_pts_strikeslip.xyz"
          }
        }'

        # Confirmed that the X,Y plot works with the .xyz format
        cat cmt_alt_lines_thrust.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps
        cat cmt_alt_lines_normal.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps
        cat cmt_alt_lines_strikeslip.xyz | tr ':' '\n' | gmt psxy -W0.1p,black $RJOK $VERBOSE >> map.ps

        gmt psxy cmt_alt_pts_thrust.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps
        gmt psxy cmt_alt_pts_normal.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps
        gmt psxy cmt_alt_pts_strikeslip.xyz -Sc0.03i -Gblack $RJOK $VERBOSE >> map.ps

      fi

      if [[ cmtthrustflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_THRUSTCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 cmt_thrust.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
      fi
      if [[ cmtnormalflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_NORMALCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 cmt_normal.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
      fi
      if [[ cmtssflag -eq 1 ]]; then
        gmt psmeca -E"${CMT_SSCOLOR}" -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 cmt_strikeslip.txt -L${FMLPEN} $RJOK $VERBOSE >> map.ps
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

    countryborders)
      gmt pscoast ${BORDER_QUALITY} -N1/${BORDER_LINEWIDTH},${BORDER_LINECOLOR} $RJOK $VERBOSE >> map.ps
      ;;

    countrylabels)
      awk -F, < $COUNTRY_CODES '{ print $3, $2, $4}' | gmt pstext -F+f${COUNTRY_LABEL_FONTSIZE},${COUNTRY_LABEL_FONT},${COUNTRY_LABEL_FONTCOLOR}+jLM $RJOK ${VERBOSE} >> map.ps
      ;;

    customtopo)
      if [[ $dontplottopoflag -eq 0 ]]; then
        info_msg "Plotting custom topography $CUSTOMBATHY"
        gmt grdimage $CUSTOMBATHY ${ILLUM} -C$TOPO_CPT -t$TOPOTRANS $RJOK $VERBOSE >> map.ps
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

      if [[ -e cmt_orig.dat ]]; then
        if [[ $labeleqlistflag -eq 1 && ${#eqlistarray[@]} -ge 1 ]]; then
          for i in ${!eqlistarray[@]}; do
            grep -- "${eqlistarray[$i]}" cmt_orig.dat >> cmtlabel.sel
          done
        fi
        if [[ $labeleqmagflag -eq 1 ]]; then
          awk < cmt_orig.dat -v minmag=$labeleqminmag '($13>=minmag) {print}'  >> cmtlabel.sel
        fi

        # 39 fields in cmt file. NR=texc NR-1=font

        awk < cmtlabel.sel -v clon=$CENTERLON -v clat=$CENTERLAT -v font=$FONTSTR -v ctype=$CMTTYPE '{
          if (ctype=="ORIGIN") { lon=$8; lat=$9 } else { lon=$5; lat=$6; }
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
          print $0, font, vpos hpos
        }' > cmtlabel_pos.sel

        case $CMTTYPE in
          ORIGIN)
            [[ $EQ_LABELFORMAT == "idmag" ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $8, $9, $(NF-1), 0, $(NF), $2, $13 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "datemag" ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $8, $9, $(NF-1), 0, $(NF), tmp[1], $13 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "dateid" ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $8, $9, $(NF-1), 0, $(NF), tmp[1], $2 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "id" ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $8, $9, $(NF-1), 0, $(NF), $2   }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "date" ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n",  $8, $9, $(NF-1), 0, $(NF), tmp[1] }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "mag" ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n",  $8, $9, $(NF-1), 0, $(NF), $13  }' >> cmt.labels
            ;;
          CENTROID)
            [[ $EQ_LABELFORMAT == "idmag"   ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $5, $6, $(NF-1), 0, $(NF), $2, $13 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "datemag" ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $5, $6, $(NF-1), 0, $(NF), tmp[1], $13 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "dateid"   ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $5, $6, $(NF-1), 0, $(NF), tmp[1], $2 }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "id"   ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $5, $6, $(NF-1), 0, $(NF), $2   }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "date"   ]] && awk < cmtlabel_pos.sel '{ split($3,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n",  $5, $6, $(NF-1), 0, $(NF), tmp[1] }' >> cmt.labels
            [[ $EQ_LABELFORMAT == "mag"   ]] && awk < cmtlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n",  $5, $6, $(NF-1), 0, $(NF), $13  }' >> cmt.labels
            ;;
        esac
        uniq -u cmt.labels | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite -F+f+a+j -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      if [[ -e eqs.txt ]]; then
        if [[ $labeleqlistflag -eq 1 && ${#eqlistarray[@]} -ge 1 ]]; then
          for i in ${!eqlistarray[@]}; do
            grep -- "${eqlistarray[$i]}" eqs.txt >> eqlabel.sel
          done
        fi
        if [[ $labeleqmagflag -eq 1 ]]; then
          awk < eqs.txt -v minmag=$labeleqminmag '($4>=minmag) {print}'  >> eqlabel.sel
        fi

        awk < eqlabel.sel -v clon=$CENTERLON -v clat=$CENTERLAT -v font=$FONTSTR '{
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
          print $0, font, vpos hpos
        }' > eqlabel_pos.sel

        [[ $EQ_LABELFORMAT == "idmag"   ]] && awk < eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, $6, $4  }' >> eq.labels
        [[ $EQ_LABELFORMAT == "datemag" ]] && awk < eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%0.1f)\n", $1, $2, $8, 0, $9, tmp[1], $4 }' >> eq.labels
        [[ $EQ_LABELFORMAT == "dateid"   ]] && awk < eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s(%s)\n", $1, $2, $8, 0, $9, tmp[1], $6 }' >> eq.labels
        [[ $EQ_LABELFORMAT == "id"   ]] && awk < eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, $6  }' >> eq.labels
        [[ $EQ_LABELFORMAT == "date"   ]] && awk < eqlabel_pos.sel '{ split($5,tmp,"T"); printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $8, 0, $9, tmp[1] }' >> eq.labels
        [[ $EQ_LABELFORMAT == "mag"   ]] && awk < eqlabel_pos.sel '{ printf "%s\t%s\t%s\t%s\t%s\t%0.1f\n", $1, $2, $8, 0, $9, $4  }' >> eq.labels
        uniq -u eq.labels | gmt pstext -Dj${EQ_LABEL_DISTX}/${EQ_LABEL_DISTY}+v0.7p,black -Gwhite  -F+f+a+j -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi
      ;;

    execute)
      info_msg "Executing script $EXECUTEFILE. Careful!"
      source $EXECUTEFILE
      ;;

    extragps)
      info_msg "Plotting extra GPS dataset $EXTRAGPS"
      gmt psvelo $EXTRAGPS -W${EXTRAGPS_LINEWIDTH},${EXTRAGPS_LINECOLOR} -G${EXTRAGPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
      # Generate XY data for reference
      awk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' $EXTRAGPS > extragps.xy
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
          cat $GPS_FILE | awk '{print $2, $1}' > eulergrid.txt   # lon lat -> lat lon
          cat $GPS_FILE > gps.obs
        fi
        if [[ $tdefnodeflag -eq 1 ]]; then    # If the GPS data are from a TDEFNODE model
          awk '{ if ($5==1 && $6==1) print $8, $9, $12, $17, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.obs   # lon lat order
          awk '{ if ($5==1 && $6==1) print $9, $8 }' ${TDPATH}${TDMODEL}.vsum > eulergrid.txt  # lat lon order
          cat ${TDMODEL}.obs > gps.obs
        fi
      else
        cp gridswap.txt eulergrid.txt  # lat lon order
      fi

      if [[ $eulervecflag -eq 1 ]]; then   # If we specified our own Euler Pole on the command line
        awk -f $EULERVEC_AWK -v eLat_d1=$eulerlat -v eLon_d1=$eulerlon -v eV1=$euleromega -v eLat_d2=0 -v eLon_d2=0 -v eV2=0 eulergrid.txt > gridvelocities.txt
      fi
      if [[ $twoeulerflag -eq 1 ]]; then   # If we specified two plates (moving plate vs ref plate) via command line
        lat1=`grep "^$eulerplate1\s" < polesextract.txt | awk '{print $2}'`
      	lon1=`grep "^$eulerplate1\s" < polesextract.txt | awk '{print $3}'`
      	rate1=`grep "^$eulerplate1\s" < polesextract.txt | awk '{print $4}'`

        lat2=`grep "^$eulerplate2\s" < polesextract.txt | awk '{print $2}'`
      	lon2=`grep "^$eulerplate2\s" < polesextract.txt | awk '{print $3}'`
      	rate2=`grep "^$eulerplate2\s" < polesextract.txt | awk '{print $4}'`
        [[ $narrateflag -eq 1 ]] && echo Plotting velocities of $eulerplate1 [ $lat1 $lon1 $rate1 ] relative to $eulerplate2 [ $lat2 $lon2 $rate2 ]
        # Should add some sanity checks here?
        awk -f $EULERVEC_AWK -v eLat_d1=$lat1 -v eLon_d1=$lon1 -v eV1=$rate1 -v eLat_d2=$lat2 -v eLon_d2=$lon2 -v eV2=$rate2 eulergrid.txt > gridvelocities.txt
      fi

      # gridvelocities.txt needs to be multiplied by 100 to return mm/yr which is what GPS files are in

      # If we are plotting only the residuals of GPS velocities vs. estimated site velocity from Euler pole (gridvelocities.txt)
      if [[ $ploteulerobsresflag -eq 1 ]]; then
         info_msg "plotting residuals of block motion and gps velocities"
         paste gps.obs gridvelocities.txt | awk '{print $1, $2, $10-$3, $11-$4, 0, 0, 1, $8 }' > gpsblockres.txt   # lon lat order, mm/yr
         # Scale at print is OK
         awk -v gpsscalefac=$(echo "$VELSCALE * $WRESSCALE" | bc -l) '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' gpsblockres.txt > grideulerres.pvec
         gmt psxy -SV$ARROWFMT -W0p,green -Ggreen grideulerres.pvec $RJOK $VERBOSE >> map.ps  # Plot the residuals
      fi

      paste -d ' ' eulergrid.txt gridvelocities.txt | awk '{print $2, $1, $3, $4, 0, 0, 1, "ID"}' > gridplatevecs.txt
      # Scale at print is OK
      cat gridplatevecs.txt | awk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }'  > grideuler.pvec
      gmt psxy -SV$ARROWFMT -W0p,red -Gred grideuler.pvec $RJOK $VERBOSE >> map.ps
      ;;

    gcdm)
      gmt grdimage $GCDMDATA -C$GCDM_CPT $RJOK $VERBOSE >> map.ps
      ;;

    gebcotid)
      gmt makecpt -Ccategorical -T1/100/1 > gebco_tid.cpt
      gmt grdimage $GEBCO20_TID -t50 -Cgebco_tid.cpt $RJOK $VERBOSE >> map.ps

      ;;
    gemfaults)
      info_msg "Plotting GEM active faults"
      gmt psxy $GEMFAULTS -W$AFLINEWIDTH,$AFLINECOLOR $RJOK $VERBOSE >> map.ps
      ;;

    gisline)
      info_msg "Plotting GIS line data $GISLINEFILE"
      gmt psxy $GISLINEFILE -W$GISLINEWIDTH,$GISLINECOLOR $RJOK $VERBOSE >> map.ps
      ;;

    gps)
      info_msg "Plotting GPS"
		  ##### Plot GPS velocities if possible (requires Kreemer plate to have same ID as model reference plate, or manual specification)
      if [[ $tdefnodeflag -eq 0 ]]; then
  			if [[ -e $GPS_FILE ]]; then
  				info_msg "GPS data is taken from $GPS_FILE and are plotted relative to plate $REFPLATE in that model"

          awk < $GPS_FILE -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
            if ($1>180) { lon=$1-360 } else { lon=$1 }
            if (lon >= minlon && lon <= maxlon && $2 >= minlat && $2 <= maxlat) {
              print
            }
          }' > gps.txt
  				gmt psvelo gps.txt -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
          # generate XY data
          awk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' < gps.txt > gps.xy
          GPSMAXVEL=$(awk < gps.xy 'BEGIN{ maxv=0 } {if ($4>maxv) { maxv=$4 } } END {print maxv}')
    		else
  				info_msg "No relevant GPS data available for given plate model"
  				GPS_FILE="None"
  			fi
      fi
			;;

    grav)
      gmt grdimage $GRAVDATA -C$GRAV_CPT -t$GRAVTRANS $RJOK $VERBOSE >> map.ps
      ;;

    grid)
      # Plot the gridded plate velocity field
      # Requires *_platevecs.txt to plot velocity field
      # Input data are in mm/yr
      info_msg "Plotting grid arrows"

      LONDIFF=$(echo "$MAXLON - $MINLON" | bc -l)
      pwnum=$(echo "5p" | awk '{print $1+0}')
      POFFS=$(echo "$LONDIFF/8*1/72*$pwnum*3/2" | bc -l)
      GRIDMAXVEL=0

      if [[ $plotplates -eq 1 ]]; then
        for i in *_platevecs.txt; do
          # Use azimuth/velocity data in platevecs.txt to infer VN/VE
          awk < $i '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' > ${i}.pvec
          GRIDMAXVEL=$(awk < ${i}.pvec -v prevmax=$GRIDMAXVEL 'BEGIN {max=prevmax} {if ($4 > max) {max=$4} } END {print max}' )
          gmt psvelo ${i} -W0p,$PLATEVEC_COLOR@$PLATEVEC_TRANS -G$PLATEVEC_COLOR@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> map.ps 2>/dev/null
          [[ $PLATEVEC_TEXT_PLOT -eq 1 ]] && awk < ${i}.pvec -v poff=$POFFS '($4 != 0) { print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, sprintf("%d", $4) }' | gmt pstext -F+f${PLATEVEC_TEXT_SIZE},${PLATEVEC_TEXT_FONT},${PLATEVEC_TEXT_COLOR}+jCM $RJOK $VERBOSE  >> map.ps
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
      info_msg "gmt grdimage $IMAGENAME ${IMAGEARGS} $RJOK ${VERBOSE} >> map.ps"
      gmt grdimage "$IMAGENAME" "${IMAGEARGS}" $RJOK $VERBOSE >> map.ps
      ;;

    kinsv)
      # Plot the slip vectors for focal mechanism nodal planes
      info_msg "Plotting kinematic slip vectors"

      if [[ kinthrustflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.4p,${NP1_COLOR} -G${NP1_COLOR} thrust_gen_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.4p,${NP2_COLOR} -G${NP2_COLOR} thrust_gen_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      if [[ kinnormalflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.7p,green -Ggreen normal_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.5p,green -Ggreen normal_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      if [[ kinssflag -eq 1 ]]; then
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.7p,blue -Gblue strikeslip_slip_vectors_np1.txt $RJOK $VERBOSE >> map.ps
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb+e -W0.5p,blue -Gblue strikeslip_slip_vectors_np2.txt $RJOK $VERBOSE >> map.ps
      fi
      ;;

    kingeo)
      info_msg "Plotting kinematic data"
      # Currently only plotting strikes and dips of thrust mechanisms
      if [[ kinthrustflag -eq 1 ]]; then
        # Plot dip line of NP1
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite thrust_gen_slip_vectors_np1_downdip.txt $RJOK $VERBOSE >> map.ps
        # Plot strike line of NP1
        [[ np1flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,white -Gwhite thrust_gen_slip_vectors_np1_str.txt $RJOK $VERBOSE >> map.ps
        # Plot dip line of NP2
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray thrust_gen_slip_vectors_np2_downdip.txt $RJOK $VERBOSE >> map.ps
        # Plot strike line of NP2
        [[ np2flag -eq 1 ]] && gmt psxy -SV0.05i+jb -W0.5p,gray -Ggray thrust_gen_slip_vectors_np2_str.txt $RJOK $VERBOSE >> map.ps
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
          access_litho -p $lat $lon -d $LITHO1_DEPTH  -l ${LITHO1_LEVEL} 2>/dev/null | awk -v lat=$lat -v lon=$lon -v extfield=$LITHO1_FIELDNUM '{
            print lon, lat, $(extfield)
          }' >> litho1_${LITHO1_DEPTH}.xyz
        done
      done
      gmt_init_tmpdir
      gmt xyz2grd litho1_${LITHO1_DEPTH}.xyz -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -fg -I${deginc}d -Glitho1_${LITHO1_DEPTH}.nc $VERBOSE
      gmt_remove_tmpdir
      gmt grdimage litho1_${LITHO1_DEPTH}.nc -C${LITHO1_CPT} $RJOK $VERBOSE >> map.ps
      ;;

    mag)
      info_msg "Plotting magnetic data"
      gmt grdimage $EMAG_V2 -C$MAG_CPT -t$MAGTRANS $RJOK -Q $VERBOSE >> map.ps
      ;;

    mapscale)
      # The values of SCALECMD will be set by the scale) section
      SCALECMD="-Lg${SCALEREFLON}/${SCALEREFLAT}+c${SCALELENLAT}+w${SCALELEN}+l+at+f"
      ;;

    mprof)

    if [[ $sprofflag -eq 1 ]]; then
      info_msg "Updating mprof to use a newly generated sprof.control file"
      PROFILE_WIDTH_IN="7i"
      PROFILE_HEIGHT_IN="2i"
      PROFILE_X="0"
      PROFILE_Y="-3i"
      MPROFFILE="sprof.control"

      echo "@ auto auto ${SPROF_MINELEV} ${SPROF_MAXELEV} " > sprof.control
      if [[ $plotcustomtopo -eq 1 ]]; then
        info_msg "Adding custom topo grid to sprof"
        echo "S $CUSTOMGRIDFILE 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES}" >> sprof.control
      elif [[ -e $BATHY ]]; then
        info_msg "Adding topography/bathymetry from map to sprof as swath and top tile"
        echo "S dem.nc 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES}" >> sprof.control
        echo "G dem.nc 0.001 ${SPROF_RES} ${SPROFWIDTH} ${SPROF_RES} topo.cpt" >> sprof.control
      fi
      if [[ -e eqs.txt ]]; then
        info_msg "Adding eqs to sprof"
        echo "E eqs.txt ${SPROFWIDTH} -1 -W0.2p,black -C$SEISDEPTH_CPT" >> sprof.control
      fi
      if [[ -e cmt.dat ]]; then
        info_msg "Adding cmt to sprof"
        echo "C cmt.dat ${SPROFWIDTH} -1 -L0.25p,black -Z$SEISDEPTH_CPT" >> sprof.control
      fi
      if [[ $volcanoesflag -eq 1 ]]; then
        # We need to sample the DEM at the volcano point locations, or else use 0 for elevation.
        info_msg "Adding volcanoes to sprof"
        echo "X volcanoes.dat ${SPROFWIDTH} 0.001 -St0.1i -W0.1p,black -Gred" >> sprof.control
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
      echo "P P1 black N N ${SPROFLON1} ${SPROFLAT1} ${SPROFLON2} ${SPROFLAT2}" >> sprof.control
    fi

      info_msg "Drawing profile(s)"

      PSFILE=$(echo "$(cd "$(dirname "map.ps")"; pwd)/$(basename "map.ps")")

      cp gmt.history gmt.history.preprofile
      . $MPROFILE_SH_SRC
      cp gmt.history.preprofile gmt.history

      # Plot the profile lines with the assigned color on the map
      # echo TRACKFILE=...$TRACKFILE

      k=$(wc -l < $TRACKFILE | awk '{print $1}')
      for ind in $(seq 1 $k); do
        FIRSTWORD=$(head -n ${ind} $TRACKFILE | tail -n 1 | awk '{print $1}')
        # echo FIRSTWORD all=${FIRSTWORD}
        # if [[ ${FIRSTWORD:0:1} != "#" && ${FIRSTWORD:0:1} != "$" && ${FIRSTWORD:0:1} != "%" && ${FIRSTWORD:0:1} != "^" && ${FIRSTWORD:0:1} != "@"  && ${FIRSTWORD:0:1} != ":"  && ${FIRSTWORD:0:1} != ">" ]]; then

        if [[ ${FIRSTWORD:0:1} == "P" ]]; then
          # echo FIRSTWORD=${FIRSTWORD}
          COLOR=$(head -n ${ind} $TRACKFILE | tail -n 1 | awk '{print $3}')
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
      #    echo $track_file
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

      if [[ -e end_points.txt ]]; then
        while read d; do
          p=($(echo $d))
          # echo END POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} - 90" | bc -l)
          SUBWIDTH=$(echo "${p[3]} / 110 * 0.1" | bc -l)
          echo ">" >> end_profile_lines.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}k > endpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}k > endpoint2.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' > endpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' > endpoint2.txt
          cat endpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >> end_profile_lines.txt
          cat endpoint1.txt >> end_profile_lines.txt
          echo "${p[0]} ${p[1]}" >> end_profile_lines.txt
          cat endpoint2.txt >> end_profile_lines.txt
          cat endpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >> end_profile_lines.txt
        done < end_points.txt

        while read d; do
          p=($(echo $d))
          # echo START POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} + 90" | bc -l)
          SUBWIDTH=$(echo "${p[3]}/110 * 0.1" | bc -l)
          echo ">" >>  start_profile_lines.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' > startpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' > startpoint2.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}d >  startpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}d >  startpoint2.txt
          cat  startpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  start_profile_lines.txt
          cat  startpoint1.txt >>  start_profile_lines.txt
          echo "${p[0]} ${p[1]}" >>  start_profile_lines.txt
          cat  startpoint2.txt >>  start_profile_lines.txt
          cat  startpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  start_profile_lines.txt
        done <  start_points.txt

        gmt psxy end_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
        gmt psxy start_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      if [[ -e mid_points.txt ]]; then
        while read d; do
          p=($(echo $d))
          # echo MID POINT ${p[0]}/${p[1]} azimuth ${p[2]} width ${p[3]} color ${p[4]}
          ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
          FOREAZ=$(echo "${p[2]} + 90" | bc -l)
          FOREAZ2=$(echo "${p[2]} - 90" | bc -l)
          SUBWIDTH=$(echo "${p[3]}/110 * 0.1" | bc -l)
          echo ">" >>  mid_profile_lines.txt
          gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' >  midpoint1.txt
          gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${p[3]}k -L0/${p[3]} | tail -n 1 | awk '{print $1, $2}' > midpoint2.txt

          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${p[2]}/${p[3]}d >  midpoint1.txt
          # echo "${p[0]} ${p[1]}" | gmt vector -Tt${ANTIAZ}/${p[3]}d >  midpoint2.txt

          cat  midpoint1.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  mid_profile_lines.txt
          cat  midpoint1.txt | gmt vector -Tt${FOREAZ2}/${SUBWIDTH}d >>  mid_profile_lines.txt
          cat  midpoint1.txt >>  mid_profile_lines.txt
          echo "${p[0]} ${p[1]}" >>  mid_profile_lines.txt
          cat  midpoint2.txt >>  mid_profile_lines.txt
          cat  midpoint2.txt | gmt vector -Tt${FOREAZ}/${SUBWIDTH}d >>  mid_profile_lines.txt
          cat  midpoint2.txt | gmt vector -Tt${FOREAZ2}/${SUBWIDTH}d >>  mid_profile_lines.txt
        done <  mid_points.txt

        gmt psxy mid_profile_lines.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
      fi

      # Plot the intersection point of the profile with the 0-distance datum line as triangle
      if [[ -e all_intersect.txt ]]; then
        info_msg "Plotting intersection of tracks with zeroline"
        gmt psxy xy_intersect.txt -W0.5p,black $RJOK $VERBOSE >> map.ps
        gmt psxy all_intersect.txt -St0.1i -Gwhite -W0.7p,black $RJOK $VERBOSE >> map.ps
      fi

      # This is used to offset the profile name so it doesn't overlap the track line
      PTEXT_OFFSET=$(echo ${PROFILE_TRACK_WIDTH} | awk '{ print ($1+0)*2 "p" }')

      while read d; do
        p=($(echo $d))
        # echo "${p[0]},${p[1]},${p[5]}  angle ${p[2]}"
        echo "${p[0]},${p[1]},${p[5]}" | gmt pstext -A -Dj${PTEXT_OFFSET} -F+f${PROFILE_FONT_LABEL_SIZE},Helvetica+jRB+a$(echo "${p[2]}-90" | bc -l) $RJOK $VERBOSE >> map.ps
      done < start_points.txt

      ;;

    oceanage)
      gmt grdimage $OC_AGE -C$OC_AGE_CPT -Q -t$OC_TRANS $RJOK $VERBOSE >> map.ps
      ;;
    plateazdiff)
      info_msg "Drawing plate azimuth differences"

      # This should probably be changed to obliquity
      # Plot the azimuth of relative plate motion across the boundary
      # azdiffpts_len.txt should be replaced with id_pts_euler.txt
      [[ $plotplates -eq 1 ]] && awk < azdiffpts_len.txt -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '{
        if ($1 != minlon && $1 != maxlon && $2 != minlat && $2 != maxlat) {
          print $1, $2, $3
        }
      }' | gmt psxy -C$CPTDIR"cycleaz.cpt" -t0 -Sc${AZDIFFSCALE}/0 $RJOK $VERBOSE >> map.ps

      mkdir az_histogram
      cd az_histogram
        awk < ../azdiffpts_len.txt '{print $3, $4}' | gmt pshistogram -C$CPTDIR"cycleaz.cpt" -JX5i/2i -R-180/180/0/1 -Z0+w -T2 -W0.1p -I -Ve > azdiff_hist_range.txt
        ADR4=$(awk < azdiff_hist_range.txt '{print $4*1.1}')
        awk < ../azdiffpts_len.txt '{print $3, $4}' | gmt pshistogram -C$CPTDIR"cycleaz.cpt" -JX5i/2i -R-180/180/0/$ADR4 -BNESW+t"$POLESRC $MINLON/$MAXLON/$MINLAT/$MAXLAT" -Bxa30f10 -Byaf -Z0+w -T2 -W0.1p > ../az_histogram.ps
      cd ..
      gmt psconvert -Tf -A0.3i az_histogram.ps
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

        awk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
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
          }' < paz1normal.txt > paz1normal_cutoff.txt

        awk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
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
          }' < paz1thrust.txt > paz1thrust_cutoff.txt

          awk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
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
            }' < paz1ss1.txt > paz1ss1_cutoff.txt

            awk -v cutoff=$PDIFFCUTOFF 'BEGIN {dist=0;lastx=9999;lasty=9999} {
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
              }' < paz1ss2.txt > paz1ss2_cutoff.txt

        # If the scale is too small, normal opening will appear to be thrusting due to arrowhead offset...!
        # Set a minimum scale for vectors to avoid improper plotting of arrowheads

        LONDIFF=$(echo "$MAXLON - $MINLON" | bc -l)
        pwnum=$(echo $PLATELINE_WIDTH | awk '{print $1+0}')
        POFFS=$(echo "$LONDIFF/8*1/72*$pwnum*3/2" | bc -l)

        # Old formatting works but isn't exactly great

        # We plot the half-velocities across the plate boundaries instead of full relative velocity for each plate

        awk < paz1normal_cutoff.txt -v poff=$POFFS -v minv=$MINVV -v gpsscalefac=$VELSCALE '{ if ($4<minv && $4 != 0) {print $1 + sin($3*3.14159265358979/180)*poff, $2 + cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2} else {print $1 + sin($3*3.14159265358979/180)*poff, $2 + cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2}}' | gmt psxy -SV"${PVFORMAT}" -W0p,$PLATEARROW_COLOR@$PLATEARROW_TRANS -G$PLATEARROW_COLOR@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
        awk < paz1thrust_cutoff.txt -v poff=$POFFS -v minv=$MINVV -v gpsscalefac=$VELSCALE '{ if ($4<minv && $4 != 0) {print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2} else {print $1 - sin($3*3.14159265358979/180)*poff, $2 - cos($3*3.14159265358979/180)*poff, $3, $4*gpsscalefac/2}}' | gmt psxy -SVh"${PVFORMAT}" -W0p,$PLATEARROW_COLOR@$PLATEARROW_TRANS -G$PLATEARROW_COLOR@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps

        # Shift symbols based on azimuth of line segment to make nice strike-slip half symbols
        awk < paz1ss1_cutoff.txt -v poff=$POFFS -v gpsscalefac=$VELSCALE '{ if ($4!=0) { print $1 + cos($3*3.14159265358979/180)*poff, $2 - sin($3*3.14159265358979/180)*poff, $3, 0.1/2}}' | gmt psxy -SV"${PVHEAD}"+r+jb+m+a33+h0 -W0p,red@$PLATEARROW_TRANS -Gred@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
        awk < paz1ss2_cutoff.txt -v poff=$POFFS -v gpsscalefac=$VELSCALE '{ if ($4!=0) { print $1 - cos($3*3.14159265358979/180)*poff, $2 - sin($3*3.14159265358979/180)*poff, $3, 0.1/2 }}' | gmt psxy -SV"${PVHEAD}"+l+jb+m+a33+h0 -W0p,yellow@$PLATEARROW_TRANS -Gyellow@$PLATEARROW_TRANS $RJOK $VERBOSE >> map.ps
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
      [[ $plotplates -eq 1 ]] && awk < map_labels.txt -F, '{print $1, $2, substr($3, 1, length($3)-2)}' | gmt pstext -C0.1+t -F+f$PLATELABEL_SIZE,Helvetica,$PLATELABEL_COLOR+jCB $RJOK $VERBOSE  >> map.ps
      ;;

    platerelvel)
      gmt makecpt -T0/100/1 -C$CPTDIR"platevel_one.cpt" -Z ${VERBOSE} > $PLATEVEL_CPT
      cat paz1*.txt > all.txt
      gmt psxy all.txt -Sc0.1i -C$PLATEVEL_CPT -i0,1,3 $RJOK >> map.ps

      # gmt psxy paz1ss2.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      # gmt psxy paz1normal.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      # gmt psxy paz1thrust.txt -Sc0.1i -Cpv.cpt -i0,1,3 $RJOK >> map.ps
      ;;

    platerotation)
      info_msg "Plotting small circle rotations"

      # Plot small circles and little arrows for plate rotations
      for i in *_smallcirc_platevecs.txt; do
        cat $i | awk -v scalefac=0.01 '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, scalefac; else print $1, $2, az+360, scalefac; }'  > ${i}.pvec
        gmt psxy -SV0.0/0.12/0.06 -: -W0p,$PLATEVEC_COLOR@70 -G$PLATEVEC_COLOR@70 ${i}.pvec -t70 $RJOK $VERBOSE >> map.ps
      done
      for i in *smallcircles_clip; do
       info_msg "Plotting small circle file ${i}"
       cat ${i} | gmt psxy -W1p,${PLATEVEC_COLOR}@50 -t70 $RJOK $VERBOSE >> map.ps
      done
      ;;

    platevelgrid)
      # Probably should move the calculation to the calculation zone of the script
      # Plot a colored plate velocity grid
      info_msg "Calculating plate velocity grids"
      mkdir pvdir
      MAXV_I=0
      MINV_I=99999

      for i in *.pole; do
        LEAD=${i%.pole*}
        info_msg "Calculating $LEAD velocity raster"
        awk < $i '{print $2, $1}' > pvdir/pole.xy
        POLERATE=$(awk < $i '{print $3}')
        cd pvdir
        cat "../$LEAD.pldat" | sed '1d' > plate.xy
        # # Determine the extent of the polygon within the map extent
        pl_max_x=$(grep "^[-*0-9]" plate.xy | sort -n -k 1 | tail -n 1 | awk -v mx=$MAXLON '{print ($1>mx)?mx:$1}')
        pl_min_x=$(grep "^[-*0-9]" plate.xy | sort -n -k 1 | head -n 1 | awk -v mx=$MINLON '{print ($1<mx)?mx:$1}')
        pl_max_y=$(grep "^[-*0-9]" plate.xy | sort -n -k 2 | tail -n 1 | awk -v mx=$MAXLAT '{print ($2>mx)?mx:$2}')
        pl_min_y=$(grep "^[-*0-9]" plate.xy | sort -n -k 2 | head -n 1 | awk -v mx=$MINLAT '{print ($2<mx)?mx:$2}')
        info_msg "Polygon region $pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y"
        # this approach requires a final GMT grdblend command
        # echo platevelres=$PLATEVELRES
        gmt grdmath ${VERBOSE} -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y -fg -I$PLATEVELRES pole.xy PDIST 6378.13696669 DIV SIN $POLERATE MUL 6378.13696669 MUL .01745329251944444444 MUL = "$LEAD"_velraster.nc
        gmt grdmask plate.xy ${VERBOSE} -R"$LEAD"_velraster.nc -fg -NNaN/1/1 -Gmask.nc
        info_msg "Calculating $LEAD masked raster"
        gmt grdmath -fg ${VERBOSE} "$LEAD"_velraster.nc mask.nc MUL = "$LEAD"_masked.nc
        zrange=$(grid_zrange ${LEAD}_velraster.nc -C -Vn)
        MINZ=$(echo $zrange | awk '{print $1}')
        MAXZ=$(echo $zrange | awk '{print $2}')
        MAXV_I=$(echo $MAXZ | awk -v max=$MAXV_I '{ if ($1 > max) { print $1 } else { print max } }')
        MINV_I=$(echo $MINZ | awk -v min=$MINV_I '{ if ($1 < min) { print $1 } else { print min } }')
        # unverified code above...
        # MAXV_I=$(gmt grdinfo ${LEAD}_velraster.nc 2>/dev/null | grep "z_max" | awk -v max=$MAXV_I '{ if ($5 > max) { print $5 } else { print max } }')
        # MINV_I=$(gmt grdinfo ${LEAD}_velraster.nc 2>/dev/null | grep "z_max" | awk -v min=$MINV_I '{ if ($3 < min) { print $3 } else { print min } }')
        # # gmt grdedit -fg -A -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y "$LEAD"_masked.nc -G"$LEAD"_masked_edit.nc
        # echo "${LEAD}_masked_edit.nc -R$pl_min_x/$pl_max_x/$pl_min_y/$pl_max_y 1" >> grdblend.cmd
        cd ../
      done
      info_msg "Merging velocity rasters"

      PVRESNUM=$(echo "" | awk -v v=$PLATEVELRES 'END {print v+0}')
      info_msg "gdal_merge.py -o plate_velocities.nc -of NetCDF -ps $PVRESNUM $PVRESNUM -ul_lr $MINLON $MAXLAT $MAXLON $MINLAT *_masked.nc"
      cd pvdir
        gdal_merge.py -o plate_velocities.nc -q -of NetCDF -ps $PVRESNUM $PVRESNUM -ul_lr $MINLON $MAXLAT $MAXLON $MINLAT *_masked.nc
      cd ..
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
        echo MINV_I MAXV_I $MINV_I $MAXV_I
        MINV=$(echo $MINV_I | awk '{ print int($1/10)*10 }')
        MAXV=$(echo $MAXV_I | awk '{ print int($1/10)*10 +10 }')
        echo MINV MAXV $MINV $MAXV

        gmt makecpt -C$CPTDIR"platevel_one.cpt" -T0/$MAXV -Z > $PLATEVEL_CPT

      else
        gmt makecpt -T0/100/1 -C$CPTDIR"platevel_one.cpt" -Z ${VERBOSE} > $PLATEVEL_CPT
      fi

      # cd ..
      info_msg "Plotting velocity raster."
      gmt grdimage -C$PLATEVEL_CPT ./pvdir/plate_velocities.nc $RJOK $VERBOSE >> map.ps
      info_msg "Plotted velocity raster."
      ;;

    points)
      info_msg "Plotting point dataset $current_plotpointnumber"
      if [[ ${pointdatacptflag[$current_plotpointnumber]} -eq 1 ]]; then
        gmt psxy ${POINTDATAFILE[$current_plotpointnumber]} -W$POINTLINEWIDTH,$POINTLINECOLOR -C${POINTDATACPT[$current_plotpointnumber]} -G+z -S${POINTSYMBOL_arr[$current_plotpointnumber]}${POINTSIZE_arr[$current_plotpointnumber]} $RJOK $VERBOSE >> map.ps
      else
        gmt psxy ${POINTDATAFILE[$current_plotpointnumber]} -G$POINTCOLOR -W$POINTLINEWIDTH,$POINTLINECOLOR -S${POINTSYMBOL_arr[$current_plotpointnumber]}${POINTSIZE_arr[$current_plotpointnumber]} $RJOK $VERBOSE >> map.ps
      fi
      current_plotpointnumber=$(echo "$current_plotpointnumber + 1" | bc -l)
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
      info_msg "Plotting seismicity; should include options for CPT/fill color"
      OLD_PROJ_LENGTH_UNIT=$(gmt gmtget PROJ_LENGTH_UNIT -Vn)
      gmt gmtset PROJ_LENGTH_UNIT p
      if [[ $SCALEEQS -eq 1 ]]; then
        # the -Cwhite option here is so that we can pass the removed EQs in the same file format as the non-scaled events
        [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && gmt psxy removed_eqs_scaled.txt -Cwhite -W${EQLINEWIDTH},${EQLINECOLOR} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
        gmt psxy eqs_scaled.txt -C$SEISDEPTH_CPT -i0,1,2,3+s${SEISSCALE} -W${EQLINEWIDTH},${EQLINECOLOR} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
      else
        [[ $REMOVE_DEFAULTDEPTHS_WITHPLOT -eq 1 ]] && gmt psxy removed_eqs.txt -Gwhite -W${EQLINEWIDTH},${EQLINECOLOR} -i0,1,2,3+s${SEISSCALE} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
        gmt psxy eqs.txt -C$SEISDEPTH_CPT -i0,1,2 -W${EQLINEWIDTH},${EQLINECOLOR} -S${SEISSYMBOL}${SEISSIZE} -t${SEISTRANS} $RJOK $VERBOSE >> map.ps
      fi
      gmt gmtset PROJ_LENGTH_UNIT $OLD_PROJ_LENGTH_UNIT

			;;

    # seisrake1)
    #   info_msg "Plotting rake of N1 nodal planes"
    #   # Plot the rake of the N1 nodal plane
    #   # lonc latc depth str1 dip1 rake1 str2 dip2 rake2 M lon lat ID
    #   awk < $CMTFILE '($6 > 45 && $6 < 135) { print $1, $2, $4-($6-180) }' | awk '{ if ($3 > 180) { print $1, $2, $3-360;} else {print $1,$2,$3} }' > eqaz1.txt
    #   gmt psxy -C$CPTDIR"cycleaz.cpt" -St${RAKE1SCALE}/0 eqaz1.txt $RJOK $VERBOSE >> map.ps
    #   ;;
    #
    # seisrake2)
    #   ;;

    slab2)

      if [[ ${SLAB2STR} =~ .*g.* ]]; then
        info_msg "Plotting SLAB2 grids"
        SLAB2_CONTOUR_BLACK=1
        for i in $(seq 1 $numslab2inregion); do
          gridfile=$(echo ${SLAB2_GRIDDIR}${slab2inregion[$i]}.grd | sed 's/clp/dep/')
          gmt grdmath ${VERBOSE} $gridfile -1 MUL = tmpgrd.grd
          gmt grdimage tmpgrd.grd -Q -t${SLAB2GRID_TRANS} -C$SEISDEPTH_CPT $RJOK $VERBOSE >> map.ps
          #COMEBACK
        done
      else
        SLAB2_CONTOUR_BLACK=0
      fi
      rm -f tmpgrd.grd

			if [[ ${SLAB2STR} =~ .*c.* ]]; then
				info_msg "Plotting SLAB2 contours"

        for i in $(seq 1 $numslab2inregion); do
          clipfile=$(echo ${SLAB2_CONTOURDIR}${slab2inregion[$i]}_contours.in | sed 's/clp/dep/')
          awk < $clipfile '{
            if ($1 == ">") {
              print $1, "-Z" 0-$2
            } else {
              print $1, $2, 0 - $3
            }
          }' > contourtmp.dat
          if [[ SLAB2_CONTOUR_BLACK -eq 0 ]]; then
            gmt psxy contourtmp.dat -C$SEISDEPTH_CPT -W0.5p+z $RJOK $VERBOSE >> map.ps
          else
            gmt psxy contourtmp.dat -W0.5p,black+z $RJOK $VERBOSE >> map.ps
          fi
        done
        rm -f contourtmp.dat
			fi
			;;

    slipvecs)
      info_msg "Slip vectors"
      # Plot a file containing slip vector azimuths
      awk < ${SVDATAFILE} '($1 != "end") {print $1, $2, $3, 0.2}' | gmt psxy -SV0.05i+jc -W1.5p,red $RJOK $VERBOSE >> map.ps
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
				eval "grep -H 'Loc  :' *" | awk -F: '{print $1, $3 }' | awk '{print $7 "	" $4 "	" $1}' > $SRCMODFSPLOCATIONS
				cd $comeback
			fi

			info_msg "Identifying SRCMOD results falling within the AOI"
			awk < $SRCMODFSPLOCATIONS -v minlat="$MINLAT" -v maxlat="$MAXLAT" -v minlon="$MINLON" -v maxlon="$MAXLON" '($1 < maxlon-1 && $1 > minlon+1 && $2 < maxlat-1 && $2 > minlat+1) {print $3}' > srcmod_eqs.txt
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
				grep "^[^%;]" "$SRCMODFSPFOLDER"${v[$i]} | awk '{print $2, $1, $6}' > temp1.xyz
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
			TDMODEL=$(echo $TDPATH | xargs -n 1 basename | awk -F. '{print $1}')
			info_msg "$TDMODEL"

      if [[ ${TDSTRING} =~ .*a.* ]]; then
        # BLOCK LABELS
        info_msg "TDEFNODE block labels"
        awk < ${TDPATH}${TDMODEL}_blocks.out '{ print $2,$3,$1 }' | gmt pstext -F+f8,Helvetica,orange+jBL $RJOK $VERBOSE >> map.ps
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
        numfaults=$(awk 'BEGIN {min=0} { if ($1 == ">" && $3 > min) { min = $3} } END { print min }' ${TDPATH}${TDMODEL}_flt_atr.gmt)
        gmt makecpt -Ccategorical -T0/$numfaults/1 $VERBOSE > faultblock.cpt
        awk '{ if ($1 ==">") printf "%s %s%f\n",$1,$2,$3; else print $1,$2 }' ${TDPATH}${TDMODEL}_flt_atr.gmt | gmt psxy -L -Cfaultblock.cpt $RJOK $VERBOSE >> map.ps
        gmt psxy ${TDPATH}${TDMODEL}_blk3.gmt -Wfatter,red,solid $RJOK $VERBOSE >> map.ps
        gmt psxy ${TDPATH}${TDMODEL}_blk3.gmt -Wthickest,black,solid $RJOK $VERBOSE >> map.ps
        #gmt psxy ${TDPATH}${TDMODEL}_blk.gmt -L -R -J -Wthicker,black,solid -O -K $VERBOSE  >> map.ps
        awk '{if ($4==1) print $7, $8, $2}' ${TDPATH}${TDMODEL}.nod | gmt pstext -F+f10p,Helvetica,lightblue $RJOK $VERBOSE >> map.ps
        awk '{print $7, $8}' ${TDPATH}${TDMODEL}.nod | gmt psxy -Sc.02i -Gblack $RJOK $VERBOSE >> map.ps
      fi
			# if [[ ${TDSTRING} =~ .*l.* ]]; then
      #   # Coupling. Not sure this is the best way, but it seems to work...
      #   info_msg "TDEFNODE coupling"
			# 	gmt makecpt -Cseis -Do -I -T0/1/0.01 -N > $SLIPRATE_DEF_CPT
			# 	awk '{ if ($1 ==">") print $1 $2 $5; else print $1, $2 }' ${TDPATH}${TDMODEL}_flt_atr.gmt | gmt psxy -L -C$SLIPRATE_DEF_CPT $RJOK $VERBOSE >> map.ps
			# fi
      if [[ ${TDSTRING} =~ .*l.* || ${TDSTRING} =~ .*c.* ]]; then
        # Plot a dashed line along the contour of coupling = 0
        info_msg "TDEFNODE coupling"
        awk '{
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
          echo $FAULTIDLIST | awk '{
            n=split($0,groups,":");
            for(i=1; i<=n; i++) {
               print groups[i]
            }
          }' | tr ',' ' ' > faultid_groups.txt
        else # Extract all fault IDs as Group 1 if we don't specify faults/groups
          awk < tdsrd_faultids.xyz '{
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
          awk < tdsrd_faultids.xyz -v idstr="$p" 'BEGIN {
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
				awk < ${TDPATH}${TDMODEL}_blk0.gmt '{ if ($1 == ">") print $3,$4, $5 " (" $2 ")" }' | gmt pstext -F+f8,Helvetica,black+jBL $RJOK $VERBOSE >> map.ps

				# PSUEDOFAULTS ############
				gmt psxy ${TDPATH}${TDMODEL}_blk1.gmt -R -J -W1p,green -O -K $VERBOSE >> map.ps 2>/dev/null
				awk < ${TDPATH}${TDMODEL}_blk1.gmt '{ if ($1 == ">") print $3,$4,$5 }' | gmt pstext -F+f8,Helvetica,brown+jBL $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*s.* ]]; then
				# SLIP VECTORS ######
        legendwords+=("slipvectors")
        info_msg "TDEFNODE slip vectors (observed and predicted)"
				awk < ${TDPATH}${TDMODEL}.svs -v size=$SVBIG '(NR > 1) {print $1, $2, $3, size}' > ${TDMODEL}.svobs
				awk < ${TDPATH}${TDMODEL}.svs -v size=$SVSMALL '(NR > 1) {print $1, $2, $5, size}' > ${TDMODEL}.svcalc
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
				echo "" | awk '{ if ($5==1 && $6==1) print $8, $9, $12, $17, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.obs
				gmt psvelo ${TDMODEL}.obs -W${TD_OGPS_LINEWIDTH},${TD_OGPS_LINECOLOR} -G${TD_OGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        # awk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.obs > ${TDMODEL}.xyobs
        # gmt psxy -SV$ARROWFMT -W0.25p,white -Gblack ${TDMODEL}.xyobs $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*v.* ]]; then
				# calculated vectors  UPDATE TO PSVELO
        info_msg "TDEFNODE modeled GPS velocities"
        legendwords+=("TDEFcalcgps")
				awk '{ if ($5==1 && $6==1) print $8, $9, $13, $18, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.vec
        gmt psvelo ${TDMODEL}.vec -W${TD_VGPS_LINEWIDTH},${TD_VGPS_LINECOLOR} -D0 -G${TD_VGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        #  Generate AZ/VEL data
        echo "" | awk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.vec > ${TDMODEL}.xyvec
        # awk '(sqrt($3*$3+$4*$4) <= 5) { print $1, $2 }' ${TDMODEL}.vec > ${TDMODEL}_smallcalc.xyvec
        # gmt psxy -SV$ARROWFMT -W0.25p,black -Gwhite ${TDMODEL}.xyvec $RJOK $VERBOSE >> map.ps
        # gmt psxy -SC$SMALLRES -W0.25p,black -Gwhite ${TDMODEL}_smallcalc.xyvec $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*r.* ]]; then
        legendwords+=("TDEFresidgps")
				#residual vectors UPDATE TO PSVELO
        info_msg "TDEFNODE residual GPS velocities"
				awk '{ if ($5==1 && $6==1) print $8, $9, $14, $19, $15, $20, $27, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.res
        # gmt psvelo ${TDMODEL}.res -W${TD_VGPS_LINEWIDTH},${TD_VGPS_LINECOLOR} -G${TD_VGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        gmt psvelo ${TDMODEL}.obs -W${TD_OGPS_LINEWIDTH},${TD_OGPS_LINECOLOR} -G${TD_OGPS_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        #  Generate AZ/VEL data
        echo "" | awk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.res > ${TDMODEL}.xyres
        # gmt psxy -SV$ARROWFMT -W0.1p,black -Ggreen ${TDMODEL}.xyres $RJOK $VERBOSE >> map.ps
        # awk '(sqrt($3*$3+$4*$4) <= 5) { print $1, $2 }' ${TDMODEL}.res > ${TDMODEL}_smallres.xyvec
        # gmt psxy -SC$SMALLRES -W0.25p,black -Ggreen ${TDMODEL}_smallres.xyvec $RJOK $VERBOSE >> map.ps
			fi

			if [[ ${TDSTRING} =~ .*f.* ]]; then
        # Fault segment midpoint slip rates
        # CONVERT TO PSVELO ONLY
        info_msg "TDEFNODE fault midpoint slip rates - all "
        legendwords+=("TDEFsliprates")
				awk '{ print $1, $2, $3, $4, $5, $6, $7, $8 }' ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvec
        # gmt psvelo ${TDMODEL}.midvec -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        gmt psvelo ${TDMODEL}.midvec -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null

        # Generate AZ/VEL data
        awk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.midvec > ${TDMODEL}.xymidvec

        # Label
        awk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvec > ${TDMODEL}.fsliplabel

		  	gmt pstext -F+f"${SLIP_FONTSIZE}","${SLIP_FONT}","${SLIP_FONTCOLOR}"+jBM $RJOK ${TDMODEL}.fsliplabel $VERBOSE >> map.ps
			fi
      if [[ ${TDSTRING} =~ .*q.* ]]; then
        # Fault segment midpoint slip rates, only plot when the "distance" between the point and the last point is larger than a set value
        # CONVERT TO PSVELO ONLY
        info_msg "TDEFNODE fault midpoint slip rates - near cutoff = ${SLIP_DIST} degrees"
        legendwords+=("TDEFsliprates")

        awk -v cutoff=${SLIP_DIST} 'BEGIN {dist=0;lastx=9999;lasty=9999} {
            newdist = sqrt(($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty));
            if (newdist > cutoff) {
              lastx=$1
              lasty=$2
              print $1, $2, $3, $4, $5, $6, $7, $8
            }
        }' < ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvecsel
        gmt psvelo ${TDMODEL}.midvecsel -W${SLIP_LINEWIDTH},${SLIP_LINECOLOR} -G${SLIP_FILLCOLOR} -Se$VELSCALE/${GPS_ELLIPSE}/0 -A${ARROWFMT} -L $RJOK $VERBOSE >> map.ps 2>/dev/null
        # Generate AZ/VEL data
        awk '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4); else print $1, $2, az+360, sqrt($3*$3+$4*$4); }' ${TDMODEL}.midvecsel > ${TDMODEL}.xymidvecsel
        awk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvecsel > ${TDMODEL}.fsliplabelsel
        gmt pstext -F+f${SLIP_FONTSIZE},${SLIP_FONT},${SLIP_FONTCOLOR}+jCM $RJOK ${TDMODEL}.fsliplabelsel $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*y.* ]]; then
        # Fault segment midpoint slip rates, text on fault only, only plot when the "distance" between the point and the last point is larger than a set value
        info_msg "TDEFNODE fault midpoint slip rates, label only - near cutoff = 2"
        awk -v cutoff=${SLIP_DIST} 'BEGIN {dist=0;lastx=9999;lasty=9999} {
            newdist = sqrt(($1-lastx)*($1-lastx)+($2-lasty)*($2-lasty));
            if (newdist > cutoff) {
              lastx=$1
              lasty=$2
              print $1, $2, $3, $4, $5, $6, $7, $8
            }
        }' < ${TDPATH}${TDMODEL}_mid.vec > ${TDMODEL}.midvecsel
        awk '{ printf "%f %f %.1f\n", $1, $2, sqrt($3*$3+$4*$4) }' ${TDMODEL}.midvecsel > ${TDMODEL}.fsliplabelsel
        gmt pstext -F+f6,Helvetica-Bold,white+jCM $RJOK ${TDMODEL}.fsliplabelsel $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*e.* ]]; then
        # elastic component of velocity CONVERT TO PSVELO
        info_msg "TDEFNODE elastic component of velocity"
        legendwords+=("TDEFelasticvelocity")

        awk '{ if ($5==1 && $6==1) print $8, $9, $28, $29, 0, 0, 1, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.elastic
        awk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.elastic > ${TDMODEL}.xyelastic
        gmt psxy -SV$ARROWFMT -W0.1p,black -Gred ${TDMODEL}.xyelastic  $RJOK $VERBOSE >> map.ps
      fi
      if [[ ${TDSTRING} =~ .*t.* ]]; then
        # rotation component of velocity; CONVERT TO PSVELO
        info_msg "TDEFNODE block rotation component of velocity"
        legendwords+=("TDEFrotationvelocity")

        awk '{ if ($5==1 && $6==1) print $8, $9, $38, $39, 0, 0, 1, $1 }' ${TDPATH}${TDMODEL}.vsum > ${TDMODEL}.block
        awk -v gpsscalefac=$VELSCALE '{ az=atan2($3, $4) * 180 / 3.14159265358979; if (az > 0) print $1, $2, az, sqrt($3*$3+$4*$4)*gpsscalefac; else print $1, $2, az+360, sqrt($3*$3+$4*$4)*gpsscalefac; }' ${TDMODEL}.block > ${TDMODEL}.xyblock
        gmt psxy -SV$ARROWFMT -W0.1p,black -Ggreen ${TDMODEL}.xyblock $RJOK $VERBOSE >> map.ps
      fi
			;;

    topo)
      if [[ $gdemtopoplotflag -eq 1 ]]; then
        # DEM will have been clipped already
        if [[ $gdaltzerohingeflag -eq 1 ]]; then
          # We need to make a gdal color file that respects the CPT hinge value (usually 0)
          # gdaldem is a bit funny about coloring around the hinge, so do some magic to make
          # the color from land not bleed to the hinge elevation.
          CPTHINGE=0
          awk < $TOPO_CPT -v hinge=$CPTHINGE '{
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
            }' | tr '/' ' ' > topocolor.dat
        else
          awk < $TOPO_CPT '{ print $1, $2 }' | tr '/' ' ' > topocolor.dat
        fi

        # Calculate the color stretch
        gdaldem color-relief dem.nc topocolor.dat colordem.tif -q

        # Calculate the multidirectional hillshade
        gdaldem hillshade -compute_edges -multidirectional -alt ${HS_ALT} -s 111120 dem.nc hs_md.tif -q
        # gdaldem hillshade -combined -s 111120 dem.nc hs_c.tif -q

        # Clip the hillshade to reduce extreme bright and extreme dark areas


        # Calculate the slope and shade the data
        gdaldem slope -compute_edges -s 111120 dem.nc slope.tif -q
        echo "0 255 255 255" > slope.txt
        echo "90 0 0 0" >> slope.txt
        gdaldem color-relief slope.tif slope.txt slopeshade.tif -q

        # A hillshade is mostly gray (127) while a slope map is mostly white (255)

        # Combine the hillshade and slopeshade into a blended, gamma corrected image
        gdal_calc.py --quiet -A hs_md.tif -B slopeshade.tif --outfile=gamma_hs.tif --calc="uint8( ( ((A/255.)*(${HSSLOPEBLEND}) + (B/255.)*(1-${HSSLOPEBLEND}) ) )**(1/${HS_GAMMA}) * 255)"


        # Combine the shaded relief and color stretch using a multiply scheme

        gdal_calc.py --quiet -A gamma_hs.tif -B colordem.tif --allBands=B --calc="uint8( ( \
                        2 * (A/255.)*(B/255.)*(A<128) + \
                        ( 1 - 2 * (1-(A/255.))*(1-(B/255.)) ) * (A>=128) \
                      ) * 255 )" --outfile=colored_hillshade.tif

        gmt grdimage colored_hillshade.tif -t$TOPOTRANS $RJOK ${VERBOSE} >> map.ps

      else
        if [[ $dontplottopoflag -eq 0 ]]; then
          gmt grdimage $BATHY ${ILLUM} -t$TOPOTRANS -C$TOPO_CPT $RJOK ${VERBOSE} >> map.ps
        else
          info_msg "Plotting of topo shaded relief suppressed by -ts"
        fi
      fi
      ;;

    volcanoes)
      info_msg "Volcanoes"
      gmt psxy volcanoes.dat -W0.25p,"${V_LINEW}" -G"${V_FILL}" -St"${V_SIZE}"/0  $RJOK $VERBOSE >> map.ps
      ;;

	esac
done

gmt gmtset FONT_TITLE 12p,Helvetica,black

################################################################################
# Plot the frame and close the map if KEEPOPEN is set to "" and we aren't
# overplotting a legend. Otherwise, keep the PS file open.

##### PLOT GRID (AND SCALE BAR) OVER MAP

if [[ $legendovermapflag -eq 0 ]]; then
  info_msg "Plotting grid and keeping PS file open if --keepopenps is set ($KEEPOPEN)"
  if [[ $usecustombflag -eq 1 ]]; then
    echo gmt psbasemap -R -J -O $KEEPOPEN $VERBOSE ${BSTRING[@]}
    gmt psbasemap -R -J -O $KEEPOPEN $VERBOSE ${BSTRING[@]} ${SCALECMD} >> map.ps
  else
    if [[ $PLOTTITLE == "BlankMapTitle" ]]; then
      gmt psbasemap -R -J -O $KEEPOPEN $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}" ${SCALECMD} >> map.ps
    else
      gmt psbasemap -R -J -O $KEEPOPEN $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}"+t"${PLOTTITLE}" ${SCALECMD} >> map.ps
    fi
  fi
else # We are overplotting a legend, so keep it open in any case
  info_msg "Plotting grid and keeping PS file open for legend"
  if [[ $usecustombflag -eq 1 ]]; then
    gmt psbasemap -R -J -O -K $VERBOSE ${BSTRING[@]} ${SCALECMD} >> map.ps
  else
    if [[ $PLOTTITLE == "BlankMapTitle" ]]; then
      gmt psbasemap -R -J -O -K $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}" ${SCALECMD} >> map.ps
    else
      gmt psbasemap -R -J -O -K $VERBOSE -Bxa"$GRIDSP""$GRIDSP_LINE" -Bya"$GRIDSP""$GRIDSP_LINE" -B"${GRIDCALL}"+t"${PLOTTITLE}" ${SCALECMD} >> map.ps
    fi
  fi
fi

##### PLOT LEGEND
if [[ $makelegendflag -eq 1 ]]; then
  gmt gmtset MAP_TICK_LENGTH_PRIMARY 0.5p MAP_ANNOT_OFFSET_PRIMARY 1.5p MAP_ANNOT_OFFSET_SECONDARY 2.5p MAP_LABEL_OFFSET 2.5p FONT_LABEL 6p,Helvetica,black

  if [[ $legendovermapflag -eq 1 ]]; then
    LEGMAP="map.ps"
    #echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -JX20ix20i -R0/10/0/10 -Xf$PLOTSHIFTX -Yf$PLOTSHIFTY -K $VERBOSE > maplegend.ps
  else
    info_msg "Plotting legend in its own file"
    LEGMAP="maplegend.ps"
    echo "0 0" | gmt psxy -Sc0.001i -Gwhite -W0p -JX20ix20i -R0/10/0/10 -X$PLOTSHIFTX -Y$PLOTSHIFTY -K $VERBOSE > maplegend.ps
  fi

  MSG="Updated legend commands are >>>>> ${legendwords[@]} <<<<<"
  [[ $narrateflag -eq 1 ]] && echo $MSG

  echo "# Legend " > legendbars.txt
  barplotcount=0
  plottedneiscptflag=0

  # First, plot the color bars in a column. How many could you possibly have anyway?
  for plot in ${legendwords[@]} ; do
  	case $plot in
      cities)
          echo "G 0.2i" >> legendbars.txt
          echo "B $POPULATION_CPT 0.2i 0.1i+malu -W0.00001 -Bxa10f1+l\"City population (100k)\"" >> legendbars.txt
          barplotcount=$barplotcount+1
        ;;

      cmt|seis|slab2)
        if [[ $plottedneiscptflag -eq 0 ]]; then
          plottedneiscptflag=1
          if [[ $(echo "$EQMAXDEPTH_COLORSCALE > 1000" | bc) -eq 1 ]]; then
            EQXINT=500
          elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 500" | bc) -eq 1 ]]; then
            EQXINT=250
          elif [[ $(echo "$EQMAXDEPTH_COLORSCALE > 100" | bc) -eq 1 ]]; then
            EQXINT=50
          else
            EQXINT=20
          fi
          echo "G 0.2i" >> legendbars.txt
          echo "B $SEISDEPTH_NODEEPEST_CPT 0.2i 0.1i+malu -Bxa${EQXINT}+l\"Earthquake / slab depth (km)\"" >> legendbars.txt
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

      topo)
        echo "G 0.2i" >> legendbars.txt
        echo "B ${TOPO_CPT} 0.2i 0.1i+malu -Bxa${BATHYXINC}f1+l\"Elevation (km)\"" -W0.001 >> legendbars.txt
        barplotcount=$barplotcount+1
        ;;

  	esac
  done

  velboxflag=0
  [[ $barplotcount -eq 0 ]] && LEGEND_WIDTH=0.01
  LEG2_X=$(echo "$LEGENDX $LEGEND_WIDTH 0.1i" | awk '{print $1+$2+$3 }' )
  LEG2_Y=${MAP_PS_HEIGHT_IN}

  # The non-colobar plots come next. pslegend can't handle a lot of things well,
  # and scaling is difficult. Instead we make small eps files and plot them,
  # keeping track of their size to allow relative positioning
  # Not sure how robust this is... but it works...

  # NOTE: Velocities need to be scaled by gpsscalefactor to fit with the map

  # We will plot items vertically in increments of 3, and then add an X_INC and send Y to MAP_PS_HEIGHT_IN
  count=0
  # Keep track of the largest width we have used and make next column not overlap it.
  NEXTX=0
  GPS_ELLIPSE_TEXT=$(awk -v c=0.95 'BEGIN{print c*100 "%" }')

  for plot in ${plots[@]} ; do
  	case $plot in
      cmt)
        MEXP_6=$(echo 6.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
                  mwmod = ($1^str)/(sref^(str-1))
                  a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
                  split(a,b,"+")
                  split(a,c,"E")
                  print c[1], b[2] }')
        MEXP_7=$(echo 7.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
                  mwmod = ($1^str)/(sref^(str-1))
                  a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
                  split(a,b,"+")
                  split(a,c,"E")
                  print c[1], b[2] }')
        MEXP_8=$(echo 8.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{
                  mwmod = ($1^str)/(sref^(str-1))
                  a=sprintf("%E", 10^((mwmod + 10.7)*3/2))
                  split(a,b,"+")
                  split(a,c,"E")
                  print c[1], b[2] }')

        if [[ $CMTLETTER == "c" ]]; then
          echo "$CENTERLON $CENTERLAT 15 322 39 -73 121 53 -104 $MEXP_6 126.020000 13.120000 C021576A" | gmt psmeca -E"${CMT_NORMALCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtnormalflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 220 0.99" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 342 0.23" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 129 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT N/6.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 14 92 82 2 1 88 172 $MEXP_7 125.780000 8.270000 B082783A" | gmt psmeca -E"${CMT_SSCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK -X0.35i -Y-0.15i ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtssflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 316 0.999" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 47 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 167 0.14" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT SS/7.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 33 321 35 92 138 55 89 $MEXP_8 123.750000 7.070000 M081676B" | gmt psmeca -E"${CMT_THRUSTCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 -X0.35i -Y-0.15i -R -J -O -K ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtthrustflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 42 0.17" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 229 0.999" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 139 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT R/8.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O >> mecaleg.ps
        fi
        if [[ $CMTLETTER == "m" ]]; then
          echo "$CENTERLON $CENTERLAT 10 -3.19 1.95 1.24 -0.968 -0.425 $MEXP_6 0 0 " | gmt psmeca -E"${CMT_NORMALCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtnormalflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 220 0.99" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 342 0.23" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 129 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT N/6.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 10 0.12 -1.42 1.3 0.143 -0.189 $MEXP_7 0 0 " | gmt psmeca -E"${CMT_SSCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 $RJOK -X0.35i -Y-0.15i ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtssflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 316 0.999" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 47 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 167 0.14" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT SS/7.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O -K >> mecaleg.ps
          echo "$CENTERLON $CENTERLAT 15 2.12 -1.15 -0.97 0.54 -0.603 $MEXP_8 0 0 2016-12-08T17:38:46" | gmt psmeca -E"${CMT_THRUSTCOLOR}" -L0.25p,black -Z$SEISDEPTH_CPT -S${CMTLETTER}"$CMTRESCALE"i/0 -X0.35i -Y-0.15i -R -J -O -K ${VERBOSE} >> mecaleg.ps
          if [[ $axescmtthrustflag -eq 1 ]]; then
            [[ $axestflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 42 0.17" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,purple -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axespflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 229 0.999" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,blue -Gblack $RJOK $VERBOSE >>  mecaleg.ps
            [[ $axesnflag -eq 1 ]] && echo "$CENTERLON $CENTERLAT 139 0.96" | awk -v scalev=${CMTAXESSCALE} '{print $1, $2, $3, $4*scalev}' | gmt psxy -SV${CMTAXESARROW}+jc+b+e -W0.4p,green -Gblack $RJOK $VERBOSE >>  mecaleg.ps
          fi
          echo "$CENTERLON $CENTERLAT R/8.0" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.15i -O >> mecaleg.ps
        fi

        PS_DIM=$(gmt psconvert mecaleg.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i mecaleg.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      eqlabel)

        [[ $EQ_LABELFORMAT == "idmag"   ]]  && echo "$CENTERLON $CENTERLAT ID Mw" | awk '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'      > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "datemag" ]]  && echo "$CENTERLON $CENTERLAT DATE Mw" | awk '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'    > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "dateid"  ]]  && echo "$CENTERLON $CENTERLAT DATE ID" | awk '{ printf "%s %s %s(%s)\n", $1, $2, $3, $4 }'    > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "id"      ]]  && echo "$CENTERLON $CENTERLAT ID" | awk '{ printf "%s %s %s\n", $1, $2, $3 }'                 > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "date"    ]]  && echo "$CENTERLON $CENTERLAT DATE" | awk '{ printf "%s %s %s\n", $1, $2, $3 }'               > eqlabel.legend.txt
        [[ $EQ_LABELFORMAT == "mag"     ]]  && echo "$CENTERLON $CENTERLAT Mw" | awk '{ printf "%s %s %s\n", $1, $2, $3 }'                 > eqlabel.legend.txt

        cat eqlabel.legend.txt | gmt pstext -Gwhite -W0.5p,black -F+f${EQ_LABEL_FONTSIZE},${EQ_LABEL_FONT},${EQ_LABEL_FONTCOLOR}+j${EQ_LABEL_JUST} -R -J -O $VERBOSE >> eqlabel.ps
        PS_DIM=$(gmt psconvert eqlabel.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i eqlabel.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      grid)
        GRIDMAXVEL_INT=$(echo "scale=0;($GRIDMAXVEL+5)/1" | bc)
        V100=$(echo "$GRIDMAXVEL_INT" | bc -l)
        if [[ $PLATEVEC_COLOR =~ "white" ]]; then
          echo "$CENTERLON $CENTERLAT $GRIDMAXVEL_INT 0 0 0 0 0 ID" | gmt psvelo -W0p,gray@$PLATEVEC_TRANS -Ggray@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velarrow.ps 2>/dev/null
        else
          echo "$CENTERLON $CENTERLAT $GRIDMAXVEL_INT 0 0 0 0 0 ID" | gmt psvelo -W0p,$PLATEVEC_COLOR@$PLATEVEC_TRANS -G$PLATEVEC_COLOR@$PLATEVEC_TRANS -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velarrow.ps 2>/dev/null
        fi
        echo "$CENTERLON $CENTERLAT Plate velocity ($GRIDMAXVEL_INT mm/yr)" | gmt pstext -F+f6p,Helvetica,black+jLB $VERBOSE -J -R -Y0.1i -O >> velarrow.ps
        PS_DIM=$(gmt psconvert velarrow.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i velarrow.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      gps)
        GPSMAXVEL_INT=$(echo "scale=0;($GPSMAXVEL+5)/1" | bc)
        echo "$CENTERLON $CENTERLAT $GPSMAXVEL_INT 0 5 5 0 ID" | gmt psvelo -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} -A${ARROWFMT} -Se$VELSCALE/${GPS_ELLIPSE}/0 -L $RJOK $VERBOSE >> velgps.ps 2>/dev/null
        GPSMESSAGE="GPS: $GPSMAXVEL_INT mm/yr (${GPS_ELLIPSE_TEXT})"
        echo "$CENTERLON $CENTERLAT $GPSMESSAGE" | gmt pstext -F+f6p,Helvetica,black+jLB -J -R -Y0.1i -O ${VERBOSE} >> velgps.ps
        PS_DIM=$(gmt psconvert velgps.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i velgps.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

    inset)
        echo "$MINLON $MINLAT" > aoi_box.txt
        echo "$MINLON $MAXLAT" >> aoi_box.txt
        echo "$MAXLON $MAXLAT" >> aoi_box.txt
        echo "$MAXLON $MINLAT" >> aoi_box.txt
        echo "$MINLON $MINLAT" >> aoi_box.txt

        gmt_init_tmpdir
        gmt pscoast -Rg -JG${CENTERLON}/${CENTERLAT}/${INSET_SIZE} -Xa${INSET_XOFF} -Ya${INSET_YOFF} -Bg -Dc -A5000 -Ggray -Swhite -K -O ${VERBOSE} >> $LEGMAP
        gmt psxy aoi_box.txt -R -J -O -K -W${INSET_AOI_LINEWIDTH},${INSET_AOI_LINECOLOR} -Xa${INSET_XOFF} -Ya${INSET_YOFF} ${VERBOSE} >> $LEGMAP
        gmt_remove_tmpdir
        ;;

    kinsv)
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
        PS_DIM=$(gmt psconvert kinsv.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i kinsv.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
       ;;

      # Strike and dip of nodal planes is plotted using kinsv above
      # kingeo)
      #
      #   ;;

      plate)
        # echo "$CENTERLON $CENTERLAT 90 1" | gmt psxy -SV$ARROWFMT -W${GPS_LINEWIDTH},${GPS_LINECOLOR} -G${GPS_FILLCOLOR} $RJOK $VERBOSE >> plate.ps
        # echo "$CENTERLON $CENTERLAT Kinematics stuff" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -X0.2i -Y0.1i -O >> plate.ps
        # PS_DIM=$(gmt psconvert plate.ps -Te -A0.05i 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        # PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        # PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        # gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i plate.ps $RJOK >> $LEGMAP
        # LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        # count=$count+1
        # NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      seis)
        MW_4=$(echo 4.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{ print ($1^str)/(sref^(str-1)) }')
        MW_5=$(echo 5.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{ print ($1^str)/(sref^(str-1)) }')
        MW_6=$(echo 6.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{ print ($1^str)/(sref^(str-1)) }')
        MW_7=$(echo 7.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{ print ($1^str)/(sref^(str-1)) }')
        MW_8=$(echo 8.0 | awk -v str=$SEISSTRETCH -v sref=$SEISSTRETCH_REFMAG '{ print ($1^str)/(sref^(str-1)) }')

        OLD_PROJ_LENGTH_UNIT=$(gmt gmtget PROJ_LENGTH_UNIT -Vn)
        gmt gmtset PROJ_LENGTH_UNIT p

        echo "$CENTERLON $CENTERLAT $MW_4 DATESTR ID" | gmt psxy -W0.5p,black -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT 4" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_5 DATESTR ID" | gmt psxy -W0.5p,black -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT 5" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_6 DATESTR ID" | gmt psxy -W0.5p,black -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT 6" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_7 DATESTR ID" | gmt psxy -W0.5p,black -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT 7" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O -K >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT $MW_8 DATESTR ID" | gmt psxy -W0.5p,black -i0,1,2+s${SEISSCALE} -S${SEISSYMBOL} -t${SEISTRANS} $RJOK -Y-0.13i -X0.25i ${VERBOSE} >> seissymbol.ps
        echo "$CENTERLON $CENTERLAT 8" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.13i -O >> seissymbol.ps

        gmt gmtset PROJ_LENGTH_UNIT $OLD_PROJ_LENGTH_UNIT

        PS_DIM=$(gmt psconvert seissymbol.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i seissymbol.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;

      srcmod)
  			# echo 0 0.1 "Slip magnitudes from: $SRCMODFSPLOCATIONS"  | gmt pstext $VERBOSE -F+f8,Helvetica,black+jBL -Y$YADD $RJOK >> maplegend.ps
        # YADD=0.2
  			;;

      tdefnode)
        velboxflag=1
        # echo 0 0.1 "TDEFNODE: $TDPATH"  | gmt pstext $VERBOSE -F+f8,Helvetica,black+jBL -Y$YADD  $RJOK >> maplegend.ps
        # YADD=0.15
        ;;

      volcanoes)
        echo "$CENTERLON $CENTERLAT" | gmt psxy -W0.25p,"${V_LINEW}" -G"${V_FILL}" -St"${V_SIZE}"/0 $RJOK ${VERBOSE} >> volcanoes.ps
        echo "$CENTERLON $CENTERLAT Volcano" | gmt pstext -F+f6p,Helvetica,black+jCB $VERBOSE -J -R -Y0.1i -O >> volcanoes.ps

        PS_DIM=$(gmt psconvert volcanoes.ps -Te -A0.05i -V 2> >(grep Width) | awk -F'[ []' '{print $10, $17}')
        PS_WIDTH_IN=$(echo $PS_DIM | awk '{print $1/2.54}')
        PS_HEIGHT_IN=$(echo $PS_DIM | awk '{print $2/2.54}')
        gmt psimage -Dx"${LEG2_X}i/${LEG2_Y}i"+w${PS_WIDTH_IN}i volcanoes.eps $RJOK ${VERBOSE} >> $LEGMAP
        LEG2_Y=$(echo "$LEG2_Y + $PS_HEIGHT_IN + 0.02" | bc -l)
        count=$count+1
        NEXTX=$(echo $PS_WIDTH_IN $NEXTX | awk '{if ($1>$2) { print $1 } else { print $2 } }')
        ;;
    esac
    if [[ $count -eq 3 ]]; then
      count=0
      LEG2_X=$(echo "$LEG2_X + $NEXTX" | bc -l)
      # echo "Updated LEG2_X to $LEG2_X"
      LEG2_Y=${MAP_PS_HEIGHT_IN}
    fi
  done

  # gmt pstext tectoplot.shortplot -F+f6p,Helvetica,black $KEEPOPEN $VERBOSE >> map.ps
  # x y fontinfo angle justify linespace parwidth parjust
  echo "> 0 0 9p Helvetica,black 0 l 0.1i ${INCH}i l" > datasourceslegend.txt
  uniq tectoplot.shortsources | awk 'BEGIN {printf "T Data sources: "} {print}'  | tr '\n' ' ' >> datasourceslegend.txt

  # gmt gmtset FONT_ANNOT_PRIMARY 8p,Helvetica-bold,black
  MAP_PS_HEIGHT_IN_minus=$(echo "$MAP_PS_HEIGHT_IN-11/72" | bc -l )
  # NUMLEGBAR=$(wc -l < legendbars.txt)
  # if [[ $NUMLEGBAR -eq 1 ]]; then
  #   gmt pslegend datasourceslegend.txt -Dx0.0i/${MAP_PS_HEIGHT_IN_minus}i+w${LEGEND_WIDTH}+w${INCH}i+jBL -C0.05i/0.05i -J -R -O $KEEPOPEN ${VERBOSE} >> $LEGMAP
  # else
    gmt pslegend datasourceslegend.txt -Dx0.0i/${MAP_PS_HEIGHT_IN_minus}i+w${LEGEND_WIDTH}+w${INCH}i+jBL -C0.05i/0.05i -J -R -O -K ${VERBOSE} >> $LEGMAP
    gmt pslegend legendbars.txt -Dx0i/${MAP_PS_HEIGHT_IN}i+w${LEGEND_WIDTH}+jBL -C0.05i/0.05i -J -R -O $KEEPOPEN ${VERBOSE} >> $LEGMAP
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

echo "${COMMAND}" > "$MAPOUT.history"
echo "${COMMAND}" >> $TECTOPLOTDIR"tectoplot.history"

grep "%@GMT:" map.ps | sed -e 's/%@GMT: //' >> "$MAPOUT.history"

##### MAKE PDF
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

[[ $obliqueflag -eq 1 ]] && tifflag=1

##### MAKE GEOTIFF
if [[ $tifflag -eq 1 ]]; then
  gmt psconvert map.ps -Tt -A -W -E${GEOTIFFRES} ${VERBOSE}

  mv map.tif "${THISDIR}/${MAPOUT}.tif"
  mv map.tfw "${THISDIR}/${MAPOUT}.tfw"

  [[ $openflag -eq 1 ]] && open -a $OPENPROGRAM "${THISDIR}/${MAPOUT}.tif"
fi

##### MAKE OBLIQUE VIEW OF TOPOGRAPHY
if [[ $obliqueflag -eq 1 ]]; then
  info_msg "Oblique map (${OBLIQUEAZ}/${OBLIQUEINC})"
  PSSIZENUM=$(echo $PSSIZE | awk '{print $1+0}')

  zrange=$(grid_zrange $BATHY -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -C -Vn)
  DELTAZ_DEG=$(echo $zrange | awk -v pss=$PSSIZENUM -v ex=$OBLIQUE_VEXAG '{print ex * ($2-$1) / 111000 * pss}')

  if [[ $gdemtopoplotflag -eq 1 ]]; then
    gmt grdview $BATHY  $NCALL -Gcolored_hillshade.tif -R$MINLON/$MAXLON/$MINLAT/$MAXLAT -JM${MINLON}/${PSSIZENUM}i -JZ${DELTAZ_DEG}i -Qi${OBLIQUERES} -p${OBLIQUEAZ}/${OBLIQUEINC} --GMT_HISTORY=false ${VERBOSE} > oblique.ps
  else
    gmt grdview $BATHY -C$TOPO_CPT -R$MINLON/$MAXLON/$MINLAT/$MAXLAT  -JM${MINLON}/${PSSIZENUM}i -JZ${DELTAZ_DEG}i -Qi${OBLIQUERES} -p${OBLIQUEAZ}/${OBLIQUEINC} -B --GMT_HISTORY=false ${VERBOSE} > oblique.ps # -Gmap.tif
  fi

  gmt psconvert oblique.ps -Tf -A0.5i --GMT_HISTORY=false ${VERBOSE}
fi

##### MAKE KML
if [[ $kmlflag -eq 1 ]]; then
  gmt psconvert map.ps -Tt -A -W+k -E${KMLRES} ${VERBOSE}
  ncols=$(gmt grdinfo map.tif -C ${VERBOSE} | awk '{print $10}')
  nrows=$(gmt grdinfo map.tif -C ${VERBOSE} | awk '{print $11}')
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
  gmt psbasemap -JA0/-89.999/3i -Rg -Bxa10fg10 -Bya10fg10 -K ${VERBOSE} > stereo.ps
  gmt makecpt -Cwysiwyg -T$MINLAT/$MAXLAT/1 > lon.cpt
  if [[ $axescmtthrustflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && awk < t_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && awk < p_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && awk < n_axes_thrust.txt '{ print $3, -$4, $2 }' | gmt psxy -Sc0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  if [[ $axescmtnormalflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && awk < t_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && awk < p_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && awk < n_axes_normal.txt '{ print $3, -$4, $2 }' | gmt psxy -Ss0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  if [[ $axescmtssflag -eq 1 ]]; then
    [[ $axestflag -eq 1 ]] && awk < t_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Gred -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axespflag -eq 1 ]] && awk < p_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Gblue -R -J -O -K ${VERBOSE} >> stereo.ps
    [[ $axesnflag -eq 1 ]] && awk < n_axes_strikeslip.txt '{ print $3, -$4, $2 }' | gmt psxy -St0.05i -Clon.cpt -W0.25p,black -Ggreen -R -J -O -K ${VERBOSE} >> stereo.ps
  fi
  echo "0 0" | gmt psxy -Sc0.001i -Gwhite -R -J -O ${VERBOSE} >> stereo.ps
  gmt psconvert stereo.ps -Tf -A0.5i ${VERBOSE}
fi

exit 0
