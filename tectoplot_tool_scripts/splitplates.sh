#!/bin/bash
#splitplates.sh

# This script takes a multisegment polygon file in -180:180 convention and
# splits the polygons across the international dateline. new polygons are given
# names id_1, id_2, id_3

cat platesref.txt | awk '{
  if ($1 == ">") {  # When we encounter a plate header
    curplate=$2     # record the plate name
    indcount=1      # index of the first plate to splif off (if necessary)
    whereflag=1
    print
    getline
    if ($1 < 0) {   # if the first point is

    }
  }
  else {
    if ($ > 160) {
        print $1-360+20, $2
    }
    else {
        print $1+20, $2
    }
  }
}' > platesgo.txt
