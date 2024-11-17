#!/bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 26/09/2024

# Define as variáveis da URL do repositório do Tor
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
# Define a variável de versão do LND
LND_VERSION=0.18.3
MAIN_DIR=/data
LN_DDIR=/data/lnd

update_and_upgrade() {
  sudo apt update && sudo apt full-upgrade -y
}

create_main_dir() {
  [[ ! -d $MAIN_DIR ]] && sudo mkdir $MAIN_DIR
  sudo chown admin:admin $MAIN_DIR
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow 22/tcp comment 'allow SSH from anywhere'
  sudo ufw --force enable
}

install_nginx() {
  sudo apt install -y nginx-full
  sudo openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650
  sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
  sudo bash -c 'cat << EOF > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
  worker_connections 768;
}

http {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:HTTP-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/sites-enabled/*.conf;
}

stream {
  ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
  ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
  ssl_session_cache shared:STREAM-TLS:1m;
  ssl_session_timeout 4h;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_prefer_server_ciphers on;
  include /etc/nginx/streams-enabled/*.conf;
}
EOF'
  sudo mkdir -p /etc/nginx/streams-available /etc/nginx/streams-enabled
  sudo rm /etc/nginx/sites-available/default
  sudo rm /etc/nginx/sites-enabled/default
  sudo nginx -t
  sudo systemctl reload nginx
}

install_tor() {
  sudo apt install -y apt-transport-https
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main" | sudo tee /etc/apt/sources.list.d/tor.list
  sudo su -c "wget -qO- $TOR_GPGLINK | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null"
  sudo apt update && sudo apt install -y tor deb.torproject.org-keyring
  sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/' /etc/tor/torrc
  sudo systemctl reload tor
  if sudo ss -tulpn | grep -q "127.0.0.1:9050" && sudo ss -tulpn | grep -q "127.0.0.1:9051"; then
    echo "Tor está configurado corretamente e ouvindo nas portas 9050 e 9051."
    wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
    sudo apt update && sudo apt install -y i2pd
    echo "i2pd instalado com sucesso."
  else
    echo "Erro: Tor não está ouvindo nas portas corretas."
  fi
}

download_lnd() {
  if [[ ! -d /tmp ]]; then
    mkdir /tmp
  else
    echo "Diretório /tmp já existe."
  fi
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig
  sha256sum --check manifest-v$LND_VERSION-beta.txt --ignore-missing
  curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
  gpg --verify manifest-roasbeef-v$LND_VERSION-beta.sig manifest-v$LND_VERSION-beta.txt
  tar -xzf lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-v$LND_VERSION-beta/lnd lnd-linux-amd64-v$LND_VERSION-beta/lncli
  sudo rm -r lnd-linux-amd64-v$LND_VERSION-beta lnd-linux-amd64-v$LND_VERSION-beta.tar.gz manifest-roasbeef-v$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots
}

configure_lnd() {
  sudo usermod -aG debian-tor admin
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo usermod -a -G debian-tor admin
  sudo mkdir -p $LN_DDIR
  sudo chown -R admin:admin $LN_DDIR
  ln -s $LN_DDIR /home/lnd/.lnd
  ln -s $MAIN_DIR/bitcoin /home/lnd/.bitcoin
  ls -la
  echo "AVISO: Salve a senha que você escolher para a carteira Lightning. Caso contrário, você pode perder seus fundos. A senha deve ter pelo menos 8 caracteres."
  while true; do
    read -p "Escolha uma senha para a carteira Lightning: " password
    echo
    if [ ${#password} -ge 8 ]; then
      break
    else
      echo "A senha deve ter pelo menos 8 caracteres. Tente novamente."
    fi
  done
  echo "$password" > $LN_DDIR/password.txt
  chmod 600 $LN_DDIR/password.txt
  read -p "Digite o alias: " alias
  read -p "Digite o bitcoind.rpcuser: " bitcoind_rpcuser
  read -sp "Digite o bitcoind.rpcpass: " bitcoind_rpcpass
  cat << EOF > $LN_DDIR/lnd.conf
# MiniBolt: lnd configuration
# /data/lnd/lnd.conf

[Application Options]
restlisten=0.0.0.0:8080
# Up to 32 UTF-8 characters, accepts emojis i.e ⚡🧡​ https://emojikeyboard.top/
alias=$alias
# You can choose the color you want at https://www.color-hex.com/
color=#ff9900

# Automatically unlock wallet with the password in this file
wallet-unlock-password-file=/data/lnd/password.txt
wallet-unlock-allow-create=true

# The TLS private key will be encrypted to the node's seed
tlsencryptkey=true

# Automatically regenerate certificate when near expiration
tlsautorefresh=true

# Do not include the interface IPs or the system hostname in TLS certificate
tlsdisableautofill=true

## Channel settings
# (Optional) Minimum channel size. Uncomment and set whatever you want
# (default: 20000 sats)
#minchansize=20000

## High fee environment (Optional)
# (default: 10 sat/byte)
#max-commit-fee-rate-anchors=50
#max-channel-fee-allocation=1

## Communication
accept-keysend=true
accept-amp=true

## Rebalancing
allow-circular-route=true

## Descomente as ultimas duas linhas e mude seu endereço ddns para ativar o modo hibrido.
# specify an interface (IPv4/IPv6) and port (default 9735) to listen on
# listen on IPv4 interface or listen=[::1]:9736 on IPv6 interface
# listen=[::1]:9736
#listen=0.0.0.0:9735
#externalhosts=meu.ddns.no-ip:9735

## Performance
gc-canceled-invoices-on-startup=true
gc-canceled-invoices-on-the-fly=true
ignore-historical-gossip-filters=true

[Bitcoin]
bitcoin.mainnet=true
bitcoin.node=bitcoind

# Fee settings - default LND base fee = 1000 (mSat), fee rate = 1 (ppm)
# You can choose whatever you want e.g ZeroFeeRouting (0,0) or ZeroBaseFee (0,X)
#bitcoin.basefee=1000
#bitcoin.feerate=1

# The CLTV delta we will subtract from a forwarded HTLC's timelock value
# (default: 80)
#bitcoin.timelockdelta=144

[Bitcoind]
bitcoind.rpchost=REDACTED_HOST:8085
bitcoind.rpcuser=$bitcoind_rpcuser
bitcoind.rpcpass=$bitcoind_rpcpass
bitcoind.zmqpubrawblock=tcp://REDACTED_HOST:28332
bitcoind.zmqpubrawtx=tcp://REDACTED_HOST:28333


#[Bitcoind]
#bitcoind.rpchost=127.0.0.1:8332
#bitcoind.rpcuser=bitcoin
#bitcoind.rpcpass=bitcoin
#bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
#bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

[protocol]
protocol.wumbo-channels=true
protocol.option-scid-alias=true
protocol.simple-taproot-chans=true

[wtclient]
## Watchtower client settings
wtclient.active=true

# (Optional) Specify the fee rate with which justice transactions will be signed
# (default: 10 sat/byte)
#wtclient.sweep-fee-rate=10

[watchtower]
## Watchtower server settings
watchtower.active=true

[routing]
routing.strictgraphpruning=true

[bolt]
## Database
# Set the next value to false to disable auto-compact DB
# and fast boot and comment the next line
db.bolt.auto-compact=true
# Uncomment to do DB compact at every LND reboot (default: 168h)
#db.bolt.auto-compact-min-age=0h

## High fee environment (Optional)
# (default: CONSERVATIVE) Uncomment the next 2 lines
#[Bitcoind]
#bitcoind.estimatemode=ECONOMICAL

[tor]
tor.active=true
tor.v3=true
tor.streamisolation=true
EOF
  echo "Configuração concluída com sucesso!"
  ln -s $LN_DDIR /home/admin/.lnd
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
}

create_lnd_service() {
  sudo bash -c 'cat << EOF > /etc/systemd/system/lnd.service
# MiniBolt: systemd unit for lnd
# /etc/systemd/system/lnd.service

[Unit]
Description=Lightning Network Daemon

[Service]
ExecStart=/usr/local/bin/lnd
ExecStop=/usr/local/bin/lncli stop

# Process management
####################
Restart=on-failure
RestartSec=60
Type=notify
TimeoutStartSec=1200
TimeoutStopSec=3600

# Directory creation and permissions
####################################
RuntimeDirectory=lightningd
RuntimeDirectoryMode=0710
User=admin
Group=admin

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF'
  ln -s $LN_DDIR /home/admin/.lnd
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo systemctl enable lnd
  sudo systemctl start lnd
  echo "Execute o comando:" 
  echo "lncli --tlscertpath /data/lnd/tls.cert.tmp create"
  echo "Depois, digite a senha 2x para confirmar e pressione 'n' para criar uma nova cateira, digite o "password" e pressione *enter* para criar uma nova carteira."
  }

install_bitcoin () {
#!/bin/bash

read -p "Escolha e digite seu usuário para o Bitcoin:" bitcoin_user
read -p "Escolha e digite sua senha para o Bitcoin:" bitcoin_pass
sudo apt update && sudo apt full-upgrade -y
cd
cd /tmp
VERSION=28.0
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc
sha256sum --ignore-missing --check SHA256SUMS
curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done
gpg --verify SHA256SUMS.asc
tar -xvf bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$VERSION/bin/bitcoin-cli bitcoin-$VERSION/bin/bitcoind
bitcoind --version
sudo rm -r bitcoin-$VERSION bitcoin-$VERSION-x86_64-linux-gnu.tar.gz SHA256SUMS SHA256SUMS.asc
cd
sudo mkdir -p /data/bitcoin
sudo chown admin:admin /data/bitcoin
ln -s /data/bitcoin /home/bitcoin/.bitcoin
sudo bash -c "cat <<EOF > /home/admin/.bitcoin/bitcoin.conf
# MiniBolt: bitcoind configuration
# /home/bitcoin/.bitcoin/bitcoin.conf

# Bitcoin daemon
server=1
txindex=1

# Disable integrated Bitcoin Core wallet
disablewallet=1

# Additional logs
debug=tor
#debug=i2p

# Assign to the cookie file read permission to the Bitcoin group users
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
#i2psam=127.0.0.1:7656

# Connections
rpcuser=$bitcoin_user
rpcpassword=$bitcoin_pass
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333

# Enable ZMQ blockhash notification (for Fulcrum)
zmqpubhashblock=tcp://127.0.0.1:8433

# Initial block download optimizations (set dbcache size in megabytes 
# (4 to 16384, default: 300) according to the available RAM of your device,
# recommended: dbcache=1/2 x RAM available e.g: 4GB RAM -> dbcache=2048)
# Remember to comment after IBD (Initial Block Download)!
dbcache=2048
blocksonly=1
EOF"
sudo chown -R admin:admin /home/admin/.bitcoin
sudo chmod 750 /home/admin/.bitcoin
sudo chmod 640 /home/admin/.bitcoin/bitcoin.conf
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
sudo systemctl daemon-reload
sudo systemctl enable bitcoind
sudo systemctl start bitcoind
}

install_lnd() {
    download_lnd
  configure_lnd
  create_lnd_service
  echo "LND Instalado!"
}

system_preparation() {
  update_and_upgrade
  create_main_dir
  configure_ufw
  install_nginx
  install_tor
}

menu() {
  echo "Escolha uma opção:"
  echo "1) Preparação do sistema"
  echo "2) Instalação do BRLNBolt"
  echo "3) Instalação do Bitcoin Daemon"
  echo "0) Sair"
  read -p "Opção: " option

  case $option in
    1)
      system_preparation
      menu
      ;;
    2)
      install_lnd
      ;;
    3)
      install_bitcoin
      ;;
    0)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida!"
      ;;
  esac
}

menu
