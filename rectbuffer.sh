# rectbuffer.sh
# Generate a 'rectangular' style buffer around a polyline by connecting the
# endpoints of angle bisectors passing through vertices. The buffer distance
# is in km and angles are calculated at the vertex.
#
# Input: polyline.xy buffer_dist(km)
# Output: buffer.xy

# gmt_init_tmpdir


# Track file is lon lat whitespace delimited columns
TRACK=$1
[[ ! -e $TRACK ]] && exit 1
cp $TRACK trackfile.txt
WIDTHKM=$2

NLINES=$(wc -l < trackfile.txt)
gawk < trackfile.txt -v numlines="${NLINES}" '
    function acos(x)       { return atan2(sqrt(1-x*x), x)   }
    function getpi()       { return atan2(0,-1)             }
    function deg2rad(deg)  { return (getpi() / 180) * deg   }
    function rad2deg(rad)  { return (180 / getpi()) * rad   }
    function ave_dir(d1, d2) {
      sumcos=cos(deg2rad(d1))+cos(deg2rad(d2))
      sumsin=sin(deg2rad(d1))+sin(deg2rad(d2))
      val=rad2deg(atan2(sumsin, sumcos))
      return val
    }
    (NR==1) {
      prevlon=$1
      prevlat=$2
      lonA=deg2rad($1)
      latA=deg2rad($2)
    }
    (NR==2) {
      lonB = deg2rad($1)
      latB = deg2rad($2)
      thetaA = (rad2deg(atan2(sin(lonB-lonA)*cos(latB), cos(latA)*sin(latB)-sin(latA)*cos(latB)*cos(lonB-lonA)))+90)%360;
      printf "%.5f %.5f %.3f\n", prevlon, prevlat, thetaA;
      prevlat=$2
      prevlon=$1
    }
    (NR>2 && NR<numlines) {
      lonC = deg2rad($1)
      latC = deg2rad($2)

      thetaB = (rad2deg(atan2(sin(lonC-lonB)*cos(latC), cos(latB)*sin(latC)-sin(latB)*cos(latC)*cos(lonC-lonB)))+90)%360;
      printf "%.5f %.5f %.3f\n", prevlon, prevlat, ave_dir(thetaA,thetaB);

      thetaA=thetaB
      prevlon=$1
      prevlat=$2
      lonB=lonC
      latB=latC
    }
    (NR==numlines){
      lonC = deg2rad($1)
      latC = deg2rad($2)

      thetaB = (rad2deg(atan2(sin(lonC-lonB)*cos(latC), cos(latB)*sin(latC)-sin(latB)*cos(latC)*cos(lonC-lonB)))+90)%360;

      printf "%.5f %.5f %.3f\n", prevlon, prevlat, ave_dir(thetaB,thetaA);

      printf "%.5f %.5f %.3f\n", $1, $2, thetaB;
    }' > az_trackfile.txt

rm -f track_buffer.txt rectbuf_back.txt

while read d; do
  p=($(echo $d))
  ANTIAZ=$(echo "${p[2]} - 180" | bc -l)
  gmt project -C${p[0]}/${p[1]} -A${p[2]} -Q -G${WIDTHKM}k -L0/${WIDTHKM} -Vn | tail -n 1 | gawk  '{print $1, $2}' >> track_buffer.txt
  gmt project -C${p[0]}/${p[1]} -A${ANTIAZ} -Q -G${WIDTHKM}k -L0/${WIDTHKM} -Vn | tail -n 1 | gawk  '{print $1, $2}' >> rectbuf_back.txt
done < az_trackfile.txt

# Create and close the polygon
tail -r rectbuf_back.txt >> track_buffer.txt
head -n 1 track_buffer.txt >> track_buffer.txt
