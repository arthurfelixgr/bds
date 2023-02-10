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

./contorno.py | sed -e 's/^.*((//' -e 's/))$//' | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/ /\t/' 
rm contorno.py
