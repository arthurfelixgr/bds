#! /bin/sh -
# argumento: SETORIZ

tr '\t' '@' < $1 > setoriz

for i in `grep '@2' setoriz`
do
  S=`echo $i | cut -d'@' -f2`
  L=
  
  if echo "$S" | grep -E '(S[0-9][0-9]|[0-9][0-9]F)' > /dev/null
  then
    L=$(echo $S | sed 's/^./I/')
  elif echo "$S" | grep '[0-9][0-9]L' > /dev/null
  then
    L=$(echo $S | sed 's/\([0-9][0-9]\)L/I\1/')
  else
    continue
  fi

  d=`echo $i | sed "s/$S/$L/"`

  sed -i "/SETOR@/i\
  $d" setoriz
done

n=`grep 'SETOR@' setoriz`
sed -i "/$n/d" setoriz
sed -i "/I01/i\
$n" setoriz

tr '@' '\t' < setoriz > $1
rm setoriz
