#!/bin/bash
cd /tmp

# Obter a última versão estável do LND no GitHub
LND_VERSION=$(curl -s https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//; s/-beta//')

echo "Última versão do LND detectada: $LND_VERSION"

{
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig

    sha256sum --check manifest-v$LND_VERSION-beta.txt --ignore-missing
    curl -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
    gpg --verify manifest-roasbeef-v$LND_VERSION-beta.sig manifest-v$LND_VERSION-beta.txt

    tar -xzf lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-v$LND_VERSION-beta/lnd lnd-linux-amd64-v$LND_VERSION-beta/lncli

    sudo rm -r lnd-linux-amd64-v$LND_VERSION-beta \
      lnd-linux-amd64-v$LND_VERSION-beta.tar.gz \
      manifest-roasbeef-v$LND_VERSION-beta.sig \
      manifest-roasbeef-v$LND_VERSION-beta.sig.ots \
      manifest-v$LND_VERSION-beta.txt \
      manifest-v$LND_VERSION-beta.txt.ots

    sudo systemctl restart lnd
    cd
} &> /dev/null &

echo "Atualizando LND para a versão $LND_VERSION... Por favor, aguarde."
wait
echo "✅ LND atualizado para a versão $LND_VERSION com sucesso!"
