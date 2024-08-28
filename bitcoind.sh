#!/bin/bash

# Como usuário admin, instale as dependências necessárias
sudo apt install python3-dev python3-pip python3-wheel -y

# Crie um ambiente virtual para o OpenTimestamps
python3 -m venv /home/admin/ots-env

# Ative o ambiente virtual
source /home/admin/ots-env/bin/activate

# Instale o cliente OpenTimestamp dentro do ambiente virtual
pip install opentimestamps-client

# Verifique a instalação do cliente OpenTimestamp
ots --version

# Desative o ambiente virtual
deactivate

# Navega para o diretório temporário
cd /tmp

# Define a versão do Bitcoin Core
VERSION=27.1

# Baixa os binários e assinaturas
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.ots

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
sudo mkdir -p /data/bitcoin

# Muda a propriedade da pasta de dados para o usuário admin
sudo chown admin:admin /data/bitcoin

# Cria o link simbólico para o diretório de configuração do Bitcoin
ln -s /data/bitcoin /home/admin/.bitcoin

# Navega para o diretório de configuração do Bitcoin
cd .bitcoin

# Baixa o script de autenticação RPC
wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py

# Solicita ao usuário a senha para o usuário minibolt
echo "Escolha uma senha para o usuário 'minibolt':"
read -s password

# Gera a linha de autenticação RPC
rpcauth=$(python3 rpcauth.py minibolt $password | grep rpcauth)

# Cria o arquivo de configuração bitcoin.conf
sudo bash -c "cat <<EOF > .bitcoin/bitcoin.conf
# MiniBolt: bitcoind configuration
# /home/admin/.bitcoin/bitcoin.conf

# Bitcoin daemon
server=1
txindex=1

# Disable integrated Bitcoin Core wallet
disablewallet=1

# Additional logs
debug=tor
debug=i2p

# Assign to the cookie file read permission
startupnotify=chmod g+r /home/admin/.bitcoin/.cookie

# Disable debug.log
nodebuglogfile=1

# Avoid assuming that a block and its ancestors are valid,
# and potentially skipping their script verification.
# We will set it to 0, to verify all.
assumevalid=0

# Enable all compact filters
blockfilterindex=1

# Serve compact block filters to peers per BIP 157
peerblockfilters=1

# Maintain coinstats index used by the gettxoutsetinfo RPC
coinstatsindex=1

# Network
listen=1

## P2P bind
bind=127.0.0.1

## Proxify clearnet outbound connections using Tor SOCKS5 proxy
proxy=127.0.0.1:9050

## I2P SAM proxy to reach I2P peers and accept I2P connections
i2psam=127.0.0.1:7656

# Connections
$rpcauth

# Initial block download optimizations (set dbcache size in megabytes 
# (4 to 16384, default: 300) according to the available RAM of your device,
# recommended: dbcache=1/2 x RAM available e.g: 4GB RAM -> dbcache=2048)
# Remember to comment after IBD (Initial Block Download)!
dbcache=2048
blocksonly=1
EOF"

# Ajusta as permissões do arquivo de configuração
sudo chown -R admin:admin /home/admin/.bitcoin
sudo chmod 750 /home/admin/.bitcoin
sudo chmod 640 /home/admin/.bitcoin/bitcoin.conf

# Cria o serviço systemd para o bitcoind
sudo bash -c "cat <<EOF > /etc/systemd/system/bitcoind.service
# MiniBolt: systemd unit for bitcoind
# /etc/systemd/system/bitcoind.service

[Unit]
Description=Bitcoin Core Daemon
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/bitcoind -pid=/run/bitcoind/bitcoind.pid \\
                                  -conf=/home/admin/.bitcoin/bitcoin.conf \\
                                  -datadir=/home/admin/.bitcoin
# Process management
####################
Type=exec
NotifyAccess=all
PIDFile=/run/bitcoind/bitcoind.pid

Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

# Directory creation and permissions
####################################
User=admin
Group=admin
RuntimeDirectory=bitcoind
RuntimeDirectoryMode=0710
UMask=0027

# Hardening measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF"

# Habilita e inicia o serviço bitcoind
sudo systemctl daemon-reload
sudo systemctl enable bitcoind
sudo systemctl start bitcoind

# Cria o link simbólico para o diretório de configuração do Bitcoin
ln -s /data/bitcoin /home/admin/.bitcoin

# Verifica o status do serviço bitcoind
sudo systemctl status bitcoind

echo "Instalação do bitcoind concluída com sucesso!"
