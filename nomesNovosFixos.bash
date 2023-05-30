#! /bin/bash -

# (c) 2023
#  @arthurfelixgr

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

planilha="$1"
base="$2"
nomeBase=$(tar -tf "$base" | head -n1 | cut -d'_' -f1)
pwd=$PWD

verificaNomes() {
   sed -i '/^[[:space:]]*$/d' "$planilha"

   while read linha
   do 
      nomeAntigo=$(echo "$linha" | cut -f1)
      nomeNovo=$(echo "$linha" | cut -f3)
      echo "$nomeAntigo $nomeNovo" 

      grep "$nomeAntigo" "$nomeBase/fix_data"
      #grep "$nomeNovo" "$nomeBase/fix_data"
   done < "$planilha"
}

atualizaNomes() {
   sed -i '/^[[:space:]]*$/d' "$planilha"

   while read linha
   do 
      nomeAntigo=$(echo "$linha" | cut -f1)
      nomeNovo=$(echo "$linha" | cut -f3)
      sed -i "/$nomeAntigo/s/$nomeAntigo/$nomeNovo/g" "$nomeBase/fix_data"
   done < "$planilha"
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

verificaNomes
