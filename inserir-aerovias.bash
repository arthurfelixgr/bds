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

cat <<_EOF > pointinpoly.js # créditos: https://github.com/metafloor/pointinpoly
(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
        define([], factory);
    } else if (typeof module === 'object' && module.exports) {
        module.exports = factory();
    } else {
        let exports = factory();
        root.pointInPoly = exports.pointInPoly;
        root.pointInXYPoly = exports.pointInXYPoly;
    }
}(typeof self !== 'undefined' ? self : this, function () {

function ptinxypoly(x, y, poly) {
    let c = false;
    for (let l = poly.length, i = 0, j = l-1; i < l; j = i++) {
        let xj = poly[j].x, yj = poly[j].y, xi = poly[i].x, yi = poly[i].y;
        let where = (yi - yj) * (x - xi) - (xi - xj) * (y - yi);
        if (yj < yi) {
            if (y >= yj && y < yi) {
                if (where == 0) return true; 
                if (where > 0) {
                    if (y == yj) { 
                        if (y > poly[j == 0 ? l-1 : j-1].y) {
                            c = !c;
                        }
                    } else {
                        c = !c;
                    }
                }
            }
        } else if (yi < yj) {
            if (y > yi && y <= yj) {
                if (where == 0) return true; 
                if (where < 0) {
                    if (y == yj) { 
                        if (y < poly[j == 0 ? l-1 : j-1].y) {
                            c = !c;
                        }
                    } else {
                        c = !c;
                    }
                }
            }
        } else if (y == yi && (x >= xj && x <= xi || x >= xi && x <= xj)) {
            return true; 
        }
    }
    return c;
}

function ptinpoly(x, y, poly) {
    let c = false;
    for (let l = poly.length, i = 0, j = l-1; i < l; j = i++) {
        let xj = poly[j][0], yj = poly[j][1], xi = poly[i][0], yi = poly[i][1];
        let where = (yi - yj) * (x - xi) - (xi - xj) * (y - yi);
        if (yj < yi) {
            if (y >= yj && y < yi) {
                if (where == 0) return true; 
                if (where > 0) {
                    if (y == yj) { 
                        if (y > poly[j == 0 ? l-1 : j-1][1]) {
                            c = !c;
                        }
                    } else {
                        c = !c;
                    }
                }
            }
        } else if (yi < yj) {
            if (y > yi && y <= yj) {
                if (where == 0) return true; 
                if (where < 0) {
                    if (y == yj) { 
                        if (y < poly[j == 0 ? l-1 : j-1][1]) {
                            c = !c;
                        }
                    } else {
                        c = !c;
                    }
                }
            }
        } else if (y == yi && (x >= xj && x <= xi || x >= xi && x <= xj)) {
            return true; 
        }
    }
    return c;
}

return { pointInPoly:ptinpoly, pointInXYPoly:ptinxypoly };
}));
_EOF

planilha="$1"
base="$2"
nomeBase=$(tar -tf "$base" | head -n1 | cut -d'_' -f1)
pwd=$PWD

extrairBase() {
   echo "Extraindo a base $1..." >&2
   pasta=$(tar -tf "$1" | head -n1 | cut -d'_' -f1)
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

geograficas() {
   node << _EOF
      function converterCoordenadas(latitude, longitude) {
         // Converter latitude
         var latHemisferio = (latitude >= 0) ? "N" : "S";
         var latGrau = padDigits(Math.floor(Math.abs(latitude)), 2);
         var latMinuto = padDigits(Math.floor((Math.abs(latitude) - Math.floor(Math.abs(latitude))) * 60), 2);
         var latSegundo = padDigits(Math.floor(((Math.abs(latitude) - Math.floor(Math.abs(latitude))) * 60 - Math.floor((Math.abs(latitude) - Math.floor(Math.abs(latitude))) * 60)) * 60), 2);

         // Converter longitude
         var lonHemisferio = (longitude >= 0) ? "E" : "W";
         var lonGrau = padDigits(Math.floor(Math.abs(longitude)), 3);
         var lonMinuto = padDigits(Math.floor((Math.abs(longitude) - Math.floor(Math.abs(longitude))) * 60), 2);
         var lonSegundo = padDigits(Math.floor(((Math.abs(longitude) - Math.floor(Math.abs(longitude))) * 60 - Math.floor((Math.abs(longitude) - Math.floor(Math.abs(longitude))) * 60)) * 60), 2);

         // Retornar coordenadas geográficas no formato HGMS
         return latHemisferio + latGrau + latMinuto + latSegundo + "\t" + lonHemisferio + lonGrau + lonMinuto + lonSegundo;
      }

      function padDigits(number, digits) {
         return String(number).padStart(digits, "0");
      }

      // Exemplo de uso
      var latitude = "$1";
      var longitude = "$2";

      var coordenadasGeograficas = converterCoordenadas(latitude, longitude);
      console.log(coordenadasGeograficas);
_EOF
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

   test -n "$pwd/$nomeBase" && grep '^SBRE' "$pwd/$nomeBase/firseg_data" | 
   awk -F';' '{ printf "%s%02d%02d%02d %s%03d%02d%02d\n", $5, $6, $7, $8, $9, $10, $11, $12 }' | 
   while read linha
   do 
      echo "$linha" | cartesianas | sed -e 's/^ */[/' -e 's/ *$/], /' -e 's/\([0-9]\)  *\([-0-9]\)/\1, \2/'
   done 

   test -n "$pwd/$nomeBase" && grep '^SBRE' "$pwd/$nomeBase/firseg_data" | 
   head -n1 |  
   awk -F';' '{ printf "%s%02d%02d%02d %s%03d%02d%02d\n", $5, $6, $7, $8, $9, $10, $11, $12 }' | 
   cartesianas | 
   sed -e 's/^ */[/' -e 's/ *$/], /' -e 's/\([0-9]\)  *\([-0-9]\)/\1, \2/'

   printf "]"
}

pontoDentro() {
   coords=$(cartesianas "$1" "$2")
   lat=$(echo "$coords" | awk '{ print $1 }')
   lon=$(echo "$coords" | awk '{ print $2 }')
   fir=$(extrairContorno)

   node <<_EOF 
   var pointIn = require('./pointinpoly').pointInPoly;
   console.log("$lat, $lon")
   console.log(pointIn($lat, $lon, $fir));
_EOF
}

cruzFronteira() {
   node << _EOF
   // Função para calcular a interseção entre dois segmentos de reta
function calcularIntersecao(pontoA, pontoB, pontoC, pontoD) {
  var ua, ub, denomitor;

  denomitor = (pontoD[1] - pontoC[1]) * (pontoB[0] - pontoA[0]) - (pontoD[0] - pontoC[0]) * (pontoB[1] - pontoA[1]);
  ua = ((pontoD[0] - pontoC[0]) * (pontoA[1] - pontoC[1]) - (pontoD[1] - pontoC[1]) * (pontoA[0] - pontoC[0])) / denomitor;
  ub = ((pontoB[0] - pontoA[0]) * (pontoA[1] - pontoC[1]) - (pontoB[1] - pontoA[1]) * (pontoA[0] - pontoC[0])) / denomitor;

  if (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1) {
    var intersecaoX = pontoA[0] + ua * (pontoB[0] - pontoA[0]);
    var intersecaoY = pontoA[1] + ua * (pontoB[1] - pontoA[1]);
    return [intersecaoX, intersecaoY];
  }

  return null;
}

// Função para verificar se um ponto está dentro de um polígono
function pontoDentroDoPoligono(ponto, poligono) {
  var intersecoes = 0;

  for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    if ((poligono[i][1] > ponto[1]) !== (poligono[j][1] > ponto[1]) &&
        ponto[0] < (poligono[j][0] - poligono[i][0]) * (ponto[1] - poligono[i][1]) / (poligono[j][1] - poligono[i][1]) + poligono[i][0]) {
      intersecoes++;
    }
  }

  return intersecoes % 2 !== 0;
}

// Função principal para calcular a interseção entre um segmento e um polígono
function calcularIntersecaoSegmentoPoligono(segmento, poligono) {
  var pontoA = segmento[0];
  var pontoB = segmento[1];

  var intersecoes = [];

  for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    var pontoC = poligono[i];
    var pontoD = poligono[j];

    var intersecao = calcularIntersecao(pontoA, pontoB, pontoC, pontoD);

    if (intersecao !== null) {
      intersecoes.push(intersecao);
    }
  }

  return intersecoes;
}

// Exemplo de uso
var segmento = $1;
var poligono = $2;

var pontosIntersecao = calcularIntersecaoSegmentoPoligono(segmento, poligono);
console.log(pontosIntersecao);
_EOF
}

coordsBase() {
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

atualizarBalizas() {
   echo "Atualizando balizas..." >&2

   data=''
   jur=''

   totalBalizas=$(awk -F '(\t| *, *)' -v 'OFS=\t' 'NF > 0 { print $3, $4, $5, $6, "\n", $7, $8, $9, $10 }' "$planilha" | sed -e 's/^[[:blank:]]*//' | grep -v '^[[:space:]]*$' | sort -uk2,2 | wc -l)
   nBaliza=0

   awk -F '(\t| *, *)' -v 'OFS=\t' 'NF > 0 { print $3, $4, $5, $6, "\n", $7, $8, $9, $10 }' "$planilha" | 
   sed -e 's/^[[:blank:]]*//' | 
   grep -v '^[[:space:]]*$' | 
   sort -uk2,2 | 
   while IFS=$'\t' read tipo nome latitude longitude 
   do 
      nBaliza=$((nBaliza+1))
      echo "Analisando $nome: baliza $nBaliza de $totalBalizas... " >&2

      if echo "$tipo" | grep -qiE '(VOR|NDB|DME)' 
      then 
         arq="$nomeBase/navaid_data"
         jur="$nomeBase/navaid_jur_data"
      elif echo "$tipo" | grep -qi 'waypoint' 
      then 
         arq="$nomeBase/fix_data"
         jur="$nomeBase/fix_jur_data"
      else 
         echo "$nome: erro no tipo da baliza ($tipo). Verifique o arquivo $planilha e reinicie o processo. " >&2
         exit 1
      fi 

      latitude=$(echo "$latitude" | sed 's/[[:blank:]]*//g')
      longitude=$(echo "$longitude" | sed 's/[[:blank:]]*//g')

      if ! echo "$latitude" | grep -q '^[NS][0-9]\{6\}\.[0-9]\{2\}$' || ! echo "$longitude" | grep -q '^[WE][0-9]\{7\}\.[0-9]\{2\}$'
      then 
        echo "Coordenadas inválidas. Verifique as coordenadas da baliza $nome no arquivo $planilha e reinicie o processo. " >&2
        exit 1
      fi 

      latitudeSeg=$(echo "$latitude" | sed 's/.*\([0-9]\{2\}\.[0-9]\{2\}\) *$/\1/' | awk '{ printf "%02.f", $1 }')
      latitude=$(echo "$latitude" | sed "s/^\([NS][0-9]\{4\}\).*/\1$latitudeSeg/")

      longitudeSeg=$(echo "$longitude" | sed 's/.*\([0-9]\{2\}\.[0-9]\{2\}\) *$/\1/' | awk '{ printf "%02.f", $1 }')
      longitude=$(echo "$longitude" | sed "s/^\([WE][0-9]\{5\}\).*/\1$longitudeSeg/")

      if registro=$(grep "$nome" "$arq")
      then 
         latBase=$(echo "$registro" | awk -F';' '{ printf "%s%02d%02d%02d", $6, $7, $8, $9 }')
         longBase=$(echo "$registro" | awk -F';' '{ printf "%s%03d%02d%02d", $10, $11, $12, $13 }')

         if [ "$latBase" != "$latitude" ] || [ "$longBase" != "$longitude" ]
         then 
            pontoBase=$(coordsBase "$latitude" "$longitude")
            sed -i "/$nome/s/[NS];\([0-9]\{1,\};\)\{3\}[WE];\([0-9]\{1,\};\)\{3\}/$pontoBase;/" "$arq"
         fi 
      else 
         resultado=$(pontoDentro "$latitude" "$longitude")

         if [ "$resultado" = "true" ]
         then 
            pontoBase=$(coordsBase "$latitude" "$longitude")
            tipoNaBase=''

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

               'Waypoint')
                  tipoNaBase='FIX'
               ;;

               *)
                  echo "$nome: erro no tipo da baliza ($tipo). Verifique o arquivo $planilha e reinicie o processo. " >&2
                  exit 1
               ;;
            esac

            echo "$nome;;$nome;$tipoNaBase;$pontoBase;0.0;0;0;0;1;0;0;0;0.0;1;20;0" >> "$arq"
         fi 
      fi
   done

   echo "Balizas atualizadas. " >&2
}

empacotarBase() {
   echo "Empacotando a base... " >&2
   cd "$nomeBase"

   for i in *
   do 
      [ "$i" != "INFO" ] && gzip -9 < "$i" > "$nomeBase"_"$i.EXP" || cp "$i" "$nomeBase"_"$i.EXP"
   done 

   if tar -cf "../$nomeBase-$(date -u '+%Y%m%d_%H%M%SP').tar" *.EXP
   then 
      rm -r *.EXP
      cd ..
      echo "Pacote criado com sucesso! " >&2
   else 
      echo "Erro na criação do pacote. " >&2
      exit 1
   fi 
}

aerovias() {
   mkdir -p awys
   rm -f awys/*

   awk -F '(\t| *, *)' -v 'OFS=\t' 'NF > 2 { print $1, $4, $5, $6, $8, $9, $10 }' "$planilha" | while IFS=$'\t' read awy p1 la1 lo1 p2 la2 lo2
   do 
      printf "$p1\t$la1\t$lo1\n$p2\t$la2\t$lo2\n" >> "awys/$awy"
   done 

   cd awys
   sed -i '/^[[:space:]]*$/d' *

   for i in * 
   do 
      cat -n "$i" | sort -uk2 | sort -nk1 | cut --complement -f1 > "$i.fase1"
   done 

   for i in *.fase1
   do 
      primeiroPontoFora=''

      while IFS=$'\t' read ponto la lo
      do 
         if ! grep -q $ponto "../$nomeBase/fix_data" "../$nomeBase/navaid_data" 
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
         if ! grep -q $ponto "../$nomeBase/fix_data" "../$nomeBase/navaid_data" 
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

   for i in * 
   do 
      echo "$i" | grep -qv '\.fase3$' && rm "$i"
   done  

   for i in *
   do 
      nome=$(echo "$i" | sed 's/\([^.]*\).*/\1/')
      mv "$i" "$nome"
   done
   
   fir=$(extrairContorno)
   n=0

   for i in * 
   do 
      ponto0=$(sed -n '1p' "$i" | cut -f1)
      ponto1=$(sed -n '2p' "$i" | cut -f1)

      if ! grep -q "$ponto0" "../$nomeBase/fix_data" "../$nomeBase/navaid_data"
      then 
         if grep -q "SBRE.*$ponto1" "../$nomeBase/firseg_data" 
         then 
            sed -i '1d' "$i"
         else 
            segA='['$(
               head -n2 "$i" | 
               awk -F '(\t|  *)' '{ printf "%s\t%s%02d%02d%02.f\t%s%03d%02d%02.f\n", $1, $2, $3, $4, $5, $6, $7, $8, $9 }' | 
               while read nome lat lon
               do 
                  cartesianas "$lat" "$lon" | sed -e 's/^/[/' -e 's/$/], /' -e 's/[[:blank:]]\{1,\}/, /'
               done 
            )']'

            cruzA=$(cruzFronteira "$segA" "$fir" | sed 's/[][ ]//g')
            while [ -z "$cruzA" ] 
            do 
               sed -i '1d' "$i"
               
            done 

            cruzALatK=$(echo "$cruzA" | cut -d',' -f1)
            cruzALonK=$(echo "$cruzA" | cut -d',' -f2)
            cruzAG=$(geograficas "$cruzALatK" "$cruzALonK")

            cruzALat=$(echo "$cruzAG" | cut -f1)
            cruzALon=$(echo "$cruzAG" | cut -f2)
            pontoBase=$(coordsBase "$cruzALat" "$cruzALon")
            cruzANome=$(echo $n | awk '{ printf "FRE%02X", $1 }')
            n=$((n+1))
            #echo "$cruzANome;;$cruzANome;FIX;$pontoBase;0.0;1;0;1;1;0;0;0;0.0;1;20;0" # >> "../$nomeBase/fix_data"

            cruzALat=$(echo "$cruzALat" | sed 's/\([NS]\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
            cruzALon=$(echo "$cruzALon" | sed 's/\([WE]\)\([0-9]\{3\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1 \2 \3 \4/')
            sed -i "/$ponto0/s/^.*$/$cruzANome\t$cruzALat\t$cruzALon/" "$i"
         fi 
      fi 
   done 

   cd ..
}

limpar() {
   rm -r "$nomeBase"
}

aerovias
#extrairContorno | sed 's/\], *\[/\n/g'
