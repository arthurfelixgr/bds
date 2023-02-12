# bds
## Já é possível:

* Tratar uma tabela de setores, eliminando problemas como pontos sem nome, pontos com nomes iguais e coordenadas diferentes e pontos com mesmas coordenadas e nomes diferentes. (setores.bash)
* Converter as coordenadas de uma tabela de setores para o formato cartesiano (setores-cartesianos.bash)
* Gerar uma tabela de setores fechados em formato cartesiano para auxiliar na projeção em aplicativos de análise geográfica (setores-fechados.bash)
* Determinar o contorno da FIR usando uma tabela de setores no formato cartesiano (contorno.bash)
* Determinar quais waypoints estão dentro da FIR (ponto-dentro.bash)

## Exemplos:

#### Organizando a tabela de setores (texto cru):
```
$ ./setores.bash setores
```

#### Para salvar o resultado num arquivo (aplicável a todos os scripts):
```
./setores.bash setores > setores-corrigidos
```
#### Gerando a tabela de setores em coordenadas cartesianas
```
./setores-cartesianos.bash setores-corrigidos
```
#### Determinar o contorno da FIR (saída geográfica):
```
./setores-cartesianos.bash setores-corrigidos > setores-cartesianos
./contorno.bash setores-cartesianos setores-corrigidos
```
#### Determinar quais pontos estão dentro da FIR a partir de um arquivo contendo waypoints (em testes):
```
./contorno.bash setores-cartesianos setores-corrigidos > contorno
./setores-cartesianos.bash contorno > contorno-cartesiano
./ponto-dentro.bash waypoints contorno-cartesiano
```
## Requisitos:

* Ambiente Linux (testado no Ubuntu 22.04)
* python3 + shapely
* Todos os arquivos devem estar em texto cru

## Afazeres:

* Determinar quais aerovias pertencem à FIR, e por onde entram e saem
* Criar scripts para inserção dos resultados na base
