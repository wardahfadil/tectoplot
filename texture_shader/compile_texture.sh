#!/bin/bash
# Usage: compile_texture.sh texture_source_dir executalbe_dest_dir

TEXTURE_DIR=$1

CC=gcc
CFLAGS="-O2 -funroll-loops"

echo dir is $TEXTURE_DIR
cd $TEXTURE_DIR

[[ -e texture ]] && rm -f texture
[[ -e texture_image ]] && rm -f texture_image

${CC} -DNOMAIN -c *.c
${CC} ${CFLAGS} *.o texture.c -o texture
${CC} ${CFLAGS} *.o shadow.c -o shadow
${CC} ${CFLAGS} *.o svf.c -o svf
${CC} ${CFLAGS} *.o texture_image.c -o texture_image

# Cleanup
rm -f *.o
