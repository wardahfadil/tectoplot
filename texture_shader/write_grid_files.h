/*
 * write_grid_files.h
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

#ifndef WRITE_GRID_FILES_H
#define WRITE_GRID_FILES_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

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
);

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
);

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
);

#ifdef __cplusplus
}
#endif

#endif
