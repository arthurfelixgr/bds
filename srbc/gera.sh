#! /bin/bash -

[ $# -lt 2 ] && {
   echo "erro args" >&2
   exit 1
}

rm -f "$1" "fixosInv$1"
arquivoPlano='' # definido depois, no laço for da função geraExercicio
fixosAISWeb='fixos-aisweb' # usado na funcao trataRota
jsonAerodromos='aerodromos'
pwd=$PWD 

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

         printf "%.f", b;
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

bibFix() {
   # ('23FR','0001','','ABUCU','','','G','0435.167S','03908.083W'),
   nomeFix=$(echo "$latOuNum" | sed -e 's/1/I/g' -e 's/2/Z/g' -e 's/3/E/g' -e 's/4/A/g' -e 's/5/S/g' -e 's/6/G/g' -e 's/7/T/g' -e 's/8/B/g' -e 's/9/Q/g' -e 's/0/O/g' -e 's/\./P/g' | cut -c1-5)
   
   if resultado=$(grep "'$latOuNum','$lonOuDistancia'" "$area@a_fixos") # busca as coordenadas do fixo na tabela de fixos da área
   then 
      latOuNum=$(echo "$resultado" | awk -F"','" '{print $2}') # substitui o nome do fixo pelo número encontrado
   else 
      ultimoNum=$(tail -1 "$area@a_fixos" | awk -F"','" '{print $2}')
      latOuNum=$(echo "$ultimoNum" | awk '{printf "%04d", $1+1}')
      printf "('$area','$latOuNum','','$nomeFix','','','G','$latOrigem','$lonOrigem'),\n" >> "$pwd/$area@a_fixos"
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
   flFinal=$(echo "$corpo" | cut -d'-' -f7 | grep -o 'F[0-9]\{3\}' | tr -d 'F' | sort -nr | head -1)

   if echo $flFinal | grep -qv '[0-9]\{3\}' #[ "$flFinal" = "VFR" ] 
   then 
      flFinal=$(echo "$corpo" | grep -o '[0-9]\{1,\} *FT' | head -1 | sed 's/FT$//' | awk '{print $1/100}') 
      [ -z "$flFinal" ] && flFinal=5
   #else 
   #   flFinal=$(echo $flFinal | tr -d 'F')
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

   indicativo=$(echo "$corpo" | cut -d'-' -f2 | cut -d'/' -f1)
   tipo=$(echo "$corpo" | cut -d'-' -f4 | sed -e 's/^[[:digit:]]*//' -e 's/\/.*//')
   equipamento=$(echo "$corpo" | cut -d'-' -f5)
   eobt=$(echo "$corpo" | cut -d'-' -f6 | grep -o '[[:digit:]]\{4\}$')
   #rota=$(echo "$corpo" | cut -d'-' -f7 | sed 's/^[^ ]* //')
   rota=$(sed -n '/Rota[[:space:]]*:/,/Obs/{p; /^Obs/q}' "$arquivoPlano" | sed -e '$d' -e 's/^Rota *://' -e 's/^[[:space:]]*//' | tr -d '\n')
   rmk=$(echo "$corpo" | awk -F'-' '{print $NF}' | sed -e 's/ IDPLANO.*//' -e 's/PBN\/[^ ]*//' -e 's/DOF\/[0-9]\{6\}//' -e "s/\(.*\)\(EET\/\(SB[A-Z]\{2\}[0-9]\{4\} *\)*\)\(.*\)/\1\4/" -e 's/^ *//' -e 's/ *$//')
   velFinal=$(echo "$corpo" | cut -d'-' -f7 | grep -o 'N[0-9]\{4\}' | tr -d 'N' | sort -nr | head -1)
   ssr=$(grep -om1 'SSR: [[:digit:]]*' "$arquivoPlano" | awk '{print $2}')

   #pilotos
   piloto=''
   primeiroSetor=$(grep -m1 '^TRECHOS' "$arquivoPlano" | grep -o '\(S[0-9]\{2\}\|[0-9]\{2\}[LF]\)' | head -1)

   case $primeiroSetor in
      S01 | S02 | S03 | 03F | S04 )
         piloto=NORTE
      ;;

      S05 | S06 | S07 | 07F | S08 | 11L | 11F )
         piloto=CENTRAL
      ;;

      S09 | S10 | 12L | S14 | 14F | S15 )
         piloto=SUL
      ;;

      * )
         piloto=ACC
      ;;
   esac
   
   #trataRota
   rota2=''
   while read linha
   do 
      linha=$(echo "$linha" | tr -d ' ')
      latitude=$(grep $linha "$fixosAISWeb" | cut -f7)
      longitude=$(grep $linha "$fixosAISWeb" | cut -f9)
      lat=$(echo "$latitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%02d%02d%s", $1, $2, $5}')
      lon=$(echo "$longitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%03d%02d%s", $1, $2, $5}')
      rota2=$(echo "$rota" | sed "s/$linha/$lat$lon/g")
      rota="$rota2"
   done < <(echo "$rota" | sed -e 's/\// \n/g' -e 's/ / \n/g' | grep -o '^[A-Z]\{2\}[[:alnum:]]\{3\} ')

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
   nasceEmTipo='' # G ou D
   latOuNum=''
   lonOuDistancia=''
   azimute=''
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
      lonOuDistancia=$lonOrigem
   else
      nasceAos='000'
      nasceEmTipo='D'
      flInicial=$flFinal
      velInicial=$velFinal
      latOuNum=$origem
      lonOuDistancia=$((minutoInicio-minutoEOBT)) #tempo decorrido desde o nascimento ate o inicio do exercicio (minutos)
      lonOuDistancia=$(echo $lonOuDistancia | awk '{print $1/60}') # em horas
      lonOuDistancia=$(printf "$lonOuDistancia\t$velInicial" | awk '{printf "%.f", $1*$2}')
      azimute=$proa
      bibFix
   fi 

   numeroTrafego=$((numeroTrafego+1))
   printf "$area\t$numeroExercicio\t$numeroTrafego\t$tipo\t$ssr\t$indicativo\t$origem\t$destino\t\t$flInicial\t$velInicial\t$proa\t$nasceEmTipo\t$latOuNum\t$lonOuDistancia\t$azimute\t\t$piloto\t$nasceAos\t\t\t$equipamento\t$rota\t$eet\t$rmk\t$flFinal\t$velFinal\t0\tN\t\n" | 
      sed -e 's/^ *//' -e 's/ *\t */\t/g' -e 's/ *$//' >> $numeroExercicio
}

trataCPL() {
   # tempo total do tráfego
   minutosTotais=$(grep -m1 '^ETIM' "$arquivoPlano" | grep -o '[0-9]\{2\}:[0-9]\{2\} *$' | awk -F':' '{print $1*60 + $2}') ##
   # inicio do exercicio em minutos
   minutoInicio=$(echo $horaInicio | sed 's/^[0-9]\{2\}/&:/' | awk -F':' '{print $1*60 + $2}') ##

   if [ $minutoInicio -ge $minutosTotais ]
   then 
      return 1
   fi 

   corpo=$(sed -n "/(CPL-/,/)/p" "$arquivoPlano" | sed -n '0,/)/p' | tr -d '\r\n()' | sed 's/^-MSGTXT *//') ##
   echo "$corpo" | cut -d'-' -f8 | grep '^M[0-9]\{1,\}F[0-9]\{3\}' && return 1 # se MACH, não interessa
   flFinal=$(echo "$corpo" | cut -d'-' -f8 | grep -o 'F[0-9]\{3\}' | tr -d 'F' | sort -nr | head -1) ##

   if echo $flFinal | grep -qv '[0-9]\{3\}' #[ "$flFinal" = "VFR" ] 
   then 
      flFinal=$(echo "$corpo" | grep -o '[0-9]\{1,\} *FT' | head -1 | sed 's/FT$//' | awk '{print $1/100}') 
      [ -z "$flFinal" ] && flFinal=5
   #else 
   #   flFinal=$(echo $flFinal | tr -d 'F')
   fi 

   origem=$(echo "$corpo" | cut -d'-' -f6) #| sed 's/[[:digit:]]\{4\}$//')
   destino=$(echo "$corpo" | cut -d'-' -f9) #| cut -c1-4) #grep -o '[[:alpha:]]\{4\}' | head -n1)

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

   indicativo=$(echo "$corpo" | cut -d'-' -f2 | cut -d'/' -f1) ##
   tipo=$(echo "$corpo" | cut -d'-' -f4 | sed -e 's/^[[:digit:]]*//' -e 's/\/.*//') ##
   equipamento=$(echo "$corpo" | cut -d'-' -f5) ##
   eobt=$(echo "$corpo" | cut -d'-' -f7 | cut -d'/' -f2 | cut -d'F' -f1) ##HORA DE ENTRADA NA FIR #cut -d'-' -f6 | grep -o '[[:digit:]]\{4\}$')
   #rota=$(echo "$corpo" | cut -d'-' -f8 | sed 's/^[^ ]* \(.*\)/\1/') ##
   rota=$(sed -n '/Rota[[:space:]]*:/,/Obs/{p; /^Obs/q}' "$arquivoPlano" | sed -e '$d' -e 's/^Rota *://' -e 's/^[[:space:]]*//' | tr -d '\n')
   rmk=$(echo "$corpo" | awk -F'-' '{print $NF}' | sed -e 's/ IDPLANO.*//' -e 's/PBN\/[^ ]*//' -e 's/DOF\/[0-9]\{6\}//' -e "s/\(.*\)\(EET\/\(SB[A-Z]\{2\}[0-9]\{4\} *\)*\)\(.*\)/\1\4/" -e 's/^ *//' -e 's/ *$//') ##
   velFinal=$(echo "$corpo" | cut -d'-' -f8 | grep -o 'N[0-9]\{4\}' | tr -d 'N' | sort -nr | head -1) ##
   ssr=$(grep -om1 'SSR: [[:digit:]]*' "$arquivoPlano" | awk '{print $2}') ##

   #pilotos
   piloto=''
   primeiroSetor=$(grep -m1 '^TRECHOS' "$arquivoPlano" | grep -o '\(S[0-9]\{2\}\|[0-9]\{2\}[LF]\)' | head -1) ##

   case $primeiroSetor in
      S01 | S02 | S03 | 03F | S04 )
         piloto=NORTE
      ;;

      S05 | S06 | S07 | 07F | S08 | 11L | 11F )
         piloto=CENTRAL
      ;;

      S09 | S10 | 12L | S14 | 14F | S15 )
         piloto=SUL
      ;;

      * )
         piloto=ACC
      ;;
   esac
   
   #trataRota ##
   rota2=''
   while read linha
   do 
      linha=$(echo "$linha" | tr -d ' ')
      latitude=$(grep $linha "$fixosAISWeb" | cut -f7)
      longitude=$(grep $linha "$fixosAISWeb" | cut -f9)
      lat=$(echo "$latitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%02d%02d%s", $1, $2, $5}')
      lon=$(echo "$longitude" | awk -F"(°|'|\"|[[:space:]])" '{ if($3 > 30){$2++}; printf "%03d%02d%s", $1, $2, $5}')
      rota2=$(echo "$rota" | sed "s/$linha/$lat$lon/g")
      rota="$rota2"
   done < <(echo "$rota" | sed -e 's/\// \n/g' -e 's/ / \n/g' | grep -o '^[A-Z]\{2\}[[:alnum:]]\{3\} ')

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
   lonOuDistancia=''
   azimute=''
   minutoEOBT=$(echo $eobt | sed 's/^[0-9]\{2\}/&:/' | awk -F':' '{print $1*60 + $2}')
   flInicial=''
   velInicial=''

   #trataNascimento
   pontoEntrada=$(echo "$corpo" | cut -d'-' -f7 | cut -d'/' -f1)
   if echo "$pontoEntrada" | grep -q '[A-Z]\{3,5\}' 
   then 
      latitude=$(grep "$pontoEntrada" "$fixosAISWeb" | cut -f7)
      longitude=$(grep "$pontoEntrada" "$fixosAISWeb" | cut -f9)
      latOrigem=$(echo "$latitude" | awk -F"(°|'|\"|[[:space:]])" '{ printf "%02d%06.3f%s", $1, $2+$3/60, $5 }')
      lonOrigem=$(echo "$longitude" | awk -F"(°|'|\"|[[:space:]])" '{ printf "%03d%06.3f%s", $1, $2+$3/60, $5 }')
   else 
      latOrigem=$(echo "$pontoEntrada" | sed 's/\([0-9]\{4\}\)\([SN]\).*/\1.000\2/')
      lonOrigem=$(echo "$pontoEntrada" | sed 's/.*\([0-9]\{5\}\)\([WE]\)/\1.000\2/')
   fi 

   flInicial=$(echo "$corpo" | cut -d'-' -f7 | cut -d'/' -f2 | cut -dF -f2)
   velInicial=$velFinal
   
   if [ $minutoEOBT -ge $minutoInicio ]
   then 
      nasceAos=$((minutoEOBT-minutoInicio))
      [ "$nasceAos" -gt 45 ] && return 1
      nasceEmTipo='G'
      latOuNum=$latOrigem
      lonOuDistancia=$lonOrigem
   else
      nasceAos='000'
      nasceEmTipo='D'
      latOuNum=$pontoEntrada
      lonOuDistancia=$((minutoInicio-minutoEOBT)) #tempo decorrido desde o nascimento ate o inicio do exercicio (minutos)
      lonOuDistancia=$(echo $lonOuDistancia | awk '{print $1/60}') # em horas
      lonOuDistancia=$(printf "$lonOuDistancia\t$velInicial" | awk '{printf "%.f", $1*$2}')
      azimute=$proa
      bibFix
   fi 

   numeroTrafego=$((numeroTrafego+1))
   printf "$area\t$numeroExercicio\t$numeroTrafego\t$tipo\t$ssr\t$indicativo\t$origem\t$destino\t\t$flInicial\t$velInicial\t$proa\t$nasceEmTipo\t$latOuNum\t$lonOuDistancia\t$azimute\t\t$piloto\t$nasceAos\t\t\t$equipamento\t$rota\t$eet\t$rmk\t$flFinal\t$velFinal\t0\tN\t\n" | 
      sed -e 's/^ *//' -e 's/ *\t */\t/g' -e 's/ *$//' >> $numeroExercicio
}

geraExercicio() {
   area=$1
   numeroExercicio=$2 
   horaInicio=$3 #HHMM
   pastaPlanos="$4"
   
   numeroTrafego=0
   #numFixoInv=5000
   
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
            trataCPL
         fi
      else
         echo "$0: erro" >&2
      fi 
   done 
}

#set -x
geraExercicio '23FR' $1 $2 'planos'
