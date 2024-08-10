#!/bin/bash

# Navega para o diretório /tmp
cd /tmp

# Define a variável de ambiente de versão temporária
VERSION=0.18.0

# Baixa os arquivos necessários
wget https://github.com/lightningnetwork/lnd/releases/download/v$VERSION-beta/lnd-linux-amd64-v$VERSION-beta.tar.gz
wget https://github.com/lightningnetwork/lnd/releases/download/v$VERSION-beta/manifest-v$VERSION-beta.txt.ots
wget https://github.com/lightningnetwork/lnd/releases/download/v$VERSION-beta/manifest-v$VERSION-beta.txt
wget https://github.com/lightningnetwork/lnd/releases/download/v$VERSION-beta/manifest-roasbeef-v$VERSION-beta.sig.ots
wget https://github.com/lightningnetwork/lnd/releases/download/v$VERSION-beta/manifest-roasbeef-v$VERSION-beta.sig

# Verifica o checksum dos arquivos
sha256sum --check manifest-v$VERSION-beta.txt --ignore-missing

# Importa a chave GPG do roasbeef e verifica a assinatura
curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
gpg --verify manifest-roasbeef-v$VERSION-beta.sig manifest-v$VERSION-beta.txt

# Extrai os binários
tar -xzf lnd-linux-amd64-v$VERSION-beta.tar.gz

# Instala os binários
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-v$VERSION-beta/lnd lnd-linux-amd64-v$VERSION-beta/lncli

# Limpa os arquivos temporários
sudo rm -r lnd-linux-amd64-v$VERSION-beta lnd-linux-amd64-v$VERSION-beta.tar.gz manifest-roasbeef-v$VERSION-beta.sig manifest-roasbeef-v$VERSION-beta.sig.ots manifest-v$VERSION-beta.txt manifest-v$VERSION-beta.txt.ots

sudo usermod -aG debian-tor admin
sudo chmod 640 /run/tor/control.authcookie
sudo chmod 750 /run/tor

# Adiciona o usuário lnd aos grupos bitcoin e debian-tor
sudo usermod -a -G bitcoin,debian-tor admin

# Cria o diretório /data/lnd e define as permissões
sudo mkdir -p /data/lnd
sudo chown -R admin:admin /data/lnd
