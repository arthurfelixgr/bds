#! /bin/bash -

# Uso:
#   $ ./inserir-aerovias.bash planilha base.tar

planilha="$1"
base="$2"
nomeBase=$(tar -tf "$base" | head -n1 | cut -d'_' -f1)

extrairBase() {
   echo "Extraindo a base $1..." >&2
   #pasta=$(tar -tf "$1" | head -n1 | cut -d'_' -f1)
   pasta="$nomeBase"
   mkdir -p "$pasta"
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

   echo "Extração completa." >&2
}

pontoDentro() {
   
}

atualizarBalizas() {
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
      else 
      fi
   done 
}
