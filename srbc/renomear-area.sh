#! /bin/sh -

# $ ./renomear-area.sh VELHA NOVA 

if [ -z "$1" ] || [ -z "$2" ]
then
  echo "Erro: argumentos insuficientes!" >&2
  exit 1
fi 

if ls "$1"@a_* > /dev/null 2>&1
then
  for i in *
  do
    if ls $i | grep "$1@" > /dev/null 2>&1
    then
      nome=$( ls $i | sed "s/^$1\(.*\)/$2\1/" )
      mv $i $nome
      
      if [ "$i" = "$1"@a_usuari ]
      then
        sed -i "s/$1/$2/g" $nome
      else
        sed -i "s/('$1',/('$2',/" $nome
      fi
    fi
  done
else
  echo "Erro: extraia a área antes!" >&2
  exit 1
fi
