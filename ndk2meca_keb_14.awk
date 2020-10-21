# Based on ndk2meca.awk retrieved from http://www-udc.ig.utexas.edu/external/becker/software/ndk2meca.awk
# # $Id: ndk2meca.awk,v 1.4 2010/07/06 22:06:57 becker Exp $
#
# Modified by Kyle Bradley, NTU, kbradley@ntu.edu.sg, 2020 for tectoplot
#
# gawk script to read new Global (Harvard) CMT moment tensor solutions in the new "ndk" format
#
# example: gawk ndk2meca_keb_14.awk jan76_dec05.ndk
#
# This script outputs 28 space separated fields:
# 1: lonc             Longitude of centroid (°)
# 2: latc             Latitude of centroid (°)
# 3: depth            Depth of centroid (km)
# 4: strike1          Strike of nodal plane 1 (°)
# 5: dip1             Dip of nodal plane 1 (°)
# 6: rake1            Rake of nodal plane 1 (°)
# 7: strike2          Strike of nodal plane 2 (°)
# 8: dip2             Dip of nodal plane 2 (°)
# 9: rake2            Rake of nodal plane 2 (°)
# 10: mantissa        Mantissa of M0
# 11: exponent        Exponent of M0
# 12: lon             Longitude of catalog origin (°)
# 13: lat             Latitude of catalog origin (°)
# 14: depth           Depth of catalog origin (km)
# 15: newid           tectoplot ID code: YYYY-MM-DDTHH:MM:SS
# 16: TAz             Azimuth of T axis (°)
# 17: TInc            Inclination of T axis (°), positive down
# 18: Naz             Azimuth of N axis (°), positive down
# 19: Ninc            Inclination of N axis (°), positive down
# 20: Paz             Azimuth of P axis (°), positive down
# 21: Pinc            Inclination of P axis (°), positive down
# 22: Mrr             Moment tensor (multiply by 10^exponent)
# 23: Mtt             Moment tensor (multiply by 10^exponent)
# 24: Mpp             Moment tensor (multiply by 10^exponent)
# 25: Mrt             Moment tensor (multiply by 10^exponent)
# 26: Mrp             Moment tensor (multiply by 10^exponent)
# 27: Mtp             Moment tensor (multiply by 10^exponent)
# 28: MW              MW converted from M0 using M_{\mathrm {w} }={\frac {2}{3}}\log _{10}(M_{0})-10.7

BEGIN{
  ls=1;
  lc=0;
}
{
  if(($1!="") && (substr($1,1,1)!="#")){
    # line counter, equal to NR if no empty lines are found in file
    lc++;

    # First line
    if(lc == ls){
      #First line: Hypocenter line
      #[1-4]   Hypocenter reference catalog (e.g., PDE for USGS location, ISC for
      #        ISC catalog, SWE for surface-wave location, [Ekstrom, BSSA, 2006])
      #[6-15]  Date of reference event
      #[17-26] Time of reference event
      #[28-33] Latitude
      #[35-41] Longitude
      #[43-47] Depth
      #[49-55] Reported magnitudes, usually mb and MS
      #[57-80] Geographical location (24 characters)

      catalog=substr($0,1,4);

      date=substr($0,6,10);split(date,dstring,"/");
      month=dstring[2];day=dstring[3];year=dstring[1];

      time=substr($0,17,10);split(time,tstring,":");
      hour=tstring[1];minute=tstring[2];second=tstring[3];

      # convert to seconds since epoch
      the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
      secs = mktime(the_time);

      # tectoplot uses this event ID/timecode format: YYYY-MM-DD:HH-MM-SS
      newid=sprintf("%04d-%02d-%02dT%02d:%02d:%02d",year,month,day,hour,minute,second)
      lat=sprintf("%lf",substr($0,28,6));

      lon=sprintf("%lf",substr($0,35,7));

      if(lon<0.0) {
	       lon+=360.0;
      }

      dep=sprintf("%lf",substr($0,43,5));
      mb=sprintf("%lf",substr($0,49,3)); # Mb

      # location string
      loc_string=substr($0,57,24);
    }

    # Second line: CMT info (1)

    else if(lc == ls+1){

#[1-16]  CMT event name. This string is a unique CMT-event identifier. Older
#        events have 8-character names, current ones have 14-character names.
#        See note (1) below for the naming conventions used.
#[18-61] Data used in the CMT inversion. Three data types may be used:
#        Long-period body waves (B), Intermediate-period surface waves (S),
#        and long-period mantle waves (M). For each data type, three values
#        are given: the number of stations used, the number of components
#        used, and the shortest period used.
#[63-68] Type of source inverted for: "CMT: 0" - general moment tensor;
#        "CMT: 1" - moment tensor with constraint of zero trace (standard);
#        "CMT: 2" - double-couple source.
#[70-80] Type and duration of moment-rate function assumed in the inversion.
#        "TRIHD" indicates a triangular moment-rate function, "BOXHD" indicates
#        a boxcar moment-rate function. The value given is half the duration
#        of the moment-rate function. This value is assumed in the inversion,
#        following a standard scaling relationship (see note (2) below),
#        and is not derived from the analysis.

      eventid=substr($0,1,17);
    }

    #Third line: CMT info (2)

    else if(lc == ls+2){

#[1-58]  Centroid parameters determined in the inversion. Centroid time, given
#        with respect to the reference time, centroid latitude, centroid
#        longitude, and centroid depth. The value of each variable is followed
#        by its estimated standard error. See note (3) below for cases in
#        which the hypocentral coordinates are held fixed.
#[60-63] Type of depth. "FREE" indicates that the depth was a result of the
#        inversion; "FIX " that the depth was fixed and not inverted for;
#        "BDY " that the depth was fixed based on modeling of broad-band
#        P waveforms.
#[65-80] Timestamp. This 16-character string identifies the type of analysis that
#        led to the given CMT results and, for recent events, the date and
#        time of the analysis. This is useful to distinguish Quick CMTs ("Q-"),
#        calculated within hours of an event, from Standard CMTs ("S-"), which
#        are calculated later. The format for this string should not be
#        considered fixed.

      latc = $4;
      lonc = $6;
      if(lonc < 0)lonc += 360;
      depc=$8;
    }

#Fourth line: CMT info (3)

    else if(lc == ls+3) {

#[1-2]   The exponent for all following moment values. For example, if the
#        exponent is given as 24, the moment values that follow, expressed in
#        dyne-cm, should be multiplied by 10**24.
#[3-80]  The six moment-tensor elements: Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, where r
#        is up, t is south, and p is east. See Aki and Richards for conversions
#        to other coordinate systems. The value of each moment-tensor
#	  element is followed by its estimated standard error. See note (4)
#	  below for cases in which some elements are constrained in the inversion.

      exponent=$1;
      for(i=1;i<=6;i++){
      	m[i]=  $(2+(i-1)*2)	# don't multiply with 10**exponent here
      	msd[i]=$(3+(i-1)*2);
      }
    }

#Fifth line: CMT info (4)

    else if(lc == ls+4) {

#[1-3]   Version code. This three-character string is used to track the version
#        of the program that generates the "ndk" file.
#[4-48]  Moment tensor expressed in its principal-axis system: eigenvalue,
#        plunge, and azimuth of the three eigenvectors. The eigenvalue should be
#        multiplied by 10**(exponent) as given on line four.
#[50-56] Scalar moment, to be multiplied by 10**(exponent) as given on line four.
#[58-80] Strike, dip, and rake for first nodal plane of the best-double-couple
#        mechanism, repeated for the second nodal plane. The angles are defined
#        as in Aki and Richards.

      for(i=1;i <= 3;i++){# eigenvectors
	       e_val[i]=   $(2+(i-1)*3); # don't multiply with 10**exponent
	       e_plunge[i]=$(3+(i-1)*3);
	       e_strike[i]=$(4+(i-1)*3);
      }
      # best double couple
      scalar_moment=$11;# in units of 10**24
      for(i=1;i <= 2;i++){
	       strike[i]=$(12+(i-1)*3);# first and second nodal planes
	       dip[i]=$(13+(i-1)*3);
	       rake[i]=$(14+(i-1)*3);
      }
      # MW is calculated from M0 in dynes-cm using the Kanamori equation M_{\mathrm {w} }={\frac {2}{3}}\log _{10}(M_{0})-10.7
      mw = 2/3*(log(scalar_moment*10**(exponent))*0.4342944819032518)-10.7;

#
# OUTPUT OF EVENT. This format outputs the centroid location in columns 1 and 2, and the origin in 12 and 13
#
# (c) Focal mechanisms in CMT convention for best double couple, plus principal axes and moment tensor
#             lonc, latc, depthc, strike1, dip1, rake1, strike2, dip2, rake2, mantissa, exponent, lon, lat, dep,
#             newid, TAz, TInc, Naz, Ninc, Paz, Pinc, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, mw

	     printf("%f %f %0.1f %i %i %i %i %i %i %f %f %f %f %0.1f %s %i %i %i %i %i %i %0.3g %0.3g %0.3g %0.3g %0.3g %0.3g %0.2g\n", lonc, latc, depc, strike[1],dip[1], rake[1], strike[2],
	      	      dip[2], rake[2], scalar_moment, exponent, lon, lat, dep, newid, e_strike[1], e_plunge[1],  e_strike[2], e_plunge[2],  e_strike[3], e_plunge[3],
                m[1], m[2], m[3], m[4], m[5], m[6], mw);

      # reset the current data block line counter
      ls = lc+1;
    } # end fifth line branch
  } # non-zero line
}
END{
  # Nothing to do here
}
