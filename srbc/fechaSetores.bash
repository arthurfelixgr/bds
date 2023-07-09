#! /bin/bash

# $ ./fechaSetores.bash setores-geo

n=0
priPonto=''

while read linha
do
	if echo "$linha" | grep -Pq '^1\t'
	then
		n=$((n+1))
		test -n "$priPonto" && echo "$priPonto" | sed "s/^1/$n/"
		printf "\n"
		priPonto="$linha"
	else
		n=$(echo "$linha" | cut -f1)
	fi

	echo "$linha"
done <<<$(grep -P '^\t[0-9]' "$1") 

n=$((n+1))
echo "$priPonto" | sed "s/^1/$n/"
