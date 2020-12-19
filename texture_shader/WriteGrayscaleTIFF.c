/*
 *  WriteGrayscaleTIFF.c
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

#include "WriteGrayscaleTIFF.h"

#include <stdlib.h>
#include <string.h>

// TIFF object size codes
#define TIFFbyte     1
#define TIFFascii    2
#define TIFFshort    3
#define TIFFlong     4
#define TIFFrational 5
#define TIFFdouble   12
#define TIFFlong8    16

// TIFF tag names
#define NewSubFile          254
#define SubfileType         255
#define ImageWidth          256
#define ImageLength         257
#define BitsPerSample       258
#define Compression         259
#define PhotometricInterp   262
#define StripOffsets        273
#define SamplesPerPixel     277
#define RowsPerStrip        278
#define StripByteCounts     279
#define XResolution         282
#define YResolution         283
#define PlanarConfiguration 284
#define ResolutionUnit      296
#define Software            305
#define ColorMap            320
#define TIFFTAG_SAMPLEFORMAT        339 // data sample format

#define PHOTOMETRIC_MINISBLACK  1      // min value is black
#define SAMPLEFORMAT_UINT       1      // unsigned integer data

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

static int WriteWord(FILE *hFileRef, unsigned short n)
   {
   int lCount;

   lCount = fwrite(&n, sizeof(unsigned short), 1, hFileRef);
   if (lCount != 1)
      {
      return -1;
      }

   return 0;
   }

static int WriteLong(FILE *hFileRef, unsigned int n)
   {
   int lCount;

   lCount = fwrite(&n, sizeof(unsigned int), 1, hFileRef);
   if (lCount != 1)
      {
      return -1;
      }

   return 0;
   }

static int Write8Byte(FILE *hFileRef, long long n)
   {
   int lCount;

   lCount = fwrite(&n, sizeof(long long), 1, hFileRef);
   if (lCount != 1)
      {
      return -1;
      }

   return 0;
   }

static int WriteString(FILE *hFileRef, const char *str, int count)
   // count MUST include the NUL terminator
   {
   int lCount;
   char pad = '\0';

   lCount = fwrite(str, count, 1, hFileRef);
   if (lCount != 1)
      {
      return -1;
      }

   if (count & (1 == 0))
      {
      return 0;
      }

   // pad string space to word boundary (even number of bytes)
   lCount = fwrite(&pad, 1, 1, hFileRef);
   if (lCount != 1)
      {
      return -1;
      }

   return 0;
   }

static int WriteTIFFTag(FILE *hFile, int tag, int type, int length, int offset)
   {
   int err;

   err = WriteWord(hFile, (unsigned short) tag);
   err |= WriteWord(hFile, (unsigned short) type);
   err |= WriteLong(hFile, length);
   if ((type == TIFFshort) && (length == 1))
      {
      err |= WriteWord(hFile, (unsigned short) offset);
      err |= WriteWord(hFile, 0);
      }
   else
      {
      err |= WriteLong(hFile, offset);
      }
   return err;
   }

static int WriteBigTIFFTag(FILE *hFile, int tag, int type, long long length, long long offset)
   {
   int err;

   err = WriteWord(hFile, (unsigned short) tag);
   err |= WriteWord(hFile, (unsigned short) type);
   err |= Write8Byte(hFile, length);
   if ((type == TIFFshort) && (length == 1))
      {
      err |= WriteWord(hFile, (unsigned short) offset);
      err |= WriteWord(hFile, 0);
      err |= WriteLong(hFile, 0);
      }
   else if ((type == TIFFlong) && (length == 1))
      {
      err |= WriteLong(hFile, (unsigned int)offset);
      err |= WriteLong(hFile, 0);
      }
   else
      {
      err |= Write8Byte(hFile, offset);
      }
   return err;
   }

static int WriteTIFFAsciiTag(FILE *hFile, int tag, const char *str, int count, int offset)
   // count MUST include the NUL terminator
   {
   int err;

   if (count <= 0) return 0;

   err = WriteTIFFTag(hFile, Software, TIFFascii, count, offset);

   if (count > 4)
      {
      return err;
      }

   err |= fseek(hFile, -4, SEEK_CUR);
   err |= WriteString(hFile, str, count);
   err |= fseek(hFile, (4-count)&2, SEEK_CUR);

   return err;
   }

static int WriteBigTIFFAsciiTag(FILE *hFile, int tag, const char *str, int count, long long offset)
   // count MUST include the NUL terminator
   {
   int err;

   if (count <= 0) return 0;

   err = WriteBigTIFFTag(hFile, Software, TIFFascii, count, offset);

   if (count > 8)
      {
      return err;
      }

   err |= fseek(hFile, -8, SEEK_CUR);
   err |= WriteString(hFile, str, count);
   err |= fseek(hFile, (8-count)&6, SEEK_CUR);

   return err;
   }

static int WriteBitmap(FILE *hFile, int width, int height, const float *data)
   {
   int lCount;
   int i, j;
   float fltval;
   const float *ptr;
   int bufsize;
   unsigned short *buffer;

   const unsigned short nodata = 0;

   bufsize = width * sizeof(unsigned short);
   buffer = (unsigned short *) malloc(bufsize);
   if (!buffer)
      {
      return -2;
      }

   for (i=0, ptr=data; i<height; ++i, ptr+=width)
      {
      for (j=0; j<width; ++j)
         {
         fltval = ptr[j];
         if (flt_isnan(fltval))
            {
            buffer[j] = nodata;
            }
         // check limits before integer conversion to avoid overflow
         else if (fltval <= 0.0)
            {
            buffer[j] = 0;
            }
         else if (fltval >= 65535.0)
            {
            buffer[j] = 65535;
            }
         else
            {
            buffer[j] = (unsigned short) (fltval+0.5);
            }
         }

      lCount = fwrite(buffer, sizeof(unsigned short), width, hFile);
      if (lCount != width)
         {
         free(buffer);
         return -1;
         }
      }
   free(buffer);

   return 0;
   }

int WriteGrayscale16BitToTIFF(
   FILE *hFile, int width, int height, const float *data, const char *softwareVersion, size_t *fileSize
)
   {
   size_t lWriteCount, tiffSize;
   short sTagCount;
   long pos, offsetpos;
   int err;
   int softwareCount, softwareSpace;

   err = 0;

   lWriteCount = (size_t) height * (size_t) width * sizeof(unsigned short);

   softwareCount = softwareVersion ? strlen(softwareVersion) : 0;

   sTagCount = 13;
   softwareSpace = 2;
   if (softwareCount)
      {
      softwareCount++;  // include NUL terminator
      softwareSpace = softwareCount + (softwareCount & 1);  // round up to word boundary
      sTagCount++;
      }

// Write the header
   if (am_big_endian())
      {
      err = WriteWord(hFile, 0x4d4d); // 'MM' is for Motorola (big-endian) number format in the file
      }
   else
      {
      err = WriteWord(hFile, 0x4949); // 'II' is for Intel (little-endian) number format in the file
      }
   err |= WriteWord(hFile, 42);
   err |= WriteLong(hFile, 24+softwareSpace);   // Offset of tags

   err |= WriteLong(hFile, (int) (72*0x02710)); // X resolution in pixels per inch
   err |= WriteLong(hFile, 0x02710);

   err |= WriteLong(hFile, (int) (72*0x02710)); // Y resolution in pixels per inch
   err |= WriteLong(hFile, 0x02710);

   if (softwareCount)
      {
      err |= WriteString(hFile, softwareVersion, softwareCount);
      }
   else
      {
      // This seems to be a typo in the code. Kyle Bradley 2020
      // err != WriteWord(hFile, 0);
      err |= WriteWord(hFile, 0);
      }

   err |= WriteWord(hFile, sTagCount);

   err |= WriteTIFFTag(hFile, ImageWidth, TIFFlong, 1, width);
   err |= WriteTIFFTag(hFile, ImageLength, TIFFlong, 1, height);
   err |= WriteTIFFTag(hFile, BitsPerSample, TIFFshort, 1, 16);
   err |= WriteTIFFTag(hFile, Compression, TIFFshort, 1, 1);
   err |= WriteTIFFTag(hFile, PhotometricInterp, TIFFshort, 1, PHOTOMETRIC_MINISBLACK);
   err |= WriteTIFFTag(hFile, StripOffsets, TIFFlong, 1, 0);
   offsetpos = ftell(hFile);
   if (offsetpos < 0)
      {
      return -1;
      }
   offsetpos -= 4; // Remember where to put the strip offset
   err |= WriteTIFFTag(hFile, SamplesPerPixel, TIFFshort, 1, 1);
   err |= WriteTIFFTag(hFile, RowsPerStrip, TIFFlong, 1, height);
   err |= WriteTIFFTag(hFile, StripByteCounts, TIFFlong, 1, lWriteCount);
   err |= WriteTIFFTag(hFile, XResolution, TIFFrational, 1, 8);
   err |= WriteTIFFTag(hFile, YResolution, TIFFrational, 1, 16);
   err |= WriteTIFFTag(hFile, ResolutionUnit, TIFFshort, 1, 2);
   if (softwareCount)
      {
      err |= WriteTIFFAsciiTag(hFile, Software, softwareVersion, softwareCount, 24);
      }
   err |= WriteTIFFTag(hFile, TIFFTAG_SAMPLEFORMAT, TIFFshort, 1, SAMPLEFORMAT_UINT);

   err |= WriteLong(hFile, 0);

   if (err)
      {
      return err;
      }

// Remember where the bitmap is going
   pos = ftell(hFile);
   if (pos < 0)
      {
      return -1;
      }

   tiffSize = pos + lWriteCount;

   if ((tiffSize-1)>>31 > 1)
      {
      rewind(hFile);
      return WriteGrayscale16BitToBigTIFF(hFile, width, height, data, softwareVersion, fileSize);
      }

   if (fileSize)
      {
      *fileSize = tiffSize;
      }

   err |= fseek(hFile, offsetpos, SEEK_SET);
   err |= WriteLong(hFile, pos);
   err |= fseek(hFile, pos, SEEK_SET);

   if (err)
      {
      return err;
      }

   err = WriteBitmap(hFile, width, height, data);

   return err;
   }


int WriteGrayscale16BitToBigTIFF(
   FILE *hFile, int width, int height, const float *data, const char *softwareVersion, size_t *fileSize
)
   {
   size_t lWriteCount;
   long long sTagCount;
   long pos, offsetpos;
   int err;
   int softwareCount, softwareSpace;

   err = 0;

   lWriteCount = (size_t) height * (size_t) width * sizeof(unsigned short);

   softwareCount = softwareVersion ? strlen(softwareVersion) : 0;

   sTagCount = 13;
   softwareSpace = 2;
   if (softwareCount)
      {
      softwareCount++;  // include NUL terminator
      softwareSpace = softwareCount + (softwareCount & 1);  // round up to word boundary
      sTagCount++;
      }

// Write the header
   if (am_big_endian())
      {
      err = WriteWord(hFile, 0x4d4d); // 'MM' is for Motorola (big-endian) number format in the file
      }
   else
      {
      err = WriteWord(hFile, 0x4949); // 'II' is for Intel (little-endian) number format in the file
      }
   err |= WriteWord(hFile, 43);
   err |= WriteWord(hFile, 8);
   err |= WriteWord(hFile, 0);
   err |= Write8Byte(hFile, 24+softwareSpace);   // Offset of tags

   err |= Write8Byte(hFile, 0);
   if (softwareCount)
      {
      err |= WriteString(hFile, softwareVersion, softwareCount);
      }
   else
      {
      err |= WriteWord(hFile, 0);
      }

   err |= Write8Byte(hFile, sTagCount);

   err |= WriteBigTIFFTag(hFile, ImageWidth, TIFFlong, 1, width);
   err |= WriteBigTIFFTag(hFile, ImageLength, TIFFlong, 1, height);
   err |= WriteBigTIFFTag(hFile, BitsPerSample, TIFFshort, 1, 16);
   err |= WriteBigTIFFTag(hFile, Compression, TIFFshort, 1, 1);
   err |= WriteBigTIFFTag(hFile, PhotometricInterp, TIFFshort, 1, PHOTOMETRIC_MINISBLACK);
   err |= WriteBigTIFFTag(hFile, StripOffsets, TIFFlong, 1, 0);
   offsetpos = ftell(hFile);
   if (offsetpos < 0)
      {
      return -1;
      }
   offsetpos -= 8; // Remember where to put the strip offset
   err |= WriteBigTIFFTag(hFile, SamplesPerPixel, TIFFshort, 1, 1);
   err |= WriteBigTIFFTag(hFile, RowsPerStrip, TIFFlong, 1, height);
   err |= WriteBigTIFFTag(hFile, StripByteCounts, TIFFlong8, 1, lWriteCount);

   err |= WriteBigTIFFTag(hFile, XResolution, TIFFrational, 1, 0);
   err |= fseek(hFile, -8, SEEK_CUR);
   err |= WriteLong(hFile, (int) (72*0x02710)); // X resolution in pixels per inch
   err |= WriteLong(hFile, 0x02710);

   err |= WriteBigTIFFTag(hFile, YResolution, TIFFrational, 1, 0);
   err |= fseek(hFile, -8, SEEK_CUR);
   err |= WriteLong(hFile, (int) (72*0x02710)); // Y resolution in pixels per inch
   err |= WriteLong(hFile, 0x02710);

   err |= WriteBigTIFFTag(hFile, ResolutionUnit, TIFFshort, 1, 2);
   if (softwareCount)
      {
      err |= WriteBigTIFFAsciiTag(hFile, Software, softwareVersion, softwareCount, 24);
      }
   err |= WriteBigTIFFTag(hFile, TIFFTAG_SAMPLEFORMAT, TIFFshort, 1, SAMPLEFORMAT_UINT);

   err |= Write8Byte(hFile, 0);

   if (err)
      {
      return err;
      }

// Remember where the bitmap is going
   pos = ftell(hFile);
   if (pos < 0)
      {
      return -1;
      }

   if (fileSize)
      {
      *fileSize = pos + lWriteCount;
      }

   err |= fseek(hFile, offsetpos, SEEK_SET);
   err |= WriteLong(hFile, pos);
   err |= fseek(hFile, pos, SEEK_SET);

   if (err)
      {
      return err;
      }

   err = WriteBitmap(hFile, width, height, data);

   return err;
   }
