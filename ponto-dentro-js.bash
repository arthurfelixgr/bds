#!/bin/bash

cat > ponto-dentro.js <<EOF
#!/bin/nodejs
/** Get relationship between a point and a polygon using ray-casting algorithm
 * @param {{x:number, y:number}} P: point to check
 * @param {{x:number, y:number}[]} polygon: the polygon
 * @returns -1: outside, 0: on edge, 1: inside
 */
function relationPP(P, polygon) {
    const between = (p, a, b) => p >= a && p <= b || p <= a && p >= b
    let inside = false
    for (let i = polygon.length-1, j = 0; j < polygon.length; i = j, j++) {
        const A = polygon[i]
        const B = polygon[j]
        // corner cases
        if (P.x == A.x && P.y == A.y || P.x == B.x && P.y == B.y) return 0
        if (A.y == B.y && P.y == A.y && between(P.x, A.x, B.x)) return 0

        if (between(P.y, A.y, B.y)) { // if P inside the vertical range
            // filter out "ray pass vertex" problem by treating the line a little lower
            if (P.y == A.y && B.y >= A.y || P.y == B.y && A.y >= B.y) continue
            // calc cross product `PA X PB`, P lays on left side of AB if c > 0 
            const c = (A.x - P.x) * (B.y - P.y) - (B.x - P.x) * (A.y - P.y)
            if (c == 0) return 0
            if ((A.y < B.y) == (c > 0)) inside = !inside
        }
    }

    return inside? 1 : -1
}

latitude = -2.67100000000000;
longitude = -43.57877777777778;
ponto = {x: latitude, y: longitude};

EOF

chmod +x ponto-dentro.js
contorno=$(cut --complement -f1 < "$2" | sed -e 's/[[:space:]]\{1,\}/, y: /' -e 's/^/{x: /' -e 's/$/}, /' | tr '\n' ' ' | sed -e 's/, *$/]/' -e 's/^/[/')
echo "fir = $contorno" >> ponto-dentro.js 

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

    sed -i -e "s/\(latitude = \).*;$/\1$x;/" -e "s/\(longitude = \).*;$/\1$y;/" ponto-dentro.js

    resultado=$(./ponto-dentro.js)
    [ "$resultado" != "-1" ] && echo "$linha"
done < "$1"

rm ponto-dentro.js 