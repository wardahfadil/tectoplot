/*
 * write_grid_files.c
 *
 * Created by Leland Brown on 2011 Feb 21.
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

// NOTE: In this file, type "float" is assumed to be 32 bits and "short" 16 bits.

#define _CRT_SECURE_NO_DEPRECATE
#define _CRT_SECURE_NO_WARNINGS

#include "write_grid_files.h"

#include "WriteGrayscaleTIFF.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

static int am_big_endian()
{
    const int one = 1;
    return !*(char *)&one;
}

static int flt_isnan( float x )
{
    volatile float y = x;
    return y != y;
}

static void prefix_error()
{
    fprintf( stderr, "\n*** ERROR: " );
}

static void error_exit( const char *message )
{
    prefix_error();
    fprintf( stderr, "%s\n", message );
    exit( EXIT_FAILURE );
}

static void write_flt_file(
    FILE *out_flt_file, int nrows, int ncols,
    const float *data, float *nodata, float *min_value, float *max_value );

static void write_bil_file(
    FILE *out_bil_file, int nrows, int ncols, const float *data,
    unsigned short *nodata, unsigned short *min_value, unsigned short *max_value );

// If flt_data_type = 0, writes header for file of 16-bit unsigned ints in BIL format;
// nodata, min_value, and max_value are assumed to be integers in the range 0 to 65535.
// If flt_data_type = 1, writes header for file of 32-fit floats in BIL format.
static void write_hdr_file(
    FILE *out_hdr_file, int nrows, int ncols,
    double xmin, double xmax, double ymin, double ymax,
    float nodata, float min_value, float max_value,
    int flt_data_type, const char *software);

static void write_tfw_file(
    FILE *out_hdr_file, int nrows, int ncols,
    double xmin, double xmax, double ymin, double ymax );

void write_flt_hdr_files(
    FILE *out_flt_file, // .flt file - should be opened in BINARY mode
    FILE *out_hdr_file, // .hdr file - should be opened in BINARY mode
    int nrows,          // number of rows in data array
    int ncols,          // number of cols in data array
    double xmin,        // min X coordinate (longitude or easting)
    double xmax,        // max X coordinate (longitude or easting)
    double ymin,        // min Y coordinate (latitude  or northing)
    double ymax,        // max Y coordinate (latitude  or northing)
    const float *data,  // array of data values
    const char *software // software name and version number (optional)
)
{
    float nodata;
    float min_value;
    float max_value;

    // Write .flt file and find min/max values:

    write_flt_file( out_flt_file, nrows, ncols, data, &nodata, &min_value, &max_value );

    // Write .hdr file:

    write_hdr_file(
        out_hdr_file, nrows, ncols, xmin, xmax, ymin, ymax,
        nodata, min_value, max_value, 1, software );
}

void write_bil_hdr_files(
    FILE *out_bil_file, // .bil file - should be opened in BINARY mode
    FILE *out_hdr_file, // .hdr file - should be opened in BINARY mode
    int nrows,          // number of rows in data array
    int ncols,          // number of cols in data array
    double xmin,        // min X coordinate (longitude or easting)
    double xmax,        // max X coordinate (longitude or easting)
    double ymin,        // min Y coordinate (latitude  or northing)
    double ymax,        // max Y coordinate (latitude  or northing)
    const float *data,  // array of data values
    const char *software // software name and version number (optional)
)
{
    unsigned short nodata;
    unsigned short min_value;
    unsigned short max_value;

    // Write .bil file and find min/max values:

    write_bil_file( out_bil_file, nrows, ncols, data, &nodata, &min_value, &max_value );

    // Write .hdr file:

    write_hdr_file(
        out_hdr_file, nrows, ncols, xmin, xmax, ymin, ymax,
        (float)nodata, (float)min_value, (float)max_value, 0, software );
}

void write_tif_tfw_files(
    FILE *out_tif_file, // .tif file - should be opened in BINARY mode
    FILE *out_tfw_file, // .tfw file - should be opened in BINARY mode
    int nrows,          // number of rows in data array
    int ncols,          // number of cols in data array
    double xmin,        // min X coordinate (longitude or easting)
    double xmax,        // max X coordinate (longitude or easting)
    double ymin,        // min Y coordinate (latitude  or northing)
    double ymax,        // max Y coordinate (latitude  or northing)
    const float *data,  // array of data values
    const char *software // software name and version number (optional)
)
{
    int error;
    size_t fileSize;
    
    // Write .tif file:

    error = WriteGrayscale16BitToTIFF( out_tif_file, ncols, nrows, data, software, &fileSize );
    if (error == -2) {
        error_exit( "Memory allocation error occurred during file output." );
    }
    if (error) {
        error_exit( "Write error occurred on output .tif file." );
    }
    
    if ((fileSize-1)>>31 > 1) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr,
            "File size too big for basic TIFF - using BigTIFF format instead.\n" );
        fprintf( stderr, "***          " );
        fprintf( stderr,
            "This may not be readable by some TIFF readers.\n" );
    } else if (fileSize>>31) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr,
            "Output TIFF file size exceeds 2 gigabytes.\n" );
        fprintf( stderr, "***          " );
        fprintf( stderr,
            "This may not be readable by some TIFF readers.\n" );
    }

    // Write .tfw file:

    write_tfw_file( out_tfw_file, nrows, ncols, xmin, xmax, ymin, ymax );
}

static void write_flt_file(
    FILE *out_flt_file, int nrows, int ncols,
    const float *data, float *nodata, float *min_value, float *max_value )
{
    // Write .flt file and find min/max values:
    
    int i, j;
    int count;
    int has_nulls = 0;
    int error;

    const float *ptr;

    int bufsize = ncols * sizeof( float );
    float *buffer = (float *)malloc( bufsize );
    
    if (!buffer) {
        error_exit( "Memory allocation error occurred during file output." );
    }
    
    *nodata = -1.0e+06; // must be negative for code below to work correctly
    //*nodata = -1.0e+38;

    *min_value = *data;
    *max_value = *data;

    for (i=0, ptr=data; i<nrows; ++i, ptr+=ncols) {
        memcpy( buffer, ptr, bufsize );
        
        for (j=0; j<ncols; ++j) {
            if (flt_isnan( buffer[j] )) {
                buffer[j] = *nodata;
                has_nulls = 1;
                continue;
            }
            if (!has_nulls) {
                if (buffer[j] < *nodata * 0.5) {    // assumes nodata < 0
                    *nodata *= 10.0;
                }
            } else if (buffer[j] == *nodata) {
                prefix_error();
                fprintf( stderr, "Actual output data point matches chosen NODATA value of " );
                fprintf( stderr, "%.6g.\n", *nodata );
                exit( EXIT_FAILURE );
            }
            if (buffer[j] < *min_value) {
                *min_value = buffer[j];
            } else if (buffer[j] > *max_value) {
                *max_value = buffer[j];
            }
        }

        count = fwrite( buffer, sizeof( float ), ncols, out_flt_file );
        if (count < ncols) {
            error_exit( "Write error occurred on output .flt file." );
        }
    }
    
    error = fflush( out_flt_file );
    
    if (error) {
        error_exit( "Write error occurred on output .flt file." );
    }

    if (*min_value <= *nodata && *max_value >= *nodata) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr,
            "NODATA value of %.6g is within range of actual output data.\n", *nodata );
        fprintf( stderr, "***          " );
        fprintf( stderr,
            "This could possibly cause good data to be identified as NODATA.\n" );
    }
}

static void write_bil_file(
    FILE *out_bil_file, int nrows, int ncols, const float *data,
    unsigned short *nodata, unsigned short *min_value, unsigned short *max_value )
{
    // Write .bil file and find min/max values:
    
    int i, j;
    int count;
    int error;

    float fltval;
    unsigned short intval;

    const float *ptr;

    const unsigned short max_limit = 65534;
    const unsigned short min_limit = 1;     // must be >= 0

    const float flt_max_limit = (float)max_limit;
    const float flt_min_limit = (float)min_limit;

    int bufsize = ncols * sizeof( unsigned short );
    unsigned short *buffer = (unsigned short *)malloc( bufsize );
    
    if (!buffer) {
        error_exit( "Memory allocation error occurred during file output." );
    }
    
    *nodata = 0;
    //*nodata = 65535;

    // initialize min & max values to opposite limits
    *min_value = max_limit;
    *max_value = min_limit;

    for (i=0, ptr=data; i<nrows; ++i, ptr+=ncols) {
        for (j=0; j<ncols; ++j) {
            if (flt_isnan( ptr[j] )) {
                buffer[j] = *nodata;
                continue;
            }

            fltval = ptr[j] + 0.5;
            // check limits before integer conversion to avoid overflow
            if (fltval <= flt_min_limit) {
                intval = min_limit;
            } else if (fltval >= flt_max_limit) {
                intval = max_limit;
            } else {
                intval = (unsigned short)floor( fltval );   // rounds down as long as fltval>=0
            }

            if (intval < *min_value) {
                *min_value = intval;
            } else if (intval > *max_value) {
                *max_value = intval;
            }

            buffer[j] = intval;
        }

        count = fwrite( buffer, sizeof( unsigned short ), ncols, out_bil_file );
        if (count < ncols) {
            error_exit( "Write error occurred on output .bil file." );
        }
    }
    
    error = fflush( out_bil_file );
    
    if (error) {
        error_exit( "Write error occurred on output .bil file." );
    }
}

static void write_hdr_file(
    FILE *out_hdr_file, int nrows, int ncols,
    double xmin, double xmax, double ymin, double ymax,
    float nodata, float min_value, float max_value,
    int flt_data_type, const char *software )
// If flt_data_type = 0, writes header for file of 16-bit unsigned ints in BIL format;
// nodata, min_value, and max_value are assumed to be integers in the range 0 to 65535.
// If flt_data_type = 1, writes header for file of 32-fit floats in BIL format.
{
    // Write .hdr file:
    
    double xdim = (xmax - xmin) / (double)ncols;
    double ydim = (ymax - ymin) / (double)nrows;
    
    int error = 0;
    
    int nbits;
    const char *layout;
    const char *pixeltype;

    if (flt_data_type) {
        nbits = 32;
        layout = "BIL";
        pixeltype = "FLOAT";
    } else {
        nbits = 16;
        layout = "BIL";
        pixeltype = "UNSIGNEDINT";
    }

    error = error || 0 > fprintf( out_hdr_file, "%-13s %d\r\n", "ncols", ncols );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %d\r\n", "nrows", nrows );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %.14g\r\n", "xllcorner", xmin );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %.14g\r\n", "yllcorner", ymin );
    if  (fabs( (xmax - xmin) / ydim - ncols ) < 0.25 &&
         fabs( (ymax - ymin) / xdim - nrows ) < 0.25)
    {
        // xdim == ydim
        double cellsize = 2.0 * xdim * ydim / (xdim + ydim);    // harmonic mean
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.14g\r\n", "cellsize", cellsize );
    } else {
        // xdim != ydim
        // warning message here?
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.14g\r\n", "xdim", xdim );
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.14g\r\n", "ydim", ydim );
    }
    error = error || 0 > fprintf( out_hdr_file, "%-13s %.6g\r\n", "NODATA_value", nodata );
    if (am_big_endian()) {
        error = error || 0 > fprintf( out_hdr_file, "%-13s %s\r\n", "byteorder", "MSBFIRST" );
    } else {
        error = error || 0 > fprintf( out_hdr_file, "%-13s %s\r\n", "byteorder", "LSBFIRST" );
    }

    error = error || 0 > fprintf( out_hdr_file, "%-13s %s\r\n", "layout", layout );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %d\r\n", "nbands", 1 );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %d\r\n", "nbits", nbits );
    error = error || 0 > fprintf( out_hdr_file, "%-13s %s\r\n", "pixeltype", pixeltype );

    if (flt_data_type) {
        // warning here if these both small relative to precision printed?
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.1f\r\n", "min_value", min_value );
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.1f\r\n", "max_value", max_value );
    } else {
        // write min_value and max_value as integers
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.0f\r\n", "min_value", min_value );
        error = error || 0 > fprintf( out_hdr_file, "%-13s %.0f\r\n", "max_value", max_value );
    }
    
    if (software) {
        error = error || 0 > fprintf( out_hdr_file, "%-13s %s\r\n", "software", software );
    }
    
    error = error || fflush( out_hdr_file );
    
    if (error) {
        error_exit( "Write error occurred on output .hdr file." );
    }
}

static void write_tfw_file(
    FILE *out_tfw_file, int nrows, int ncols,
    double xmin, double xmax, double ymin, double ymax )
{
    // Write .tfw file:
    
    double xdim = (xmax - xmin) / (double)ncols;
    double ydim = (ymax - ymin) / (double)nrows;
    
    double ulxmap = xmin + xdim * 0.5;
    double ulymap = ymax - ydim * 0.5;

    int error = 0;

    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", xdim );
    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", 0.0 );
    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", 0.0 );
    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", -ydim );
    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", ulxmap );
    error = error || 0 > fprintf( out_tfw_file, "%.14g\r\n", ulymap );

    error = error || fflush( out_tfw_file );
    
    if (error) {
        error_exit( "Write error occurred on output .tfw file." );
    }
}
