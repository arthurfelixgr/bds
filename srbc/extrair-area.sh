#!/bin/sh -

# $ ./extrair-area.sh base.MySQL AREA 

[ -z "$1" -o -z "$2" ] && {
  echo "Erro: argumentos insuficientes!" >&2
  exit 1
}

n=1
m=$( grep -E "(\('$2',|INSERT INTO \`a_)" < $1 | wc -l )
PROGRESSO=0

grep -E "(\('$2',|INSERT INTO \`a_)" < $1 | while read linha
do
  clear
  printf "Progresso: \n%s%%\n" "$PROGRESSO" 

  echo $linha | grep "INSERT INTO \`a_" > /dev/null 2>&1 && {
    arq=$( echo $linha | sed "s/.*\`\([a-z_]*\)\`.*/\1/" )
    ls "$2@$arq" > /dev/null 2>&1 || touch "$2@$arq"
  } || echo $linha >> "$2@$arq"
  
  n=$((n+1))
  PROGRESSO=$(echo "scale=2; $n*100/$m" | bc)
done

for i in *
do
  if ls $i | grep "$2@" > /dev/null 2>&1 
  then
    tamanho=$( ls -s $i | cut -d' ' -f1 )

    if [ "$tamanho" -eq 0 ] 
    then
      rm $i 
    else
      sed -i 's/;$/,/' $i
    fi
  fi
done
