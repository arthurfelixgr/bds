#! /bin/bash -

echo "Extraindo a base $1..." >&2
pasta=$(tar -tf "$1" | head -n1 | cut -d'_' -f1)
rm -rf "$pasta"
mkdir "$pasta"

tar -xf "$1" -C "$pasta" || {
   echo "extrairBase(): pane" >&2
   exit 1
}

cd "$pasta"

for i in *
do 
   nome=$(echo "$i" | sed -e "s/^$pasta\(.*\)\.EXP$/\1/" -e 's/^_//')

   if file "$i" | grep -q 'gzip' 
   then 
      gunzip < "$i" > "$nome"
      rm "$i"
   else 
      mv "$i" "$nome"
   fi 
done 

cd ..
echo "Extração completa." >&2
