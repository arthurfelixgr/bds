#!/bin/sh

caminho=$(head -n1 Ftab)
cd "$caminho"

FM=$4
data=$(date +'%m/%d/%Y')
unixtime=$(date -d "$data $1:$2:$3" +"%s.%N")
n=0

while true
do
  n=$((n+1))
  celere=$(echo $unixtime | awk -v "fatorSoma=$n" -v "vzs=$FM" '{printf "%d", $1+(fatorSoma*vzs)}')
  #echo $celere
  argumento=$(date -d@$celere +"%H %M %S")
  echo "$argumento"
  hora=$(echo "$argumento" | cut -d' ' -f1)
  minuto=$(echo "$argumento" | cut -d' ' -f2)
  segundo=$(echo "$argumento" | cut -d' ' -f3)
  ./syq_msghora $hora $minuto $segundo
  sleep 1
done

