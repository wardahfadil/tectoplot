#!/usr/bin/perl

use File::Basename;
use lib dirname (__FILE__);
# BEGIN {push @INC, '.'}
use Math::Trig;
use Scalar::Util qw(looks_like_number);
use List::Util qw[min max];
use Math::MatrixReal;

$r2d=180/pi();
$d2r=pi()/180;

# Modified by Kyle bradley, NTU, November 2020 to output principal axes and
# nodal plane strike/dip/rake of moment tensors.

# Based on original code diagonalize.pl by Utpal Kumar (IESAS) and
# GMT's psmeca.c/ultimeca.c by G. Patau (IPGP)

# Build the symmetric moment tensor matrix from the input arguments

$Mxx = $ARGV[0];
$Myy = $ARGV[1];
$Mzz = $ARGV[2];
$Mxy = $ARGV[3];
$Mxz = $ARGV[4];
$Myz = $ARGV[5];
$Myx = $Mxy;
$Mzx = $Mxz;
$Mzy = $Myz;

if (looks_like_number($Mxx) && looks_like_number($Mxy) && looks_like_number($Mxz) && looks_like_number($Myx) && looks_like_number($Myy) && looks_like_number($Myz) && looks_like_number($Mzx) && looks_like_number($Mzy) && looks_like_number($Mzz)) {
	$matrix = Math::MatrixReal->new_from_rows( [ [$Mxx,$Mxy,$Mxz], [$Myx,$Myy,$Myz], [$Mzx,$Mzy,$Mzz] ] );

	($l, $V) = $matrix->sym_diagonalize();	#obtain the eigenvalues and eigenvectors
	$detV = $V->det;
	# print STDERR sprintf("\nDetv is %f\n", $detV);
	# print $l;
	$l1=$l->element(1,1);
	$l2=$l->element(2,1);
	$l3=$l->element(3,1);
	$lsum=$l1+$l2+$l3;
	# print STDERR sprintf("\nlsum is %f\n", $lsum);

	# Criteria are that the trace of the diagonalized matrix is small and the determinant of V is not small.
	if ( ($l1 + $l2 + $l3 < 0.05) && (abs($detV) > 1e-2 ) ) {

		# Rearrange the eigenvalues and eigenvectors so that l1>=l2>=l3
		@lb=($l1,$l2,$l3);
		$temp1 = max($l1,$l2,$l3);	#max eigenvalue
		$temp3 = min($l1,$l2,$l3);	#min eigenvalue

		for(my $i = 0; $i <= $#lb; $i++){
			$j=$i+1;
			# print("$sorted[$i] \n");
			if ($lb[$i] == $temp1) {
				$lb1new = $lb[$i];
				# print "Middle eigenvector is from index $j\n";
				$V1 = $V->column($i+1);
			} elsif ($lb[$i] == $temp3) {
				$lb3new = $lb[$i];
				# print "Largest eigenvector is from index $j\n";
				$V3 = $V->column($i+1);
			} else {
				# print "Smallest eigenvector is from index $j\n";
				$lb2new = $lb[$i];
				$V2 = $V->column($i+1);
			}
		}

		# Calculate the plunge and azimuth of the principal axes
		$pl0 = asin(-$V1->element(1,1))*180/3.141592;
		$az0 = atan2($V1->element(3,1), -$V1->element(2,1))*180/3.141592;
		$pl1 = asin(-$V2->element(1,1))*180/3.141592;
		$az1 = atan2($V2->element(3,1), -$V2->element(2,1))*180/3.141592;
		$pl2 = asin(-$V3->element(1,1))*180/3.141592;
		$az2 = atan2($V3->element(3,1), -$V3->element(2,1))*180/3.141592;

		# T axis
		if ($pl0 <= 0) {
			$pl0 = -$pl0;
			$az0 = $az0 + 180;
		}
		if ($az0 < 0) {
			$az0 = $az0 + 360;
		} elsif ($az0 > 360) {
			$az0 = $az0 - 360;
		}

		# N axis
		if ($pl1 <= 0) {
			$pl1 = -$pl1;
			$az1 = $az1 + 180;
		}
		if ($az1 < 0) {
			$az1 = $az1 + 360;
		} elsif ($az1 > 360) {
			$az1 = $az1 - 360;
		}

		# P axis
		if ($pl2 <= 0) {
			$pl2 = -$pl2;
			$az2 = $az2 + 180;
		}
		if ($az2 < 0) {
			$az2 = $az2 + 360;
		} elsif ($az2 > 360) {
			$az2 = $az2 - 360;
		}

		printf "%.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f\n", $lb1new, $az0, $pl0, $lb2new, $az1, $pl1, $lb3new, $az2, $pl2
	} else {
		# Matrix is not well conditioned for diagonalization. Skip.
		#valval=$l1 + $l2 + $l3;
		print "0 0 0 0 0 0 0 0 1\n";
	}
} else {
	# Input is not in number format for some reason. Skip
 	print "0 0 0 0 0 0 0 0 0\n";
	exit 0;
}
