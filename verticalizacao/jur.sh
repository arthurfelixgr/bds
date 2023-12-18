#! /bin/sh -

for i in `grep -n FIR_SECTOR $1`
do
  n=`echo $i | cut -d':' -f1` # número da linha
  t=`echo $i | cut -d':' -f2` # conteúdo da linha
  S=`echo $t | cut -d';' -f3` # setor
  L=
  
  if echo "$S" | grep -E '(S[0-9][0-9]|[0-9][0-9]F)' > /dev/null
  then
    L=$(echo $S | sed 's/^./I/')
  elif echo "$S" | grep '[0-9][0-9][A-Z]' > /dev/null
  then
    L=$(echo $S | sed 's/\([0-9][0-9]\)[A-Z]/I\1/')
  fi
  
  d=`echo $t | sed "s/$S/$L/"`
  sed -i "/$t/i\
  $d" $1
done
