# tectoplot

Kyle Edward Bradley, Asian School of the Environment, Nanyang Technological University, Singapore - November 2020
kbradley@ntu.edu.sg

NOTE: This script is being actively developed during my spare time to support my own research projects, and large changes can occur that can accidentally break functionality. Eventually the code will be reworked to be more robust and will be more thoroughly tested and documented. In the mean time, a general changelog can be found at the top of the main tectoplot script. I am commiting updates fairly often as of December 2020.

If you use this script, please keep an eye on your data and validate any plots and outputs before you use them!

At present, not all the data files linked in the script are downloadable from original sources. This mainly includes the plate and plate motion models and GPS data, which do need a small amount of customization before use, like splitting polygons that cross the antimeridian, etc.

### Note:
While I am currently working on this script in my spare time, I have not validated all of its functions and there are certainly some bugs/unforseen effects, especially in lesser-used functions. Not all of the functions are even good ideas in the first place. If you use this script for your research, please sanity check your own results!

## Overview
tectoplot is a bash script and associated helper scripts that makes seismotectonic maps, cross sections, and oblique block diagrams. It tries to simplify the process of visualizing data while also maintaining flexibility by running from the command line in a Unix environment and operating mainly on flat text-format data files. tectoplot started as a basic script to automate making shaded relief maps with GMT, and has snowballed over time to incorporate additional functions like plate motion models, swath profiles of topography or other data, cross sections, perspective block diagrams, etc. It will also plot TDEFNODE model results.

tectoplot is intended for small-scale geological studies where maps are 10+km across and data are in geographic coordinates. More detailed areas with projected data are currently beyond the scope of the program.

Calculations generally leave behind the intermediate steps and final data in a temporary folder. This gives access to (for instance) raw swath profile data, filtered seismicity data, clipped DEMs or grids, etc. Some functions generate scripts that can be used to adjust displays or can be the basis of more complex plots (e.g. perspective diagrams).

tectoplot will download and manage various publicly available datasets, like SRTM/GEBCO bathymetry, ISC/GCMT seismicity and focal mechanisms, global populated places, volcanoes, active faults, etc. It tries to simplify the seismicity catalogs to ensure that maps do not have (for instance) multiple versions of the same event. This process is currently a bit ad-hoc and could be improved. tectoplot can plot either centroid or origin locations for CMT data and will also draw lines to show the alternative location.

tectoplot's cross section functionality supports multiple profiles incorporating various kinds of data (swath grids like topography or gravity, along-profile sampled grids like Slab2 depth grids, XYZ data, XYZ seismicity data scaled by magnitude, and focal mechanisms). Profiles can be aligned in the X direction using an XY polyline that crosses the profiles, such as a trench axis, and can be aligned in the Z direction by matching profile values to 0 at this intersection point. This allows stacking of profiles. Profiles can have more than two vertices, and attempts are made to project data intelligently onto such profiles. Notably, a signed distance function is available that will extract topography in a distance-from-track and distance-along-track-of-closest-point-on-track space, which avoids some of the nasty artifacts arising from kinked profiles.

## Credits
This script relies very heavily on GMT 6 (www.generic-mapping-tools.org), gdal (gdal.org), and GNU awk (gawk).

NDK import in cmt_tools.sh is from a heavily modified version of ndk2meca.awk by Thorsten Becker (sourced from http://www-udc.ig.utexas.edu/external/becker/software/ndk2meca.awk)

Moment tensor diagonalization via perl is heavily modified from diagonalize.pl by Utpal Kumar (IESAS)

Various CMT calculations are modified from GMT's psmeca.c/ultimeca.c by G. Patau (IPGP)

tectoplot includes source redistributions for:
 Texture shading by Leland Brown and TIFF generation by Brett Casebolt (C source).
 MatrixReal.pm by Steffen Beyer, Rodolphe Ortalo, and Jonathan Leto

tectoplot will download and compile access_litho from LITHO1.0

## Setup

tectoplot requires GMT6.1, gdal, geod, and a standard UNIX command line environment (awk, bc, cat, curl, date, grep, sed).
It is verified to run on MacOSX 10.15.4 and Fedora Linux, but no attempts have been made to ensure portability (yet).

Download and extract the ZIP file from Github, or install it using git:

`git clone https://github.com/kyleedwardbradley/tectoplot.git tectoplot`

Installation and setup information can be found by running the script from its source directory:

`./tectoplot -setup`

## Examples

<table>
<tr>
<td>Example 1: Four global plots in one PDF
</td>
</tr>
<tr>
<td><a href=examples/example1.pdf><img src=examples/example1.jpg height=100></a></td>
</tr>
<tr>
<td>Example 10: Litho1 profile / map and profile
</td>
</tr>
<tr>
<td><a href=examples/example10.pdf><img src=examples/example10.jpg height=100></a></td>
</tr>
<tr>
<td>Example 10b: Litho1 perspective diagram
</td>
</tr>
<tr>
<td><a href=examples/example10_profile_150_40_10.pdf><img src=examples/example10_profile_150_40_10.jpg height=100></a></td>
</tr>
<tr>
<td>Example 11: Oceanic crust age
</td>
</tr>
<tr>
<td><a href=examples/example11.pdf><img src=examples/example11.jpg height=100></a></td>
</tr>
<tr>
<td>Example 13: MORVEL57 NNR plate velocities
</td>
</tr>
<tr>
<td><a href=examples/example13.pdf><img src=examples/example13.jpg height=100></a></td>
</tr>
<tr>
<td>Example 14: Large earthquakes near EQ event
</td>
</tr>
<tr>
<td><a href=examples/example14.pdf><img src=examples/example14.jpg height=100></a></td>
</tr>
<tr>
<td>Example 15: Plot custom seismicity/CMT data
</td>
</tr>
<tr>
<td><a href=examples/example15.pdf><img src=examples/example15.jpg height=100></a></td>
</tr>
<tr>
<td>Example 16: Plot CMT from custom NDK file
</td>
</tr>
<tr>
<td><a href=examples/example16.pdf><img src=examples/example16.jpg height=100></a></td>
</tr>
<tr>
<td>Example 18: Oblique Mercator projection
</td>
</tr>
<tr>
<td><a href=examples/example18.pdf><img src=examples/example18.jpg height=100></a></td>
</tr>
<tr>
<td>Example 19: Topography with cast shadows - map
</td>
</tr>
<tr>
<td><a href=examples/example19.pdf><img src=examples/example19.jpg height=100></a></td>
</tr>
<tr>
<td>Example 19: Topography with cast shadows - perspective
</td>
</tr>
<tr>
<td><a href=examples/example19_oblique.pdf><img src=examples/example19_oblique.jpg height=100></a></td>
</tr>
<tr>
<td>Example 2: Two stereographic global plots in one PDF
</td>
</tr>
<tr>
<td><a href=examples/example2.pdf><img src=examples/example2.jpg height=100></a></td>
</tr>
<tr>
<td>Example 3: Regional seismotectonic map with Slab2
</td>
</tr>
<tr>
<td><a href=examples/example3.pdf><img src=examples/example3.jpg height=100></a></td>
</tr>
<tr>
<td>Example 4: GPS velocities and tectonic blocks
</td>
</tr>
<tr>
<td><a href=examples/example4.pdf><img src=examples/example4.jpg height=100></a></td>
</tr>
<tr>
<td>Example 5: Topography and seismicity
</td>
</tr>
<tr>
<td><a href=examples/example5.pdf><img src=examples/example5.jpg height=100></a></td>
</tr>
<tr>
<td>Example 6: Profile across subduction zone seismicity
</td>
</tr>
<tr>
<td><a href=examples/example6.pdf><img src=examples/example6.jpg height=100></a></td>
</tr>
<tr>
<td>Example 6b: Oblique perspective of subduction zone seismicity
</td>
</tr>
<tr>
<td><a href=examples/example6_profile_140_30_8.pdf><img src=examples/example6_profile_140_30_8.jpg height=100></a></td>
</tr>
<tr>
<td>Example 6a: Oblique perspective of subduction zone seismicity
</td>
</tr>
<tr>
<td><a href=examples/example6_profile_220_20_5.pdf><img src=examples/example6_profile_220_20_5.jpg height=100></a></td>
</tr>
<tr>
<td>Example 7: Large earthquakes of Chile over Bouguer gravity
</td>
</tr>
<tr>
<td><a href=examples/example7.pdf><img src=examples/example7.jpg height=100></a></td>
</tr>
<tr>
<td>Example 8: Stacked swath profiles
</td>
</tr>
<tr>
<td><a href=examples/example8.pdf><img src=examples/example8.jpg height=100></a></td>
</tr>
<tr>
<td>Example 9: Stacked gravity profiles
</td>
</tr>
<tr>
<td><a href=examples/example9.pdf><img src=examples/example9.jpg height=100></a></td>
</tr>
