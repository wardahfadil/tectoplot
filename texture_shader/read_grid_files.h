/*
 * read_grid_files.h
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

#ifndef READ_GRID_FILES_H
#define READ_GRID_FILES_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

float *read_flt_hdr_files(
    // returns allocated array of data values;
    // NOTE: caller is responsible to free this pointer!
    FILE *in_flt_file,  // .flt file - should be opened in BINARY mode
    FILE *in_hdr_file,  // .hdr file - should be opened in BINARY mode
    int *nrows,         // number of rows in data array
    int *ncols,         // number of cols in data array
    double *xmin,       // min X coordinate (longitude or easting)  - left   edge of left   pixels
    double *xmax,       // max X coordinate (longitude or easting)  - right  edge of right  pixels
    double *ymin,       // min Y coordinate (latitude  or northing) - bottom edge of bottom pixels
    double *ymax,       // max Y coordinate (latitude  or northing) - top    edge of top    pixels
    int *has_nulls,
    int *all_ints,
    char * (*software)  // if software != 0, returns with *software either
                        // null or pointing to a software name/version string;
                        // caller is responsible to free *software pointer!
);

// Copies input .prj file to output .prj file, and changes any "ZUNITS" line to "ZUNITS NO"
void copy_prj_file( FILE *in_prj_file, FILE *out_prj_file );

#ifdef __cplusplus
}
#endif

#endif
