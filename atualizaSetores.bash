#! /bin/bash -

# (c) 2023
#  @arthurfelixgr

# ./setores.bash setores aerovias base

if [ "$#" -eq 3 ]
then 
   if ! file "$1" | grep -q '\(ASCII\|CSV\)'
   then 
      echo "Planilha de setores inválida." >&2
      exit 1
   fi 

   if ! file "$2" | grep -q '\(ASCII\|CSV\)'
   then 
      echo "Planilha de aerovias inválida." >&2
      exit 1
   fi 

   if ! file "$3" | grep -q 'tar archive'
   then 
      echo "Arquivo de base inválido." >&2
      exit 1
   fi 
else 
   echo "Argumentos insuficientes." >&2
   exit 1
fi 

planilha1="$1" #setores
planilha2="$2" #aerovias
base="$3"
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

criaFixos() {
   echo "Separando os fixos a partir da planilha de aerovias... " >&2
   rm -f "$planilha2.temp"

   awk -F'\t' 'NF > 0 { printf "%s\t%s\t%s\n%s\t%s\t%s\n", $3, $4, $5, $7, $8, $9 }' "$planilha2" | sort -uk1,1 | while IFS=$'\t' read nome lat lon
   do 
      lat=$(echo "$lat" | awk -F' ' '{ printf "%s%02d%02d%02.f", $1, $2, $3, $4 }')
      lon=$(echo "$lon" | awk -F' ' '{ printf "%s%03d%02d%02.f", $1, $2, $3, $4 }')
      nome=$(echo "$nome" | sed 's/[[:space:]]//g')
      printf "$nome\t$lat\t$lon\n" >> "$planilha2.temp"
   done 
}

criaSetores() {
   echo "Ajustando o formato das coordenadas da planilha de setores... " >&2
   rm -f "$planilha1.temp"

   awk -F'(\t| *, *)' -v OFS='\t' 'NF > 0 { print $1, $3, $4, $5 }' "$planilha1" | while IFS=$'\t' read setor nome lat lon
   do 
      lat=$(echo "$lat" | awk -F' ' '{ printf "%s%02d%02d%02.f", $1, $2, $3, $4 }')
      lon=$(echo "$lon" | awk -F' ' '{ printf "%s%03d%02d%02.f", $1, $2, $3, $4 }')
      printf "$setor\t$nome\t$lat\t$lon\n" >> "$planilha1.temp"
   done 
}

nomesPontos() {
   echo "Atribuindo nomes aos pontos dos limites dos setores... " >&2
   rm -f "$planilha1.final"
   resultado=''
   n=0
   while read setor nome lat lon
   do 
      if resultado=$(grep -P "$lat\t$lon" "$planilha2.temp")
      then 
         resultado=$(echo "$resultado" | cut -f1)
      else 
         resultado=$(echo "$n" | awk '{ printf "SRE%02X", $1 }')
         n=$((n+1))
      fi 

      printf "$setor\t$resultado\t$lat\t$lon\n" >> "$planilha1.final"
   done < "$planilha1.temp"
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

setoresBase() {
   echo "Atualizando a base... " >&2
   sed -i '12q' "$nomeBase/firsecseg_data"
   n=1
   nSetor=''

   while read setor nome lat lon
   do 
      nSetorAtual=$(echo "$setor" | cut -d'_' -f2)

      if [ "$nSetor" != "$nSetorAtual" ]
      then 
         n=1
         nSetor="$nSetorAtual"
      fi 

      camposFinais=$(coordsBase "$lat" "$lon")
      echo "S$nSetor;FIR_SECTOR;$n;$nome;$camposFinais" >> "$nomeBase/firsecseg_data"
      n=$((n+1))
   done < "$planilha1.final"
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

extrairBase "$base"
criaFixos
nomesPontos
setoresBase
empacotarBase
rm "$planilha1".* "$planilha2".*
