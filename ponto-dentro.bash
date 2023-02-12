#!/bin/bash


cat > ponto-dentro.py <<EOF
#!/bin/python3

from shapely.geometry import Point, Polygon

EOF

chmod +x ponto-dentro.py 
contorno=$(cut --complement -f1 < "$2" | sed -e 's/^/(/' -e 's/$/)/' -e 's/[[:space:]]\{1,\}/, /g' | tr '\n' ',' | sed -e 's/,$//' -e 's/),(/), (/' -e 's/^/[/' -e 's/$/]/')
echo "fir = Polygon($contorno)" >> ponto-dentro.py 


while read linha 
do 
    linha=$(echo "$linha" | sed 's/[[:space:]]\{1,\}/\t/g')

    nome=$(echo "$linha" | cut -f1)

    hemx=$(echo "$linha" | cut -f2)
    sigx=''
    graux=$(( 10#$(echo "$linha" | cut -f3) ))
    minx=$(( 10#$(echo "$linha" | cut -f4) ))
    segx=$(echo "$linha" | cut -f5)

    hemy=$(echo "$linha" | cut -f6)
    sigy=''
    grauy=$(( 10#$(echo "$linha" | cut -f7) ))
    miny=$(( 10#$(echo "$linha" | cut -f8) ))
    segy=$(echo "$linha" | cut -f9)

    [ "$hemx" = 'S' ] && sigx='-1' || sigx='1'
    [ "$hemy" = 'W' ] && sigy='-1' || sigy='1'

    x=$( echo "($graux + $minx/60 + $segx/3600) * $sigx" | bc -l | awk '{printf "%0.16f", $0}' | awk '{ if ($0 ~ /\./){ sub("0*$","",$0); sub ("\\.$","",$0);} print}')
    y=$( echo "($grauy + $miny/60 + $segy/3600) * $sigy" | bc -l | awk '{printf "%0.16f", $0}' | awk '{ if ($0 ~ /\./){ sub("0*$","",$0); sub ("\\.$","",$0);} print}')

    echo "$nome = Point($x, $y)" >> ponto-dentro.py 
    echo "print($nome.within(fir))" >> ponto-dentro.py 

    resultado=$(./ponto-dentro.py)
    echo $resultado | grep "True" > /dev/null && echo "$linha"
    sed -i "/$nome/d" ponto-dentro.py 
done < "$1"

rm ponto-dentro.py 