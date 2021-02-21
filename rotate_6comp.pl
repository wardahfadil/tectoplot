#!/usr/bin/perl

# Kyle Bradley, NTU, January 2021

# Rotate a focal mechanism in Moment Tensor format around a given axis
# Tested by back-rotating nodal planes to horizontal; seems to work.

# Inputs: none
# Pipe in a file that has 14 column tectoplot MomentTensor format (psmeca+) plus
# trend, plunge, and angle in three final columns (15, 16, 17), all in degrees
# If doing strike/dip correction, trend=strike, plunge=0, angle=dip


use File::Basename;
use lib dirname (__FILE__);
# BEGIN {push @INC, '.'}
use Math::Trig;
use Scalar::Util qw(looks_like_number);
use List::Util qw[min max];
use Math::MatrixReal;

$r2d=180/pi();
$d2r=pi()/180;


while(<>){

	my @params = split(' ', $_);

	$Mxx = $params[3];
	$Myy = $params[4];
	$Mzz = $params[5];
	$Mxy = $params[6];
	$Mxz = $params[7];
	$Myz = $params[8];
	$Myx = $Mxy;
	$Mzx = $Mxz;
	$Mzy = $Myz;

	$trenddeg=$params[14];

	# plunge here is the angle up the horizontal plane [-90=down; 90=up];
	# trend is the azimuth angle CW from north [0-360]

	$plungedeg=($params[15]);

	$angle=$params[16]*$d2r;
	$plunge=$plungedeg*$d2r;
	$trend=$trenddeg*$d2r;

	# GCMT focal mechanisms are in Up, South, East coordinates

	$ux = sin($plunge);
	$uy = -cos($plunge)*cos($trend);
	$uz = cos($plunge)*sin($trend);

	$ct = cos($angle);
	$st = sin($angle);

	$R1 = $ct + $ux*$ux*(1-$ct);
	$R2 = $ux*$uy*(1-$ct)-$uz*$st;
	$R3 = $ux*$uz*(1-$ct)+$uy*$st;
	$R4 = $uy*$ux*(1-$ct)+$uz*$st;
	$R5 = $ct+$uy*$uy*(1-$ct);
	$R6 = $uy*$uz*(1-$ct)-$ux*$st;
	$R7 = $uz*$ux*(1-$ct)-$uy*$st;
	$R8 = $uz*$uy*(1-$ct)+$ux*$st;
	$R9 = $ct+$uz*$uz*(1-$ct);

	$rotmatrix = Math::MatrixReal->new_from_rows( [ [$R1, $R2, $R3], [$R4, $R5, $R6 ], [$R7, $R8, $R9] ] );

	if (looks_like_number($Mxx) && looks_like_number($Mxy) && looks_like_number($Mxz) && looks_like_number($Myx) && looks_like_number($Myy) && looks_like_number($Myz) && looks_like_number($Mzx) && looks_like_number($Mzy) && looks_like_number($Mzz)) {

		$matrix = Math::MatrixReal->new_from_rows( [ [$Mxx,$Mxy,$Mxz], [$Myx,$Myy,$Myz], [$Mzx,$Mzy,$Mzz] ] );

		$rotated= ~$rotmatrix * $matrix * $rotmatrix;
		# print $rotated;
		printf "%s %s %s %.3f %.3f %.3f %.3f %.3f %.3f %s %s %s %s %s\n", $params[0], $params[1], $params[2],
		      $rotated->[0][0][0], $rotated->[0][1][1], $rotated->[0][2][2], $rotated->[0][0][1],
					$rotated->[0][0][2], $rotated->[0][1][2], $params[9], $params[10], $params[11],
					$params[12], $params[13];
	}
}
