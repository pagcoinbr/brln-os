#!/bin/bash

# Define as variáveis da URL do repositório do Tor
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
LND_VERSION=0.18.3
MAIN_DIR=/data
LN_DDIR=/data/lnd
LNDG_DIR=/home/admin/lndg
VERSION_THUB=0.13.31
USER=admin
LND_CONF="/data/lnd/lnd.conf"
APACHE_CONF="/etc/apache2/sites-enabled/000-default.conf"
HTML_SRC=~/brlnfullauto/html
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
SERVICES="/home/admin/brlnfullauto/services"
USER_HOME="/home/admin"
LNBITS_DIR="/home/admin/lnbits"
POETRY_BIN="$USER_HOME/.local/bin/poetry"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

update_and_upgrade() {
# Atualizar sistema e instalar Apache + módulos
sudo apt update && sudo apt full-upgrade -y
sudo apt install apache2 -y
sudo a2enmod cgid dir
sudo systemctl restart apache2

# Criar diretórios e mover arquivos
sudo mkdir -p "$CGI_DST"
sudo rm -f "$WWW_HTML/"*.html
sudo rm -f "$WWW_HTML"/*.png
sudo rm -f "$CGI_DST/"*.sh
sudo cp "$HTML_SRC/"*.html "$WWW_HTML/"
sudo cp "$HTML_SRC"/*.png "$WWW_HTML/"
sudo cp "$HTML_SRC/cgi-bin/"*.sh "$CGI_DST/"

# Corrigir permissões de execução
sudo chmod +x "$CGI_DST"/*.sh
for script in "$CGI_DST"/*.sh; do
  sudo chmod +x "$script"
done

# Configurar o Apache para permitir CGI no diretório correto
if ! grep -q 'Directory "/usr/lib/cgi-bin"' "$APACHE_CONF"; then
  echo "Adicionando bloco de configuração CGI ao Apache..."
  sudo sed -i '/<\/VirtualHost>/i \
<Directory "/usr/lib/cgi-bin">\n\
  AllowOverride None\n\
  Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch\n\
  Require all granted\n\
  AddHandler cgi-script .sh\n\
</Directory>\n' "$APACHE_CONF"
else
  echo "Bloco de configuração CGI já existe no Apache."
fi

# Gerar sudoers dinâmico com todos os scripts .sh do cgi-bin
echo "Atualizando permissões sudo para www-data nos scripts do CGI..."

SCRIPT_LIST=$(find /usr/lib/cgi-bin/ -maxdepth 1 -type f -name "*.sh" | sort | paste -sd ", " -)

if [ -n "$SCRIPT_LIST" ]; then
  sudo tee /etc/sudoers.d/www-data-scripts > /dev/null <<EOF
www-data ALL=(ALL) NOPASSWD: $SCRIPT_LIST
EOF
  echo "Permissões atualizadas com sucesso!"
else
  echo "Nenhum script encontrado no diretório /usr/lib/cgi-bin/. Verifique se os scripts estão no local correto."
fi


# Abre a posta 80 no UFW
if ! sudo ufw status | grep -q "80/tcp"; then
  echo "Abrindo a porta 80 no UFW..."
  sudo ufw allow from 192.168.0.0/24 to any port 80 proto tcp comment 'allow Apache from local network'
else
  echo "A porta 80 já está aberta no UFW."
fi
echo "✅ Interface web do node Lightning instalada com sucesso!"
}

create_main_dir() {
  sudo mkdir $MAIN_DIR
  sudo chown admin:admin $MAIN_DIR
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow from 192.168.0.0/24 to any port 22 proto tcp comment 'allow SSH from local network'
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

configure_lnd() {
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
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo cp $SERVICES/lnd.service /etc/systemd/system/lnd.service
if [[ $use_brlnd == "yes" ]]; then
  create_wallet
if [ -f /data/lnd/password.txt ]; then
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
else
  echo -e "${RED}Erro: Arquivo de senha não encontrado.${NC}"
  exit 1
fi
else
  echo -e "${RED}Você escolheu não usar o bitcoind remoto da BRLN!${NC}"
  echo -e "${YELLOW}Agora Você irá criar sua ${RED}FRASE DE 24 PALAVRAS${YELLOW} Você precisa aguardar seu bitcoin core sincronizar para prosseguir com a instalação, este processo pode demorar de 3 a 7 dias, dependendo do seu hardware.${NC}"
  echo -e "${YELLOW}Para acompanhar a sincronização do bitcoin core, use o comando ${RED} journalctl -fu bitcoind ${YELLOW}. Ao atingir 100%, você deve iniciar este programa novamente e escolher a opção ${RED}2 ${YELLOW}mais uma vez. ${NC}"
  echo -e "${YELLOW}Apenas após o termino deste processo, você pode prosseguir com a instalação do lnd, caso contrário você receberá um erro na criação da carteira.${NC}"
  read -p "Seu bitcoin core já está sincronizado? (yes/no): " sync_choice
  if [[ $sync_choice == "yes" ]]; then
  echo -e "${GREEN} Você escolheu que o bitcoin core já está sincronizado! ${NC}"
  toogle_on >> ~/brlnfullauto/install.log 2>&1
  create_wallet
if [ -f /data/lnd/password.txt ]; then
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
else
  echo -e "${RED}Erro: Arquivo de senha não encontrado.${NC}"
  exit 1
fi
fi
fi
}

create_wallet () {
  ln -s "$LN_DDIR" /home/admin/.lnd
  sudo chmod -R g+X $LN_DDIR
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  echo -e "${YELLOW}############################################################################################### ${NC}"
  echo -e "${YELLOW}Agora Você irá criar sua ${RED}FRASE DE 24 PALAVRAS${YELLOW}, digite a senha de desbloqueio do lnd, depois repita mais 2x para registra-la no lnd e pressione 'n' para criar uma nova carteira. ${NC}" 
  echo -e "${YELLOW}apenas pressione ${RED}ENTER${YELLOW} quando questionado se quer adicionar uma senha a sua frase de 24 palavras.${NC}" 
  echo -e "${YELLOW}AVISO!: Anote sua frase de 24 palavras com ATENÇÃO, AGORA! ${RED}Esta frase não pode ser recuperada no futuro se não for anotada agora. ${NC}" 
  echo -e "${RED}Se voce não guardar esta informação de forma segura, você pode perder seus fundos depositados neste node, permanentemente!!!${NC}"
  echo -e "${YELLOW}############################################################################################### ${NC}"
  read -p "Digite sua senha do lnd(Lghtning Daemon): " password
  
  sudo touch /data/lnd/password.txt
  sudo chown admin:admin /data/lnd/password.txt
  sudo chmod 600 /data/lnd/password.txt
  cat << EOF > /data/lnd/password.txt
  $password
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable lnd >> install.log 2>&1
  sudo systemctl start lnd
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
sudo cp $SERVICES/bitcoind.service /etc/systemd/system/bitcoind.service
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
sudo cp $SERVICES/bos-telegram.service /etc/systemd/system/bost-elegram.service
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
  npm install
  npm run build
sudo ufw allow from 192.168.0.0/24 to any port 3000 proto tcp comment 'allow ThunderHub SSL from local network'
cp /home/$USER/thunderhub/.env /home/$USER/thunderhub/.env.local
sed -i '51s|.*|ACCOUNT_CONFIG_PATH="/home/admin/thunderhub/thubConfig.yaml"|' /home/$USER/thunderhub/.env.local
bash -c "cat <<EOF > thubConfig.yaml
masterPassword: '$thub_senha'
accounts:
  - name: 'BRLNBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '$thub_senha'
EOF"
sudo cp $SERVICES/thunderhub.service /etc/systemd/system/thunderhub.service
sudo systemctl start thunderhub.service
sudo systemctl enable thunderhub.service
fi
}

install_lndg () {
if [[ -d $LNDG_DIR ]]; then
    echo "LNDG já está instalado."
    else
sudo apt install -y python3-pip python3-venv
sudo ufw allow from 192.168.0.0/24 to any port 8889 proto tcp comment 'allow lndg from local network'
cd
git clone https://github.com/cryptosharks131/lndg.git
cd lndg
sudo apt install -y virtualenv
virtualenv -p python3 .venv
.venv/bin/pip install -r requirements.txt >> ~/brlnfullauto/install.log 2>&1
.venv/bin/pip install whitenoise >> ~/brlnfullauto/install.log 2>&1
.venv/bin/python3 initialize.py --whitenoise >> ~/brlnfullauto/install.log 2>&1
sudo cp $SERVICES/lndg.service /etc/systemd/system/lndg.service
sudo cp $SERVICES/lndg-controller.service /etc/systemd/system/lndg-controller.service
sudo systemctl daemon-reload
sudo systemctl enable lndg-controller.service
sudo systemctl start lndg-controller.service
sudo systemctl enable lndg.service
sudo systemctl start lndg.service
fi
}

lnbits_install() {
# Atualiza e instala dependências básicas
sudo apt install -y pkg-config libsecp256k1-dev libffi-dev build-essential python3-dev git curl

# Instala Poetry (não precisa ativar venv manual)
curl -sSL https://install.python-poetry.org | python3 -
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "/home/$USER/.bashrc"
export PATH="$HOME/.local/bin:$PATH"

# Verifica versão do Poetry
"$POETRY_BIN" self update || true
"$POETRY_BIN" --version

# Clona o repositório LNbits
git clone https://github.com/lnbits/lnbits.git "/home/$USER/lnbits"
sudo chown -R admin:admin "/home/$USER/lnbits"

# Entra no diretório e instala dependências com Poetry
cd "/home/$USER/lnbits"
git checkout main
"$POETRY_BIN" install

# Copia o arquivo .env e ajusta a variável LNBITS_ADMIN_UI
cp .env.example .env
sed -i 's/LNBITS_ADMIN_UI=.*/LNBITS_ADMIN_UI=true/' .env

# Criar o script de inicialização dinâmico
cat > "/home/$USER/start-lnbits.sh" <<EOF
#!/bin/bash
cd /home/$USER/lnbits
export PATH="\$HOME/.local/bin:\$PATH"
exec $POETRY_BIN run lnbits --port 5000 --host 0.0.0.0
EOF

# Torna o script executável
chmod +x "/home/$USER/start-lnbits.sh"

# Configurações do lnbits no ufw
sudo ufw allow from 192.168.0.0/24 to any port 5000 proto tcp comment 'allow LNbits from local network'

# Configura systemd
sudo cp $SERVICES/lnbits.service /etc/systemd/system/lnbits.service

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
# 2️⃣ Aguarda a autenticação do Tailscale
  for i in {20..1}; do
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
    touch tailscale_qr.log # cria o log do QR code
    echo "🔗 QR Code salvo em tailscale_qr.log"
    echo "$url" | qrencode -t ANSIUTF8 >> tailscale_qr.log 2>&1
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
        rm -f "$file" >> /dev/null 2>&1
        echo "Deleted: $file"
      else
        echo "File not found: $file" >> /dev/null 2>&1
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

manutencao_script () {
  # Executa o script de manutenção
lnd_update () {
  cd /tmp
LND_VERSION=$(curl -s https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep -oP '"tag_name": "\Kv[0-9]+\.[0-9]+\.[0-9]+(?=-beta)')
echo "$LND_VERSION"
{
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/lnd-linux-amd64-$LND_VERSION-beta.tar.gz
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-$LND_VERSION-beta.txt.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-$LND_VERSION-beta.txt
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-roasbeef-$LND_VERSION-beta.sig.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-roasbeef-$LND_VERSION-beta.sig
    sha256sum --check manifest-$LND_VERSION-beta.txt --ignore-missing
    curl -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
    gpg --verify manifest-roasbeef-$LND_VERSION-beta.sig manifest-$LND_VERSION-beta.txt
    tar -xzf lnd-linux-amd64-$LND_VERSION-beta.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-$LND_VERSION-beta/lnd lnd-linux-amd64-$LND_VERSION-beta/lncli
    sudo rm -r lnd-linux-amd64-$LND_VERSION-beta lnd-linux-amd64-$LND_VERSION-beta.tar.gz manifest-roasbeef-$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots
    sudo systemctl restart lnd
    cd
} &> /dev/null &
echo "Atualizando LND... Por favor, aguarde."
wait
  echo "LND atualizado!"
}

bitcoin_update () {
  cd /tmp
VERSION=$(curl -s https://bitcoincore.org/en/download/ | grep -oP 'bitcoin-core-\K[0-9]+\.[0-9]+' | head -n1)
echo "$VERSION"
{
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
    sudo systemctl restart bitcoind
    cd
} &> /dev/null &
echo "Atualizando Bitcon Core... Por favor, aguarde."
wait
  echo "Bitcoin Core atualizado!"
}

thunderhub_update () {
  read -p "Deseja atualizar o Thunderhub para qual versão? (Ex: 0.13.0) " THUB_VERSION
  sudo systemctl stop thunderhub
  cd
  cd thunderhub
  git pull https://github.com/apotdevin/thunderhub.git $THUB_VERSION
  npm install
  npm run build
  sudo systemctl start thunderhub
  echo "Thunderhub atualizado!"
head -n 3 /home/admin/thunderhub/package.json | grep version
}

lndg_update () {
  cd
  cd /home/admin/lndg
  sudo systemctl stop lndg.service
  sudo systemctl stop lndg-controller.service
  git stash
  git pull
  .venv/bin/python manage.py migrate
  sudo systemctl daemon-reload
  sudo systemctl start lndg.service
  sudo systemctl start lndg-controller.service
    echo "LNDg atualizado!"
  }

lnbits_update () {
  cd /home/admin/lnbits
  sudo systemctl stop lnbits
  git stash
  git pull
  poetry self update
  poetry install --only main
  sudo systemctl daemon-reload
  sudo systemctl start lnbits
    echo "LNbits atualizado!"
  }

thunderhub_uninstall () {
  sudo systemctl stop thunderhub
  sudo systemctl disable thunderhub
  sudo rm -rf /home/admin/thunderhub
  sudo rm -rf /etc/systemd/system/thunderhub.service
  sudo rm -rf /etc/nginx/sites-available/thunderhub-reverse-proxy.conf
  echo "Thunderhub desinstalado!"
}

lndg_unninstall () {
  sudo systemctl stop lndg.service
  sudo systemctl disable lndg.service
  sudo systemctl stop lndg-controller.service
  sudo systemctl disable lndg-controller.service
  sudo rm -rf /home/admin/lndg
  sudo rm -rf /etc/systemd/system/lndg.service
  sudo rm -rf /etc/systemd/system/lndg-controller.service
  sudo rm -rf /etc/nginx/sites-available/lndg-reverse-proxy.conf
  echo "LNDg desinstalado!"
}

lnbits_unninstall () {
  sudo systemctl stop lnbits
  sudo systemctl disable lnbits
  sudo rm -rf /home/admin/lnbits
  sudo rm -rf /etc/systemd/system/lnbits.service
  sudo rm -rf /etc/nginx/sites-available/lnbits-reverse-proxy.conf
  echo "LNbits desinstalado!"
}

pacotes_do_sistema () {
  sudo apt update && sudo apt upgrade -y
  sudo systemctl reload tor
  echo "Os pacotes do sistema foram atualizados! Ex: Tor + i2pd + PostgreSQL"
}

menu_manutencao() {
  echo "Escolha uma opção:"
  echo "1) Atualizar o LND"
  echo "2) Atualizar o Bitcoind ATENÇÃO"
  echo "Antes de atualizar o Bitcoind, leia as notas de atualização"
  echo "3) Atualizar o Thunderhub"
  echo "4) Atualizar o LNDg"
  echo "5) Atualizar o LNbits"
  echo "6) Atualizar os pacotes do sistema"
  echo "7) Desinstalar Thunderhub"
  echo "8) Desinstalar LNDg"
  echo "9) Desinstalar LNbits"
  echo "0) Sair"
  read -p "Opção: " option

  case $option in
    1)
      lnd_update
      ;;
    2)
      bitcoin_update
      ;;
    3)
      thunderhub_update
      ;;
    4)
      lndg_update
      ;;
    5)
      lnbits_update
      ;;
    6)
      pacotes_do_sistema
      ;;
    7)
      thunderhub_uninstall
      ;;
    8)
      lndg_unninstall
      ;;
    9)
      lnbits_unninstall
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

lnd --version
bitcoin-cli --version
menu_manutencao
}	

simple_lnwallet () {
  if [[ -f ./simple-lnwallet ]]; then
    echo "O binário simple-lnwallet já existe."
  else
    echo "O binário simple-lnwallet não foi encontrado. Baixando..."
    wget https://github.com/jvxis/simple-lnwallet-go/releases/download/v.0.0.1/simple-lnwallet >> install.log 2>&1
    chmod +x simple-lnwallet
    sudo apt install xxd -y
  fi
  echo
  echo -e "${YELLOW}📝 Copie o conteúdo do arquivo macaroon.hex e cole no campo macaroon:${NC}"
  xxd -p ~/.lnd/data/chain/bitcoin/mainnet/admin.macaroon | tr -d '\n' > ~/brlnfullauto/macaroon.hex
  cat ~/brlnfullauto/macaroon.hex
  rm -f ~/brlnfullauto/macaroon.hex
  echo
  echo
  echo -e "${YELLOW}📝 Copie o conteúdo do arquivo tls.hex e cole no campo tls:${NC}" 
  xxd -p ~/.lnd/tls.cert | tr -d '\n' > ~/brlnfullauto/tls.hex
  cat ~/brlnfullauto/tls.hex
  rm -f ~/brlnfullauto/tls.hex
  echo
  echo
  echo -e "${YELLOW} Acesse o endereço de IP do seu nó:${NC}"
  echo -e "${YELLOW} http://<IP_DO_SEU_NODE>:<PORTA>${NC}"
  if [[ -f ~/brlnfullauto/services/simple-lnwallet.service ]]; then
    echo "O serviço simple-lnwallet já existe."
    echo "Voce deseja sobrescrever o serviço? (yes/no)"
    read -r lnsimplewallet_service_response
    if [[ "$lnsimplewallet_service_response" == "yes" ]]; then
      sudo rm -f /etc/systemd/system/simple-lnwallet.service
      sudo cp ~/brlnfullauto/services/simple-lnwallet.service /etc/systemd/system/simple-lnwallet.service
    else
      echo "O serviço simple-lnwallet não foi sobrescrito."
    fi
  else
    echo "O serviço simple-lnwallet não foi encontrado. Criando..."
    sudo rm -f /etc/systemd/system/simple-lnwallet.service
    sudo mv ~/brlnfullauto/services/simple-lnwallet.service /etc/systemd/system/simple-lnwallet.service
    if [[ $? -eq 0 ]]; then
      echo "✅ Serviço simple-lnwallet sobrescrito com sucesso!"
    else
      echo "❌ Erro ao sobrescrever o serviço simple-lnwallet."
    fi
  fi
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl enable simple-lnwallet
  sudo systemctl start simple-lnwallet
    # Extrair a porta do comando systemctl status e exibir para o usuário
  PORT=$(sudo systemctl status simple-lnwallet.service | grep -oP 'porta :\K[0-9]+')
  touch ~/brlnfullauto/html/simple-lnwallet-porta.txt
  echo $PORT >> ~/brlnfullauto/html/simple-lnwallet-porta.txt
  if [[ -n "$PORT" ]]; then
    echo -e "${YELLOW} Acesse o endereço de IP do seu nó:${NC}"
    echo -e "${YELLOW} http://<IP_DO_TAILSCALE>:<PORTA>${NC}"
    echo -e "${YELLOW}🚀 O Simple LN Wallet está rodando na porta:${NC} ${GREEN}$PORT${NC}"
  else
    echo -e "${RED}❌ Não foi possível determinar a porta do Simple LN Wallet.${NC}"
  fi
}

submenu_opcoes() {
  echo -e "${CYAN}🔧 Mais opções disponíveis:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- 🏠 Trocar para o bitcoin local."
  echo -e "   ${GREEN}2${NC}- ☁️ Trocar para o bitcoin remoto."
  echo -e "   ${GREEN}3${NC}- 🔴 Atualizar e desinstalar programas."
  echo -e "   ${GREEN}4${NC}- 🚀 Instalar Simple LNWallet."
  echo -e "   ${RED}0${NC}- Voltar ao menu principal"
  echo

  read -p "👉 Digite sua escolha: " suboption

  case $suboption in
    1)
      echo -e "${YELLOW}🏠 🔁 Trocar para o bitcoin local...${NC}"
      toogle_on
      echo -e "${GREEN}✅ Serviços reiniciados!${NC}"
      submenu_opcoes
      ;;
    2)
      echo -e "${YELLOW}🔁 ☁️ Trocar para o bitcoin remoto...${NC}"
      toogle_off
      echo -e "${GREEN}✅ Atualização concluída!${NC}"
      submenu_opcoes
      ;;
    3)
      manutencao_script
      ;;
    4)
      echo -e "${CYAN}🚀 Instalando Simple LNWallet...${NC}"
      simple_lnwallet
      echo -e "${GREEN}✅ Simple LNWallet instalado com sucesso!${NC}"
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

ip_finder () {
  ip_local=$(hostname -I | awk '{print $1}')
}  

menu() {
  echo
  echo
  echo -e "${CYAN}🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟${NC}"
  echo
  echo -e "${YELLOW}⚡ Este Sript Instalará um Node Lightning Standalone${NC}"
  echo -e "  ${GREEN}🛠️ Bem Vindo ao Seu Novo Banco, Ele é BRASILEIRO. ${NC}"
  echo
  echo -e "${YELLOW} Acesse seu nó usando o IP no navegador:${RED} $ip_local${NC}"
  echo
  echo -e "${YELLOW}📝 Escolha uma opção:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- Instalar Interface Gráfica & Interface de Rede"
  echo -e "   ${GREEN}2${NC}- Instalar LND & Criar Carteira"
  echo -e "   ${GREEN}3${NC}- Instalar Bitcoin Core"
  echo
  echo -e "${YELLOW}${NC} Estas São as Opções de Instalação de Aplicativos de Administração:"
  echo
  echo -e "   ${GREEN}4${NC}- Instalar Balance of Satoshis (Exige LND)"
  echo -e "   ${GREEN}5${NC}- Instalar Thunderhub (Exige LND)"
  echo -e "   ${GREEN}6${NC}- Instalar Lndg (Exige LND)"
  echo -e "   ${GREEN}7${NC}- Instalar LNbits"
  echo -e "   ${GREEN}8${NC}- Instalar Tailscale VPN"
  echo -e "   ${GREEN}9${NC}- Mais opções"
  echo -e "   ${RED}0${NC}- Sair"
  echo 
  echo -e "${GREEN} v0.7.1 beta${NC}"
  echo
  read -p "👉 Digite sua escolha: " option

  case $option in
    1)
      echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
      touch ~/brlnfullauto/install.log
      chmod +w ~/brlnfullauto/install.log
      echo -e "${YELLOW}✅ A instalação será executada em segundo plano.${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
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
      clear
      echo -e "${GREEN}✅ Instalação da interface e gráfica e interface de rede concluída!${NC}"
      menu      
      ;;
    2)
      echo -e "${CYAN}🚀 Iniciando a instalação BTC + LND...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW} instalando o lnd...${NC}"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco...${NC}"
      download_lnd >> install.log 2>&1
      clear
      configure_lnd
      menu
      ;;
    3)
      echo -e "${YELLOW} instalando o bitcoind...${NC}"
      read -p "Escolha sua senha do Bitcoin Core: " "rpcpsswd"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco...${NC}  "
      install_bitcoind >> install.log 2>&1
      clear
      echo -e "${GREEN}✅ Sua instalação do bitcoin core foi bem sucedida!${NC}"
      menu
      ;;
    4)
      echo -e "${CYAN}🚀 Instalando Balance of Satoshis...${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco...${NC}  "
      install_bos >> install.log 2>&1
      clear
      echo -e "${GREEN}✅ Balance of Satoshis instalado com sucesso!${NC}"
      menu
      ;;
    5)
      read -p "Digite a senha para ThunderHub: " thub_senha
      echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      install_thunderhub >> install.log 2>&1
      clear
      echo -e "${GREEN}✅ ThunderHub instalado com sucesso!${NC}"
      menu
      ;;
    6)
      echo -e "${CYAN}🚀 Instalando LNDG...${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      install_lndg >> install.log 2>&1
      clear
      echo -e "${YELLOW}📝 Para acessar o LNDG, use a seguinte senha:${NC}"
      echo
      cat ~/lndg/data/lndg-admin.txt
      echo
      echo
      echo -e "${YELLOW}📝 Você deve mudar essa senha ao final da instalação."
      echo -e "${GREEN}✅ LNDG instalado com sucesso!${NC}"
      menu
      ;;
    7)
      echo -e "${CYAN}🚀 Instalando LNbits...${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      echo -e "${YELLOW} 🕒 Isso pode demorar um pouco... ${NC}"
      lnbits_install >> install.log 2>&1
      clear
      echo -e "${GREEN}✅ LNbits instalado com sucesso!${NC}"
      menu
      ;;
    8)
      echo -e "${CYAN}🚀 Instalando Tailscale VPN...${NC}"
      echo -e "${YELLOW}📝 Para acompanhar o progresso abra outro terminal e use:${NC}" 
      echo -e "${GREEN}tail -f ~/brlnfullauto/install.log${NC}"
      tailscale_vpn
      menu
      ;;
    9)
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

ip_finder >> install.log 2>&1
menu