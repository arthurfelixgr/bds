#! /bin/sh -

# $ ./inserir-area.sh base.MySQL AREA

if [ -z "$1" ] || [ -z "$2" ]
then
  echo "Erro: argumentos insuficientes!" >&2
  exit 1
fi 

if ls "$2"@a_* > /dev/null 2>&1
then
  for i in *
  do
    if ls $i | grep "$2@" > /dev/null 2>&1
    then
      tabela=$( ls $i | sed "s/$2@\(.*\)/\1/" )
      linha=$( grep -n "INSERT INTO \`$tabela\`" $1 | head -n1 | cut -d: -f1 )
      sed -i "${linha}r $i" $1
    fi
  done

#  rm "$2"@a_*
else
  echo "Erro: extraia a área antes!" >&2
  exit 1
fi
