# Function to add two Euler poles given in geographic coords, output in geographic coords
# This function uses two poles of rotation given in the form A->B  C->B -- to find -->  A->C
# Call like this: awk -f euleradd.awk eulerpairs.txt
# Where eulerpairs.txt (or stdin if piped in) are in the form lat1 lon1 rate1 lat2 lon2 rate2


# Something is wrong, where sometimes the addition returns a bad eLon...

# Input
# lat1   lon1   rate1   lat2   lon2   rate2
# 50.37  -3.29  0.544   44.44  23.09  0.608
# Output
# -1.95016 -74.4483 0.197499


function atan(x) { return atan2(x,1) }
function acos(x) { return atan2(sqrt(1-x*x), x) }
function asin(x) { return atan2(x, sqrt(1-x*x)) }

function deg2rad(Deg){ return ( 4.0*atan(1.0)/180 ) * Deg }
function rad2deg(Rad){ return ( 45.0/atan(1.0) ) * Rad }

function euleradd(eLat_d1, eLon_d1, eV1, eLat_d2, eLon_d2, eV2) {
	eLat_r1 = deg2rad(eLat_d1)
	eLon_r1 = deg2rad(eLon_d1)
	eLat_r2 = deg2rad(eLat_d2)
	eLon_r2 = deg2rad(eLon_d2)

	a11 = eV1*cos(eLat_r1)*cos(eLon_r1)
	a21 = eV1*cos(eLat_r1)*sin(eLon_r1)
	a31 = eV1*sin(eLat_r1)

	a12 = eV2*cos(eLat_r2)*cos(eLon_r2)
	a22 = eV2*cos(eLat_r2)*sin(eLon_r2)
	a32 = eV2*sin(eLat_r2)

	a1 = a11-a12
	a2 = a21-a22
	a3 = a31-a32

  eVA = sqrt(a1*a1+a2*a2+a3*a3)

  if (eVA == 0) {
		elat_rA = 0
		elon_rA = 0
	}
	else {
		elat_rA = asin(a3/eVA)
		elon_rA = atan2(a2,a1)
	}
  print(rad2deg(elat_rA), rad2deg(elon_rA), eVA)
}

BEGIN{
}
NF {
	printf euleradd($1, $2, $3, $4, $5, $6)
}
