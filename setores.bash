#!/bin/bash -

rm fixosConhecidos 2> /dev/null
rm loop1 2> /dev/null
touch fixosConhecidos
i=1

while read linha 
do 
    if echo "$linha" | grep -v "\(SETOR\|-MOD\|LAT[[:blank:]]\{1,\}LON\|^[[:blank:]]*$\)" > /dev/null && ! echo "$linha" | grep "^[[:blank:]]*[0-9]\{6,7\}[A-Z]" > /dev/null
    then
        linha=$(echo "$linha" | sed 's/[[:space:]]\{1,\}/\t/g' )
        nome=$( echo "$linha" | cut -f1 )

        latitude=$( echo "$linha" | cut -f2 )
        longitude=$( echo "$linha" | cut -f3 )

        if fixoRepetido=$( grep "$latitude[[:blank:]]\{1,\}$longitude" < fixosConhecidos )
        then 
            echo "$fixoRepetido" >> loop1
        else 
            echo "$linha" >> loop1
            echo "$linha" >> fixosConhecidos
        fi 
    else 
        echo "$linha" >> loop1 
    fi 
done < <(sed "/[A-Z][0-9]\{6,7\}/s/\([A-Z]\)\([0-9]\{6,7\}\)/\2\1/g" < "$1")

while read linha 
do 
    j=$( printf "%.2X" "$i" )

    if echo "$linha" | grep -v "\(SETOR\|-MOD\|LAT[[:blank:]]\{1,\}LON\|^[[:blank:]]*$\)" > /dev/null && echo "$linha" | grep "^[[:blank:]]*[0-9]\{6,7\}[A-Z]" > /dev/null
    then 
        linha=$(echo "$linha" | sed 's/[[:space:]]\{1,\}/\t/g' )

        latitude=$( echo "$linha" | cut -f1 )
        longitude=$( echo "$linha" | cut -f2 )

        if fixoRepetido=$( grep "$latitude[[:blank:]]\{1,\}$longitude" < fixosConhecidos )
        then 
            echo "$fixoRepetido"
        else 
            fixoNovo=$(printf "SEC$j\t$linha")
            echo "$fixoNovo"
            echo "$fixoNovo" >> fixosConhecidos
            i=$((i+1))
        fi 
    else 
        echo "$linha"
    fi 
done < loop1 | uniq | sed -e '/^[[:space:]]*$/d' -e '/\(SETOR\|MODIFICADO\)/i\\'

rm fixosConhecidos 2> /dev/null
rm loop1 2> /dev/null
