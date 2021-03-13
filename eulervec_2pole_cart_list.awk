# Kyle Bradley, Nanyang Technological University, kbradley@ntu.edu.sg
# February 2021

# Function to calculate Euler velocity vectors (azimuth, velocity) for points within an input file
# This function uses two poles of rotation given in the form A->B  C->B -- to find -->  A->C
# This function skips lines that begin with >
# Expected input file format is:
# 1        2        3       4        5       6       7      8      9       10     11		  12
# lon      lat      seg_az  seglen   plate1  plate2  p1lat  p1lon  p1rate  p2lat  p2lon  p2rate
# 90.31501 -0.58031 67.529  512.321  in      cp      50.37  -3.29  0.544   44.44  23.09  0.608
# Output is
# 1   2   3       4      5      6      7     8     9      10    11		12		 13 14
# lon lat azimuth seglen plate1 plate2 p1lat p1lon p1rate p2lat p2lon p2rate VN VE


# A spherical Earth with a radius of 6371 km is assumed.

# ***** NOT YET IMPLEMENTED: To account for the
# (small) effect of ellipticity, input geodetic site coordinates should be
# converted to spherical latitude/longitude before calculating velocities
# using lat'=atan((1-e*e)*tan(lat)) with e=0.081819 *****

# Example:
# awk -f eulervec_2pole_list.awk listdata.txt






function atan(x) { return atan2(x,1) }
function acos(x) { return atan2(sqrt(1-x*x), x) }
function deg2rad(Deg){ return ( 4.0*atan(1.0)/180 ) * Deg }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }

# Take data in lon lat format
# The units of eV1,eV2 dictate the units of the output
# e.g. rad/year or deg/Myr

function eulervec(eLat_d1, eLon_d1, eV1, eLat_d2, eLon_d2, eV2, tLon_d, tLat_d) {
	pi = atan2(0, -1)
	earthrad = 6371
	eLat_r1 = deg2rad(eLat_d1)
	eLon_r1 = deg2rad(eLon_d1)
	eLat_r2 = deg2rad(eLat_d2)
	eLon_r2 = deg2rad(eLon_d2)

	tLat_r = deg2rad(tLat_d)
	tLon_r = deg2rad(tLon_d)

	a11 = eV1*cos(eLat_r1)*cos(eLon_r1)
	a21 = eV1*cos(eLat_r1)*sin(eLon_r1)
	a31 = eV1*sin(eLat_r1)

	a12 = eV2*cos(eLat_r2)*cos(eLon_r2)
	a22 = eV2*cos(eLat_r2)*sin(eLon_r2)
	a32 = eV2*sin(eLat_r2)

	a1 = a11-a12
	a2 = a21-a22
	a3 = a31-a32

	b1 = earthrad*cos(tLat_r)*cos(tLon_r)
	b2 = earthrad*cos(tLat_r)*sin(tLon_r)
  b3 = earthrad*sin(tLat_r)

	V1 = a2*b3-a3*b2
	V2 = a3*b1-a1*b3
	V3 = a1*b2-a2*b1

	R11 = -sin(tLat_r)*cos(tLon_r)
	R12 = -sin(tLat_r)*sin(tLon_r)
	R13 = cos(tLat_r)
  R21 = -sin(tLon_r)
  R22 = cos(tLon_r)
  R23 = 0
  R31 = cos(tLat_r)*cos(tLon_r)
  R32 = cos(tLat_r)*sin(tLon_r)
  R33 = sin(tLat_r)

	L1 = R11*V1 + R12*V2 + R13 * V3
	L2 = R21*V1 + R22*V2 + R23 * V3
 	azimuth=rad2deg(atan2(L2, L1))
	if (azimuth<0) {
		azimuth=azimuth+360
	}

	print(L2*2*pi/360, L1*2*pi/360, azimuth)
}

BEGIN{
}
NF {
	if ($1 == ">") printf("%s %s\n", $1, $2); else { ORS=" "; print; eulervec($7, $8, $9, $10, $11, $12, $1, $2); printf "\n"; }
}
