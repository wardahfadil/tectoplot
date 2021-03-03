#!/bin/bash


awk 'BEGIN{
  for (year=1900;year<=2100;year++) {
    for (month=1; month<=12; month++) {
      for (day=1; day<=31; day++) {
        for (hour=0; hour<=23; hour++) {
          minute=int(59*rand())
          second=int(60*rand())
          the_time=sprintf("%04i %02i %02i %02i %02i %02i",year,month,day,hour,minute,int(second+0.5))
          result=mktime(the_time)
          if (result == -1) {
            print the_time
          }
        }
      }
    }
  }
}'
