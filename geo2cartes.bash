#!/bin/bash

while read linha
do 
    if echo "$linha" | grep -v "\(SETOR\|LAT[[:blank:]]\{1,\}LON\|^[[:blank:]]*$\)" > /dev/null
    then 
        fixo=$(echo "$linha" | cut -f1)
        coord=$(echo "$linha" | cut --complement -f1 | sed 's/\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([S,N]\)[[:blank:]]\([0-9]\{3\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)\([W,E]\)/\4\t\1\t\2\t\3\t\8\t\5\t\6\t\7\t/')
        
        hemx=$(echo "$coord" | cut -f1)
        sigx=''
        graux=$(( 10#$(echo "$coord" | cut -f2) ))
        minx=$(( 10#$(echo "$coord" | cut -f3) ))
        segx=$(( 10#$(echo "$coord" | cut -f4) ))

        hemy=$(echo "$coord" | cut -f5)
        sigy=''
        grauy=$(( 10#$(echo "$coord" | cut -f6) ))
        miny=$(( 10#$(echo "$coord" | cut -f7) ))
        segy=$(( 10#$(echo "$coord" | cut -f8) ))

        [ "$hemx" = 'S' ] && sigx='-'
        [ "$hemy" = 'W' ] && sigy='-'

        x=$(echo "$sigx")$(awk "BEGIN{ OFMT=\"%0.14f\"; print $graux + $minx/60 + $segx/3600 ; }")
        y=$(echo "$sigy")$(awk "BEGIN{ OFMT=\"%0.14f\"; print $grauy + $miny/60 + $segy/3600 ; }")

        printf "$fixo\t$x\t$y\n" | sed 's/0*$//'
    else 
        echo "$linha"
    fi 
done < "$1"
