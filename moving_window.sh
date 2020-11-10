#!/bin/bash
# Read in array in main body. END block processes it.
# window is half-width of moving mean (number of lines to each side to include)
# Input rows are averaged with each other.

awk -v window="${1}" '{
    if (max_nf < NF) {
        max_nf = NF
    }
    max_nr = NR
    for (x = 1; x <= NF; ++x) {
        vector[x, NR] = $x
        result[x, NR] = 0  # This seems to be a bug, = missing?
    }
} END {
    for (p = 1; p < window + 1; ++p) {
      numbelow = p - 1
      total_rows[p] = 1 + numbelow + window
      for (j = p - numbelow; j <= p + window; ++j) {
        for (k = 1; k <= max_nf; ++k) {
          result[k,p] = result[k,p]+vector[k,j]
        }
      }
    }
    for (p = window + 1; p < max_nr - window - 1; ++p) {
      total_rows[p] = 1 + 2*window
      for (k = 1; k <= max_nf; ++k) {
        result[k,p] = result[k,p-1]+vector[k,p+window]-vector[k,p-window-1]
      }
    }
    for (p = max_nr - window - 1; p <= max_nr; ++p) {
      numabove = max_nr - p
      total_rows[p] = 1 + numabove + window
      for (j = p - window; j <= max_nr; ++j) {
        for (k = 1; k <= max_nf; ++k) {
          result[k,p] = result[k,p]+vector[k,j]
        }
      }
    }
    for (p = 1; p <= max_nr; ++p) {
      for (k = 1; k < max_nf; ++k) {
        printf("%s ", result[k, p]/total_rows[p])
      }
      printf("%s", result[k, p]/total_rows[p])
      printf("\n")
    }
}' < "${2}"
