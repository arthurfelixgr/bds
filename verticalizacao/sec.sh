#! /bin/bash -
#firsec_data

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

  b=
  case $S in
    'S01' | 'S02' | 'S03' )
        b=NNN
    ;;

    'S04' | 'S05' | 'S06' | 'S07' | '07F' | 'S10' | 'S11' |'11L' | '11F' )
        b=HHH
    ;;

    'S08' | 'S09' | 'S12' | '12L' )
        b=WWW
    ;;

    'S13' | 'S14' | '14F' | 'S15' )
        b=SSS
    ;;
  esac

  d=`echo $i | sed -e "s/$S/$L/" -e "s/\(;NULO;\)...\(;FIR_SECTOR;\)/\1$b\2/" -e 's/\(SBRE;0;\).../\1149/'`

  sed -i "/----/i\
  $d" $1
done

n=`grep -n FIR_SECTOR $1 | head -n1 | cut -d':' -f1`
sed -i "/----/d" $1
sed -i "$n i----" $1
sed -i -e 's/0\(;999;\)/150\1/' -e 's/0\(;350;\)/150\1/' $1