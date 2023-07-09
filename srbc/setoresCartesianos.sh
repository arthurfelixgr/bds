#! /bin/sh - 

cartesianas() { #auxiliar
   if [ "$#" -eq 0 ] 
   then 
      stdin=$(cat)
      lat=$(echo "$stdin" | cut -d' ' -f1)
      lon=$(echo "$stdin" | cut -d' ' -f2)
   else 
      lat="$1"
      lon="$2"

      if [ -z "$1" ] || [ -z "$2" ]
      then
         echo "cartesianas(): argumentos insuficientes. " >&2
         exit 1
      fi 
   fi 

   hy=$(echo $lat | cut -c1)
   gy=$(echo $lat | cut -c2,3)
   my=$(echo $lat | cut -c4,5)
   sy=$(echo $lat | cut -c6,7)

   hx=$(echo $lon | cut -c1)
   gx=$(echo $lon | cut -c2-4)
   mx=$(echo $lon | cut -c5,6)
   sx=$(echo $lon | cut -c7,8)

   [ "$hy" = "S" ] && hy='-1' || hy=1
   [ "$hx" = "W" ] && hx='-1' || hx=1

   latCart=$(awk -v "latHem=$hy" -v "latGrau=$gy" -v "latMin=$my" -v "latSeg=$sy" 'BEGIN { lat = latHem * (latGrau + latMin/60 + latSeg/3600) ; printf "%.15f", lat }')
   lonCart=$(awk -v "lonHem=$hx" -v "lonGrau=$gx" -v "lonMin=$mx" -v "lonSeg=$sx" 'BEGIN { lon = lonHem * (lonGrau + lonMin/60 + lonSeg/3600) ; printf "%.15f", lon }')

   printf "%s %s" "$latCart" "$lonCart"
}

while read linha
do
   if echo "$linha" | grep -q "^[[:blank:]]*$"
   then 
      echo "$linha"
   else 
      lat=$(echo "$linha" | cut -f3 | sed "s/\(.*\)\([A-Z]\)$/\2\1/")
      lon=$(echo "$linha" | cut -f4 | sed "s/\(.*\)\([A-Z]\)$/\2\1/")
      nome=$(echo "$linha" | cut -f2)

      echo "$nome" $(cartesianas "$lat" "$lon")
   fi 
done < "$1"