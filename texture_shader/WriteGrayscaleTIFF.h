 /*
 *  WriteGrayscaleTIFF.h
 *  
 *
 *  Created by Brett Casebolt on 11/19/13.
 *  Copyright 2013 Brett Casebolt. All rights reserved.
 *  Modifications copyright 2013 Leland Brown. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notices, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notices, this list of conditions and the following disclaimer in the
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

#ifndef WRITE_GRAYSCALE_TIFF_H
#define WRITE_GRAYSCALE_TIFF_H

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

// writes BigTIFF instead if file size would exceed 4 GB
int WriteGrayscale16BitToTIFF(
   FILE *hFile, int width, int height, const float *data, const char *softwareVersion, size_t *fileSize
);  

int WriteGrayscale16BitToBigTIFF(
   FILE *hFile, int width, int height, const float *data, const char *softwareVersion, size_t *fileSize
);

#ifdef __cplusplus
}
#endif

#endif
