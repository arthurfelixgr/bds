#! /bin/bash -

# Uso:
#   $ ./inserir-aerovias.bash planilha-crua base.tar

if [ "$#" -eq 2 ]
then 
   if file "$2" | grep -q 'ASCII' && file "$1" | grep -q 'tar archive'
   then 
      echo "Erro de sintaxe." >&2
      exit 1
   fi 

   if ! file "$1" | grep -q 'ASCII' && ! file "$2" | grep -q 'tar archive'
   then 
      echo "Arquivos inválidos." >&2
      exit 1
   fi 

   if ! file "$1" | grep -q 'ASCII'
   then 
      echo "Arquivo de aerovias inválido." >&2
      exit 1
   fi 

   if ! file "$2" | grep -q 'tar archive'
   then 
      echo "Arquivo de base inválido." >&2
      exit 1
   fi 
else 
   echo "Argumentos insuficientes." >&2
   exit 1
fi 

planilha="$1"
base="$2"
nomeBase=$(tar -tf "$base" | head -n1 | cut -d'_' -f1)

extrairBase() {
   echo "Extraindo a base $1..." >&2
   #pasta=$(tar -tf "$1" | head -n1 | cut -d'_' -f1)
   pasta="$nomeBase"
   mkdir -p "$pasta"
   rm "$pasta"/*
   tar -xf "$1" -C "$pasta"
   cd "$pasta"

   for i in *
   do 
      nome=$(echo "$i" | sed -e "s/^$pasta\(.*\)\.EXP$/\1/" -e 's/^_//')

      if file "$i" | grep -q 'gzip' 
      then 
         gunzip < "$i" > "$nome"
         rm "$i"
      else 
         mv "$i" "$nome"
      fi 
   done 

   cd ..
   echo "Extração completa." >&2
}

cartesianas() {
   if [ "$#" -eq 0 ] 
   then 
      stdin=$(cat)
      lat=$(echo "$stdin" | cut -d' ' -f1)
      lon=$(echo "$stdin" | cut -d' ' -f2)
   else 
      lat="$1"
      lon="$2"
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

   latCart=$(awk -v "latHem=$hy" -v "latGrau=$gy" -v "latMin=$my" -v "latSeg=$sy" 'BEGIN { lat = latHem * (latGrau + latMin/60 + latSeg/3600) ; printf "%.15f \n", lat }')
   lonCart=$(awk -v "lonHem=$hx" -v "lonGrau=$gx" -v "lonMin=$mx" -v "lonSeg=$sx" 'BEGIN { lon = lonHem * (lonGrau + lonMin/60 + lonSeg/3600) ; printf "%.15f \n", lon }')

   printf "%s %s" "$latCart" "$lonCart"
}

extrairContorno() {
   printf "["

   test -n "$pasta" && grep '^SBRE' "$pasta/firseg_data" | 
   awk -F';' '{ printf "%s%02d%02d%02d %s%03d%02d%02d\n", $5, $6, $7, $8, $9, $10, $11, $12 }' | 
   while read linha
   do 
      echo "$linha" | cartesianas | sed -e 's/^ */[/' -e 's/ *$/], /' -e 's/\([0-9]\)  *\([-0-9]\)/\1, \2/'
   done 

   printf "]"
}

#pontoDentro() {}

atualizarBalizas() {
   echo "Atualizando balizas..." >&2

   data=''
   jur=''

   awk -F '(\t| *, *)' -v 'OFS=\t' 'NF > 0 { print $3, $4, $5, $6, "\n", $7, $8, $9, $10 }' "$planilha" | 
   sed -e 's/^[[:blank:]]*//' | 
   grep -v '^[[:space:]]*$' | 
   sort -uk2,2 | 
   while read tipo nome latitude longitude 
   do 
      if echo "$tipo" | grep -qiE '(VOR|NDB|DME)' 
      then 
         arq='navaid_data'
         jur='navaid_jur_data'
      elif echo "$tipo" | grep -qi 'waypoint' 
      then 
         arq='fix_data'
         jur='fix_jur_data'
      else 
         echo "Erro." >&2
         exit 1
      fi 

      latitudeSeg=$(echo "$latitude" | awk '{ printf "%02.f", $4 }')
      latitudeJ=$(echo "$latitude" | awk '{ "%s%02d%02d", $1, $2, $3 }}' ; echo "$latitudeSeg")

      longitudeSeg=$(echo "$longitude" | awk '{ printf "%02.f", $4 }')
      longitudeJ=$(echo "$longitude" | awk '{ "%s%03d%02d", $1, $2, $3 }}' ; echo "$longitudeSeg")

      if registro=$(grep "$nome" "$arq")
      then 
         latBase=$(echo "$registro" | awk -F';' '{ printf "%s%02d%02d%02d", $6, $7, $8, $9 }')
         longBase=$(echo "$registro" | awk -F';' '{ printf "%s%03d%02d%02d", $10, $11, $12, $13 }')

         if ! [ "$latBase" = "$latitudeJ" ] && ! [ "$longBase" = "$longitudeJ" ]
         then 
            hem_y=$(echo "$latitude" | cut -d' ' -f1 | awk '{ printf "%d", $1 }')
            grau_y=$(echo "$latitude" | cut -d' ' -f2 | awk '{ printf "%d", $1 }')
            min_y=$(echo "$latitude" | cut -d' ' -f3 | awk '{ printf "%d", $1 }')
            seg_y=$(echo "$latitudeSeg" | awk '{ printf "%d", $1 }')

            hem_x=$(echo "$longitude" | cut -d' ' -f1 | awk '{ printf "%d", $1 }')
            grau_x=$(echo "$longitude" | cut -d' ' -f2 | awk '{ printf "%d", $1 }')
            min_x=$(echo "$longitude" | cut -d' ' -f3 | awk '{ printf "%d", $1 }')
            seg_x=$(echo "$longitudeSeg" | awk '{ printf "%d", $1 }')

            sed -i "/$nome/s/[NS];\([0-9]\{1,\};\)\{3\}[WE];\([0-9]\{1,\};\)\{3\}/$hem_y;$grau_y;$min_y;$seg_y;$hem_x;$grau_x;$min_x;$seg_x;" "$arq"
         fi 
      #else 
      fi
   done 

   echo "Balizas atualizadas. " >&2
}
