# tectoplot_functions.awk

# Include in scripts using gawk:
# @include "tectoplot_functions.awk"

# Math functions

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
function ddiff(u)      { return u > 180 ? 360 - u : u   }
function ceil(x)       { return int(x)+(x>int(x))       }


function ave_dir(d1, d2) {
  sumcos=cos(deg2rad(d1))+cos(deg2rad(d2))
  sumsin=sin(deg2rad(d1))+sin(deg2rad(d2))
  val=rad2deg(atan2(sumsin, sumcos))
  return val
}

# The following function will take a string in the (approximate) form
# +-[deg][chars][min][chars][sec][chars][north|*n*]|[south|*s*]|[east|*e*]|[west|*w*][chars]
# and return the appropriately signed decimal degree
# -125°12'18" -> -125.205
# 125 12 18 WEST -> -125.205

function coordinate_decimal(str) {
  neg=1
  ss=tolower(str)
  gsub("south", "s", ss)
  gsub("west", "w", ss)
  gsub("east", "e", ss)

  if (ss ~ /s/ || ss ~ /w/ || substr($0,1,1)=="-") {
    neg=-1;
  }
  gsub(/[^0-9\s\.]/, " ", ss)
  split(ss, arr);
  val=neg*(arr[1]+arr[2]/60+arr[3]/3600)
  return val
}

# Data selection by longitude range potentially spanning dateline

function test_lon(minlon, maxlon, lon) {
  while (lon>180) {lon=lon-360}
  while (lon<-180) {lon=lon+360}
  if (minlon < -180) {
    if (maxlon <= -180) {
      return (lon-360 <= maxlon && lon-360 >= minlon)?1:0
    } else { # (maxlon >= -180)
      return (lon-360 >= minlon || lon <= maxlon)?1:0
    }
  } else {   # (minlon >= -180)
    if (minlon < 180){
      if (maxlon <= 180) {
        return (lon <= maxlon && lon >= minlon)?1:0
      } else { # maxlon > 180
        return (lon >= minlon || lon+360 <= maxlon)?1:0
      }
    } else {  # (minlon >= 180)
      return (lon+360 >= minlon && lon+360 <= maxlon)?1:0
    }

  }
}

# Round down n to the nearest multiple of multipleOf

function rd(n, multipleOf)
{
  if (n % multipleOf == 0) {
    num = n
  } else {
     if (n > 0) {
        num = n - n % multipleOf;
     } else {
        num = n + (-multipleOf - n % multipleOf);
     }
  }
  return num
}

function test_include() {
  print "Works"
}

### Focal mechanism functions

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
