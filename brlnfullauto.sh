#!/bin/bash

# Define as variáveis da URL do repositório do Tor
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
# Define a variável de versão do LND
LND_VERSION=0.18.3
MAIN_DIR=/data
LN_DDIR=/data/lnd
LNDG_DIR=/home/admin/lndg
VERSION_THUB=0.13.31

update_and_upgrade() {
#read -p "Voce deseja atualizar e fazer upgrade do sistema? (y/n): " choice
if [ "$choice" = "y" ]; then
  sudo apt update && sudo apt full-upgrade -y
else
  echo "Pulando atualização e upgrade do sistema."
fi
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

install_tor() {
    if [[ -d /etc/tor ]]; then
    echo "Tor já está instalado."
    else
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
fi
}

download_lnd() {
  if [[ -d /etc/systemd/system/lnd.service ]]; then
    echo "LND já está instalado."
  else
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig
  sha256sum --check manifest-v$LND_VERSION-beta.txt --ignore-missing
  curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
  gpg --verify manifest-roasbeef-v$LND_VERSION-beta.sig manifest-v$LND_VERSION-beta.txt
  if [ $? -ne 0 ]; then
    echo "####################################################################################### WARNING: GPG SIGNATURE NOT VERIFIED.##################################################################################################################################################"
    exit 1
  fi
  tar -xzf lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-v$LND_VERSION-beta/lnd lnd-linux-amd64-v$LND_VERSION-beta/lncli
  sudo rm -r lnd-linux-amd64-v$LND_VERSION-beta lnd-linux-amd64-v$LND_VERSION-beta.tar.gz manifest-roasbeef-v$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots
fi
}

configure_lnd() {
    if [[ -d /etc/systemd/system/lnd.service ]]; then
    echo "LND já está configurado."
    else
  sudo usermod -aG debian-tor admin
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo usermod -a -G debian-tor admin
  sudo mkdir -p $LN_DDIR
  sudo chown -R admin:admin $LN_DDIR
  ln -s $LN_DDIR /home/admin/.lnd
  cat << EOF > $LN_DDIR/lnd.conf
# MiniBolt: lnd configuration
# /data/admin/lnd.conf

[Application Options]
externalhosts=<ddns_clearnet>:9735
# externalip=<fixed_ip_clearnet>
# Up to 32 UTF-8 characters, accepts emojis i.e ⚡🧡​ https://emojikeyboard.top/
alias=$alias|BR⚡️LN
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
minchansize=1000000

## (Optional) High fee environment settings
#max-commit-fee-rate-anchors=10
#max-channel-fee-allocation=0.5

## Communication
accept-keysend=true
accept-amp=true

## Rebalancing
allow-circular-route=true

## Modo Hibrido
# specify an interface (IPv4/IPv6) and port (default 9735) to listen on
# listen on IPv4 interface or listen=[::1]:9736 on IPv6 interface
listen=0.0.0.0:9735
# listen=[::1]:9736

## Performance
gc-canceled-invoices-on-startup=true
gc-canceled-invoices-on-the-fly=true
ignore-historical-gossip-filters=true
restlisten=0.0.0.0:8080
rpclisten=0.0.0.0:10009

[Bitcoin]
bitcoin.mainnet=true
bitcoin.node=bitcoind

# Fee settings - default LND base fee = 1000 (mSat), fee rate = 1 (ppm)
# You can choose whatever you want e.g ZeroFeeRouting (0,0) or ZeroBaseFee (0,X)
bitcoin.basefee=0
bitcoin.feerate=0
# (Optional) Specify the CLTV delta we will subtract from a forwarded HTLC's timelock value
# (default: 80)
#bitcoin.timelockdelta=80

#[Bitcoind]
#bitcoind.rpchost=127.0.0.1:8332
#bitcoind.rpcuser=
#bitcoind.rpcpass=
#bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
#bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

[Bitcoind]
bitcoind.rpchost=bitcoin.br-ln.com:8085
bitcoind.rpcuser=$bitcoind_rpcuser
bitcoind.rpcpass=$bitcoind_rpcpass
bitcoind.zmqpubrawblock=tcp://bitcoin.br-ln.com:28332
bitcoind.zmqpubrawtx=tcp://bitcoin.br-ln.com:28333

[protocol]
protocol.wumbo-channels=false
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
# If clearnet active, change the 2 lines below to true and false
tor.skip-proxy-for-clearnet-targets=false
tor.streamisolation=true
tor.active=true
tor.v3=true
EOF
  echo "Configuração concluída com sucesso!"
  ln -s $LN_DDIR /home/admin/.lnd
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
fi
}

create_lnd_service() {
if [[ -d /etc/systemd/system/lnd.service ]]; then
    echo "O serviço LND já existe."
    else
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
    until [ ${#password} -ge 8 ]; do
    read -p "Por favor, escolha uma senha para a sua carteira Lightning (mínimo 8 caracteres): " password
    echo
    if [ ${#password} -lt 8 ]; then
      echo "A senha deve ter pelo menos 8 caracteres. Tente novamente."
    fi
  done
  echo "$password" > $LN_DDIR/password.txt
  chmod 600 $LN_DDIR/password.txt
  sudo systemctl enable lnd
  sudo systemctl start lnd
  sleep 10
  echo "###############################################################################################"
  echo "Agora Você irá criar sua senha, digite a senha 3x para confirmar e pressione 'n' para criar uma nova cateira ou "y" para recuperar uma carteira antiga com 24 palavras, digite o "password" caso queira proteger sua frade de 24 palavras com uma senha e pressione *enter* para criar uma nova carteira."
  echo "AVISO!: Anote sua frase de 24 palavras com ATENÇÃO, AGORA! Esta frase não pode ser recuperada se não anotada agora. Caso contrário, você pode perder seus fundos. A senha deve ter pelo menos 8 caracteres."
  echo "###############################################################################################"
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
  while true; do
    read -p "Digite 'yes' para continuar a instalação do seu nó lightning após anotar a frase de 24 palavras: " confirm
    case $confirm in
      [Yy][Ee][Ss])
        break
        ;;
      *)
        echo "Por favor, digite 'yes' para continuar."
        ;;
    esac
  done
  fi
  }

install_bitcoind() {
if [[ -d /data/bitcoin ]]; then
    echo "Bitcoind já está instalado."
    else
    cd /tmp
    VERSION=28.0
    wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
    wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
    wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc
    sha256sum --ignore-missing --check SHA256SUMS
    curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done
    gpg --verify SHA256SUMS.asc
    tar -xzvf bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$VERSION/bin/bitcoin-cli bitcoin-$VERSION/bin/bitcoind
    sudo rm -r bitcoin-$VERSION bitcoin-$VERSION-x86_64-linux-gnu.tar.gz SHA256SUMS SHA256SUMS.asc
    sudo mkdir -p /data/bitcoin
    sudo chown admin:admin /data/bitcoin
    ln -s /data/bitcoin /home/admin/.bitcoin
    cd /home/admin/.bitcoin
    wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
    python3 rpcauth.py minibolt $rpcpsswd > /home/admin/.bitcoin/rpc.auth
    cat << EOF > /home/admin/.bitcoin/bitcoin.conf
# MiniBolt: bitcoind configuration
# /data/bitcoin/bitcoin.conf

# Bitcoin daemon
server=1
txindex=1

# Append comment to the user agent string
uacomment=MiniBolt node

# Suppress a breaking RPC change that may prevent LND from starting up
deprecatedrpc=warnings

# Disable integrated wallet
disablewallet=1

# Additional logs
debug=tor
debug=i2p

# Assign to the cookie file read permission to the Bitcoin group users
rpccookieperms=group

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
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333

whitelist=download@127.0.0.1          # for Electrs
# Initial block download optimizations
EOF
sudo chmod 640 /home/admin/.bitcoin/bitcoin.conf
sudo tee /etc/systemd/system/bitcoind.service > /dev/null << EOF
# MiniBolt: systemd unit for bitcoind
# /etc/systemd/system/bitcoind.service

[Unit]
Description=Bitcoin Core Daemon
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/bitcoind -pid=/run/bitcoind/bitcoind.pid \
                                                                    -conf=/home/admin/.bitcoin/bitcoin.conf \
                                                                    -datadir=/home/admin/.bitcoin \
                                                                    -startupnotify='systemd-notify --ready' \
                                                                    -shutdownnotify='systemd-notify --status="Stopping"'
# Process management
####################
Type=notify
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
EOF
sudo systemctl enable bitcoind
sudo systemctl start bitcoind
sudo ss -tulpn | grep bitcoind
echo "Bitcoind instalado com sucesso!"
fi
}

install_nodejs() {
if [[ -d ~/.npm-global ]]; then
    echo "Node.js já está instalado."
    else
  curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
  sudo apt-get install nodejs -y
fi
}

install_bos() {
if [[ -d ~/.npm-global ]]; then
    echo "Balance of Satoshis já está instalado."
    else
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global'
if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
  echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
fi
  source ~/.profile
  npm i -g balanceofsatoshis
  bos --version
  sudo bash -c 'echo "127.0.0.1" >> /etc/hosts'
  sudo chown -R $USER:$USER /data/lnd
  sudo chmod -R 755 /data/lnd
  export BOS_DEFAULT_LND_PATH=/data/lnd
  mkdir -p ~/.bos/$alias
  base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
  base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64
  cert_base64=$(cat /data/lnd/tls.cert.base64)
  macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)
  bash -c "cat <<EOF > ~/.bos/$alias/credentials.json
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOF"
  sudo bash -c "cat <<EOF > /etc/systemd/system/bos-telegram.service
# Systemd unit for Bos-Telegram Bot
# /etc/systemd/system/bos-telegram.service
# Substitua as variáveis iniciadas com \$ com suas informações
# Não esquece de apagar o \$

[Unit]
Description=bos-telegram
Wants=lnd.service
After=lnd.service

[Service]
ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect <seu_connect_code_aqui>
User=admin
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal
Environment=BOS_DEFAULT_LND_PATH=/data/lnd

[Install]
WantedBy=multi-user.target
EOF"
  sudo systemctl daemon-reload
  sudo systemctl start bos-telegram.service
  sudo systemctl enable bos-telegram.service
fi
}

install_thunderhub() {
if [[ -d ~/thunderhub ]]; then
    echo "ThunderHub já está instalado."
    else
  node -v
  npm -v
  sudo apt update && sudo apt full-upgrade -y
  cd
  curl https://github.com/apotdevin.gpg | gpg --import
  git clone --branch v$VERSION_THUB https://github.com/apotdevin/thunderhub.git && cd thunderhub
  git verify-commit v$VERSION_THUB
  sudo apt update && sudo apt full-upgrade -y
  npm install
  npm run build
sudo ufw allow 3000/tcp comment 'allow ThunderHub SSL from anywhere'
cp .env .env.local
sed -i '51s|.*|ACCOUNT_CONFIG_PATH="/home/admin/thunderhub/thubConfig.yaml"|' .env.local
bash -c "cat <<EOF > thubConfig.yaml
masterPassword: '$senha'
accounts:
  - name: 'MiniBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '$senha'
EOF"
sudo bash -c 'cat <<EOF > /etc/systemd/system/thunderhub.service
# MiniBolt: systemd unit for Thunderhub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub
Requires=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/home/admin/thunderhub
ExecStart=/usr/bin/npm run start

User=admin

# Process management
####################
TimeoutSec=300

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl start thunderhub.service
sudo systemctl enable thunderhub.service
fi
}

install_lndg () {
if [[ -d $LNDG_DIR ]]; then
    echo "LNDG já está instalado."
    else
sudo apt install -y python3-pip python3-venv
sudo ufw allow 8889/tcp comment 'allow lndg SSL from anywhere'
cd
git clone https://github.com/cryptosharks131/lndg.git
cd lndg
sudo apt install -y virtualenv
virtualenv -p python3 .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/pip install whitenoise
.venv/bin/python3 initialize.py --whitenoise
sudo tee /etc/systemd/system/lndg-controller.service > /dev/null <<EOF
[Unit]
Description=Controlador de backend para Lndg

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
ExecStart=$LNDG_DIR/.venv/bin/python3 $LNDG_DIR/controller.py
StandardOutput=append:/var/log/lndg-controller.log
StandardError=append:/var/log/lndg-controller.log
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF
sudo tee /etc/systemd/system/lndg.service > /dev/null  <<EOF
[Unit]
Description=LNDG Django Server
After=network.target

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
WorkingDirectory=$LNDG_DIR
ExecStart=$LNDG_DIR/.venv/bin/python3 $LNDG_DIR/manage.py runserver 0.0.0.0:8889
StandardOutput=append:/var/log/lndg.log
StandardError=append:/var/log/lndg.log
Restart=always
RestartSec=5
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable lndg-controller.service
sudo systemctl start lndg-controller.service
sudo systemctl enable lndg.service
sudo systemctl start lndg.service
fi
}

manage_bitcoin_node() {
    # Caminho do arquivo de configuração e arquivos para apagar
    local LND_CONF="/home/admin/.lnd/lnd.conf"
    local FILES_TO_DELETE=(
        "/home/admin/.lnd/tls.cert"
        "/home/admin/.lnd/tls.key"
        "/home/admin/.lnd/v3_onion_private_key"
    )

    # Função interna para comentar linhas 73 a 78
    comment_lines() {
        sed -i '73,78 s/^/#/' "$LND_CONF"
    }

    # Função interna para descomentar linhas 73 a 78
    decomment_lines() {
        sed -i '73,78 s/^#//' "$LND_CONF"
    }

    # Função interna para apagar os arquivos
    delete_files() {
        for file in "${FILES_TO_DELETE[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file"
                echo "Deleted: $file"
            else
                echo "File not found: $file"
            fi
        done
    }

    # Função interna para reiniciar o serviço LND
    restart_lnd() {
        sudo systemctl restart lnd
        if [ $? -eq 0 ]; then
            echo "LND service restarted successfully."
        else
            echo "Failed to restart LND service."
        fi
    }

    # Exibir o menu para o usuário
    while true; do
        echo "Escolha uma opção:"
        echo "1) Trocar para o Bitcoin Core local"
        echo "2) Trocar para o node Bitcoin remoto"
        echo "3) Sair"
        read -p "Digite sua escolha: " choice

        case $choice in
            1)
                echo "Trocando para o Bitcoin Core local..."
                comment_lines
                delete_files
                restart_lnd
                echo "Trocado para o Bitcoin Core local."
                ;;
            2)
                echo "Trocando para o node Bitcoin remoto..."
                decomment_lines
                delete_files
                restart_lnd
                echo "Trocado para o node Bitcoin remoto."
                ;;
            3)
                echo "Saindo."
                break
                ;;
            *)
                echo "Escolha inválida. Por favor, tente novamente."
                ;;
        esac
        echo ""
    done
}

main() {
read -p "Digite a senha para ThunderHub: " senha
read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
read -p "Digite o bitcoind.rpcuser(BRLN): " "bitcoind_rpcuser"
read -p "Digite o bitcoind.rpcpass(BRLN): " bitcoind_rpcpass
read -p "Escolha sua senha do Bitcoin Core: " rpcpsswd
    update_and_upgrade
    create_main_dir
    configure_ufw
    install_tor
    download_lnd
    configure_lnd
    create_lnd_service
    install_nodejs
    install_bos
    install_thunderhub
    install_lndg
    install_bitcoind
}

menu() {
  echo "🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟"
  echo
  echo "⚡ Este script instalará:"
  echo "  🛠️ Nó Lightning Standalone"
  echo "  🏗️ Bitcoin Core"
  echo "  🖥️ Ferramentas de administração:"
  echo "    - ThunderHub"
  echo "    - Balance of Satoshis (BOS)"
  echo "    - LNDG"
  echo
  echo "📝 Escolha uma opção:"
  echo "   1- Instalação do BRLN Bolt (Tor + LND + BTCd + Ferramentas)"
  echo "   2- Alterne Bitcoin Local/Remoto"
  echo "   3- Instalar Bitcoin Core (Tor + BTCd)"
  echo "   0- Sair"
  echo
  read -p "👉 Digite sua escolha: " option

  case $option in
    1)
      echo "🚀 Iniciando a instalação..."
      main
      ;;
    2)
      manage_bitcoin_node
      ;;
    3)
      read -p "Escolha sua senha do Bitcoin Core: " rpcpsswd
      update_and_upgrade
      create_main_dir
      configure_ufw
      install_tor
      install_bitcoind
      ;;
    0)
      echo "👋 Saindo... Até a próxima!"
      exit 0
      ;;
    *)
      echo "❌ Opção inválida! Tente novamente."
      ;;
  esac
}


menu
