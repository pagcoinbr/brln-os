#!/bin/bash

# Navega para o diretório temporário
cd /tmp

# Define a versão do Bitcoin Core
VERSION=27.1

# Baixa os binários e assinaturas
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc

# Verifica o checksum
sha256sum --ignore-missing --check SHA256SUMS

# Importa as chaves GPG dos mantenedores do Bitcoin Core
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done

# Verifica a assinatura das checksums
gpg --verify SHA256SUMS.asc

# Descompacta o arquivo tar
tar -xvf bitcoin-$VERSION-x86_64-linux-gnu.tar.gz

# Instala os binários
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$VERSION/bin/bitcoin-cli bitcoin-$VERSION/bin/bitcoind

# Verifica a instalação
bitcoind --version

# Remove os arquivos de instalação temporários
sudo rm -r bitcoin-$VERSION bitcoin-$VERSION-x86_64-linux-gnu.tar.gz SHA256SUMS SHA256SUMS.asc

sudo adduser admin debian-tor

# Cria a pasta de dados do Bitcoin
mkdir /data/bitcoin

# Muda a propriedade da pasta de dados para o usuário admin
sudo chown admin:admin /data/bitcoin

# Cria o link simbólico para o diretório de configuração do Bitcoin
ln -s /data/bitcoin /home/admin/.bitcoin

# Navega para o diretório de configuração do Bitcoin
cd .bitcoin

# Baixa o script de autenticação RPC
wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
