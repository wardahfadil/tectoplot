# tectoplot

Kyle Edward Bradley, Asian School of the Environment, Nanyang Technological University, Singapore - November 2020
kbradley@ntu.edu.sg

Note: while I am currently working on this script in my spare time, I have not validated all of its functions and there are certainly some bugs/unforseen effects, especially in lesser-used functions. Not all of the functions are even good ideas in the first place. If you use this script for your research, please sanity check your own results!

tectoplot is a bash script and associated helper scripts that makes seismotectonic maps, cross sections, and oblique block diagrams. It tries to simplify the process of visualizing data while also maintaining flexibility by running from the command line in a Unix environment and operating mainly on flat text-format data files. tectoplot started as a basic script to automate making shaded relief maps with GMT, and has snowballed over time to incorporate additional functions like plate motion models, swath profiles of topography or other data, cross sections, perspective block diagrams, etc. It will also plot TDEFNODE model results. 

tectoplot is intended for small-scale geological studies where maps are 10+km across and data are in geographic coordinates. More detailed areas with projected data are currently beyond the scope of the program.

Calculations generally leave behind the intermediate steps and final data in a temporary folder. This gives access to (for instance) raw swath profile data, filtered seismicity data, clipped DEMs or grids, etc. Some functions generate scripts that can be used to adjust displays or can be the basis of more complex plots (e.g. perspective diagrams). 

tectoplot will download and manage various publicly available datasets, like SRTM/GEBCO bathymetry, ISC/GCMT seismicity and focal mechanisms, global populated places, volcanoes, active faults, etc. It tries to simplify the seismicity catalogs to ensure that maps do not have (for instance) multiple versions of the same event. This process is currently a bit ad-hoc and could be improved. tectoplot can plot either centroid or origin locations for CMT data and will also draw lines to show the alternative location.

tectoplot's cross section functionality supports multiple profiles incorporating various kinds of data (swath grids like topography or gravity, along-profile sampled grids like Slab2 depth grids, XYZ data, XYZ seismicity data scaled by magnitude, and focal mechanisms). Profiles can be aligned in the X direction using an XY polyline that crosses the profiles, such as a trench axis, and can be aligned in the Z direction by matching profile values to 0 at this intersection point. This allows stacking of profiles. Profiles can have more than two vertices, and attempts are made to project data intelligently onto such profiles. Notably, a signed distance function is available that will extract topography in a distance-from-track and distance-along-track-of-closest-point-on-track space, which avoids some of the nasty artifacts arising from kinked profiles. 

Credits for external code used: 
A heavily modified version of ndk2meca.awk by Thorsten Becker (NDK to PSMECA conversion script)

Setup

Download and extract the ZIP file from Github, or install it using git:

git clone https://github.com/kyleedwardbradley/tectoplot.git tectoplot

Installation and setup information can be found by running the script from its source directory:

./tectoplot -setup
