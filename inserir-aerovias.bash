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

   test -n "$pasta" && grep '^SBRE' "$pasta/firseg_data" | 
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
   console.log(pointIn($lat, $lon, $fir));
_EOF
}

atualizarBalizas() {
   echo "Atualizando balizas..." >&2

   data=''
   jur=''

   awk -F '(\t| *, *)' -v 'OFS=\t' 'NF > 0 { print $3, $4, $5, $6, "\n", $7, $8, $9, $10 }' "$planilha" | 
   sed -e 's/^[[:blank:]]*//' | 
   grep -v '^[[:space:]]*$' | 
   sort -uk2,2 | 
   while IFS=$'\t' read tipo nome latitude longitude 
   do 
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
            hem_y=$(echo "$latitude" | cut -c1 | awk '{ printf "%s", $1 }')
            grau_y=$(echo "$latitude" | cut -c2,3 | awk '{ printf "%d", $1 }')
            min_y=$(echo "$latitude" | cut -c4,5 | awk '{ printf "%d", $1 }')
            seg_y=$(echo "$latitudeSeg" | awk '{ printf "%d", $1 }')

            hem_x=$(echo "$longitude" | cut -c1 | awk '{ printf "%s", $1 }')
            grau_x=$(echo "$longitude" | cut -c2-4 | awk '{ printf "%d", $1 }')
            min_x=$(echo "$longitude" | cut -c5,6 | awk '{ printf "%d", $1 }')
            seg_x=$(echo "$longitudeSeg" | awk '{ printf "%d", $1 }')

            sed -i "/$nome/s/[NS];\([0-9]\{1,\};\)\{3\}[WE];\([0-9]\{1,\};\)\{3\}/$hem_y;$grau_y;$min_y;$seg_y;$hem_x;$grau_x;$min_x;$seg_x;/" "$arq"
         fi 
      #else 
      fi
   done

   echo "Balizas atualizadas. " >&2
}

extrairBase "$base"
atualizarBalizas
