#!/bin/bash

# Solicita o node-key do peer
read -p "Digite o node-key do peer: " peerpubkey

# Solicita o valor local do canal
read -p "Digite o valor local do canal (em satoshis): " chansize

# Solicita a taxa de satoshis por vbyte
read -p "Digite a taxa de satoshis por vbyte: " satpervbyte

# Executa o comando lncli openchannel com os valores fornecidos
lncli openchannel --node-key $peerpubkey --local-amt $chansize --sat_per_vbyte $satpervbyte

# Verifica se o comando foi executado com sucesso
if [ $? -eq 0 ]; then
  echo "Canal aberto com sucesso!"
else
  echo "Falha ao abrir o canal."
fi
