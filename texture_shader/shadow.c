/*
 * shadow.c
 *
 * New function implemented by Kyle Bradley, NTU
 * Created by Leland Brown on 2011 Feb 19.
 *
 * Copyright (c) 2011-2013 Leland Brown.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define _CRT_SECURE_NO_DEPRECATE
#define _CRT_SECURE_NO_WARNINGS

#include "read_grid_files.h"
#include "write_grid_files.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stddef.h> // for ptrdiff_t

#include <math.h>
#include <assert.h>
#include "terrain_filter.h"

#define LONG ptrdiff_t

#define deg2rad(angleDegrees) ((angleDegrees) * M_PI / 180.0)
#define rad2deg(angleRadians) ((angleRadians) * 180.0 / M_PI)


// CAUTION: This __DATE__ is only updated when THIS file is recompiled.
// If other source files are modified but this file is not touched,
// the version date may not be correct.
static const char sw_name[]    = "Texture";
static const char sw_version[] = "1.3.1";
static const char sw_date[]    = __DATE__;

static const char sw_format[] = "%s v%s %s";

static const char *command_name;

static const char *get_command_name( const char *argv[] )
{
    const char *colon;
    const char *slash;
    const char *result;

    colon = strchr( argv[0], ':' );
    if (colon) {
        ++colon;
    } else {
        colon = argv[0];
    }
    slash = strrchr( colon, '/' );
    if (slash) {
        ++slash;
    } else {
        slash = colon;
    }
    result = strrchr( slash, '\\' );
    if (result) {
        ++result;
    } else {
        result = slash;
    }
    return result;
}

static void prefix_error()
{
    fprintf( stderr, "\n*** ERROR: " );
}

static void usage_exit( const char *message )
{
    if (message) {
        prefix_error();
        fprintf( stderr, "%s\n", message );
    }
    fprintf( stderr, "\n" );
    fprintf( stderr, "USAGE:    %s sun_az sun_elev elev_file [-options ...]\n", command_name );
    fprintf( stderr, "          %s 120 22 rainier_elev -mercator -32.5 45\n", command_name );
    fprintf( stderr, "\n" );
    fprintf( stderr, "Requires both .flt and .hdr files as input  " );
    fprintf( stderr, "(e.g., rainier_elev.flt and rainier_elev.hdr).\n" );
    fprintf( stderr, "Writes   both .flt and .hdr files as output " );
    fprintf( stderr, "(e.g., rainier_tex.flt  and rainier_tex.hdr).\n" );
    fprintf( stderr, "Also reads & writes optional .prj file if present " );
    fprintf( stderr, "(e.g., elev.prj to tex.prj).\n" );
    fprintf( stderr, "Input and output filenames must not be the same.\n" );
    fprintf( stderr, "NOTE: Output files will be overwritten if they already exist.\n" );
    fprintf( stderr, "\n" );
    fprintf( stderr, "Available option:\n" );
    fprintf( stderr, "    -mercator lat1 lat2    " );
    fprintf( stderr, "input is in normal Mercator projection (not UTM)\n" );
    fprintf( stderr, "Values lat1 and lat2 must be in decimal degrees.\n" );
    fprintf( stderr, "\n" );
    exit( EXIT_FAILURE );
}

static void get_filenames(
    const char *arg, char **data_name, char **hdr_name, char **prj_name, char *ext )
// NOTE: caller is responsible to free pointers *data_name, *hdr_name, and *prj_name!
{
    const char *dot;

    size_t len = strlen( arg );

    *data_name = (char *)malloc( len+5 );   // add 5 for ".", extension, and null terminator
    *hdr_name  = (char *)malloc( len+5 );   // assume these mallocs succeed
    *prj_name  = (char *)malloc( len+5 );   // assume these mallocs succeed

    dot = strrchr( arg, '.' );

    if (dot++ && !strpbrk( dot, "/\\" ) && strlen( dot ) <= 4) {
        // filename has extension (of up to 4 characters)
        strncpy( ext, dot, strlen( ext ) );
        if (strcmp( dot, "flt" ) != 0 && strcmp( dot, "FLT" ) != 0)
        {
            usage_exit( "Filenames must have .flt extension (if any)." );
        }
        strcpy ( *data_name, arg );
        strncpy( *hdr_name, arg, len-3 );
        strncpy( *prj_name, arg, len-3 );
        strcpy ( *hdr_name+len-3, "hdr" );
        strcpy ( *prj_name+len-3, "prj" );
    } else {
        // filename does not have extension
        strncpy( *data_name, arg, len );
        (*data_name)[len] = '.';
        strncpy( *data_name+len+1, ext, 3 );    // max 3 chars default extension
        (*data_name)[len+4] = '\0';
        strncpy( *hdr_name, arg, len );
        strncpy( *prj_name, arg, len );
        strcpy ( *hdr_name+len, ".hdr" );
        strcpy ( *prj_name+len, ".prj" );
    }
}

static int print_progress( float portion, float steps_done, int total_steps, void *state )
{
    int *last_count = (int *)state;
    int  this_count = (int)steps_done;

    if (this_count > *last_count) {
        printf( "Processing phase %d...\n", this_count + 1 );
        fflush( stdout );
        *last_count = this_count;
    }

    return 0;
}

// Returns -1 for geographic coordinates, +1 for projected coordinates, 0 if unable to determine
static int determine_projection(
    double xmin, double xmax, double ymin, double ymax, double xdim, double ydim )
{
    // Determine projection type:

    if  ( (ydim <    0.02 && xdim <   0.02) &&
          (xmin > -180.01 && xmax < 180.01) &&
          (ymin >  -90.01 && ymax <  90.01) )
    {
        return -1;  // lat/lon (geographic) coordinates
    } else if
        // Kyle Bradley December 2020 : dim check interferes with along-topo grid in km/km units
        // ( (ydim >    0.09 && xdim >   0.09) &&
        ( (xmin < -181.00 || xmax > 181.00) &&
          (ymin <  -91.00 || ymax >  91.00) )
    {
        return +1;  // projected into linear coordinates (easting/northing)
    }

    return 0;   // unable to determine correct projection type
}

static void check_aspect(
    double xmin, double xmax, double ymin, double ymax, double xdim, double ydim,
    int proj_type )
{
    // Check pixel aspect ratio and size of map extent:

    const double max_meters = 1000000.0;        // = 1000 kilometers
    const double distortion_limit = 15.0/16.0;  // must be < 1

    double xsize, ysize;
    double xres,  yres;
    double aspect;
    double ynarrow;
    double min_aspect;

    if (proj_type < 0) {
        geographic_scale( 0.5 * (ymin + ymax), &xsize, &ysize );

        xres = xsize * xdim;
        yres = ysize * ydim;

        // printf( "Assuming pixel aspect ratio of %5.3f based on latitude range.\n", xres / yres );
        // fflush( stdout );

        aspect = xsize / ysize;
        ynarrow = ymax >= -ymin ? ymax : ymin;
        min_aspect = geographic_aspect( ynarrow );
        if (min_aspect < aspect * distortion_limit ) {
            fprintf( stderr, "*** WARNING: " );
            fprintf( stderr, "Map area too large.\n" );
            fprintf( stderr, "***          " );
            fprintf( stderr, "(Small-scale maps require data to be in Mercator projection.)\n" );
            fprintf( stderr, "***          " );
            fprintf( stderr, "This will degrade the quality of the result.\n" );
        }
    } else {
        // printf( "Assuming pixel aspect ratio of %5.3f.\n", xdim / ydim );
        // fflush( stdout );

        if (proj_type != 2) {
            if (ymax - ymin > max_meters || xmax - xmin > max_meters) {
                fprintf( stderr, "*** WARNING: " );
                fprintf( stderr, "Map area too large. (Small-scale maps require -mercator option.)\n" );
                fprintf( stderr, "***          " );
                fprintf( stderr, "This will degrade the quality of the result.\n" );
            }
        }
    }
}

// Turn a geographic azimuth (xdim,ydim) into a grid-coordinate azimuth (xinc=yinc)
// az is in degrees, returns azimuth in degrees

static double fix_azimuth(double az, double xdim, double ydim )
{
  double val;
  val=rad2deg(atan(ydim/xdim*tan(deg2rad(az))));
  if (az>90) {
    val=val+180;
  }
  if (az>270) {
    val=val+180;
  }
  return val;
}


// Main terrain_filter function:
//
// int cast_shadows(
//     float *data,        // input/output: array of data to process (row-major order)
//     double sun_az,      // input: sun azimuth (degrees CW from north)
//     double sun_el,      // input: sun elevation (degrees above horizon)
//     int    nrows,       // input: number of rows    in data array
//     int    ncols,       // input: number of columns in data array
//     double xdim,        // input: spacing between pixel columns (in degrees or meters)
//     double ydim,        // input: spacing between pixel rows    (in degrees or meters)
//     enum Terrain_Coord_Type
//            coord_type,  // input: coordinate type for xdim & ydim (degrees or meters)
//     double center_lat  // input: latitude in degrees at center of data array
//                         //        (ignored if coord_type == TERRAIN_METERS)
// )
// // Computes shadows, replacing the contents of the data array.
// // Returns 0 on success, nonzero if an error occurred .
// {
//     int error;
//
//     int i, j;
//     float *ptr;
//
//     float data_min, data_max;
//
//     double normalizer;
//
//     double xres,   yres;
//     double xscale, yscale;
//     double xsize,  ysize;
//
//     // Determine pixel dimensions:
//
//     if (coord_type == TERRAIN_DEGREES) {
//         geographic_scale( center_lat, &xsize, &ysize );
//         // convert degrees to meters (approximately)
//         xres = xdim * xsize;
//         yres = ydim * ysize;
//     } else {
//         xres = xdim;
//         yres = ydim;
//     }
//
//     xscale = fabs( 1.0 / xres );
//     yscale = fabs( 1.0 / yres );
//
//     data_min = data[0];
//     data_max = data[0];
//
//     // Allocate shadow array
//     int (*shadowarray)[ncols]=malloc(ncols*nrows*sizeof(int));
//
//     int *shadowdata = (int *)malloc( (LONG)nrows * (LONG)ncols * sizeof( int ) );
//
//     if (!shadowdata) {
//         fprintf(stderr, "Insufficient memory for shadow array data." );
//         exit(1);
//     }
//
//     // This uses a linear index into the array whereas I want ptr[i][j]
//
//     for (i=0, ptr=data; i<nrows; ++i, ptr+=ncols) {
//         //float *ptr = data + (LONG)i * (LONG)ncols;
//         for (j=0; j<ncols; ++j) {
//             if (ptr[j] < data_min) {
//                 data_min = ptr[j];
//             } else if (ptr[j] > data_max) {
//                 data_max = ptr[j];
//             }
//         }
//     }
//     free(shadowdata);
//     return 0;
// }



#ifndef NOMAIN

int main( int argc, const char *argv[] )
{
    const int minargs = 4;  // including command name

    int last_count = -1;

    struct Terrain_Progress_Callback progress = { print_progress, &last_count };

    int argnum;

    const char *thisarg;
    char *endptr;
    char extension[4];  // 3 chars plus null terminator

    char *in_dat_name;
    char *in_hdr_name;
    char *in_prj_name;
    char *out_dat_name;
    char *out_hdr_name;
    char *out_prj_name;

    double detail;

    FILE *in_dat_file;
    FILE *in_hdr_file;
    FILE *in_prj_file;
    FILE *out_dat_file;
    FILE *out_hdr_file;
    FILE *out_prj_file;

    int nrows;
    int ncols;
    double xmin;
    double xmax;
    double ymin;
    double ymax;
    double xdim;
    double ydim;
    float *data;
    char *software;

    enum Terrain_Coord_Type coord_type;

    int proj_type;
    int has_nulls;
    int all_ints;

    double lat1 = 0.0;  // default unless -merc option used
    double lat2 = 0.0;  // default unless -merc option used
    double center_lat;
    double temp;

    double sun_az;
    double sun_el;
    // float *ptr;

    int error;

    // printf( "\nShadow mapping program - version %s, built %s\n", sw_version, sw_date );

    // Validate parameters:

//  command_name = "SHADOW";
    command_name = get_command_name( argv );

    if (argc == 1) {
        usage_exit( 0 );
    } else if (argc < minargs) {
        usage_exit( "Not enough command-line parameters." );
    }

    argnum = 1;

    thisarg = argv[argnum++];
    // read decimal number
    sun_az = strtod( thisarg, &endptr );
    if (endptr == thisarg || *endptr != '\0') {
        usage_exit( "First parameter (sun_az) must be a number." );
    }
    thisarg = argv[argnum++];
    // read decimal number
    sun_el = strtod( thisarg, &endptr );
    if (endptr == thisarg || *endptr != '\0') {
        usage_exit( "Second parameter (sun_el) must be a number." );
    }

    software = (char *)malloc( strlen(sw_format) + strlen(sw_name) + strlen(sw_version) + strlen(sw_date) );
    if (!software) {
        prefix_error();
        fprintf( stderr, "Memory allocation error occurred.\n" );
        exit( EXIT_FAILURE );
    }
    sprintf( software, sw_format, sw_name, sw_version, sw_date );

    // Validate filenames and open files:

    strncpy( extension, "flt", 4 );
    get_filenames( argv[argnum++], &in_dat_name, &in_hdr_name, &in_prj_name, extension );

    strncpy( extension, "flt", 4 );
    get_filenames( argv[argnum++], &out_dat_name, &out_hdr_name, &out_prj_name, extension );

    if (!strcmp( in_hdr_name, out_hdr_name )) {
        usage_exit( "Input and outfile filenames must not be the same." );
    }

    while (argnum < argc) {
        thisarg = argv[argnum++];
        if (*thisarg != '-') {
            prefix_error();
            fprintf( stderr, "Extra command-line parameter '%s' not recognized.\n", thisarg );
            usage_exit( 0 );
        }
        ++thisarg;
        if (strncmp( thisarg, "mercator", 4 ) == 0 || strncmp( thisarg, "Mercator", 4 ) == 0) {
            if (argnum+1 >= argc) {
                usage_exit( "Option -mercator must be followed by two numeric latitude values." );
            }
            thisarg = argv[argnum++];
            lat1 = strtod( thisarg, &endptr );
            if (endptr == thisarg || *endptr != '\0') {
                usage_exit( "Option -mercator must be followed by two numeric latitude values." );
            }
            thisarg = argv[argnum++];
            lat2 = strtod( thisarg, &endptr );
            if (endptr == thisarg || *endptr != '\0') {
                usage_exit( "Option -mercator must be followed by two numeric latitude values." );
            }
            if (lat1 == lat2) {
                usage_exit( "Min & max mercator latitudes cannot be equal." );
            }
            if (lat1 > lat2) {
                temp = lat1;
                lat1 = lat2;
                lat2 = temp;
            }
            if (lat1 <= -90.0 || lat2 >= 90.0) {
                usage_exit( "Mercator latitude limits must be between -90 and +90 (exclusive)." );
            }
        } else if (strncmp( thisarg, "cellreg", 4 ) == 0 ||
                   strncmp( thisarg, "corner",  6 ) == 0)
        {
            // ignore flag - cellreg is currently assumed
        } else if (strncmp( thisarg, "gridreg", 4 ) == 0 ||
                   strncmp( thisarg, "center",  6 ) == 0)
        {
            fprintf( stderr, "\n" );
            fprintf( stderr, "*** WARNING: " );
            fprintf( stderr, "Option -%s is not yet implemented.\n", thisarg );
            fprintf( stderr, "***          " );
            fprintf( stderr, "Treating data as cell-registered (corner-aligned).\n" );
        } else {
            prefix_error();
            fprintf( stderr, "Command-line option '-%s' not recognized.\n", thisarg );
            usage_exit( 0 );
        }
    }

    in_hdr_file = fopen( in_hdr_name, "rb" );   // use binary mode for compatibility
    if (!in_hdr_file) {
        prefix_error();
        fprintf( stderr, "Could not open input file '%s'.\n", in_hdr_name );
        usage_exit( 0 );
    }

    in_dat_file = fopen( in_dat_name, "rb" );
    if (!in_dat_file) {
        prefix_error();
        fprintf( stderr, "Could not open input file '%s'.\n", in_dat_name );
        usage_exit( 0 );
    }

    free( in_dat_name );
    free( in_hdr_name );

    out_hdr_file = fopen( out_hdr_name, "wb" ); // use binary mode for compatibility
    if (!out_hdr_file) {
        prefix_error();
        fprintf( stderr, "Could not open output file '%s'.\n", out_hdr_name );
        usage_exit( 0 );
    }

    out_dat_file = fopen( out_dat_name, "wb" );
    if (!out_dat_file) {
        prefix_error();
        fprintf( stderr, "Could not open output file '%s'.\n", out_dat_name );
        usage_exit( 0 );
    }

    free( out_dat_name );
    free( out_hdr_name );

    // Read .flt and .hdr files:

    // printf( "Reading input files...\n" );
    fflush( stdout );

    data = read_flt_hdr_files(
        in_dat_file, in_hdr_file, &nrows, &ncols, &xmin, &xmax, &ymin, &ymax,
        &has_nulls, &all_ints, 0 );

    fclose( in_dat_file );
    fclose( in_hdr_file );

    if (has_nulls) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr, "Input .flt file contains void (NODATA) points.\n" );
        fprintf( stderr, "***          " );
        fprintf( stderr, "Assuming these are ocean points - setting these elevations to 0.\n" );
    }

    if (all_ints && detail > 0.0) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr, "Input .flt file appears to contain only integer values.\n" );
        fprintf( stderr, "***          " );
        fprintf( stderr, "This may degrade the quality of the result.\n" );
    }

    // Process data:

    xdim = (xmax - xmin) / (double)ncols;
    ydim = (ymax - ymin) / (double)nrows;

    // determine projection type
    proj_type = determine_projection( xmin, xmax, ymin, ymax, xdim, ydim );

    if (proj_type < 0) {
        coord_type = TERRAIN_DEGREES;
        center_lat = 0.5 * (ymin + ymax);
        // printf( "\nInput data appears to be in lat/lon (geographic) coordinates.\n" );
        fflush( stdout );
    } else if (proj_type > 0) {
        coord_type = TERRAIN_METERS;
        center_lat = 0.0;   // ignored when coord_type == TERRAIN_METERS
        // printf( "\nInput data appears to be projected into linear coordinates " );
        // printf( "(easting/northing).\n" );
        fflush( stdout );
    } else {
        prefix_error();
        fprintf( stderr, "Unable to determine projection type from info in .hdr file.\n" );
        exit( EXIT_FAILURE );
    }

    if (lat1 != lat2) {
        if (proj_type < 0) {
            usage_exit( "Option -mercator is invalid for data in geographic coordinates." );
        }
        proj_type = 2;  // indicate Mercator projection
        // printf( "Assuming input data is in normal-aspect Mercator projection.\n" );
        // printf( "Latitude range %.3f deg %c to %.3f deg %c.\n",
        //     fabs(lat1), lat1>=0.0 ? 'N' : 'S', fabs(lat2), lat2>=0.0 ? 'N' : 'S' );
        // printf( "(NOTE: Do NOT use option -mercator with UTM projection.)\n\n" );

    }

    // check pixel aspect ratio and size of map extent
    check_aspect( xmin, xmax, ymin, ymax, xdim, ydim, proj_type );

    // printf(
    //     "Processing %d column x %d row array using sun_az = %f, sun_el = %f...\n",
    //     ncols, nrows, sun_az, sun_el );
    fflush( stdout );

    float *shadowarray2 = (float *)malloc( (LONG)nrows * (LONG)ncols * sizeof( float ) );
    float z_max=-999999;

    // Find maximum value to limit shadow search
    float *ptr;
    //
    for (int i=0; i<nrows; ++i) {
      ptr = data + (LONG)i * (LONG)ncols;
      for (int j=0; j<ncols; ++j) {
          if (ptr[j] > z_max) {
            z_max = ptr[j];
          }
      }
      ptr+=(LONG)ncols;
    }

    double zval;
    double x;
    double y;
    int lit;
    int x_int;
    int y_int;
    int xp_int;
    int yp_int;
    int i_smooth=4;

    double const_deg_m=111132;

    double csa=cos(deg2rad(sun_az));
    double ssa=sin(deg2rad(sun_az));

    double num_az= deg2rad(fix_azimuth(sun_az, xdim, ydim));
    // fprintf(stderr, "xdim=%f, ydim=%f, sun_az=%f, fixed sun look angle=%f\n", xdim, ydim, sun_az, fix_azimuth(sun_az+180, xdim, ydim));
    double num_el= deg2rad(sun_el);
    double sun_x = sin(num_az)*cos(num_el);
    double sun_y = -cos(num_az)*cos(num_el);
    double sun_z = sin(num_el)*sqrt(ydim*ydim*csa*csa+xdim*xdim*ssa*ssa);
    double xp;
    double yp;

    // fprintf(stderr, "zmax=%f, xdim=%f, ydim=%f, sun_x=%f, sun_y=%f, sun_z=%f\n", z_max, xdim, ydim, sun_x, sun_y, sun_z);

    double val;
    double this_z;
    float *ptr2;
    float *ptr3;
    int j;
    int i;
    int runcount;
    int i_set;
    int j_set;

    // Shadow algorithm

    for(int i=0;i<nrows;i++) {
      ptr = data + (LONG)i * (LONG)ncols;
      ptr2 = shadowarray2 + (LONG)i * (LONG)ncols;
      for(int j=0;j<ncols;j++) {
        x=j;
        y=i;
        zval=ptr[j];   // dataarray[row][column]
        lit=0;
        x_int=x;
        y_int=y;

        while(x_int > 0 && x_int < ncols && y_int > 0 && y_int < nrows && zval <= z_max) {
          ptr3 = data + (LONG)y_int * (LONG)ncols;
          if (zval < ptr3[x_int]) {
            lit=lit+(ptr3[x_int]-zval);  // Sum the height above the sun line
          }
          x=x+sun_x;
          y=y+sun_y;
          zval=zval+sun_z;
          x_int=(int) x;
          y_int=(int) y;
        }
        if (lit==0) {
          ptr2[j]=0;
        } else {
          ptr2[j]=log(lit);  // Use the natural logarithm of the total shading volume
        }
      }
    }

    if (error) {
        assert( error == TERRAIN_FILTER_MALLOC_ERROR );
        prefix_error();
        fprintf( stderr, "Memory allocation error occurred during processing of data.\n" );
        exit( EXIT_FAILURE );
    }

    // if (lat1 != lat2) {
    //     fix_mercator( data, detail, nrows, ncols, lat1, lat2 );
    // }

    // Write .flt and .hdr files:

    // printf( "Writing output files...\n" );
    fflush( stdout );

    write_flt_hdr_files(
        out_dat_file, out_hdr_file, nrows, ncols, xmin, xmax, ymin, ymax, shadowarray2, software );

    fclose( out_dat_file );
    fclose( out_hdr_file );

    free( data );
    free( software );

    // Copy optional .prj file:

    in_prj_file = fopen( in_prj_name, "rb" );   // use binary mode for compatibility
    if (in_prj_file) {
        out_prj_file = fopen( out_prj_name, "wb" ); // use binary mode for compatibility
        if (!out_prj_file) {
            fprintf( stderr, "*** WARNING: " );
            fprintf( stderr, "Could not open output file '%s'.\n", out_prj_name );
        } else {
            // copy file and change any "ZUNITS" line to "ZUNITS NO"
            copy_prj_file( in_prj_file, out_prj_file );

            fclose( out_prj_file );
        }
        fclose( in_prj_file );
    }

    free( in_prj_name );
    free( out_prj_name );

    // printf( "DONE.\n" );

    return EXIT_SUCCESS;
}

#endif
