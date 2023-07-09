#! /bin/sh -

# $ ./tratamento.sh base.MySQL

if [ -z "$1" ]
then
  echo "Erro: argumentos insuficientes!" >&2
  exit 1
fi 

for i 
do
  nome=$( ls $i | sed 's/\(.*\)\(\.MySQL\)$/\1.tratado\2/' )

  sed "s/VALUES (/VALUES \n(/" < $i > $nome
  sed -i "s/'),('/'),\n('/g" $nome
done
