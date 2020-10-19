#!/bin/bash
# Block 360_to_180.sh $BLOCKFILE $POLEFILE

cat $1 | awk '{if ($1 == ">") print; else if ($1 <= 180) print $1, $2; else print $1-360, $2; }' > block.180.dat
cat $2 | awk '{if ($3 <= 180) print; else print $1, $2, $3-360, $4}' > block.180.poles.dat

