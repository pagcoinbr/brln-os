#!/bin/bash

# Solicita o valor local do canal
read -p "Digite o tamanho do canal (min. 50.000 sats): " chansize

# Solicita a taxa de satoshis por vbyte
read -p "Digite a taxa de satoshis por vbyte: " satpervbyte

# Conecta ao nó remoto
lncli connect 03477b0f9679de60b3a803b47294e37b4c14a383564afded973114134623d2ec82@owczcn2vcq5gs5bn5rv3vadtcob3yq34ywnqwglnkejsftdlkc5a4vyd.onion:9735

# Verifica se a conexão foi bem-sucedida
if [ $? -eq 0 ]; then
  echo "Conectado com sucesso ao BRLN HUB."
else
  echo "Falha ao conectar ao BRLN HUB."
  exit 1
fi

# Executa o comando lncli openchannel com os valores fornecidos
lncli openchannel --node_key 03477b0f9679de60b3a803b47294e37b4c14a383564afded973114134623d2ec82 --local_amt $chansize --sat_per_vbyte $satpervbyte

# Verifica se o comando foi executado com sucesso
if [ $? -eq 0 ]; then
  echo "Canal aberto com sucesso!"
else
  echo "Falha ao abrir o canal."
fi
