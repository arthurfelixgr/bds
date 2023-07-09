#! /bin/sh - 
# $ ./numFix.sh fixos.nomes fixos.numero-nome 
while read linha 
do 
   if num=$(grep -P "\t$linha$" "$2") 
   then 
      echo "$num" 
   else 
      echo "FALHA" 
   fi
done < "$1" 
