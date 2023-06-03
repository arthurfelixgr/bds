#! /bin/bash -

# Uso:
#   $ ./inserir-aerovias.bash planilha-crua base.tar

if [ "$#" -eq 2 ]
then 
   if file "$2" | grep -q '\(ASCII\|CSV\)' && file "$1" | grep -q 'tar archive'
   then 
      echo "Erro de sintaxe." >&2
      exit 1
   fi 

   if ! file "$1" | grep -q '\(ASCII\|CSV\)' && ! file "$2" | grep -q 'tar archive'
   then 
      echo "Arquivos inválidos." >&2
      exit 1
   fi 

   if ! file "$1" | grep -q '\(ASCII\|CSV\)'
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
pwd=$PWD

extrairBase() { 
   echo "Extraindo a base $1..." >&2
   pasta=$(tar -tf "$1" | head -n1 | cut -d'_' -f1)
   rm -rf "$pasta"
   mkdir "$pasta"

   tar -xf "$1" -C "$pasta" || {
      echo "extrairBase(): pane" >&2
      exit 1
   }
   
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

geograficas() { #auxiliar
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
         echo "geograficas(): argumentos insuficientes. " >&2
         exit 1
      fi 
   fi

   lat=$1
   lon=$2

   echo "$lat" | grep -q '^-' && hem_y='S' || hem_y='N'
   echo "$lon" | grep -q '^-' && hem_x='W' || hem_x='E'

   grau_y=$(echo "$lat" | sed 's/^-//' | awk '{ printf "%02d", $1 }')
   d_min_y=$(echo "$lat" | sed 's/^-//' | awk -v "grau_y=$grau_y" '{ printf "%.15f", ($1 - grau_y) * 60 }')
   min_y=$(echo "$d_min_y" | awk '{ printf "%02d", $1 }')
   seg_y=$(echo "$d_min_y" | awk -v "min_y=$min_y" '{ printf "%02d", ($1 - min_y) * 60 }')

   grau_x=$(echo "$lon" | sed 's/^-//' | awk '{ printf "%03d", $1 }')
   d_min_x=$(echo "$lon" | sed 's/^-//' | awk -v "grau_x=$grau_x" '{ printf "%.15f", ($1 - grau_x) * 60 }')
   min_x=$(echo "$d_min_x" | awk '{ printf "%02d", $1 }')
   seg_x=$(echo "$d_min_x" | awk -v "min_x=$min_x" '{ printf "%02d", ($1 - min_x) * 60 }')

   echo "$hem_y$grau_y$min_y$seg_y $hem_x$grau_x$min_x$seg_x"
}

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

extrairContorno() { #auxiliar para variável "fir"
   test -n "$pwd/$nomeBase" && grep '^SBRE' "$pwd/$nomeBase/firseg_data" | 
   awk -F';' '{ printf "%s%02d%02d%02d %s%03d%02d%02d\n", $5, $6, $7, $8, $9, $10, $11, $12 }' | 
   while read linha
   do 
      echo "$linha" | cartesianas | sed -e 's/^ */(/' -e 's/ *$/), /' -e 's/\([0-9]\)  *\([-0-9]\)/\1, \2/'
   done 

   test -n "$pwd/$nomeBase" && grep '^SBRE' "$pwd/$nomeBase/firseg_data" | 
   head -n1 |  
   awk -F';' '{ printf "%s%02d%02d%02d %s%03d%02d%02d\n", $5, $6, $7, $8, $9, $10, $11, $12 }' | 
   cartesianas | 
   sed -e 's/^ */(/' -e 's/ *$/), /' -e 's/\([0-9]\)  *\([-0-9]\)/\1, \2/'
}

pontoDentro() { #auxiliar
   coords=$(cartesianas "$1" "$2")
   lat=$(echo "$coords" | awk '{ print $1 }')
   lon=$(echo "$coords" | awk '{ print $2 }')

   dentro() {
   python3 << _EOF
from shapely import geometry
from shapely.geometry import Point
from shapely.geometry.polygon import Polygon
point = Point($1, $2)
polygon = Polygon([$3])
print(polygon.contains(point))
_EOF
   }

   borda() {
   python3 << _EOF
from shapely import geometry
polygon = [$3] 
line = geometry.LineString(polygon)
point = geometry.Point($1, $2)
print(line.contains(point))
_EOF
   }

   inserido=$(dentro "$lat" "$lon" "$fir")

   if [ "$inserido" = "True" ]
   then 
      echo "dentro"
   else 
      bordado=$(borda "$lat" "$lon" "$fir")
      
      if [ "$bordado" = "True" ]
      then 
         echo "borda"
      else 
         echo "fora"
      fi 
   fi 
}

cruzFronteira() { #auxiliar
   if [ "$#" -eq 0 ] 
   then 
      segmento=$(cat)
   else 
      segmento="$1"

      if [ -z "$1" ] 
      then
         echo "cruzFronteira(): argumentos insuficientes. " >&2
         exit 1
      fi 
   fi 

   poligona() {
      python3 <<_EOF
from shapely import geometry
fir = [$fir] 
polygon = geometry.Polygon(fir)
print(polygon)
_EOF
   }

   segmenta() {
      python3 <<_EOF
from shapely import geometry
segmento = [$segmento] 
line = geometry.LineString(segmento)
print(line)
_EOF
   } 

   pontoCruz() {
      python3 << _EOF
from shapely.wkt import loads
poly = loads('$1')
line = loads('$2')
intersection = poly.exterior.intersection(line)
print(intersection)
_EOF
   }

   poligona=$(poligona)
   segmenta=$(segmenta)
   pontoCruz "$poligona" "$segmenta" | sed -e 's/POINT (//' -e 's/)//' 
}

coordsBase() { #auxiliar
   if [ "$#" -eq 0 ] 
   then 
      stdin=$(cat)
      latitude=$(echo "$stdin" | cut -d' ' -f1)
      longitude=$(echo "$stdin" | cut -d' ' -f2)
   else 
      latitude="$1"
      longitude="$2"
   fi 

   hem_y=$(echo "$latitude" | cut -c1)
   grau_y=$(echo "$latitude" | cut -c2,3 | awk '{ printf "%d", $1 }')
   min_y=$(echo "$latitude" | cut -c4,5 | awk '{ printf "%d", $1 }')
   seg_y=$(echo "$latitude" | cut -c6,7 | awk '{ printf "%d", $1 }')
   
   hem_x=$(echo "$longitude" | cut -c1)
   grau_x=$(echo "$longitude" | cut -c2-4 | awk '{ printf "%d", $1 }')
   min_x=$(echo "$longitude" | cut -c5,6 | awk '{ printf "%d", $1 }')
   seg_x=$(echo "$longitude" | cut -c7,8 | awk '{ printf "%d", $1 }')

   printf "$hem_y;$grau_y;$min_y;$seg_y;$hem_x;$grau_x;$min_x;$seg_x"
}

recortar() {
   mkdir -p awys
   rm -f awys/* 

   awk -F ' *\t *' -v 'OFS=\t' 'NF > 2 { print $1, $3, $4, $5, $7, $8, $9 }' "$planilha" | while IFS=$'\t' read awy p1 la1 lo1 p2 la2 lo2
   do 
      awy=$(echo "$awy" | sed 's/[[:space:]]//g')
      printf "$p1\t$la1\t$lo1\n$p2\t$la2\t$lo2\n" >> "awys/$awy"
   done 

   cd awys
   sed -i '/^[[:space:]]*$/d' *

   for i in *
   do 
      cat -n "$i" | sort -uk2 | sort -nk1 | cut --complement -f1 > "$i.fase0"
   done

   for i in *.fase0
   do 
      while IFS=$'\t' read nome lat lon
      do 
         hem_y=$(echo "$lat" | cut -d' ' -f1)
         grau_y=$(echo "$lat" | awk '{ printf "%d", $2 }')
         min_y=$(echo "$lat" | awk '{ printf "%d", $3 }')
         seg_y=$(echo "$lat" | awk '{ printf "%.f", $4 }')

         [ "$seg_y" -eq 60 ] && {
            seg_y=0
            min_y=$((min_y+1))
         }

         [ "$min_y" -eq 60 ] && {
            min_y=0
            grau_y=$((grau_y+1))
         }

         hem_x=$(echo "$lon" | cut -d' ' -f1)
         grau_x=$(echo "$lon" | awk '{ printf "%d", $2 }')
         min_x=$(echo "$lon" | awk '{ printf "%d", $3 }')
         seg_x=$(echo "$lon" | awk '{ printf "%.f", $4 }')

         [ "$seg_x" -eq 60 ] && {
            seg_x=0
            min_x=$((min_x+1))
         }

         [ "$min_x" -eq 60 ] && {
            min_x=0
            grau_x=$((grau_x+1))
         }

         lat=$(echo "$hem_y $grau_y $min_y $seg_y" | awk '{ printf "%s %02d %02d %02d", $1, $2, $3, $4 }')
         lon=$(echo "$hem_x $grau_x $min_x $seg_x" | awk '{ printf "%s %03d %02d %02d", $1, $2, $3, $4 }')

         printf "$nome\t$lat\t$lon\n" >> "$i.fase1"
      done < "$i"
   done 

   for i in *.fase1
   do 
      primeiroPontoFora=''

      while IFS=$'\t' read ponto la lo
      do 
         laJ=$(echo "$la" | awk -F' ' '{ printf "%s%02d%02d%02d", $1, $2, $3, $4 }')
         loJ=$(echo "$lo" | awk -F' ' '{ printf "%s%03d%02d%02d", $1, $2, $3, $4 }')

         statusPonto=$(pontoDentro "$laJ" "$loJ")

         if [ "$statusPonto" = "fora" ] 
         then 
            primeiroPontoFora="$ponto"
         else 
            if [ -z "$primeiroPontoFora" ] 
            then 
               tac "$i" > "$i.fase2"
            else 
               tac "$i" | sed "/$primeiroPontoFora/q" > "$i.fase2"
            fi 

            break
         fi 
      done < "$i"
   done
   
   for i in *.fase2
   do 
      primeiroPontoFora=''

      while IFS=$'\t' read ponto la lo
      do 
         laJ=$(echo "$la" | awk -F' ' '{ printf "%s%02d%02d%02d", $1, $2, $3, $4 }')
         loJ=$(echo "$lo" | awk -F' ' '{ printf "%s%03d%02d%02d", $1, $2, $3, $4 }')

         statusPonto=$(pontoDentro "$laJ" "$loJ")

         if [ "$statusPonto" = "fora" ] 
         then 
            primeiroPontoFora="$ponto"
         else 
            if [ -z "$primeiroPontoFora" ] 
            then 
               tac "$i" > "$i.fase3"
            else 
               tac "$i" | sed "/$primeiroPontoFora/q" > "$i.fase3"
            fi 

            break
         fi 
      done < "$i"
   done
   
   n=0

   for i in *.fase3 
   do 
      ponto1=$(sed -n '1p' "$i")
      latitudePonto1=$(echo "$ponto1" | cut -f2 | sed 's/ //g')
      longitudePonto1=$(echo "$ponto1" | cut -f3 | sed 's/ //g')
      statusPonto1=$(pontoDentro "$latitudePonto1" "$longitudePonto1")

      if [ "$statusPonto1" = "fora" ]
      then 
         ponto2=$(sed -n '2p' "$i")
         latitudePonto2=$(echo "$ponto2" | cut -f2 | sed 's/ //g')
         longitudePonto2=$(echo "$ponto2" | cut -f3 | sed 's/ //g')
         statusPonto2=$(pontoDentro "$latitudePonto2" "$longitudePonto2")

         if [ "$statusPonto2" = "borda" ]
         then 
            tac "$i" | sed "/$ponto2/q" > "$i.fase4"
         elif [ "$statusPonto2" = "dentro" ]
         then 
            cartesianasPonto1=$(cartesianas "$latitudePonto1" "$longitudePonto1")
            cartesianasPonto2=$(cartesianas "$latitudePonto2" "$longitudePonto2")

            ponto1Segmento=$(echo "$cartesianasPonto1" | sed -e 's/.*/(&)/' -e 's/ /, /' -e 's/ *)$/)/')
            ponto2Segmento=$(echo "$cartesianasPonto2" | sed -e 's/.*/(&)/' -e 's/ /, /' -e 's/ *)$/)/')
            segmento=$(echo "$ponto1Segmento, $ponto2Segmento")

            pontoCruz=$(cruzFronteira "$segmento")
            pontoCruzLat=$(echo "$pontoCruz" | cut -d' ' -f1)
            pontoCruzLon=$(echo "$pontoCruz" | cut -d' ' -f2)

            pontoCruzGeo=$(geograficas "$pontoCruzLat" "$pontoCruzLon")
            pontoCruzGeoLat=$(echo "$pontoCruzGeo" | cut -d' ' -f1)
            pontoCruzGeoLon=$(echo "$pontoCruzGeo" | cut -d' ' -f2)

            pontoBase=$(coordsBase "$pontoCruzGeoLat" "$pontoCruzGeoLon")
            
            if resultado=$(grep "$pontoBase" "$pwd/$nomeBase/fix_data") || resultado=$(grep "$pontoBase" "$pwd/$nomeBase/navaid_data") || resultado=$(grep "$pontoBase" "$pwd/$nomeBase/waypoint_data")
            then  
               nomePonto=$(echo "$resultado" | cut -d';' -f1)
               latPonto=$(echo "$resultado" | awk -F';' '{ printf "%s %02d %02d %02d", $6, $7, $8, $9 }')
               lonPonto=$(echo "$resultado" | awk -F';' '{ printf "%s %03d %02d %02d", $10, $11, $12, $13 }')
               sed -i "/$ponto1/s/^.*$/$nomePonto\t$latPonto\t$lonPonto/" "$i"
            else 
               cruzANome=$(echo $n | awk '{ printf "FRE%02X", $1 }' | sed -e 's/0/G/g' -e 's/1/H/g' -e 's/2/I/g' -e 's/3/J/g' -e 's/4/K/g' -e 's/5/L/g' -e 's/6/M/g' -e 's/7/N/g' -e 's/8/O/g' -e 's/9/P/g')
               n=$((n+1))
               cruzALat=$(echo "$pontoCruzGeoLat" | sed 's/\([NS]\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
               cruzALon=$(echo "$pontoCruzGeoLon" | sed 's/\([WE]\)\([0-9]\{3\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
               sed -i "/$ponto1/s/^.*$/$cruzANome\t$cruzALat\t$cruzALon/" "$i"
            fi 
            
            tac "$i" > "$i.fase4"
         else
            echo "aerovias(): pane: $status" >&2
         fi 
      else 
         tac "$i" > "$i.fase4"
      fi 
   done 

   for i in *.fase4 
   do 
      ponto1=$(sed -n '1p' "$i")
      latitudePonto1=$(echo "$ponto1" | cut -f2 | sed 's/ //g')
      longitudePonto1=$(echo "$ponto1" | cut -f3 | sed 's/ //g')
      statusPonto1=$(pontoDentro "$latitudePonto1" "$longitudePonto1")

      if [ "$statusPonto1" = "fora" ]
      then 
         ponto2=$(sed -n '2p' "$i")
         latitudePonto2=$(echo "$ponto2" | cut -f2 | sed 's/ //g')
         longitudePonto2=$(echo "$ponto2" | cut -f3 | sed 's/ //g')
         statusPonto2=$(pontoDentro "$latitudePonto2" "$longitudePonto2")

         if [ "$statusPonto2" = "borda" ]
         then 
            tac "$i" | sed "/$ponto2/q" > "$i.fase5"
         elif [ "$statusPonto2" = "dentro" ]
         then 
            cartesianasPonto1=$(cartesianas "$latitudePonto1" "$longitudePonto1")
            cartesianasPonto2=$(cartesianas "$latitudePonto2" "$longitudePonto2")

            ponto1Segmento=$(echo "$cartesianasPonto1" | sed -e 's/.*/(&)/' -e 's/ /, /' -e 's/ *)$/)/')
            ponto2Segmento=$(echo "$cartesianasPonto2" | sed -e 's/.*/(&)/' -e 's/ /, /' -e 's/ *)$/)/')
            segmento=$(echo "$ponto1Segmento, $ponto2Segmento")

            pontoCruz=$(cruzFronteira "$segmento")
            pontoCruzLat=$(echo "$pontoCruz" | cut -d' ' -f1)
            pontoCruzLon=$(echo "$pontoCruz" | cut -d' ' -f2)

            pontoCruzGeo=$(geograficas "$pontoCruzLat" "$pontoCruzLon")
            pontoCruzGeoLat=$(echo "$pontoCruzGeo" | cut -d' ' -f1)
            pontoCruzGeoLon=$(echo "$pontoCruzGeo" | cut -d' ' -f2)

            pontoBase=$(coordsBase "$pontoCruzGeoLat" "$pontoCruzGeoLon")
            
            if resultado=$(grep "$pontoBase" "$pwd/$nomeBase/fix_data") || resultado=$(grep "$pontoBase" "$pwd/$nomeBase/navaid_data") || resultado=$(grep "$pontoBase" "$pwd/$nomeBase/waypoint_data")
            then  
               nomePonto=$(echo "$resultado" | cut -d';' -f1)
               latPonto=$(echo "$resultado" | awk -F';' '{ printf "%s %02d %02d %02d", $6, $7, $8, $9 }')
               lonPonto=$(echo "$resultado" | awk -F';' '{ printf "%s %03d %02d %02d", $10, $11, $12, $13 }')
               sed -i "/$ponto1/s/^.*$/$nomePonto\t$latPonto\t$lonPonto/" "$i"
            else 
               cruzANome=$(echo $n | awk '{ printf "FRE%02X", $1 }' | sed -e 's/0/G/g' -e 's/1/H/g' -e 's/2/I/g' -e 's/3/J/g' -e 's/4/K/g' -e 's/5/L/g' -e 's/6/M/g' -e 's/7/N/g' -e 's/8/O/g' -e 's/9/P/g')
               n=$((n+1))
               cruzALat=$(echo "$pontoCruzGeoLat" | sed 's/\([NS]\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
               cruzALon=$(echo "$pontoCruzGeoLon" | sed 's/\([WE]\)\([0-9]\{3\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
               sed -i "/$ponto1/s/^.*$/$cruzANome\t$cruzALat\t$cruzALon/" "$i"
            fi
            
            tac "$i" > "$i.fase5"
         else
            echo "aerovias(): pane: $status" >&2
         fi 
      else 
         tac "$i" > "$i.fase5"
      fi 
   done

   for i in * 
   do 
      echo "$i" | grep -qv '\.fase5$' && rm "$i"
   done  

   for i in *
   do 
      nome=$(echo "$i" | sed 's/\([^.]*\).*/\1/')
      mv "$i" "$nome"
   done 

   cd ..
}

balizas() {
   cd awys

   for i in *
   do 
      while IFS=$'\t' read nome lat lon
      do 
         tipo=$(grep -m2 "$nome" "../$planilha" | tail -n1 | awk -F' *\t *' '{ print $2 }')
         
         if echo "$tipo" | grep -qi "waypoint" 
         then
            if echo "$nome" | grep -q '[0-9]'
            then 
               tipo="waypoint"
               arq="waypoint_data"
            else 
               tipo="fixo"
               arq="fix_data"
            fi 
         else 
            if echo "$nome" | grep -q '^FRE'
            then 
               tipo="fixo"
               arq="fix_data"
            else 
               arq="navaid_data"
            fi 
         fi 
         
         case "$tipo" in
            'VOR')
               tipoNaBase='NAV_VOR'
            ;;

            'NDB')
               tipoNaBase='NAV_NDB'
            ;;

            'DME')
               tipoNaBase='NAV_VD'
            ;;

            'fixo')
               tipoNaBase='FIX'
            ;;

            'waypoint')
               tipoNaBase='WAY_PT'
            ;;

            *)
               echo "$nome: erro no tipo da baliza ($tipo). Verifique o arquivo $planilha e reinicie o processo. " >&2
               exit 1
            ;;
         esac
         
         lat=$(echo "$lat" | sed 's/ //g')
         lon=$(echo "$lon" | sed 's/ //g')
         pontoBase=$(coordsBase "$lat" "$lon")

         if grep -q "$nome" "$pwd/$nomeBase/$arq"
         then 
            sed -i "/$nome/s/[NS];\([0-9]\{1,2\};\)\{3\}[WE];[0-9]\{1,3\};\([0-9]\{1,2\};\)\{2\}/$pontoBase;/" "$pwd/$nomeBase/$arq"
         else 
            if echo "$nome" | grep -q '^FRE'
            then 
               echo "$nome;;$nome;$tipoNaBase;0;$pontoBase;0.0;1;0;1;1;0;0;0;0.0;1;20;0" >> ../fixosAInserir
            else 
               if [ "$tipo" = "fixo" ]
               then
                  echo "$nome;;$nome;$tipoNaBase;0;$pontoBase;0.0;0;0;0;1;0;0;0;0.0;1;20;0" >> ../fixosAInserir
               else 
                  echo "$nome;;$nome;$tipoNaBase;0;$pontoBase;0.0;0;0;0;1;0;0;0;0.0;1;20;0" >> "$pwd/$nomeBase/$arq"
               fi 
            fi 
         fi 
         
      done < "$i"
   done 

   cd ..
   tail +13 "$nomeBase/fix_data" >> fixosAInserir
   sort -t';' -uk1,1 < fixosAInserir > footer
   head -n12 "$nomeBase/fix_data" > header

   while read linha
   do 
      echo "$linha" >> header
   done < footer

   mv header "$nomeBase/fix_data"
   rm fixosAInserir footer
}

inserir() {
   cd awys
   rm -f *.base

   for i in * 
   do 
      n=2
      while read nome lat lon 
      do 
         fixoAtual=$(echo $nome)
         fixoSeguinte=$(sed -n "$n"p "$i" | cut -f1)
         echo "$fixoAtual $fixoSeguinte" 
         n=$((n+1))
      done < "$i" | sed '$d' > "$i.base"
   done 

   for i in *.base 
   do 
      aerovia=$(echo "$i" | sed 's/\(.*\)\..*$/\1/') 
      sed -i "/^$aerovia;/d" "$pwd/$nomeBase/airway_data"

      if echo "$aerovia" | grep -q '^U' 
      then 
         nivInf='250'
         nivSup='999'
      else 
         nivInf='145'
         nivSup='245'
      fi 

      n=1
      while read p1 p2
      do 
         echo "$aerovia;AIRWAY;;0;$n;$p1;$p2;1;1;$nivInf;$nivSup;0;0;NULO;;" >> "$pwd/$nomeBase/airway_data" 
         n=$((n+1))
      done < "$i"
   done 

   cd ..
}

empacotarBase() {
   echo "Empacotando a base... " >&2
   cd "$nomeBase"

   for i in *
   do 
      [ "$i" != "INFO" ] && gzip -9 < "$i" > "$nomeBase"_"$i.EXP" || cp "$i" "$nomeBase"_"$i.EXP"
   done 

   if tar -cf "../$(date -u '+%Y%m%d%H%M%S')-$nomeBase.tar" *.EXP
   then 
      rm -r *.EXP
      cd ..
      echo "Pacote criado com sucesso! " >&2
   else 
      echo "Erro na criação do pacote. " >&2
      exit 1
   fi 
}

limpar() {
   rm -r "$nomeBase" "awys"
}

extrairBase "$base"
fir=$(extrairContorno)
recortar
balizas
inserir
empacotarBase
limpar
