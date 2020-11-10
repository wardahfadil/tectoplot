#!/bin/bash
# Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020

# Input multiple lines of space separated values
# For each line, prints the min, quartile 1, median (q2), quartile 3, and max.

awk '{
  q1=-1;
  q2=-1;
  q3=-1

  split( $0 , a, " " );
  asort( a );
  n=length(a);
  p[1] = 0;
  # printf("0\n");
  for (i = 2; i<=n; i++) {
    p[i] = (i-1)/(n-1);
  #  printf("%g\n", p[i]);
    if (p[i] >= .25 && q1 == -1) {
      f = (p[i]-.25)/(p[i]-p[i-1]);
      q1 = a[i-1]*(f)+a[i]*(1-f);
     # printf("%g 0.25 %g --- %g \n", p[i-1], p[i], f )
     # printf("q1 = a[i-1]*(f)+a[i]*(1-f) = %g*(%g)+%g*(%g)\n", a[i-1],f,a[i],(1-f));
    }
    if (p[i] >= .5 && q2 == -1) {
      f = (p[i]-.5)/(p[i]-p[i-1]);
      q2 = a[i-1]*(f)+a[i]*(1-f);
    }
    if (p[i] >= .75 && q3 == -1) {
      f = (p[i]-.75)/(p[i]-p[i-1]);
      q3 = a[i-1]*(f)+a[i]*(1-f);
    }
  }
  if (q1 == -1) { q1 = a[1] }
  if (q2 == -1) { q2 = a[1] }
  if (q3 == -1) { q3 = a[1] }
  printf("%g %g %g %g %g\n", a[1], q1, q2, q3, a[n])
}' < $1
