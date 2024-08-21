#!/bin/bash

# Verifica se a porta 8080 está aberta e ouvindo conexões do LND
sudo ss -tulpn | grep LISTEN | grep lnd | grep 8080

# Permite o tráfego na porta 8080 com o UFW
sudo ufw allow 8080/tcp comment 'allow LND REST from anywhere'

# Navega para o diretório /tmp
cd /tmp

# Define a versão do lndconnect
VERSION=0.2.0

# Baixa o lndconnect
wget https://github.com/LN-Zap/lndconnect/releases/download/v$VERSION/lndconnect-linux-amd64-v$VERSION.tar.gz

# Descompacta o arquivo baixado
tar -xvf lndconnect-linux-amd64-v$VERSION.tar.gz

# Move o binário do lndconnect para /usr/local/bin/
sudo install -m 0755 -o root -g root -t /usr/local/bin lndconnect-linux-amd64-v$VERSION/lndconnect

echo "Instalação do lndconnect concluída. Tire o zoom do terminal com <Ctrl + -> pelo menos 6x e depois execute: lndconnect --host=<0.0.0.0> --port=8080 --nocert, trocando o ip 0.0.0.0 pelo seu ip local. Depois basta escanear o qr code com o Zeus Wallet App para se conectar."
