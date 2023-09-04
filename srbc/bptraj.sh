#! /bin/sh -

# script para reaproveitar as trajetórias de uma área antiga numa área nova

bptrajAntigo=$(zenity --file-selection --title="Selecione o a_bptraj antigo" --file-filter="*a_bptraj")
fixosAntigo=$(zenity --file-selection --title="Selecione o a_fixos antigo" --file-filter="*a_fixos")
fixosNovo=$(zenity --file-selection --title="Selecione o a_fixos novo" --file-filter="*a_fixos")

rm -f bptrajAtualizado

while read linha 
do 
   tipo=$(echo "$linha" | awk -F "','" '{print $4}')

   case $tipo in 
      F )
         numFixAntigo=$(echo "$linha" | awk -F "','" '{print $5}')
         nomeFix=$(grep "'$numFixAntigo'" "$fixosAntigo" | awk -F "','" '{print $4}')

         if grep -q "$nomeFix" "$fixosNovo"
         then
            numFixNovo=$(grep -m1 "$nomeFix" "$fixosNovo" | awk -F "','" '{print $2}')
            echo "$linha" | sed "s/,'$numFixAntigo',/,'$numFixNovo',/" >> bptrajAtualizado
         else
            coords=$(grep "'$numFixAntigo'" "$fixosAntigo" | grep -o "'G'[^)]*")
            echo "$linha" | sed "s/'F','$numFixAntigo','',''/$coords/" >> bptrajAtualizado
         fi 
      ;;

      D )
         numFixAntigo=$(echo "$linha" | awk -F "','" '{print $5}')
         nomeFix=$(grep "'$numFixAntigo'" "$fixosAntigo" | awk -F "','" '{print $4}')

         if grep -q "$nomeFix" "$fixosNovo"
         then
            numFixNovo=$(grep -m1 "$nomeFix" "$fixosNovo" | awk -F "','" '{print $2}')
            echo "$linha" | sed "s/,'$numFixAntigo',/,'$numFixNovo',/" >> bptrajAtualizado
         else
            numProxFix=$(tail -1 "$fixosNovo" | awk -F "','" '{printf "%04d", $2+1}')
            grep "'$numFixAntigo'" "$fixosAntigo" | sed "s/,'$numFixAntigo',/,'$numProxFix',/" >> "$fixosNovo"
            echo "$linha" | sed "s/,'$numFixAntigo',/,'$numProxFix',/" >> bptrajAtualizado
         fi 
      ;;

      G )
         continue
      ;;

      * )
         echo "Erro de tipo" >&2
         exit 1
      ;;
   esac
done < $bptrajAntigo
