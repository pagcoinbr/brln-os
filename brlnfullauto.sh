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
USER=admin
LND_CONF="/home/admin/.lnd/lnd.conf"
APACHE_CONF="/etc/apache2/sites-enabled/000-default.conf"
HTML_SRC=~/brlnfullauto/html
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
ADM_SCRIPTS="/usr/local/bin"

update_and_upgrade() {
# Atualizar sistema e instalar Apache + módulos
sudo apt update && sudo apt full-upgrade -y
sudo apt install apache2 -y
sudo a2enmod cgid dir
sudo systemctl restart apache2

# Criar diretórios e mover arquivos
sudo mkdir -p "$CGI_DST"
sudo rm -f "$WWW_HTML/index.html"
sudo cp "$HTML_SRC/index.html" "$WWW_HTML/"
sudo cp "$HTML_SRC/config.html" "$WWW_HTML/"
sudo cp "$HTML_SRC"/*.png "$WWW_HTML/"
sudo cp "$HTML_SRC/cgi-bin/status.sh" "$CGI_DST/"
sudo cp "$HTML_SRC/cgi-bin/execute.sh" "$CGI_DST/"
sudo cp "$HTML_SRC/adm_scripts/"*.sh "$ADM_SCRIPTS/"

# Corrigir permissões de execução
sudo chmod +x "$CGI_DST/"*.sh
for script in "$ADM_SCRIPTS"/*.sh; do
  sudo chmod +x "$script"
done

# Configurar o Apache para permitir CGI no diretório
if ! grep -q 'Directory "/var/www/html/cgi-bin"' "$APACHE_CONF"; then
    echo "Adicionando bloco de configuração CGI ao Apache..."
    sudo sed -i '/<\/VirtualHost>/i \
<Directory "/var/www/html/cgi-bin">\n\
    Options +ExecCGI\n\
    AddHandler cgi-script .sh\n\
</Directory>\n' "$APACHE_CONF"
fi

# Permissões de sudo para www-data nos scripts permitidos
sudo tee /etc/sudoers.d/www-data-scripts > /dev/null <<EOF
www-data ALL=(ALL) NOPASSWD: \\
  /usr/local/bin/toogle_bitcoin.sh, \\
  /usr/local/bin/update_lnd.sh, \\
  /usr/local/bin/update_lndg.sh, \\
  /usr/local/bin/update_thunderhub.sh, \\
  /usr/local/bin/update_lnbits.sh, \\
  /usr/local/bin/update_bitcoind.sh, \\
  /usr/local/bin/uninstall.sh, \\
  /usr/local/bin/update_apt.sh
EOF

# Abre a posta 80 no UFW
sudo ufw allow from 192.168.0.0/24 to any port 80 proto tcp comment 'allow Apache from local network'

echo "✅ Interface web do node Lightning instalada com sucesso!"
}

create_main_dir() {
  sudo mkdir $MAIN_DIR
  sudo chown admin:admin $MAIN_DIR
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow 22/tcp comment 'allow SSH from anywhere'
  sudo ufw --force enable
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
}

btc_toogle_func() {
  echo -e "${GREEN}################################################################${NC}"
  echo -e "${GREEN} A seguir você será solicitado a adicionar suas credenciais do ${NC}"
  echo -e "${GREEN} bitcoind.rpcuser e bitcoind.rpcpass, caso você seja membro da BRLN.${NC}"
  echo -e "${YELLOW} Caso você não seja membro, escolha a opção ${RED}não${NC} ${YELLOW}e prossiga.${NC}"
  echo -e "${GREEN}################################################################${NC}"  
  echo
  read -p "Você deseja utilizar o bitcoind da BRLN? (yes/no): " use_brlnd
  if [[ $use_brlnd == "yes" ]]; then
    echo -e "${GREEN} Você escolheu usar o bitcoind remoto da BRLN! ${NC}"
    read -p "Digite o bitcoind.rpcuser(BRLN): " "bitcoind_rpcuser"
    read -p "Digite o bitcoind.rpcpass(BRLN): " "bitcoind_rpcpass"
  elif [[ $use_brlnd == "no" ]]; then
    echo -e "${RED} Você escolheu não usar o bitcoind remoto da BRLN! ${NC}"
  else
    echo -e "${RED} Opção inválida. Por favor, escolha 'yes' ou 'no'. ${NC}"
    exit 1
  fi
}

configure_lnd() {
  sudo usermod -aG debian-tor admin
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo usermod -a -G debian-tor admin
  sudo mkdir -p $LN_DDIR
  sudo chown -R admin:admin $LN_DDIR
  ln -s "$LN_DDIR" /home/admin/.lnd
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
bitcoind.rpchost=REDACTED_HOST:8085
bitcoind.rpcuser=$bitcoind_rpcuser
bitcoind.rpcpass=$bitcoind_rpcpass
bitcoind.zmqpubrawblock=tcp://REDACTED_HOST:28332
bitcoind.zmqpubrawtx=tcp://REDACTED_HOST:28333

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
  ln -s "$LN_DDIR" /home/admin/.lnd
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo systemctl enable lnd
  sudo systemctl start lnd
  for i in {120..1}; do
    echo -ne "Aguardando $i segundos...\r"
    sleep 1
  done
  echo -ne "\n"
}

create_wallet() {
  echo -e "${YELLOW}############################################################################################### ${NC}"
  echo -e "${YELLOW}Agora Você irá criar sua senha, digite a senha 3x para confirmar e pressione 'n' para criar uma nova carteira ${NC}"
  echo -e "${YELLOW}ou 'y' para recuperar uma carteira antiga com 24 palavras, pressione ${RED}ENTER${NC}${YELLOW} ao ser perguntado se ${NC}" 
  echo -e "${YELLOW}quer adicionar sua frase de 24 palavras com uma senha e pressione ${RED}ENTER${NC}${YELLOW} para criar uma nova carteira.${NC}" 
  echo -e "${YELLOW}AVISO!: Anote sua frase de 24 palavras com ATENÇÃO, AGORA! ${NC}" 
  echo -e "${RED}Esta frase não pode ser recuperada se não for anotada agora. ${NC}" 
  echo -e "${RED}Caso contrário, você pode perder seus fundos depositados neste node.${NC}"
  echo -e "${YELLOW}############################################################################################### ${NC}"

  until [ ${#password} -ge 8 ]; do
    read -p "Por favor, escolha uma senha para a sua carteira Lightning (mínimo 8 caracteres): " password
    echo
    if [ ${#password} -lt 8 ]; then
      echo "A senha deve ter pelo menos 8 caracteres. Tente novamente."
    fi
  done

  touch $LN_DDIR/password.txt
  chmod 600 $LN_DDIR/password.txt
  echo "$password" > $LN_DDIR/password.txt
  
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Carteira criada com sucesso!${NC}"
  else
    echo -e "${YELLOW}Caso tenha escolhido por fazer a instalação com o bitcoin core local, é normal receber a mensagem de erro: ${NC}"
    echo -e "${RED}[lncli] could not load global options: could not load TLS cert file: open /data/lnd/tls.cert.tmp: no such file or directory ${NC}"
  fi
}

install_bitcoind() {
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
#Restart=always
TimeoutSec=120
#RestartSec=30
StandardOutput=null
StandardError=journal
Environment=BOS_DEFAULT_LND_PATH=/data/lnd

[Install]
WantedBy=multi-user.target
EOF"
  sudo systemctl daemon-reload
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

lnbits_install() {
# Instalação do LNbits 1.0 automatizada
# Execute como usuário comum (ex: admin), não como root

set -e  # Para o script em caso de erro

# VARIÁVEIS
USER_HOME="/home/admin"
LNBITS_DIR="$USER_HOME/lnbits"
POETRY_BIN="$USER_HOME/.local/bin/poetry"
SYSTEMD_FILE="/etc/systemd/system/lnbits.service"

# Atualiza e instala dependências básicas
sudo apt update
sudo apt install -y pkg-config libsecp256k1-dev libffi-dev build-essential python3-dev git curl

# Instala Poetry (não precisa ativar venv manual)
curl -sSL https://install.python-poetry.org | python3 -
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$USER_HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"

# Verifica versão do Poetry
"$POETRY_BIN" self update || true
"$POETRY_BIN" --version

# Clona o repositório LNbits
git clone https://github.com/lnbits/lnbits.git "$LNBITS_DIR"
sudo chown -R admin:admin "$LNBITS_DIR"

# Entra no diretório e instala dependências com Poetry
cd "$LNBITS_DIR"
git checkout main
"$POETRY_BIN" install

# Copia o arquivo .env e ajusta a variável LNBITS_ADMIN_UI
cp .env.example .env
sed -i 's/LNBITS_ADMIN_UI=.*/LNBITS_ADMIN_UI=true/' .env

# Criar o script de inicialização dinâmico
cat > "$LNBITS_DIR/start-lnbits.sh" <<EOF
#!/bin/bash
cd $LNBITS_DIR
export PATH="\$HOME/.local/bin:\$PATH"
exec $POETRY_BIN run lnbits --port 5000 --host 0.0.0.0
EOF

# Torna o script executável
chmod +x "$LNBITS_DIR/start-lnbits.sh"

# Cria o serviço systemd
sudo tee "$SYSTEMD_FILE" > /dev/null <<EOF
[Unit]
Description=LNbits
After=network.target

[Service]
WorkingDirectory=$LNBITS_DIR
ExecStart=$LNBITS_DIR/start-lnbits.sh
User=admin
Restart=always
TimeoutSec=120
RestartSec=30
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Ativa e inicia o serviço
sudo systemctl daemon-reload
sudo systemctl enable lnbits.service
sudo systemctl start lnbits.service

echo "✅ LNbits instalado e rodando como serviço systemd!"
}

tailscale_vpn () {
# Instalação do Tailscale VPN
curl -fsSL https://tailscale.com/install.sh | sh >> install.log 2>&1
# Instala o qrencode para gerar QR codes
sudo apt install qrencode -y >> install.log 2>&1
log_file="tailscale_up.log"
rm -f "$log_file" # remove log antigo se existir
touch "$log_file" # cria um novo log
# 1️⃣ Roda tailscale up em segundo plano e envia a saída pro log
echo "▶️ Iniciando 'tailscale up' em background..."
(sudo tailscale up > "$log_file" 2>&1) &
wait $!
# 2️⃣ Aguarda a autenticação do Tailscale
  for i in {10..1}; do
    echo -ne "Aguardando $i segundos...\r"
    sleep 1
  done
  echo -ne "\n"
# 3️⃣ Tenta extrair o link de autenticação do log
echo "🔍 Procurando o link de autenticação..."
url=$(grep -Eo 'https://login\.tailscale\.com/[a-zA-Z0-9/]+' "$log_file")
if [[ -n "$url" ]]; then
    echo "✅ Link encontrado: $url"
    echo "📲 QR Code:"
    echo "$url" | qrencode -t ANSIUTF8
else
    echo "❌ Não foi possível encontrar o link no log."
    cat "$log_file"
fi
# 4️⃣ Aguarda a finalização do tailscale up
echo "⏳ Aguardando autenticação para finalizar o comando..."
echo "✅ tailscale up finalizado."
}

toogle_bitcoin () {
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
                toogle_on
                wait
                echo "Trocado para o Bitcoin Core local."
                ;;
            2)
                echo "Trocando para o node Bitcoin remoto..."
                toogle_off
                wait 
                echo "Trocado para o node Bitcoin remoto."
                ;;
            3)
                echo "Saindo."
                menu
                ;;
            *)
                echo "Escolha inválida. Por favor, tente novamente."
                ;;
        esac
        echo ""
    done
}

toogle_on () {
  local LND_CONF="/home/admin/.lnd/lnd.conf"
  local FILES_TO_DELETE=(
    "/home/admin/.lnd/tls.cert"
    "/home/admin/.lnd/tls.key"
    "/home/admin/.lnd/v3_onion_private_key"
  )

  # Função interna para comentar linhas 73 a 78
    sed -i '73,78 s/^/#/' "$LND_CONF"
  # Função interna para apagar os arquivos
    for file in "${FILES_TO_DELETE[@]}"; do
      if [ -f "$file" ]; then
        rm -f "$file"
        echo "Deleted: $file"
      else
        echo "File not found: $file"
      fi
    done
  # Função interna para reiniciar o serviço LND
    sudo systemctl restart lnd
    if [ $? -eq 0 ]; then
      echo "LND service restarted successfully."
    else
      echo "Failed to restart LND service."
    fi
}

toogle_off () {
  local LND_CONF="/home/admin/.lnd/lnd.conf"
  local FILES_TO_DELETE=(
    "/home/admin/.lnd/tls.cert"
    "/home/admin/.lnd/tls.key"
    "/home/admin/.lnd/v3_onion_private_key"
  )

  # Função interna para descomentar linhas 73 a 78
    sed -i '73,78 s/^#//' "$LND_CONF"
  # Função interna para apagar os arquivos
    for file in "${FILES_TO_DELETE[@]}"; do
      if [ -f "$file" ]; then
        rm -f "$file"
        echo "Deleted: $file"
      else
        echo "File not found: $file"
      fi
    done

  # Função interna para reiniciar o serviço LND
    sudo systemctl restart lnd
    if [ $? -eq 0 ]; then
      echo "LND service restarted successfully."
    else
      echo "Failed to restart LND service."
    fi
}

submenu_opcoes() {
  echo -e "${CYAN}🔧 Mais opções disponíveis:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- Reiniciar serviços lnd"
  echo -e "   ${GREEN}2${NC}- Atualizar todos os pacotes do sistema"
  echo -e "   ${GREEN}3${NC}- Ver status dos lnd"
  echo -e "   ${RED}0${NC}- Voltar ao menu principal"
  echo

  read -p "👉 Digite sua escolha: " suboption

  case $suboption in
    1)
      echo -e "${YELLOW}🔁 Reiniciando serviços...${NC}"
      systemctl restart bitcoind lnd
      echo -e "${GREEN}✅ Serviços reiniciados!${NC}"
      submenu_opcoes
      ;;
    2)
      echo -e "${YELLOW}⬆️ Atualizando pacotes...${NC}"
      sudo apt update && sudo apt upgrade -y
      echo -e "${GREEN}✅ Atualização concluída!${NC}"
      submenu_opcoes
      ;;
    3)
      echo -e "${CYAN}📋 Status dos serviços:${NC}"
      systemctl status lnd --no-pager
      submenu_opcoes
      ;;
    0)
      menu
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      submenu_opcoes
      ;;
  esac
}

menu() {
  echo -e "${CYAN}🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟${NC}"
  echo
  echo -e "${YELLOW}⚡ Este script instalará:${NC}"
  echo -e "  ${GREEN}🛠️ Nó Lightning Standalone${NC}"
  echo -e "  ${GREEN}🏗️ Bitcoin Core${NC}"
  echo -e "  ${GREEN}🖥️ Ferramentas de administração:${NC}"
  echo -e "    ${BLUE}- ThunderHub${NC}"
  echo -e "    ${BLUE}- Balance of Satoshis (BOS)${NC}"
  echo -e "    ${BLUE}- LNDG${NC}"
  echo
  echo -e "${YELLOW}📝 Escolha uma opção:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- Instalar Pre-requisitos (Obrigatório para as opções 2-8)"
  echo -e "   ${GREEN}2${NC}- Instalar Bitcoin + Lightning Daemon/LND"
  echo -e "   ${GREEN}3${NC}- Instalar Balance of Satoshis (Exige LND)"
  echo -e "   ${GREEN}4${NC}- Instalar Thunderhub (Exige LND)"
  echo -e "   ${GREEN}5${NC}- Instalar Lndg (Exige LND)"
  echo -e "   ${GREEN}6${NC}- Instalar LNbits"
  echo -e "   ${GREEN}7${NC}- Instalar Tailscale VPN"
  echo -e "   ${GREEN}8${NC}- Mais opções"
  echo -e "   ${RED}0${NC}- Sair"
  echo
  read -p "👉 Digite sua escolha: " option

  case $option in
    1)
      echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
      touch ~/brlnfullauto/install.log
      chmod +w ~/brlnfullauto/install.log
      echo -e "${YELLOW}✅ A instalação será executada em segundo plano.${NC}"
      echo -e "${YELLOW}📝 Acompanhe o progresso usando o comando:"
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
      update_and_upgrade >> install.log 2>&1
      create_main_dir >> install.log 2>&1
      configure_ufw >> install.log 2>&1
      echo -e "${YELLOW}🕒 Isso pode demorar um pouco...${NC}"
      echo -e "${YELLOW}Na pior das hipóteses, até 30 minutos...${NC}"
      echo -e "${RED}Seja paciente!${NC}"
      install_tor >> install.log 2>&1
      install_nodejs >> install.log 2>&1
      wait
      echo -e "${GREEN}✅ Instalação concluída!${NC}"
      menu      
      ;;
    2)
      echo -e "${CYAN}🚀 Iniciando a instalação BTC + LND...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      read -p "Escolha sua senha do Bitcoin Core: " "rpcpsswd"
      echo -e "${YELLOW} Digite a senha do usuário admin caso solicitado.${NC}"
      echo -e "${YELLOW} instalando o bitcoind...${NC}"
      install_bitcoind >> install.log 2>&1
      echo -e "${YELLOW} instalando o lnd...${NC}"
      download_lnd >> install.log 2>&1
      btc_toogle_func
      echo -e "${YELLOW} configurando o lnd...${NC}"
      configure_lnd >> install.log 2>&1
      create_lnd_service >> install.log 2>&1
      create_wallet
      echo -e "${GREEN}✅ Se sua criação de carteira foi bem sucedida, você pode seguir para o próximo passo!${NC}"
      menu
      ;;
    3)
      echo -e "${CYAN}🚀 Instalando Balance of Satoshis...${NC}"
      install_bos >> install.log 2>&1
      echo -e "${GREEN}✅ Balance of Satoshis instalado com sucesso!${NC}"
      menu
      ;;
    4)
      read -p "Digite a senha para ThunderHub: " senha
      echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
      sleep 1
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      install_thunderhub >> install.log 2>&1
      echo -e "${GREEN}✅ ThunderHub instalado com sucesso!${NC}"
      menu
      ;;
    5)
      echo -e "${CYAN}🚀 Instalando LNDG...${NC}"
      sleep 1
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      install_lndg >> install.log 2>&1
      echo -e "${GREEN}✅ LNDG instalado com sucesso!${NC}"
      menu
      ;;
    6)
      echo -e "${CYAN}🚀 Instalando LNbits...${NC}"
      sleep 1
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      lnbits_install >> install.log 2>&1
      echo -e "${GREEN}✅ LNbits instalado com sucesso!${NC}"
      menu
      ;;
    7)
      echo -e "${CYAN}🚀 Instalando Tailscale VPN...${NC}"
      tailscale_vpn
      menu
      ;;
    8)
      submenu_opcoes
      ;;
    0)
      echo -e "${MAGENTA}👋 Saindo... Até a próxima!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      ;;
    esac
  }

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

menu