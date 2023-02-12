#!/bin/bash -
mkdir sectores
i=1
j=0
primeira=''

grep -v "\(SETOR\|MODIFICADO\|LAT[[:blank:]]\{1,\}LON\)" < "$1" | sed -e '1{/^$/d}' -e '$a \\' | while read linha
do 
    arquivo=setor$(printf "%.2d" "$i")

    if echo "$linha" | grep '^[[:space:]]*$' > /dev/null 
    then 
        echo "$primeira" >> sectores/$arquivo
        printf '\n' >> sectores/$arquivo
        ((i++))
        j=0
        continue
    fi 

    [ $j -eq 0 ] && primeira="$linha"
    echo "$linha" >> sectores/$arquivo
    ((j++))
done 

cat sectores/*
rm -r sectores