#! /bin/bash -

rm -f traffs fixosInv
arquivoPlano='' # definido depois, no laço for da função geraExercicio
fixosAISWeb='fixos-aisweb' # usado na funcao trataRota
jsonAerodromos='aerodromos'


radial() {
   y_origem=$1
   x_origem=$2
   y_destino=$3
   x_destino=$4

   bearing=$(python3 << _EOF
import math

def calculate_bearing(lat1, lon1, lat2, lon2):
    # Convert latitude and longitude from degrees to radians
    lat1 = math.radians(lat1)
    lon1 = math.radians(lon1)
    lat2 = math.radians(lat2)
    lon2 = math.radians(lon2)
    
    # Calculate the difference in longitudes
    delta_lon = lon2 - lon1
    
    # Calculate the bearing using the atan2 function
    y = math.sin(delta_lon) * math.cos(lat2)
    x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(delta_lon)
    
    bearing_radians = math.atan2(y, x)
    
    # Convert the bearing from radians to degrees
    bearing_degrees = math.degrees(bearing_radians)
    
    # Adjust the range of bearing degrees to be between 0 and 360
    bearing_degrees = (bearing_degrees + 360) % 360
    
    return bearing_degrees + 22

# Coordinates of the two points
lat1 = $y_origem
lat2 = $y_destino
lon1 = $x_origem
lon2 = $x_destino

bearing = calculate_bearing(lat1, lon1, lat2, lon2)
print(bearing)
_EOF
   )

   awk -v b=$bearing 'BEGIN {
         if (b > 360) {
            b -= 360;
         }

         printf "%i\n", b;
   }'
}

distancia() {
   y_origem=$1
   x_origem=$2
   y_destino=$3
   x_destino=$4

   distance=$(python3 << _EOF
from geopy.distance import great_circle

# Coordinates of the two points (latitude, longitude)
point1 = ($y_origem, $x_origem)
point2 = ($y_destino, $x_destino)

# Calculate the distance using great-circle distance (Haversine formula)
distance = great_circle(point1, point2).nautical

print(f"{distance:f}")
_EOF
   )

   awk -v d=$distance 'BEGIN {
         printf "%.d\n", d;   
   }'
}

filtroFIS() {
   if [ "$flFinal" -lt 150 ] # nivel abaixo do 150
   then 
      echo 1
   elif echo $origem | grep -qv '^SB' && echo $destino | grep -qv '^SB' # origem e destino desprovidos
   then
      echo 1
   elif vemDeFora=1 && echo $destino | grep -qv '^SB' # vindo de fora com destino desprovido
   then
      echo 1
   elif vaiPraFora=1 && echo $origem | grep -qv '^SB' # indo pra fora com origem desprovida
   then
      echo 1
   else
      echo 0
   fi
}

trataFPL() {
   # tempo total do tráfego
   minutosTotais=$(grep -m1 '^ETIM' "$arquivoPlano" | grep -o '[0-9]\{2\}:[0-9]\{2\} *$' | awk -F':' '{print $1*60 + $2}')
   # inicio do exercicio em minutos
   minutoInicio=$(echo $horaInicio | sed 's/^[0-9]\{2\}/&:/' | awk -F':' '{print $1*60 + $2}')

   if [ $minutoInicio -ge $minutosTotais ]
   then 
      return 1
   fi 

   corpo=$(sed -n "/(FPL-/,/)/p" "$arquivoPlano" | sed -n '0,/)/p' | tr -d '\r\n()' | sed 's/^-MSGTXT *//')
   echo "$corpo" | cut -d'-' -f7 | grep '^M[0-9]\{1,\}F[0-9]\{3\}' && return 1 # se MACH, não interessa
   flFinal=$(echo "$corpo" | cut -d'-' -f7 | sed 's/^.\{5\}\([^ ]*\).*/\1/')

   if echo $flFinal | grep -qv 'F[0-9]\{3\}' #[ "$flFinal" = "VFR" ] 
   then 
      flFinal=$(echo "$corpo" | grep -o '[0-9]\{1,\} *FT' | head -1 | sed 's/FT$//' | awk '{print $1/100}') 
      [ -z "$flFinal" ] && flFinal=$(echo "$corpo" | cut -d'-' -f7 | grep -o 'N[0-9]\{4\}F[0-9]\{3\}' | head -1 | cut -dF -f2) # se nao houver pés no plano, buscar nível na rota
      [ -z "$flFinal" ] && flFinal=5
   else 
      flFinal=$(echo $flFinal | tr -d 'F')
   fi 

   origem=$(echo "$corpo" | cut -d'-' -f6 | sed 's/[[:digit:]]\{4\}$//')
   destino=$(echo "$corpo" | cut -d'-' -f8 | cut -c1-4) #grep -o '[[:alpha:]]\{4\}' | head -n1)

   vemDeFora=
   vaiPraFora=
   eet='EET/SBRE0001'
   
   grep -m1 '^Posi' "$arquivoPlano" | grep -q ': *AIDC' && {
      vemDeFora=1
      eet="EET/$(sed -n '/^ETB/{n;p;q}' "$arquivoPlano" | cut -c16-19)0001 SBRE0002"
   } 

   grep -m1 '^Posi' "$arquivoPlano" | grep -q 'AIDC$' && {
      vaiPraFora=1
      eet="$eet $(sed -n '/^ETB/{n;p;q}' "$arquivoPlano" | cut -c24-27)0002"
   }

   fis=$(filtroFIS)
   [ "$fis" -eq 0 ] && return 1 

   indicativo=$(echo "$corpo" | cut -d'-' -f2)
   tipo=$(echo "$corpo" | cut -d'-' -f4 | sed -e 's/^[[:digit:]]*//' -e 's/\/.*//')
   equipamento=$(echo "$corpo" | cut -d'-' -f5)
   eobt=$(echo "$corpo" | cut -d'-' -f6 | grep -o '[[:digit:]]\{4\}$')
   rota=$(echo "$corpo" | cut -d'-' -f7 | sed 's/^[^ ]* \(.*\)/\1/')
   rmk=$(echo "$corpo" | awk -F'-' '{print $NF}' | sed -e 's/ IDPLANO.*//' -e 's/DOF\/[0-9]\{6\}//' -e "s/\(.*\)\(EET\/\(SB[A-Z]\{2\}[0-9]\{4\} *\)*\)\(.*\)/\1\4/" -e 's/^ *//' -e 's/ *$//')
   velFinal=$(echo "$corpo" | cut -d'-' -f7 | sed 's/^N\([[:digit:]]\{4\}\).*/\1/')
   ssr=$(grep -om1 'SSR: [[:digit:]]*' "$arquivoPlano" | awk '{print $2}')
   
   #trataRota
   rota2=''
   while read linha
   do 
      latitude=$(grep $linha "$fixosAISWeb" | cut -f7)
      longitude=$(grep $linha "$fixosAISWeb" | cut -f9)
      lat=$(echo "$latitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%02d%02d%s", $1, $2, $5}')
      lon=$(echo "$longitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%03d%02d%s", $1, $2, $5}')
      rota2=$(echo "$rota" | sed "s/$linha/$lat$lon/g")
      rota="$rota2"
   done < <(echo "$rota" | tr ' ' '\n' | grep -o '^[[:alnum:]]\{5\}\( \|\/\)' | tr -d '/')

   grep -q "$origem" "$jsonAerodromos" || {
      echo "Aeródromo não encontrado: $origem" >&2
      return 1
   }

   grep -q "$destino" "$jsonAerodromos" || {
      echo "Aeródromo não encontrado: $destino" >&2
      return 1
   }

   y_origem=$(grep $origem "$jsonAerodromos" | grep -io '"LATGEOPOINT":"[^"]*"' | cut -d':' -f2 | tr -d '"')
   x_origem=$(grep $origem "$jsonAerodromos" | grep -io '"LONGEOPOINT":"[^"]*"' | cut -d':' -f2 | tr -d '"')
   y_destino=$(grep $destino "$jsonAerodromos" | grep -io '"LATGEOPOINT":"[^"]*"' | cut -d':' -f2 | tr -d '"')
   x_destino=$(grep $destino "$jsonAerodromos" | grep -io '"LONGEOPOINT":"[^"]*"' | cut -d':' -f2 | tr -d '"')

   proa=$(radial $y_origem $x_origem $y_destino $x_destino)
   milhas=$(distancia $y_origem $x_origem $y_destino $x_destino)

   nasceAos=''
   nasceEmTipo='' # G ou T
   latOuNum=''
   lonOuTempo=''
   minutoEOBT=$(echo $eobt | sed 's/^[0-9]\{2\}/&:/' | awk -F':' '{print $1*60 + $2}')
   flInicial=''
   velInicial=''

   latOrigem=$(grep $origem "$jsonAerodromos" | 
      grep -oi '"Latitude":"[^,]*"' | 
         tr '"°\\:' '\t' | 
            sed -e 's/\(Latitude\|u0027\)//gi' -Ee  's/\t+/\t/g' -Ee 's/^\t+//' | 
               awk '{
                  printf "%02.f%06.3f%s", $1, $2+$3/60, $4;
               }'
   )

   lonOrigem=$(grep $origem "$jsonAerodromos" | 
      grep -oi '"Longitude":"[^,]*"' | 
         tr '"°\\:' '\t' | 
            sed -e 's/\(Longitude\|u0027\)//gi' -Ee  's/\t+/\t/gi' -Ee 's/^\t+//' | 
               awk '{
                  printf "%03.f%06.3f%s", $1, $2+$3/60, $4;
               }'
   )
   
   if [ $minutoEOBT -ge $minutoInicio ]
   then 
      nasceAos=$((minutoEOBT-minutoInicio))
      [ "$nasceAos" -gt 45 ] && return 1
      nasceEmTipo='G'
      flInicial='2'
      velInicial='100'
      latOuNum=$latOrigem
      lonOuTempo=$lonOrigem
   else
      nasceAos='000'
      nasceEmTipo='T'
      flInicial=$flFinal
      velInicial=$velFinal
      latOuNum=$origem
      lonOuTempo=$((minutoInicio-minutoEOBT)) #tempo decorrido desde o nascimento ate o inicio do exercicio
   fi 

   numFixoInv=$((numFixoInv+1))
   printf "$area\t$numFixoInv\t\t$origem\t\t\tG\t$latOrigem\t$lonOrigem\n" >> ../fixosInv

   numeroTrafego=$((numeroTrafego+1))
   printf "$area\t$numeroExercicio\t$numeroTrafego\t$tipo\t$ssr\t$indicativo\t$origem\t$destino\t \t$flInicial\t$velInicial\t$proa\t$nasceEmTipo\t$latOuNum\t$lonOuTempo\t \t \t43\t$nasceAos\t \t \t$equipamento\t$rota\t$eet\t$rmk\t$flFinal\t$velFinal\t0\tN\t \n" >> traffs
}

geraExercicio() {
   area=$1
   numeroExercicio=$2 
   horaInicio=$3 #HHMM
   pastaPlanos="$4"
   
   numeroTrafego=0
   numFixoInv=5000
   
   for i in "$pastaPlanos"/*
   do 
      arquivoPlano=$i 
      echo $i 
      if grep -q "(FPL" "$arquivoPlano" || grep -q "(CPL" "$arquivoPlano"
      then 
         if grep -q "(FPL" "$arquivoPlano"
         then
            trataFPL
         elif grep -q "(CPL" "$arquivoPlano"
         then 
            continue #trataCPL
         fi
      else
         echo "$0: erro" >&2
      fi 
   done 
}

#set -x
geraExercicio '23FR' '1001' '0900' 'planos'
