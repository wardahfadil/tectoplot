#!/bin/bash
# Awk tools ingest focal mechanism data into tectoplot format
printheader=0
# Usage
# cmt_tools.sh FILE FORMATCODE IDCODE SWITCH

# If FILE is a single hyphen - , then read from stdin

# We want to be able to ingest focal mechanism data in different formats. Note that [newdepth] is
# accepted as an extra field tacked onto the end of GMT's standard input formats. That is followed
# by a [timecode] in the format YYYY-MM-DDTHH:MM:SS

# FOR GMT FORMATS,
# We assume that X Y depth are ORIGIN locations and newX newY newdepth are CENTROID locations.
# If SWITCH=="switch" then we switch this assignment ***AT THE OUTPUT STEP***

# tectoplot focal mechanisms have a 2 letter ID with a source character (A-Z) and a mechanism type (TSN)
# I=ISC G=GCMT. All other characters can be used.

# Includes a fix for moment for ASIES mechanisms in the ISC catalog that are reported in dynes-cm and not N-m

#  Accepted input formats are:
#  Fields without a value should contain "none" if subsequent fields need to be used.
#  e.g. for format a
#  109 -10 12 120 20 87 4.5 none none none none 1973-12-01T05:04:22
#

# Code   GMT or other format info
# ----   -----------------------------------------------------------------------
#   a    psmeca Aki and Richards format (mag= 28. MW)
#         X Y depth strike dip rake mag [newX newY] [event_title] [newdepth] [timecode]
#   c    psmeca GCMT format
#         X Y depth strike1 dip1 rake1 aux_strike dip2 rake2 moment [newX newY] [event_title] [newdepth] [timecode]
#   x    psmeca principal axes
#         X Y depth T_value T_azim T_plunge N_value N_azim N_plunge P_value P_azim P_plunge exp [newX newY] [event_title] [newdepth] [timecode]
#   m    psmeca moment tensor format
#         X Y depth mrr mtt mff mrt mrf mtf exp [newX newY] [event_title] [newdepth] [timecode]
#   I    ISC focal mechanism, CSV format
#        EVENT_ID,AUTHOR, DATE, TIME, LAT, LON, DEPTH, CENTROID, AUTHOR, EX,MO, MW, EX,MRR, MTT, MPP, MRT, MTP, MPR, STRIKE1, DIP1, RAKE1, STRIKE2, DIP2, RAKE2, EX,T_VAL, T_PL, T_AZM, P_VAL, P_PL, P_AZM, N_VAL, N_PL, N_AZM
#   K    NDK format (e.g. GCMT)
#  ---   -----------------------------------------------------------------------

# OUTPUT FORMAT
#  idcode event_code id epoch lon_centroid lat_centroid depth_centroid lon_origin lat_origin depth_origin author_centroid author_origin MW mantissa exponent strike1 dip1 rake1 strike2 dip2 rake2 exponent Tval Taz Tinc Nval Naz Ninc Pval Paz Pinc exponent Mrr Mtt Mpp Mrt Mrp Mtp centroid_dt

# DIAGSCRIPT = full path to diagonalize_6comp.pl
# DIAGDIR = full path to folder containing DIAGSCRIPT

if [[ $1 == "format" ]]; then
  echo "idcode event_code id epoch lon_centroid lat_centroid depth_centroid lon_origin lat_origin depth_origin author_centroid author_origin MW mantissa exponent strike1 dip1 rake1 strike2 dip2 rake2 exponent Tval Taz Tinc Nval Naz Ninc Pval Paz Pinc exponent Mrr Mtt Mpp Mrt Mrp Mtp centroid_dt"
  exit
fi

INFILE=$1
# if [[ $INFILE == "stdin" ]]; then
#   INFILE=$(cat -)
# fi

# ISC data are comma delimited.
if [[ $2 == "I" ]]; then
  DELIM="-F,"
else
  DELIM=""
fi

cat $INFILE | gawk $DELIM -v FMT=$2 -v INID=$3 -v diagscript=$DIAGSCRIPT -v diagdir=$DIAGDIR '

function getpi()       { return atan2(0,-1)             }
function abs(v)        { return v < 0 ? -v : v          }
function tan(x)        { return sin(x)/cos(x)           }
function atan(x)       { return atan2(x,1)              }
function asin(x)       { return atan2(x, sqrt(1-x*x))   }
function acos(x)       { return atan2(sqrt(1-x*x), x)   }
function rad2deg(rad)  { return (180 / getpi()) * rad   }
function deg2rad(deg)  { return (getpi() / 180) * deg   }
function hypot(x,y)    { return sqrt(x*x+y*y)           }
function d_atan2d(y,x) { return (x == 0.0 && y == 0.0) ? 0.0 : rad2deg(atan2(y,x)) }

# Calculate the six components of the moment tensor from strike, dip, rake and M0 in mantissa, exponent form
# Mf array will be filled Mf[1]-Mf[6] with Mrr Mtt Mpp Mrt Mrp Mtp

function sdr_mantissa_exponent_to_full_moment_tensor(strike_d, dip_d, rake_d, mantissa, exponent, Mf)
{
  strike=deg2rad(strike_d)
  dip=deg2rad(dip_d)
  rake=deg2rad(rake_d)

  M0=mantissa*(10^exponent)

  M[1]=M0*sin(2*dip)*sin(rake)
  M[2]=-M0*(sin(dip)*cos(rake)*sin(2*strike)+sin(2*dip)*sin(rake)*sin(strike)*sin(strike))
  M[3]=M0*(sin(dip)*cos(rake)*sin(2*strike)-sin(2*dip)*sin(rake)*cos(strike)*cos(strike))
  M[4]=-M0*(cos(dip)*cos(rake)*cos(strike)+cos(2*dip)*sin(rake)*sin(strike))
  M[5]=M0*(cos(dip)*cos(rake)*sin(strike)-cos(2*dip)*sin(rake)*cos(strike))
  M[6]=-M0*(sin(dip)*cos(rake)*cos(2*strike)+0.5*sin(2*dip)*sin(rake)*sin(2*strike))

  # Do we need to adjust the scale if one of the M components is too large? Not sure but...
  maxscale=0
  for (key in M) {
    scale=int(log(M[key]>0?M[key]:-M[key])/log(10))
    maxscale=scale>maxscale?scale:maxscale
  }

  Mf[1]=M[1]/10^maxscale
  Mf[2]=M[2]/10^maxscale
  Mf[3]=M[3]/10^maxscale
  Mf[4]=M[4]/10^maxscale
  Mf[5]=M[5]/10^maxscale
  Mf[6]=M[6]/10^maxscale
}


# Calculate the principal axes azimuth and plunge from strike, dip, rake of a nodal plane
# Results are placed into TNP[1]-TNP[6] in the order Taz, Tinc, Naz, Ninc, Paz, Pinc (degrees)

function sdr_to_tnp(strike_d, dip_d, rake_d, TNP) {
  strike=deg2rad(strike_d)
  dip=deg2rad(dip_d)
  rake=deg2rad(rake_d)

  # l is the slick vector
  l[1]=sin(strike)*cos(rake)-cos(strike)*cos(dip)*sin(rake)
  l[2]=cos(strike)*cos(rake)+sin(strike)*cos(dip)*sin(rake)
  l[3]=sin(dip)*sin(rake)

  # n is the normal vector
  n[1]=cos(strike)*sin(dip)
  n[2]=-sin(strike)*sin(dip)
  n[3]=cos(dip)

  P[1]=1/sqrt(2)*(n[1]-l[1])
  P[2]=1/sqrt(2)*(n[2]-l[2])
  P[3]=1/sqrt(2)*(n[3]-l[3])

  T[1]=1/sqrt(2)*(n[1]+l[1])
  T[2]=1/sqrt(2)*(n[2]+l[2])
  T[3]=1/sqrt(2)*(n[3]+l[3])

  Paz = rad2deg(atan2(P[1],P[2]))
  Pinc = rad2deg(asin(P[3]))
  if (Pinc>0) {
    Paz=(Paz+180)%360
  }
  if (Pinc<0) {
    Pinc=-Pinc
    Paz=(Paz+360)%360
  }
  Taz = rad2deg(atan2(T[1],T[2]))
  Tinc = rad2deg(asin(T[3]))
  if (Tinc>0) {
    Taz=(Taz+180)%360
  }
  if (Tinc<0) {
    Tinc=-Tinc
    Taz=(Taz+360)%360
  }

  # N = n × l
  N[1]=(n[2]*l[3]-n[3]*l[2])
  N[2]=-(n[1]*l[3]-n[3]*l[1])
  N[3]=(n[1]*l[2]-n[2]*l[1])

  Naz = rad2deg(atan2(N[1],N[2]))
  Ninc = rad2deg(asin(N[3]))
  if (Ninc>0) {
    Naz=(Naz+180)%360
  }
  if (Ninc<0) {
    Ninc=-Ninc
    Naz=(Naz+360)%360
  }

  # When using this method to get principal axes, we have lost all information
  # about the relative magnitudes of the eigenvalues.
  Tval=1
  Nval=0
  Pval=-1

  TNP[1]=Tval
  TNP[2]=Taz
  TNP[3]=Tinc
  TNP[4]=Nval
  TNP[5]=Naz
  TNP[6]=Ninc
  TNP[7]=Pval
  TNP[8]=Paz
  TNP[9]=Pinc

}

# Calculate the focal mechanism type (N,S,T) and append it to the ID CODE:
# e.g. N = Normal  T = Thrust S = Strikeslip
# Following the basic classification scheme of FMC; Jose-Alvarez, 2019 https://github.com/Jose-Alvarez/FMC

function mechanism_type_from_TNP(Tinc, Ninc, Pinc) {
  if (Pinc >= Ninc && Pinc >= Tinc) {
   class="N"
 } else if (Ninc >= Pinc && Ninc >= Tinc) {
   class="S"
  } else {
   class="T"
  }
  return class
}

# Calculate the auxilliary fault plane from strike, dip, rake of a nodal plane
# Modified from code by Utpal Kumar, Li Zhao, IESCODERS
# Return values in SDR array: SDR[1]=strike SDR[2]=dip SDR[3]=rake


function aux_sdr(strike_d, dip_d, rake_d, SDR) {
  strike = deg2rad(strike_d)
  dip = deg2rad(dip_d)
  rake = deg2rad(rake_d)

  aux_dip = acos(sin(rake)*sin(dip))
  r2 = atan2(cos(dip)/sin(aux_dip), -sin(dip)*cos(rake)/sin(aux_dip))
  aux_strike = rad2deg(strike - atan2(cos(rake)/sin(aux_dip), -1/(tan(dip)*tan(aux_dip))))
  aux_dip = rad2deg(aux_dip)
  aux_rake = rad2deg(r2)

  if (aux_dip > 90) {
      aux_strike = aux_strike + 180
      aux_dip = 180 - aux_dip
      aux_rake = 360 - aux_rake
  }

  if (aux_strike > 360) {
      aux_strike = aux_strike - 360
  }

  SDR[1]=aux_strike
  SDR[2]=aux_dip
  SDR[3]=aux_rake
}

# Calculate rake of a nodal plane from two nodal plane strike/dips and a sign
# factor that defines the slip direction

# Modified from GMT psmeca (G. Patau, IPGP)


function rake_from_twosd_im(S1, D1, S2, D2, im) {

    ss=sin(deg2rad(S1-S2))
    cs=cos(deg2rad(S1-S2))

  	sd = sin(deg2rad(D1));
    cd = cos(deg2rad(D2));

  	if ( abs(D2 - 90.0) < 0.1) {
  		sinrake2 = im * cd;
    } else {
  		sinrake2 = -im * sd * cs / cd;
    }

  	rake2 = d_atan2d(sinrake2, -im*sd*ss);
    return rake2
}

# Calculate the strike, dip, and rake of both nodal planes from principal axes
# Modified from GMT psutil.c (G Patau, IPGP)
# Inputs are in degrees, Output is stored in SDR array (all in degrees)
# SDR[1]=strike1, SDR[2]=dip1, SDR[3]=rake1 SDR[4]=strike2 SDR[5]=dip2 SDR[6]=rake2


function ntp_to_sdr(Taz, Tinc, Paz, Pinc, SDR) {

  sdp=sin(deg2rad(Pinc))
  cdp=cos(deg2rad(Pinc))
  spp=sin(deg2rad(Paz))
  cpp=cos(deg2rad(Paz))

  sdt=sin(deg2rad(Tinc))
  cdt=cos(deg2rad(Tinc))
  spt=sin(deg2rad(Taz))
  cpt=cos(deg2rad(Taz))

	cpt=cpt*cdt;
  spt=spt*cdt;
	cpp=cpp*cdp;
  spp=spp*cdp;

  amz = sdt + sdp; amx = spt + spp; amy = cpt + cpp;
  d1 = rad2deg(atan2(hypot(amx, amy), amz));
  p1 = rad2deg(atan2(amy, -amx));

  if (d1 > 90.0) {
    d1 = 180.0 - d1;
    p1 = p1 - 180.0;
  }
  if (p1 < 0.0) {
    p1 = p1 + 360.0;
  }

  amz = sdt - sdp; amx = spt - spp; amy = cpt - cpp;
  d2 = rad2deg(atan2(hypot(amx, amy), amz));
  p2 = rad2deg(atan2(amy, -amx));
  if (d2 > 90.0) {
    d2 = 180.0 - d2;
    p2 = p2 - 180.0;
  }
  if (p2 < 0.0) {
    p2 = p2 + 360.0;
  }

  if (Pinc > Tinc) {
    im = -1;
  } else {
    im = 1
  }

  rake1=rake_from_twosd_im(p2, d2, p1, d1, im)
  rake2=rake_from_twosd_im(p1, d1, p2, d2, im)

  SDR[1]=p1
  SDR[2]=d1
  SDR[3]=rake1

  SDR[4]=p2
  SDR[5]=d2
  SDR[6]=rake2
}

# Check if ID is in tectoplot YYYY:MM:DDTHH:MM:SS format. If not, return a dummy ID with an impossible time

function make_tectoplot_id(proposed_id) {
  if (proposed_id ~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) {
    return proposed_id
  } else {
    return sprintf("0000-00-00T00:00:00%s", proposed_id)
  }
}

function isnumber(val) {
  if ((val ~ /^[-+]?[0-9]*\.?[0-9]+$/) || (val == "none")) {
    return 1
  } else {
    return 0
  }
}

######### CODE BLOCK TO RUN BEFORE PROCESSING LINES GOES HERE ##################
BEGIN {

  ###### For each input format, we define which components we need to calculate.

  calc_ntp_from_moment_tensor=0
  calc_mantissa_from_exp_and_mt=0
  calc_sdr_from_ntp=0
  calc_sdr2=0
  calc_moment_tensor_from_sdr1=0
  calc_mant_exp_from_M=0
  calc_principal_axes_from_sdr1=0
  calc_M_from_mantissa_exponent=0
  calc_epoch=0

  # Aki and Richard  psmeca -Sa
  if (FMT=="a") {
    calc_ntp_from_moment_tensor=0
    calc_mantissa_from_exp_and_mt=0
    calc_sdr_from_ntp=0
    calc_sdr2=1
    calc_moment_tensor_from_sdr1=1
    calc_mant_exp_from_M=1
    calc_principal_axes_from_sdr1=1
    calc_M_from_mantissa_exponent=0
    calc_epoch=1
    determine_calcs_needed_each_step=0
  }

  #  X Y depth strike1 dip1 rake1 aux_strike dip2 rake2 mantissa exponent [newX newY] [event_title]
  # Global CMT   psmeca -Sc
  if (FMT=="c") {
    calc_ntp_from_moment_tensor=0
    calc_mantissa_from_exp_and_mt=0
    calc_sdr_from_ntp=0
    calc_sdr2=0
    calc_moment_tensor_from_sdr1=1
    calc_mant_exp_from_M=0
    calc_principal_axes_from_sdr1=1
    calc_M_from_mantissa_exponent=1
    calc_epoch=1
    determine_calcs_needed_each_step=0

  }

  #  X Y depth mrr mtt mff mrt mrf mtf exp [newX newY] [event_title] [newdepth] [timecode]
  # Moment tensor   psmeca -Sm
  if (FMT=="m") {
    calc_ntp_from_moment_tensor=1
    calc_mantissa_from_exp_and_mt=1
    calc_sdr_from_ntp=1
    calc_sdr2=0
    calc_moment_tensor_from_sdr1=0
    calc_mant_exp_from_M=0
    calc_principal_axes_from_sdr1=0
    calc_M_from_mantissa_exponent=1
    calc_epoch=1
    determine_calcs_needed_each_step=0
  }

  # NDK
  if (FMT=="K") {
    calc_ntp_from_moment_tensor=0
    calc_mantissa_from_exp_and_mt=0
    calc_sdr_from_ntp=0
    calc_sdr2=0
    calc_moment_tensor_from_sdr1=0
    calc_mant_exp_from_M=0
    calc_principal_axes_from_sdr1=0
    calc_M_from_mantissa_exponent=1
    calc_epoch=1
    determine_calcs_needed_each_step=0
  }

  # ISC CSV
  # Note that moments are in N-m and not dynes-cm (factor of 10^7 apparently)
  if (FMT=="I") {
    calc_ntp_from_moment_tensor=0
    calc_mantissa_from_exp_and_mt=0
    calc_sdr_from_ntp=0
    calc_sdr2=0
    calc_moment_tensor_from_sdr1=0
    calc_mant_exp_from_M=0
    calc_principal_axes_from_sdr1=0
    calc_M_from_mantissa_exponent=0
    calc_epoch=1
    determine_calcs_needed_each_step=1
  }

  # GFZ focal mechanisms.
  if (FMT=="Z") {
    calc_ntp_from_moment_tensor=0
    calc_mantissa_from_exp_and_mt=0
    calc_sdr_from_ntp=0
    calc_sdr2=0
    calc_moment_tensor_from_sdr1=0

    # GFZ has weird exponent and very weird TNP axes. Just recalc from MW and SDR
    calc_mant_exp_from_M=1
    calc_principal_axes_from_sdr1=1
    calc_M_from_mantissa_exponent=0
    calc_epoch=1
    determine_calcs_needed_each_step=0
  }


}
################# END OF BEGIN BLOCK ###########################################

########## CODE BLOCK TO PROCESS EACH LINE GOES HERE ###########################
{

  # Skip blank lines and lines that begin with a # (comments)
  if(($1!="") && (substr($1,1,1)!="#")) {

    idcode="none"
    event_code="none"
    id="none"
    epoch="none"
    lon_centroid="none"
    lat_centroid="none"
    depth_centroid="none"
    lon_origin="none"
    lat_origin="none"
    depth_origin="none"
    author_centroid="none"
    author_origin="none"
    MW="none"
    mantissa="none"
    exponent="none"
    strike1=0
    dip1=0
    rake1=0
    strike2=0
    dip2=0
    rake2=0


    Tval=1
    Nval=0
    Pval=-1
    Taz=0
    Tinc=0
    Naz=0
    Ninc=0
    Paz=0
    Pinc=0
    Mrr=0
    Mtt=0
    Mpp=0
    Mrt=0
    Mrp=0
    Mtp=0

    centroid_dt=0
    skip_this_entry=0

    np1_exists=0
    np2_exists=0
    tensor_exists
    ntp_axes_exist=0

    SDR[1]=0
    SDR[2]=0
    SDR[3]=0
    SDR[4]=0
    SDR[5]=0
    SDR[6]=0
    TNP[1]=0
    TNP[2]=0
    TNP[3]=0
    TNP[4]=0
    TNP[5]=0
    TNP[6]=0
    TNP[7]=0
    TNP[8]=0
    TNP[9]=0
    MT2[1]=0
    MT2[2]=0
    MT2[3]=0
    MT2[4]=0
    MT2[5]=0
    MT2[6]=0

    ##### Read the input lines based on the input format

    # ------------------------------#
    # FMT=a is Aki and Richards
    if (FMT=="a") {
      # X Y depth strike dip rake mag [newX newY] [event_title] [depth_centroid]
      lon_origin=$1
      lat_origin=$2
      depth_origin=$3
      strike1=$4
      dip1=$5
      rake1=$6
      MW=$7

      ### Optional fields
      if (NF > 7) {
        lon_centroid=$8
      } else {
        lon_centroid="none"
      }
      if (NF > 8) {
        lat_centroid=$9
      } else {
        lat_centroid="none"
      }
      if (NF > 9) {
        event_code=$10
      } else {
        event_code="nocode"
      }
      if (NF > 10) {
        depth_centroid=$11
      } else {
        depth_centroid="none"
      }
      if (NF > 11) {
        id=make_tectoplot_id($12)
      } else {
        id=make_tectoplot_id("")
      }
      ### End optional fields
    } # FMT = a
    # ------------------------------#

    # ------------------------------#
    # FMT=c is GCMT
    if (FMT=="c") {
      # X Y depth strike1 dip1 rake1 strike2 dip2 rake2 mantissa exponent [newX newY] [event_title] [depth_centroid]
      lon_origin=$1
      lat_origin=$2
      depth_origin=$3
      strike1=$4
      dip1=$5
      rake1=$6
      strike2=$7
      dip2=$8
      rake2=$9
      mantissa=$10
      exponent=$11

      ### Optional fields
      if (NF > 11) {
        lon_centroid=$12
      } else {
        lon_centroid="none"
      }
      if (NF > 12) {
        lat_centroid=$13
      } else {
        lat_centroid="none"
      }
      if (NF > 13) {
        event_code=$14
      } else {
        event_code="nocode"
      }
      if (NF > 14) {
        depth_centroid=$15
      } else {
        depth_centroid="none"
      }
      if (NF > 15) {
        id=make_tectoplot_id($16)
      } else {
        id=make_tectoplot_id("")
      }
    } # FMT = c
    #---------------------------------#

    #----------------------------------#
    # X Y depth mrr mtt mpp mrt mrp mtp exp [newX newY] [event_title] [newdepth]
    # FMT=m is moment tensor   psmeca -Sm
    if (FMT=="m") {
      lon_origin=$1
      lat_origin=$2
      depth_origin=$3
      Mrr=$4
      Mtt=$5
      Mpp=$6
      Mrt=$7
      Mrp=$8
      Mtp=$9
      exponent=$10

      ### Optional fields
      if (NF > 10) {
        lon_centroid=$11
      } else {
        lon_centroid="none"
      }
      if (NF > 11) {
        lat_centroid=$12
      } else {
        lat_centroid="none"
      }
      if (NF > 12) {
        event_code=$13
      } else {
        event_code="nocode"
      }
      if (NF > 13) {
        depth_centroid=$14
      } else {
        depth_centroid="none"
      }
      if (NF > 14) {
        id=make_tectoplot_id($15)
      } else {
        id=make_tectoplot_id("")
      }
    } # FMT = m
    #------------------------------#

    #----------------------------------#
    # NDK files will always have every entry defined (at least for GCMT NDK)
    if (FMT=="K") {
      ###### Each NDK entry consists of five lines. We enter with the first line in $0

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

      # Determine the catalog the provided the origin information
      author_origin=substr($0,1,4);

      # Determine the origin date and time.
      date=substr($0,6,10);
      split(date,dstring,"/");
      month=dstring[2];
      day=dstring[3];
      year=dstring[1];
      time=substr($0,17,10);
      split(time,tstring,":");
      hour=tstring[1];
      minute=tstring[2];
      second=tstring[3];

      # convert to seconds since epoch
      the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
      secs = mktime(the_time);

      # tectoplot uses this event ID/timecode format: YYYY-MM-DD:HH-MM-SS
      id=make_tectoplot_id(sprintf("%04d-%02d-%02dT%02d:%02d:%02d",year,month,day,hour,minute,second))

      # The origin location
      lat_origin=sprintf("%lf",substr($0,28,6));
      lon_origin=sprintf("%lf",substr($0,35,7));
      if(lon_origin > 180) {
         lon_origin-=360.0;
      }
      depth_origin=sprintf("%lf",substr($0,43,5));

      # mb=sprintf("%lf",substr($0,49,3)); # Mb

      ###### Load the second line. If we cannot, die
      if (getline <= 0) {
        print("unexpected EOF or error:", ERRNO) > "/dev/stderr"
        exit
      }
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

      event_code=substr($0,1,17);
      # remove leading and trailing whitespace from the event_code
      gsub(/^[ \t]+/,"",event_code);gsub(/[ \t]+$/,"",event_code)

      ###### Load the third line. If we cannot, die
      if (getline <= 0) {
        print("unexpected EOF or error:", ERRNO) > "/dev/stderr"
        exit
      }
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
      centroid_dt=$2
      lat_centroid = $4;
      lon_centroid = $6;
      if(lon_centroid > 180) {
        lon_centroid =- 360;
      }
      depth_centroid=$8;

      ###### Load the fourth line. If we cannot, die
      if (getline <= 0) {
        print("unexpected EOF or error:", ERRNO) > "/dev/stderr"
        exit
      }
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
        m[i]=  $(2+(i-1)*2)
        msd[i]=$(3+(i-1)*2);
      }
      Mrr=m[1]
      Mtt=m[2]
      Mpp=m[3]
      Mrt=m[4]
      Mrp=m[5]
      Mtp=m[6]

      ###### Load the fifth line. If we cannot, die
      if (getline <= 0) {
        print("unexpected EOF or error:", ERRNO) > "/dev/stderr"
        exit
      }
      #[1-3]   Version code. This three-character string is used to track the version
      #        of the program that generates the "ndk" file.
      #[4-48]  Moment tensor expressed in its principal-axis system: eigenvalue,
      #        plunge, and azimuth of the three eigenvectors. The eigenvalue should be
      #        multiplied by 10**(exponent) as given on line four.
      #[50-56] Scalar moment, to be multiplied by 10**(exponent) as given on line four.
      #[58-80] Strike, dip, and rake for first nodal plane of the best-double-couple
      #        mechanism, repeated for the second nodal plane. The angles are defined
      #        as in Aki and Richards.

      # Eigenvectors and principal axes
      for(i=1;i <= 3;i++) { # eigenvectors
         e_val[i]=   $(2+(i-1)*3);
         e_plunge[i]=$(3+(i-1)*3);
         e_strike[i]=$(4+(i-1)*3);
      }
      Tval=e_val[1]
      Tinc=e_plunge[1]
      Taz=e_strike[1]
      Nval=e_val[2]
      Ninc=e_plunge[2]
      Naz=e_strike[2]
      Pval=e_val[3]
      Pinc=e_plunge[3]
      Paz=e_strike[3]

      # Best double couple
      mantissa=$11;# in units of 10**24
      for(i=1;i <= 2;i++){
         strike[i]=$(12+(i-1)*3);# first and second nodal planes
         dip[i]=$(13+(i-1)*3);
         rake[i]=$(14+(i-1)*3);
      }
      strike1=strike[1]
      dip1=dip[1]
      rake1=rake[1]
      strike2=strike[2]
      dip2=dip[2]
      rake2=rake[2]

      author_centroid="GCMT"

    } # FMT = K
    #------------------------------#

    #------------------------------#
    if (FMT=="I") {
      # ISC FORMAT
      # 1       , 2             , 3   , 4   , 5  , 6  , 7    ,   8      ,               9     ,
      # EVENT_ID, ORIGIN_AUTHOR, DATE, TIME, LAT, LON, DEPTH, ISCENTROID, CENTROID_AUTHOR,
      #
      # 10, 11, 12, 13,  14,  15,  16,  17,  18,  19,     20,  21,   22,     23,  24,   25,
      # EX, MO, MW, EX, MRR, MTT, MPP, MRT, MTP, MPR, STRIKE, DIP, RAKE, STRIKE, DIP, RAKE,
      #
      # 26,    27,   28,    29,    30,   31,    32,    33,   34,    35
      # EX, T_VAL, T_PL, T_AZM, P_VAL, P_PL, P_AZM, N_VAL, N_PL, N_AZM
      #
      # Because the fields are comma delimited and fixed width, the field entries will contain whitespace.
      # We have to chop out the whitespace on read to make the data processable.

      # idcode	event_code	id	epoch	lon_centroid	lat_centroid	depth_centroid	lon_origin	lat_origin	depth_origin
      # author_centroid	author_origin	MW	mantissa	exponent	strike1	dip1	rake1	strike2	dip2	rake2	exponent	Tval
      # Taz	Tinc	Nval	Naz	Ninc	Pval	Paz	Pinc	exponent	Mrr	Mtt	Mpp	Mrt	Mrp	Mtp	centroid_dt


      # Reinitialize the calculation commands as the ISC format varies quite a lot
      # and each line needs its own approach

      calc_ntp_from_moment_tensor=0
      calc_moment_tensor_from_sdr1=0
      calc_principal_axes_from_sdr1=0
      calc_ntp_from_moment_tensor=0
      calc_mantissa_from_exp_and_mt=0
      calc_sdr_from_ntp=0
      calc_sdr2=0
      calc_mant_exp_from_M=0
      calc_M_from_mantissa_exponent=0

      event_code=$1;      gsub(/^[ \t]+/,"",event_code);gsub(/[ \t]+$/,"",event_code)
      author_origin=$2; gsub(/^[ \t]+/,"",author_origin);gsub(/[ \t]+$/,"",author_origin)
      date=$3;          gsub(/^[ \t]+/,"",date);gsub(/[ \t]+$/,"",date)
      time=substr($4,1,8)
      id=sprintf("%sT%s", date, time)
      is_centroid=$8;   gsub(/^[ \t]+/,"",is_centroid);gsub(/[ \t]+$/,"",is_centroid)

      lat_tmp=$5+0;
      lon_tmp=$6+0;
      depth_tmp=$7+0;

      # This entry is for a centroid location
      if (is_centroid == "TRUE") {
        lat_centroid=lat_tmp
        lon_centroid=lon_tmp
        depth_centroid=depth_tmp
        lat_origin="none"
        lon_origin="none"
        depth_origin="none"
        author_centroid=$9; gsub(/^[ \t]+/,"",author_centroid);gsub(/[ \t]+$/,"",author_centroid);
        author_origin="none"
      } else {
        lat_centroid="none"
        lon_centroid="none"
        depth_centroid="none"
        lat_origin=lat_tmp
        lon_origin=lon_tmp
        depth_origin=depth_tmp
        author_origin=$2;     gsub(/^[ \t]+/,"",author_origin);gsub(/[ \t]+$/,"",author_origin)
        author_centroid="none"
      }

      # Read and check SDR values
      strike1=$20+0;
      dip1=$21+0;
      rake1=$22+0;
      strike2=$23+0;
      dip2=$24+0;
      rake2=$25+0;

      # 10, 11, 12, 13,  14,  15,  16,  17,  18,  19,
      # EX, MO, MW, EX, MRR, MTT, MPP, MRT, MTP, MPR,

      # N-m to dynes-cm is a factor of 10^7
      moment_exponent=$13+7
      # Adopt the moment tensor exponent if M0 exponent is not already set
      if (exponent==0 && moment_moment>0)  { exponent=moment_exponent }
      Mrr=$14+0;
      Mtt=$15+0
      Mpp=$16+0
      Mrt=$17+0
      Mtp=$18+0
      Mrp=$19+0

      # 26,    27,   28,    29,    30,   31,    32,    33,   34,    35
      # EX, T_VAL, T_PL, T_AZM, P_VAL, P_PL, P_AZM, N_VAL, N_PL, N_AZM

      # Read and check principal axes values
      # N-m to dynes-cm is a factor of 10^7

      axes_moment=$26+7
      if (exponent==0 && axes_moment>0) { exponent=moment_exponent }

      Tval=$27+0
      Tinc=$28+0
      Taz=$29+0
      Pval=$30+0
      Pinc=$31+0
      Paz=$32+0
      Nval=$33+0
      Ninc=$34+0
      Naz=$35+0

      if (Tval==0 && Pval==0 && Nval==0) {
        Tval=1
        Nval=0
        Pval=-1
      }

      # isnumber does not work to detect 0, 0, 0, 0, ... data which is what we
      # see now that we are converting using +0


      if (((isnumber(strike1) && strike1<=360 && strike1 >= -360)   &&
          (isnumber(dip1) && dip1<=90 && dip1 >= 0)                 &&
          (isnumber(rake1) && rake1<=180 && rake1 >= -180))         &&
          (!(strike1==0 && dip1==0 && rake1==0))                     )
      {
        np1_exists=1
      } else {
        np1_exists=0
      }

      # print "--"
      # print "np1: ", np1_exists
      # print $0
      # print "--"

      if ((isnumber(strike2) && strike2<=360 && strike2 >= -360)   &&
          (isnumber(dip2) && dip2<=90 && dip2 >= 0)                &&
          (isnumber(rake2) && rake2<=180 && rake2 >= -180)         &&
          (!(strike2==0 && dip2==0 && rake2==0))                    )
      {
        np2_exists=1
      } else {
        np2_exists=0
      }

	    # Read and check moment tensor values. Tricky as ISC switches the typical order of Mrp Mtp
      #

      if ( (isnumber(Mrr) && isnumber(Mtt) && isnumber(Mpp)               &&
            isnumber(Mrt) && isnumber(Mtp) && isnumber(Mrp))              &&
            (!(Mrr==0 && Mtt==0 && Mpp==0 && Mrt==0 && Mtp==0 && Mrp==0))  )
      {
        tensor_exists=1
      } else {
        tensor_exists=0
      }

      if ((isnumber(Taz) && isnumber(Tinc) && isnumber(Paz)                 &&
           isnumber(Pinc) && isnumber(Naz) && isnumber(Ninc))               &&
           (!(Taz==0 && Tinc==0 && Paz==0 && Pinc==0 && Naz==0 && Ninc==0))  )
      {
        ntp_axes_exist=1
      } else {
        ntp_axes_exist=0
      }

      if ( isnumber(Tval) && isnumber(Pval) && isnumber(Nval) )
      {
        ntp_vals_exist=1
      } else {
        ntp_vals_exist=0
      }

      # There are no ISC examples with exponent defined but not mantissa.
      # All EX fields are always the same when they are defined.

      # N-m to dynes-cm is a factor of 10^7

      exponent=$10+7
      mantissa=$11+0
      MW=$12+0

      # ASIES mechanism in the ISC catalog are in the wrong units (dynes-cm) vs ISC
      if (author_centroid == "ASIES" || author_origin == "ASIES") {
        exponent=$10
        calc_M_from_mantissa_exponent=1
      }

      if (exponent<8 || mantissa < 1e-10) {
        skip_this_entry=1
      }


      # Currently the script is failing hard for np1 and np2 existing but not other things.



      # Logic to complete the entries if possible.
      # FLAGS: np1_exists np2_exists ntp_axes_exist ntp_vals_exist tensor_exists get_moment_from_either_tensor_or_ntp
      #
      # FUNCTIONS: calc_ntp_from_moment_tensor  calc_mantissa_from_exp_and_mt calc_sdr_from_ntp calc_sdr2 calc_mant_exp_from_M
      #            calc_M_from_mantissa_exponent calc_moment_tensor_from_sdr1 calc_principal_axes_from_sdr1


      # TODO: Check that the following functions go in the order mt->ntp ntp->sdr
      #


      # If we DO have the moment tensor, calculate the NTP and SDR as needed.
      if (tensor_exists==1) {
        if (ntp_axes_exist==0 || ntp_vals_exist==0) {
          calc_ntp_from_moment_tensor=1
        }
        if (np1_exists==0 || np2_exists==0) {
          calc_sdr_from_ntp=1
        }
      }

      # If we DO NOT have the moment tensor...
      if (tensor_exists==0) {
        if (np1_exists==1 && np2_exists==1) {
          # If we DO have both nodal planes, calculate MT and NTP from the nodal planes
          calc_moment_tensor_from_sdr1=1
          calc_principal_axes_from_sdr1=1
        } else {
            # If we have none of MT, SDR, or NTP, we skip the record
            skip_this_entry=1
        }
      }

      if (mantissa==0) { skip_this_entry=1 }

      # BYKL reports ~462 entries from 199-2015 with ONLY TNP + exponent!

      # skip_this_entry=0

    }
    #------------------------------#

    #------------------------------#
    # GFZ moment tensor, accepts multiple events reports concatenated together
    # Each event needs to be the 44 line standard format

    if (FMT=="Z") {
      # Detect the first line of an event entry
      if ($1=="GFZ" && $2=="Event") {
        # Line 1
        event_code=$3

        # Line 2
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
          split($1,ymd,"/")
          year=ymd[1]+2000
          month=sprintf("%02d", ymd[2]+0)
          day=sprintf("%02d", ymd[3]+0)
          split($2,hmsd,".")
          split(hmsd[1], hms, ":")
          hour=hms[1]+0
          minute=hms[2]+0
          second=hms[3]+0
          id=sprintf("%s-%s-%sT%02d:%02d:%02d", year, month, day, hour, minute, second)

        # Line 3
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}

        # Line 4
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
          lon_centroid="none"
          lat_centroid="none"
          author_centroid="none"

          lon_origin=$3
          lat_origin=$2
          depth_origin="none"
          author_origin="GFZ"

        # Line 5
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
          MW=$2

        # Line 6
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}

        # Line 7
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}

        if ($2 == "CENTROID") {
          # Line 8
          getline
          # Line 9
          getline
          lat_centroid=$2
          lon_centroid=$3
          author_centroid="GFZ"

          getline
          depth_centroid=$2

          # GFZ does not give depth of origin for Centroid solutions so set all to none
          lat_origin="none"
          lon_origin="none"
          depth_origin="none"
          author_origin="none"

        } else {
          # Line 8
          if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
            depth_origin=$2
        }

        # Lines after this are origin; +2 if it was centroid
        # Line 9
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}

        # Line 10
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Mrr=sprintf("%g", substr($0,7,5))
           Mtt=sprintf("%g", substr($0,23,5))

        # Line 11
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Mpp=sprintf("%g", substr($0,7,5))
           Mrt=sprintf("%g", substr($0,23,5))

        # Line 12
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Mrp=sprintf("%g", substr($0,7,5))
           Mtp=sprintf("%g", substr($0,23,5))

        # Line 13
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}

        # Line 14
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Tval=sprintf("%g", substr($0,10,6))
           Tinc=sprintf("%g", substr($0,22,4))
           Taz=sprintf("%g", substr($0,30,4))

        # Line 15
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Nval=sprintf("%g", substr($0,10,6))
           Ninc=sprintf("%g", substr($0,22,4))
           Naz=sprintf("%g", substr($0,30,4))

        # Line 16
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           Pval=sprintf("%g", substr($0,10,6))
           Pinc=sprintf("%g", substr($0,22,4))
           Paz=sprintf("%g", substr($0,30,4))

        # Line 17
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
        # Line 18
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}


        # Line 19
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
           strike1=sprintf("%g", substr($0,13,3))
           dip1=sprintf("%g", substr($0,21,3))
           rake1=sprintf("%g", substr($0,29,4))

        # Line 20
        if (getline <= 0) {print("unexpected EOF or error:", ERRNO) > "/dev/stderr"; exit 0}
            strike2=sprintf("%g", substr($0,13,3))
            dip2=sprintf("%g", substr($0,21,3))
            rake2=sprintf("%g", substr($0,29,4))

        # GFZ files must be truncated at line 20 if they are contatenated

        INID="Z"
        focaltype=mechanism_type_from_TNP(Tinc, Ninc, Pinc)
      } else {
        skip_this_entry=1
      }
    }


    ########## Perform the required calculations to fill in the blanks #########

    if (skip_this_entry==0) {

      if (calc_mantissa_from_exp_and_mt==1) {
        # printf "%s-", "calc_mantissa_from_exp_and_mt"
        mantissa = sqrt(Mrr*Mrr+Mtt*Mtt+Mpp*Mpp + 2.*(Mrt*Mrt + Mrp*Mrp + Mtp*Mtp))/sqrt(2)
      }

      if (calc_ntp_from_moment_tensor==1) {
        # printf "%s-", "calc_ntp_from_moment_tensor"

        cmd = sprintf("perl -I %s %s %s %s %s %s %s %s", diagdir, diagscript, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp)
        while ( ( cmd | getline diagline ) > 0 ) {
          split(diagline, diagarray, " ")
        }
        close(cmd);

        Tval=diagarray[1]
        Taz=diagarray[2]
        Tinc=diagarray[3]
        Nval=diagarray[4]
        Naz=diagarray[5]
        Ninc=diagarray[6]
        Pval=diagarray[7]
        Paz=diagarray[8]
        Pinc=diagarray[9]

        if (Tval==0 && Taz==0 && Tinc==0 && Nval==0 && Naz==0 && Ninc==0 && Pval==0 && Paz==0) {
          skip_this_entry=1
        }
      }

      if (calc_sdr_from_ntp==1) {
        # printf "%s-", "calc_sdr_from_ntp"

        ntp_to_sdr(Taz, Tinc, Paz, Pinc, SDR)
        strike1=SDR[1]
        dip1=SDR[2]
        rake1=SDR[3]
        strike2=SDR[4]
        dip2=SDR[5]
        rake2=SDR[6]
      }

      if (calc_sdr2==1) {
        # printf "%s-", "calc_sdr2"

        aux_sdr(strike1, dip1, rake1, SDR)
        strike2=SDR[1]
        dip2=SDR[2]
        rake2=SDR[3]
      }

      if (calc_mant_exp_from_M==1) {
        # printf "%s-", "calc_mant_exp_from_M"

        tmpval=sprintf("%e", 10^((MW+10.7)*3/2));
        split(tmpval, tmparr, "e")
        mantissa=tmparr[1]
        split(tmparr[2], newtmparr, "+")
        exponent=newtmparr[2]
      }

      if (calc_M_from_mantissa_exponent==1) {
        # printf "%s-", "calc_M_from_mantissa_exponent"
         if (mantissa<=0) {
            skip_this_entry=1
         } else {
            MW=(2/3)*log(mantissa*(10**exponent))/log(10)-10.7
         }
      }

      if (calc_moment_tensor_from_sdr1==1) {
        # printf "%s-", "calc_moment_tensor_from_sdr1"

        sdr_mantissa_exponent_to_full_moment_tensor(strike1, dip1, rake1, mantissa, exponent, MT2)

        Mrr=MT2[1]
        Mtt=MT2[2]
        Mpp=MT2[3]
        Mrt=MT2[4]
        Mrp=MT2[5]
        Mtp=MT2[6]
      }

      # Principal axes returned this way have TPN eigenvalues of 1, 0, -1
      if (calc_principal_axes_from_sdr1==1) {
        # printf "%s-", "calc_principal_axes_from_sdr1"

        sdr_to_tnp(strike1, dip1, rake1, TNP)

        Tval=TNP[1]*mantissa
        Taz=TNP[2]
        Tinc=TNP[3]
        Nval=TNP[4]*mantissa
        Naz=TNP[5]
        Ninc=TNP[6]
        Pval=TNP[7]*mantissa
        Paz=TNP[8]
        Pinc=TNP[9]
      }

      if (calc_epoch==1) {
        # printf "%s-", "calc_epoch"

        split(id, a, "-")
        year=a[1]
        month=a[2]
        split(a[3],b,"T")
        day=b[1]
        split(b[2],c,":")
        hour=c[1]
        minute=c[2]
        second=c[3]
        the_time=sprintf("%i %i %i %i %i %i",year,month,day,hour,minute,int(second+0.5));
        epoch=mktime(the_time);
      }

      # Always calculate the type of focal mechanism and append to ID code
      focaltype=mechanism_type_from_TNP(Tinc, Ninc, Pinc)
      idcode=sprintf("%s%s", INID, focaltype)

      # Sanitize longitudes
      if (lon_centroid+0 == lon_centroid) {
        while (lon_centroid > 180) {
          lon_centroid = lon_centroid-360
        }
        while (lon_centroid < -180) {
          lon_centroid = lon_centroid+360
        }
      }
      if (lon_origin+0 == lon_origin) {
        while (lon_origin > 180) {
          lon_origin = lon_origin-360
        }
        while (lon_origin < -180) {
          lon_origin = lon_origin+360
        }
      }

      if (skip_this_entry==0) {
        # Record checks out as OK, print to stdout
        # print "-"
        print idcode, event_code, id, epoch, lon_centroid, lat_centroid, depth_centroid, lon_origin, lat_origin, depth_origin, author_centroid, author_origin, MW, mantissa, exponent, strike1, dip1, rake1, strike2, dip2, rake2, exponent, Tval, Taz, Tinc, Nval, Naz, Ninc, Pval, Paz, Pinc, exponent, Mrr, Mtt, Mpp, Mrt, Mrp, Mtp, centroid_dt
      } else {
        # Something is wrong. Print to stderr
        # print "Error:"
        print $0 >> "./cmt_tools_rejected.dat"
      }
    } else {
      print $0 >> "./cmt_tools_rejected.dat"
    }# end skip of entries that are determined to be bad during processing
  } # end skip of blank or commented lines
}

# CODE BLOCK AT THE END GOES HERE
# END
# {
#
# }
'
# tectoplot focal mechanism format:
# Tectoplot format: (first 15 fields are psmeca format)
# 1: code             Code G=GCMT I=ISC
# 2: lon_origin              Longitude (°)
# 3: lat_origin              Latitude (°)
# 4: depth_origin            Depth (km)
# 5: strike1          Strike of nodal plane 1
# 6: dip1             Dip of nodal plane 1
# 7: rake1            Rake of nodal plane 1
# 8: strike2       Strike of nodal plane 2
# 9: dip2             Dip of nodal plane 2
# 10: rake2           Rake of nodal plane 2
# 11: mantissa        Mantissa of M0
# 12: exponent        Exponent of M0
# 13: lon_centroid          Longitude alternative (col1=origin, col13=centroid etc) (°)
# 14: lat_centroid          Longitude alternative (col1=origin, col13=centroid etc) (°)
# 15: newid           tectoplot ID code: YYYY-MM-DDTHH:MM:SS
# 16: TAz             Azimuth of T axis
# 17: TInc            Inclination of T axis
# 18: Naz             Azimuth of N axis
# 19: Ninc            Inclination of N axis
# 20: Paz             Azimuth of P axis
# 21: Pinc            Inclination of P axis
# 22: Mrr             Moment tensor
# 23: Mtt             Moment tensor
# 24: Mpp             Moment tensor
# 25: Mrt             Moment tensor
# 26: Mrp             Moment tensor
# 27: Mtp             Moment tensor
# 28: MW
# 29: depth_centroid
# (30: seconds)
