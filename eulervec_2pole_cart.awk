# Function to calculate Euler velocity vectors (azimuth, velocity) for lat lon pairs in an input file
# This function uses two poles of rotation given in the form A->B  C->B -- to find -->  A->C
# Call like this: awk -f eulervec_2pole.awk -v eLat_d1=17.69 -v eLon_d1=134.30 -v eV1=1.763 -v eLat_d2=7.69 -v eLon_d2=34.30 -v eV2=0.3 testlatlon.txt


function atan(x) { return atan2(x,1) }
function acos(x) { return atan2(sqrt(1-x*x), x) }
function deg2rad(Deg){ return ( 4.0*atan(1.0)/180 ) * Deg }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }

# Take data in lon lat format
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

	azimuth = rad2deg(atan2(L2,L1))
	velocity = sqrt(V1*V1+V2*V2+V3*V3)

  print(L2*2*pi/360, L1*2*pi/360)
}

BEGIN{
}
NF {
	printf eulervec(eLat_d1, eLon_d1, eV1, eLat_d2, eLon_d2, eV2, $2, $1)
}
