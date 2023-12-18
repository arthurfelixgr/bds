#! /bin/bash -

nomeBase=$1
echo "Empacotando a base... " >&2
cd "$1"

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
