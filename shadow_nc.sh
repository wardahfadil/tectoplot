#!/bin/bash

# Calculate a cast shadow raster from a NetCDF DEM.
# Input raster is a regular grid of geographic coordinates

if [[ ! $(command -v ncdump) ]]; then
   echo "Shadow calculation requires netcdf tool ncdump" > /dev/stderr
   exit 0
fi

if [[ $# -ne 4 ]]; then
  echo "Usage: shadow_nc.sh infile.nc outfile.nc sun_az sun_el" > /dev/stderr
  echo "Output is shadow.nc" > /dev/stderr
  exit
fi

RASTER=$1

if [[ ! -e $RASTER ]]; then
  echo "Input raster file $RASTER does not exist."
  exit 0
fi

OUTFILE=$2

SUN_AZ=$3
SUN_EL=$4

# z[0][0] refers to the lower left corner of the grid

# Read the grid resolution
CELL_SIZE=$(gmt grdinfo -C $RASTER -Vn | awk '{print $8}')

# Set up the output file header
ncdump -c $RASTER | sed '$d' > shadow.cdl

ncdump $RASTER | gawk '/^z =$/{flag=1;next}/^;$/{flag=0}flag'

# Cellsize is in degrees

ncdump $RASTER | gawk -v sun_az=$SUN_AZ -v sun_el=$SUN_EL -v cellsize=$CELL_SIZE '
  function getpi()       { return atan2(0,-1)             }
  function abs(v)        { return v < 0 ? -v : v          }
  function tan(x)        { return sin(x)/cos(x)           }
  function atan(x)       { return atan2(x,1)              }
  function asin(x)       { return atan2(x, sqrt(1-x*x))   }
  function acos(x)       { return atan2(sqrt(1-x*x), x)   }
  function rad2deg(rad)  { return (180 / getpi()) * rad   }
  function deg2rad(deg)  { return (getpi() / 180) * deg   }
  function hypot(x,y)    { return sqrt(x*x+y*y)           }
  function d_atan2d(y,x) { return (x == 0.0 && y == 0.0) ? 0.0 : rad2deg(atan2(y,x)) }


  # Return the azimuth needed to move from a grid cell at a
  # specified latitude in the given azimuth direction.
  # function cell_az(az,lat) {
  #
  # }
  BEGIN { read=0; lathas=0; lonhas=0; curmax=-9999999; cur_i=1; ind=1; line=1;
    const_deg_m=111132;
    const_a=6378137.0;
    const_ee=0.00669437999014;

    num_az= deg2rad(sun_az+180);
    num_el= deg2rad(sun_el);
    sun_x = -cos(num_az)*cos(num_el);
    sun_y = -sin(num_az)*cos(num_el);
    sun_z = sin(num_el)*cellsize*const_deg_m;
    # meters up per unit horizontal distance
  }

  ($1=="lon") {
    if (NF==4) {
      numlon=$3
    }
  }

  ($1=="lat") {
    if (NF==4) {
      numlat=$3
    }
  }

  ($1=="z") {
    # Starts on the next line
    stillgoing=1
    while (stillgoing) {
      getline;
      for(i=1;i<=NF;i++) {
        if ($(i)==";") {
          stillgoing=0;
        } else {
          z[line][ind]=$(i)+0;
          if (ind==numlon) {
            line=line+1;
            ind=1;
          } else {
            ind=ind+1;
          }
        }
      }
    }
  }

 END {

  #### Do any calculations on the grid z[i][j] here.

  # This is the shadow mapping algorithm
  for(i=1;i<=numlat;i++) {
    for(j=1;j<=numlon;j++) {
      x=i;
      y=j;
      zval=z[i][j];
      lit=0;
      cont=1
      shadowmap[i][j]=0;

      while(int(x)>0 && int(x) <= numlat && int(y)>0 && int(y) <= numlon && zval <= z_max) {
        if (zval < z[int(x)][int(y)]) {
          lit=lit+1;
        }
        x=x+sun_x;
        y=y+sun_y;
        zval=zval+sun_z;
      }
      shadowmap[i][j]=(lit>10)?10:lit;
    }
  }

  printf("\n z =\n");
  for(i=1;i<=numlat;i++)
  {
    count=1
    printf("  ");
    for (j=1;j<numlon;j++)
    {
      count=count+1
      printf("%s, ",shadowmap[i][j])
      if (count==11)
      {
        printf("\n  ");
        count=1;
      }
    }
    if (i==numlat)
    {
      printf("%s ;\n",shadowmap[i][j])
    } else
    {
      printf("%s,\n",shadowmap[i][j])
    }
  }
  print "}"

}' >> shadow.cdl

# ncdump $RASTER > dem.cdl
ncgen -o $OUTFILE shadow.cdl
