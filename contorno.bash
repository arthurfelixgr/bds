#!/bin/bash -

mkdir sectores
i=1
primeira=''

grep -v "\(SETOR\|MODIFICADO\|LAT[[:blank:]]\{1,\}LON\)" < "$1" | sed -e '1{/^$/d}' -e '$a \\' | while read linha
do 
    arquivo=setor$(printf "%.2d" "$i")

    echo "$linha" | grep '^[[:space:]]*$' > /dev/null  && {
        printf '\n' >> sectores/$arquivo
        ((i++))
        continue
    }

    echo "$linha" >> sectores/$arquivo
done 


cat > contorno.py <<EOF
#!/bin/python3

from shapely.geometry import Polygon
from shapely.ops import unary_union

EOF


sects=
cd sectores 

for i in *
do 
    echo "$i" | grep 'setor[0-9][0-9]' > /dev/null && {
        echo $( cut --complement -f1 < "$i" | sed -e '$d' -e 's/^/(/' -e 's/$/), /' -e 's/\t/, /' | tr '\n' ' ' | sed -e "s/^/$i = Polygon([/" -e "s/, *$/])/" ) >> ../contorno.py 
        printf '\n' >> ../contorno.py 
        sects+=("$i")
    }
done 

cd ..
rm -r sectores
echo "fir = unary_union([$( echo "${sects[@]}" | sed -e 's/ /, /g' -e 's/^, //' )])" >> contorno.py 
echo "print(fir)" >> contorno.py 
chmod +x contorno.py

./contorno.py | sed -e 's/^.*((//' -e 's/))$//' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/ /\t/' | while read linha 
do 
    linha=$(echo "$linha" | sed 's/[[:space:]]\{1,\}/\t/g' )

    latitude=$( echo "$linha" | cut -f1 )
    longitude=$( echo "$linha" | cut -f2 )

    hemx='N'
    echo "$latitude" | grep '^-' > /dev/null && hemx='S'

    graux=$(echo "$latitude/(-1)" | bc)
    minxf=$(echo "($latitude*(-1) - $graux ) * 60" | bc)
    minx=$(echo "$minxf/1" | bc)
    secxf=$(LC_NUMERIC="en_US.UTF-8" printf "%0.2f" "$(echo "($minxf - $minx) * 0.6" | bc)")
    secx=$(printf "%d" "$(echo "$secxf * 100" | bc)" 2> /dev/null)

    hemy='E'
    echo "$longitude" | grep '^-' > /dev/null && hemy='W'

    grauy=$(echo "$longitude/(-1)" | bc)
    minyf=$(echo "($longitude*(-1) - $grauy ) * 60" | bc)
    miny=$(echo "$minyf/1" | bc)
    secyf=$(LC_NUMERIC="en_US.UTF-8" printf "%0.2f" "$(echo "($minyf - $miny) * 0.6" | bc)")
    secy=$(printf "%d" "$(echo "$secyf * 100" | bc)" 2> /dev/null)

    latitudeg=$(printf "%0.2d%0.2d%0.2d$hemx" "$(echo "$graux/1" | bc)" "$(echo "$minx/1" | bc)" "$(echo "$secx/1" | bc)")
    longitudeg=$(printf "%0.3d%0.2d%0.2d$hemy" "$(echo "$grauy/1" | bc)" "$(echo "$miny/1" | bc)" "$(echo "$secy/1" | bc)")

    latitudeg=$(echo "$latitudeg" | sed 's/-//g')
    longitudeg=$(echo "$longitudeg" | sed 's/-//g')

    echo "$latitudeg" | grep '0\{6\}' > /dev/null && latitudeg=$(echo "$latitudeg" | sed 's/[A-Z]//')
    echo "$longitudeg" | grep '0\{6\}' > /dev/null && longitudeg=$(echo "$longitudeg" | sed 's/[A-Z]//')

    grep -m1 "$latitudeg[A-Z]*[[:blank:]]\{1,\}$longitudeg[A-Z]*" < "$2" || {
        echo "Um fixo não foi encontrado: $latitude $longitude $latitudeg $longitudeg" >&2
        break
    }
done 

rm contorno.py