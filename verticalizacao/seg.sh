#! /bin/sh -
#firsecseg_data

for i in `grep FIR_SECTOR $1`
do
  S=`echo $i | cut -d';' -f1`
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

  sed -i "/----/i\
  $d" $1
done

n=`grep -n FIR_SECTOR $1 | head -n1 | cut -d':' -f1`
sed -i "/----/d" $1
sed -i "$n i----" $1
