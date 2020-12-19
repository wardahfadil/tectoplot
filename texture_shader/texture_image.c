/*
 * texture_image.c
 *
 * Created by Leland Brown on 2013 Nov 03.
 *
 * Copyright (c) 2013 Leland Brown.
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
#include "terrain_filter.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// CAUTION: This __DATE__ is only updated when THIS file is recompiled.
// If other source files are modified but this file is not touched,
// the version date may not be correct.
static const char sw_name[]    = "Texture_Image";
static const char sw_version[] = "1.3.1";
static const char sw_date[]    = __DATE__;

static const char sw_format[] = "%s%s%s v%s %s";

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
    fprintf( stderr, "USAGE:    %s contrast texture_file output_file\n",   command_name );
    fprintf( stderr, "Examples: %s 2.5 rainier_tex.flt rainier_img.tif\n", command_name );
    fprintf( stderr, "          %s  -1 rainier_tex rainier_img\n",         command_name );
    fprintf( stderr, "\n" );
    fprintf( stderr, "Typical range for contrast is -4.0 to +10.0.\n" );
    fprintf( stderr, "\n" );
    fprintf( stderr, "Requires both .flt and .hdr files as input  " );
    fprintf( stderr, "(e.g., rainier_tex.flt and rainier_tex.hdr).\n" );
    fprintf( stderr, "Writes   both .tif and .tfw files as output " );
    fprintf( stderr, "(e.g., rainier_img.tif  and rainier_img.tfw).\n" );
    fprintf( stderr, "Also reads & writes optional .prj file if present " );
    fprintf( stderr, "(e.g., rainier_tex.prj to rainier_img.prj).\n" );
    fprintf( stderr, "Input and output filenames must not be the same.\n" );
    fprintf( stderr, "NOTE: Output files will be overwritten if they already exist.\n" );
    fprintf( stderr, "\n" );
    exit( EXIT_FAILURE );
}

static void get_filenames(
    const char *arg, char **data_name, char **hdr_name, char **prj_name, char *ext, char *hdr )
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
        if (strcmp( dot, "flt" ) != 0 && strcmp( dot, "FLT" ) != 0 &&
            strcmp( dot, "tif" ) != 0 && strcmp( dot, "TIF" ) != 0)
        {
            usage_exit( "Filenames must have .flt or .tif extension (if any)." );
        }
        strcpy ( *data_name, arg );
        strncpy( *hdr_name, arg, len-3 );
        strncpy( *hdr_name+len-3, hdr, 3 );
        (*hdr_name)[len] = '\0';
        strncpy( *prj_name, arg, len-3 );
        strcpy ( *prj_name+len-3, "prj" );
    } else {
        // filename does not have extension
        strncpy( *data_name, arg, len );
        (*data_name)[len] = '.';
        strncpy( *data_name+len+1, ext, 3 );    // max 3 chars default extension
        (*data_name)[len+4] = '\0';
        strncpy( *hdr_name, arg, len );
        (*hdr_name)[len] = '.';
        strncpy( *hdr_name+len+1, hdr, 3 );
        (*hdr_name)[len+4] = '\0';
        strncpy( *prj_name, arg, len );
        strcpy ( *prj_name+len, ".prj" );
    }
}

#ifndef NOMAIN

int main( int argc, const char *argv[] )
{
    const int numargs = 4;  // including command name
    
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

    double contrast;

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
    float *data;
    char *software1;
    char *software2;
    char *separator;
    
    int has_nulls;
    int all_ints;

    printf( "\nTexture shading image data generator - version %s, built %s\n", sw_version, sw_date );

    // Validate parameters:

//  command_name = "TEXTURE_IMAGE";
    command_name = get_command_name( argv );

    if (argc == 1) {
        usage_exit( 0 );
    } else if (argc < numargs) {
        usage_exit( "Not enough command-line parameters." );
    } else if (argc > numargs) {
        usage_exit( "Too many command-line parameters." );
    }
    
    argnum = 1;
    
    thisarg = argv[argnum++];
    contrast = strtod( thisarg, &endptr );
    if (endptr == thisarg || *endptr != '\0') {
        usage_exit( "First parameter (contrast) must be a number." );
    }

    // Validate filenames and open files:

    strncpy( extension, "flt", 4 );
    get_filenames( argv[argnum++], &in_dat_name, &in_hdr_name, &in_prj_name, extension, "hdr" );
    if (strcmp( extension, "flt" ) != 0 && strcmp( extension, "FLT" ) != 0) {
        usage_exit( "Input filename must have .flt extension (if any)." );
    }
    
    strncpy( extension, "tif", 4 );
    get_filenames( argv[argnum++], &out_dat_name, &out_hdr_name, &out_prj_name, extension, "tfw" );
    
    if (strcmp( extension, "tif" ) != 0 && strcmp( extension, "TIF" ) != 0) {
        usage_exit( "Output filename must have .tif extension (if any)." );
    }
    
    if (!strcmp( in_prj_name, out_prj_name )) {
        usage_exit( "Input and outfile filenames must not be the same." );
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

    printf( "Reading input files...\n" );
    fflush( stdout );

    data = read_flt_hdr_files(
        in_dat_file, in_hdr_file, &nrows, &ncols, &xmin, &xmax, &ymin, &ymax,
        &has_nulls, &all_ints, &software1 );
    
    fclose( in_dat_file );
    fclose( in_hdr_file );
    
    if (software1) {
        separator = "; ";
    } else {
        separator = "";
        software1 = "";
    }
    software2 = (char *)malloc(
        strlen(sw_format) + strlen(software1) + strlen(separator) +
        strlen(sw_name) + strlen(sw_version) + strlen(sw_date) );
    if (!software2) {
        prefix_error();
        fprintf( stderr, "Memory allocation error occurred.\n" );
        exit( EXIT_FAILURE );
    }
    sprintf( software2, sw_format, software1, separator, sw_name, sw_version, sw_date );
    if (*separator) {
        free( software1 );
    }

    // Process data:

    printf(
        "Processing %d column x %d row array using contrast value of %f...\n",
        ncols, nrows, contrast );
    fflush( stdout );

    // Adjust contrast:
    
    // set vertical enhancement parameter and set range to 0..65535
    terrain_image_data( data, nrows, ncols, contrast, 0.0, 65535.0 );
    
    // Write .tif and .tfw files:

    printf( "Writing output files...\n" );
    fflush( stdout );

    write_tif_tfw_files(
        out_dat_file, out_hdr_file, nrows, ncols, xmin, xmax, ymin, ymax, data, software2 );
    
    fclose( out_dat_file );
    fclose( out_hdr_file );

    free( data );
    free( software2 );
    
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

    printf( "DONE.\n" );

    return EXIT_SUCCESS;
}

#endif
