/*
 * read_grid_files.c
 *
 * Created by Leland Brown on 2011 Feb 20.
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

// NOTE: In this file, type "float" is assumed to be 32 bits.

#define _CRT_SECURE_NO_DEPRECATE
#define _CRT_SECURE_NO_WARNINGS

#include "read_grid_files.h"

#include <stddef.h> // for ptrdiff_t
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

// For a 64-bit compile we need LONG to be 64 bits, even if the compiler uses an LLP64 model
#define LONG ptrdiff_t

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

static void make_lowercase( char *str )
{
    char *cptr;
    for (cptr=str; *cptr!='\0'; ++cptr) {
        *cptr = tolower( *cptr );
    }
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

static void parse_exit( const char *line )
{
    prefix_error();
    fprintf( stderr, "Trouble understanding format of input .hdr file at this line:\n" );
    fprintf( stderr, "%s\n", line );
    exit( EXIT_FAILURE );
}

static void bad_value_exit( const char *line, const char *expected )
{
    prefix_error();
    fprintf( stderr, "Input .hdr file contains unsupported value " );
    if (expected) {
        fprintf( stderr, "(expected %s)\n", expected );
    }
    fprintf( stderr, "at this line:\n" );
    fprintf( stderr, "%s\n", line );
    exit( EXIT_FAILURE );
}

static void bad_zero_exit( const char *line )
{
    prefix_error();
    fprintf( stderr, "Input .hdr file contains unexpected zero value at this line:\n" );
    fprintf( stderr, "%s\n", line );
    exit( EXIT_FAILURE );
}

static void negative_exit( const char *line, int value )
{
    if (value == 0) {
        bad_zero_exit( line );
    }
    prefix_error();
    fprintf( stderr, "Input .hdr file contains unexpected negative value\n" );
    fprintf( stderr, "at this line:\n" );
    fprintf( stderr, "%s\n", line );
    exit( EXIT_FAILURE );
}

static void read_int( const char *line, int pos, int *value )
{
    if (sscanf( line+pos, "%d", value ) != 1) {
        parse_exit( line );
    }
}

static void read_float( const char *line, int pos, float *value )
{
    if (sscanf( line+pos, "%f", value ) != 1) {
        parse_exit( line );
    }
}

static void read_double( const char *line, int pos, double *value )
{
    if (sscanf( line+pos, "%lf", value ) != 1) {
        parse_exit( line );
    }
}

static void read_string( const char *line, int pos, char *value )
{
    if (sscanf( line+pos, "%s", value ) != 1) {
        parse_exit( line );
    }
    make_lowercase( value );
}

static void read_hdr_file(
    FILE *in_hdr_file, int *nrows, int *ncols,
    double *xmin, double *xmax, double *ymin, double *ymax,
    float *nodata, int *big_endian, int *skipbytes, int *rowpad,
    char **software );

static float *read_flt_file(
    FILE *in_flt_file, int nrows, int ncols,
    float nodata, int big_endian, int skipbytes, int rowpad,
    int *has_nulls, int *all_ints );

float *read_flt_hdr_files(
    // returns allocated array of data values;
    // NOTE: caller is responsible to free this pointer!
    FILE *in_flt_file,  // .flt file - should be opened in BINARY mode
    FILE *in_hdr_file,  // .hdr file - should be opened in BINARY mode
    int *nrows,         // number of rows in data array
    int *ncols,         // number of cols in data array
    double *xmin,       // min X coordinate (longitude or easting)
    double *xmax,       // max X coordinate (longitude or easting)
    double *ymin,       // min Y coordinate (latitude  or northing)
    double *ymax,       // max Y coordinate (latitude  or northing)
    int *has_nulls,
    int *all_ints,
    char * (*software)  // if software != 0, returns with *software either
                        // null or pointing to a software name/version string;
                        // caller is responsible to free *software pointer!
)
{
    float nodata;
    int big_endian;
    int skipbytes;
    int rowpad;

    // Read and validate .hdr file:

    read_hdr_file(
        in_hdr_file, nrows, ncols, xmin, xmax, ymin, ymax,
        &nodata, &big_endian, &skipbytes, &rowpad, software );

    // Read data from .flt file:

    return read_flt_file(
        in_flt_file, *nrows, *ncols, nodata, big_endian, skipbytes, rowpad,
        has_nulls, all_ints );
}

#define MAXLINE 80

static void read_hdr_file(
    FILE *in_hdr_file, int *nrows, int *ncols,
    double *xmin, double *xmax, double *ymin, double *ymax,
    float *nodata, int *big_endian, int *skipbytes, int *rowpad,
    char **software )
{
    char line   [MAXLINE+3];    // add 3 for possible "\r\n\0" terminators
    char keyword[MAXLINE+3];
    char strval [MAXLINE+1];
    
    int   pos;
    char *ptr;
    
    int    intval;
    float  fltval;
    double dblval;
    
    double xdim = 0.0;
    double ydim = 0.0;
    double xcoord;
    double ycoord;
    int xcoord_type = 0;
    int ycoord_type = 0;
    int bandrow  = 0;
    int totalrow = 0;

    // Read .hdr file:

    *big_endian = 0;    // default is little-endian (LSBFIRST)
    *ncols = 0;
    *nrows = 0;
    *nodata = -3.40282347e+38;
    *skipbytes = 0;
    if (software) {
        *software = 0;
    }

    while (fgets( line, MAXLINE+3, in_hdr_file )) {
        // error here if line longer than MAXLINE characters?
        
        if (sscanf( line, "%s %n", keyword, &pos ) > 0) {
            make_lowercase( keyword );
            if (strcmp( keyword, "ncols" ) == 0) {
                read_int( line, pos, ncols );
                if (*ncols <= 0) {
                    negative_exit( line, *ncols );
                }
            } else if (strcmp( keyword, "nrows" ) == 0) {
                read_int( line, pos, nrows );
                if (*nrows <= 0) {
                    negative_exit( line, *nrows );
                }
            } else if (strcmp( keyword, "xllcorner" ) == 0) {
                read_double( line, pos, &xcoord );
                xcoord_type = 1;
            } else if (strcmp( keyword, "yllcorner" ) == 0) {
                read_double( line, pos, &ycoord );
                ycoord_type = 1;
            } else if (strcmp( keyword, "xllcenter" ) == 0) {
                read_double( line, pos, &xcoord );
                xcoord_type = 2;
            } else if (strcmp( keyword, "yllcenter" ) == 0) {
                read_double( line, pos, &ycoord );
                ycoord_type = 2;
            } else if (strcmp( keyword, "ulxmap" ) == 0) {
                read_double( line, pos, &xcoord );
                xcoord_type = 3;
            } else if (strcmp( keyword, "ulymap" ) == 0) {
                read_double( line, pos, &ycoord );
                ycoord_type = 3;
            } else if (strcmp( keyword, "cellsize" ) == 0) {
                read_double( line, pos, &xdim );
                ydim = xdim;
                if (xdim == 0.0) {
                    bad_zero_exit( line );
                }
            } else if (strcmp( keyword, "xdim" ) == 0) {
                read_double( line, pos, &xdim );
                if (xdim == 0.0) {
                    bad_zero_exit( line );
                }
            } else if (strcmp( keyword, "ydim" ) == 0) {
                read_double( line, pos, &ydim );
                if (ydim == 0.0) {
                    bad_zero_exit( line );
                }
            } else if (strcmp( keyword, "nodata_value" ) == 0) {
                read_float( line, pos, nodata );
            } else if (strcmp( keyword, "nodata" ) == 0) {
                read_float( line, pos, nodata );
            } else if (strcmp( keyword, "nbands" ) == 0) {
                read_int( line, pos, &intval );
                if (intval != 1) {
                    bad_value_exit( line, "1" );
                }
            } else if (strcmp( keyword, "nbits" ) == 0) {
                read_int( line, pos, &intval );
                if (intval == 8 ||
                    intval == 16 ||
                    intval != 32)
                {
                    bad_value_exit( line, "32" );
                }
            } else if (strcmp( keyword, "skipbytes" ) == 0) {
                read_int( line, pos, skipbytes );
                if (*skipbytes < 0) {
                    negative_exit( line, *skipbytes );
                }
            } else if (strcmp( keyword, "bandrowbytes" ) == 0) {
                read_int( line, pos, &bandrow );
                if (bandrow <= 0) {
                    negative_exit( line, bandrow );
                }
            } else if (strcmp( keyword, "totalrowbytes" ) == 0) {
                read_int( line, pos, &totalrow );
                if (totalrow <= 0) {
                    negative_exit( line, totalrow );
                }
            } else if (strcmp( keyword, "bandgapbytes" ) == 0) {
                read_int( line, pos, &intval );
                if (intval != 0) {
                    bad_value_exit( line, "0" );
                }
            } else if (strcmp( keyword, "min_value" ) == 0) {   // MIN_VALUE ignored
                read_float( line, pos, &fltval );
            } else if (strcmp( keyword, "max_value" ) == 0) {   // MAX_VALUE ignored
                read_float( line, pos, &fltval );
            } else if (strcmp( keyword, "byteorder" ) == 0) {
                read_string( line, pos, strval );
                if (strcmp( strval, "lsbfirst" ) == 0) {
                    *big_endian = 0;
                } else if (strcmp( strval, "i" ) == 0) {
                    *big_endian = 0;
                } else if (strcmp( strval, "msbfirst" ) == 0) {
                    *big_endian = 1;
                } else if (strcmp( strval, "m" ) == 0) {
                    *big_endian = 1;
                } else {
                    bad_value_exit( line, NULL );
                }
            } else if (strcmp( keyword, "layout" ) == 0) {
                read_string( line, pos, strval );
                if (strcmp( strval, "bip" ) == 0 ||
                    strcmp( strval, "bsq" ) == 0 ||
                    strcmp( strval, "bil" ) != 0)
                {
                    bad_value_exit( line, "BIL" );
                }
            } else if (strcmp( keyword, "numbertype" ) == 0) {
                read_string( line, pos, strval );
                if (strcmp( strval, "1_byte_integer" ) == 0 ||
                    strcmp( strval, "byte" ) == 0)
                {
                    bad_value_exit( line, NULL );
                } else if (strcmp( strval, "2_byte_integer" ) == 0) {
                    bad_value_exit( line, NULL );
                } else if (strcmp( strval, "4_byte_float" ) != 0) {
                    bad_value_exit( line, NULL );
                }
            } else if (strcmp( keyword, "pixeltype" ) == 0) {
                read_string( line, pos, strval );
                if (strcmp( strval, "signedint" ) == 0) {
                    bad_value_exit( line, NULL );
                } else if (strcmp( strval, "unsignedint" ) == 0) {
                    bad_value_exit( line, NULL );
                } else if
                    (strcmp( strval, "float" ) != 0 &&
                     strcmp( strval, "floatingpoint" ) != 0)
                {
                    bad_value_exit( line, NULL );
                }
            } else if (strcmp( keyword, "offset" ) == 0) {  // OFFSET ignored
                read_float( line, pos, &fltval );
            } else if (strcmp( keyword, "scale" ) == 0) {   // SCALE ignored
                read_float( line, pos, &fltval );
            } else if (strcmp( keyword, "units" ) == 0) {   // UNITS ignored
                read_string( line, pos, strval );
            } else if (strcmp( keyword, "zunits" ) == 0) {  // ZUNITS ignored
                read_string( line, pos, strval );
            } else if (strcmp( keyword, "software" ) == 0) {
                if (software) {
                    free( *software );
                    *software = (char *)malloc( strlen(line+pos) + 1 );
                    if (!*software) {
                        error_exit( "Memory allocation error occurred while reading .hdr file." );
                    }
                    strcpy( *software, line+pos );
                    ptr = strpbrk( *software, "\r\n" );
                    if (ptr) {
                        *ptr = '\0';
                    }
                }
            } else {
                fprintf( stderr, "*** WARNING - " );
                fprintf( stderr, "Input .hdr file contains unrecognized keyword at this line:\n" );
                fprintf( stderr, "%s\n", line );
            }
        }
        
        // make sure entire input line has been read
        // (and ignore remainder of line - can be used for comments)
        while (!strchr( line, '\n' ) && fgets( line, MAXLINE+3, in_hdr_file )) { }
    }
    
    if (!feof( in_hdr_file )) {
        error_exit( "Read error occurred on input .hdr file." );
    }
    
    // Validate values read from .hdr file:
    
    if (*ncols == 0) {
        error_exit( "Input .hdr file does not specify NCOLS." );
    } else if (*nrows == 0) {
        error_exit( "Input .hdr file does not specify NROWS." );
    }
    
    if (bandrow && bandrow != 4 * (*ncols)) {
        prefix_error();
        fprintf( stderr, "Input .hdr file contains unsupported value for BANDROWBYTES\n" );
        fprintf( stderr, "(expected 4 x NCOLS).\n" );
        exit( EXIT_FAILURE );
    }
    
    bandrow = 4 * (*ncols);
    
    if (totalrow) {
        *rowpad = totalrow - bandrow;
    } else {
        *rowpad = 0;
    }
    
    if (*rowpad < 0) {
        prefix_error();
        fprintf( stderr, "Input .hdr file contains bad value for TOTALROWBYTES\n" );
        fprintf( stderr, "(expected at least 4 x NCOLS).\n" );
        exit( EXIT_FAILURE );
    }
    
    if (xdim == 0.0) {
        error_exit( "Input .hdr file does not specify CELLSIZE or XDIM." );
    }
    if (ydim == 0.0) {
        error_exit( "Input .hdr file does not specify CELLSIZE or YDIM." );
    }
    
    switch (xcoord_type) {
        case 1: // XLLCORNER
            *xmin = xcoord;
            *xmax = xcoord + xdim * (*ncols);
            break;
        case 2: case 3: // XLLCENTER or ULXMAP
            *xmin = xcoord - xdim * 0.5;
            *xmax = xcoord + xdim * (*ncols - 0.5);
            break;
        default:
            error_exit( "Input .hdr file does not specify XLLCORNER or XLLCENTER or ULXMAP." );
    }

    switch (ycoord_type) {
        case 1: // YLLCORNER
            *ymin = ycoord;
            *ymax = ycoord + ydim * (*nrows);
            break;
        case 2: // YLLCENTER
            *ymin = ycoord - ydim * 0.5;
            *ymax = ycoord + ydim * (*nrows - 0.5);
            break;
        case 3: // ULYMAP
            *ymax = ycoord + ydim * 0.5;
            *ymin = ycoord - ydim * (*nrows - 0.5);
            break;
        default:
            error_exit( "Input .hdr file does not specify YLLCORNER or YLLCENTER or ULYMAP." );
    }
    
    if (xdim < 0.0 ) {
        dblval = *xmin;
        *xmin  = *xmax;
        *xmax  = dblval;
    }
    if (ydim < 0.0 ) {
        dblval = *ymin;
        *ymin  = *ymax;
        *ymax  = dblval;
    }
}

void copy_prj_file( FILE *in_prj_file, FILE *out_prj_file )
// Copies input .prj file to output .prj file, and changes any "ZUNITS" line to "ZUNITS NO"
{
    char line   [MAXLINE+3];    // add 3 for possible "\r\n\0" terminators
    char keyword[MAXLINE+3];
    char strval [MAXLINE+1];
    
    int pos, pos2;
    
    int error = 0;
    
    // Read and write .prj files:

    while (fgets( line, MAXLINE+3, in_prj_file )) {
        
        pos = 0;
        
        if (sscanf( line, "%s %n", keyword, &pos ) > 0) {
            // write keyword and optional whitespace
            error = error || 0 > fprintf( out_prj_file, "%.*s", pos, line );
            make_lowercase( keyword );
            if (strcmp( keyword, "zunits" ) == 0) {
                if (sscanf( line+pos, "%s%n", strval, &pos2 ) > 0) {
                    // check that entire value string was read
                    if (line[pos+pos2] != '\0') {
                        // skip input ZUNITS value and write "NO" instead
                        pos += pos2;
                        error = error || 0 > fprintf( out_prj_file, "NO" );
                    }
                }
            }
        }
        
        // write remainder of line read
        error = error || 0 > fprintf( out_prj_file, "%s", line+pos );
        
        // make sure entire input line has been read and copy remainder of line
        while (!strchr( line, '\n' ) && fgets( line, MAXLINE+3, in_prj_file )) {
            error = error || 0 > fprintf( out_prj_file, "%s", line );
        }
    }
    
    error = error || fflush( out_prj_file );
    
    if (!feof( in_prj_file )) {
        error_exit( "Read error occurred on input .prj file." );
    }

    if (error) {
        error_exit( "Write error occurred on output .prj file." );
    }
}

static float *read_flt_file(
    FILE *in_flt_file, int nrows, int ncols,
    float nodata, int big_endian, int skipbytes, int rowpad,
    int *has_nulls, int *all_ints )
{
    union {
        float f;
        char c[4];
    } pun;

    float *data;
    float *ptr;
    int i, j;
    int count;
    int error;
    char c;
    int reverse_bytes = ( am_big_endian() != big_endian );
    char temp;
    
    *has_nulls = 0;
    *all_ints  = 1;

    // Read data from .flt file:

    data = (float *)malloc( (LONG)nrows * (LONG)ncols * sizeof( float ) );

    if (!data) {
        error_exit( "Insufficient memory for input .flt data." );
    }

    error = fseek( in_flt_file, skipbytes, SEEK_CUR );
    if (error) {
        error_exit( "Read error occurred on input .flt file." );
    }

    for (i=0, ptr=data; i<nrows; ++i, ptr+=ncols) {
        count = fread( ptr, sizeof( float ), ncols, in_flt_file );
        if (count < ncols) {
            if (feof( in_flt_file )) {
                error_exit( "Input .flt file size too small - does not match .hdr info." );
            } else {
                error_exit( "Read error occurred on input .flt file." );
            }
        }
        
        if (reverse_bytes) {
            for (j=0; j<ncols; ++j) {
                pun.f = ptr[j];
                temp = pun.c[0];
                pun.c[0] = pun.c[3];
                pun.c[3] = temp;
                temp = pun.c[1];
                pun.c[1] = pun.c[2];
                pun.c[2] = temp;
                ptr[j] = pun.f;
            }
        }

        for (j=0; j<ncols; ++j) {
            if (flt_isnan( ptr[j] )) {
                prefix_error();
                fprintf( stderr, "Input .flt file contains NaNs - probably bad data" );
                fprintf( stderr, "(or wrong .hdr file).\n" );
                exit( EXIT_FAILURE );
            }
            if (ptr[j] == nodata || ptr[j] < -1.0e+38) {
                ptr[j] = 0.0;
                *has_nulls = 1;
            } else if (*all_ints && ptr[j] != floor( ptr[j] )) {
                *all_ints = 0;
            }
        }

        error = fseek( in_flt_file, rowpad, SEEK_CUR );
        if (error) {
            error_exit( "Read error occurred on input .flt file." );
        }
    }
    
    fread( &c, 1, 1, in_flt_file );
    if (!feof( in_flt_file )) {
        fprintf( stderr, "*** WARNING: " );
        fprintf( stderr, "Input .flt file size too large - does not match .hdr info.\n" );
    }
    
    return data;
}
