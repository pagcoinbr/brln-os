#!/bin/bash

# Solicita o alias do node
read -p "Digite o alias do seu node: " nome_do_seu_node

# Atualiza e instala o Node.js
curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
sudo apt-get install nodejs -y

# Configura npm para instalação global sem sudo
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

# Adiciona o caminho do npm global ao PATH no ~/.profile
if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
  echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
fi

# Carrega o perfil atualizado
source ~/.profile

# Instala o Balance of Satoshis (bos)
npm i -g balanceofsatoshis

# Verifica a instalação
bos --version

# Atualiza o arquivo /etc/hosts
sudo bash -c 'echo "127.0.0.1" >> /etc/hosts'

# Ajusta permissões do diretório LND
sudo chown -R $USER:$USER /data/lnd
sudo chmod -R 755 /data/lnd

# Exporta a variável de ambiente BOS_DEFAULT_LND_PATH
export BOS_DEFAULT_LND_PATH=/data/lnd

# Cria o diretório para o node do bos
mkdir -p ~/.bos/$nome_do_seu_node

# Gera os arquivos base64 do certificado TLS e do macaroon admin
base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64

# Cria o arquivo credentials.json com os valores codificados em base64
cert_base64=$(cat /data/lnd/tls.cert.base64)
macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)

cat <<EOF > ~/.bos/$nome_do_seu_node/credentials.json
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOF

# Testa a instalação do bos
bos utxos

echo "Instalação e configuração do Balance of Satoshis (bos) concluída com sucesso!"
