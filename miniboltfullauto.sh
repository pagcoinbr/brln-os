#!/bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 26/09/2024

# Define as variáveis da URL do repositório do Tor
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
# Define a variável de versão do LND
LND_VERSION=0.18.3

# Atualiza a lista de pacotes e faz upgrade
sudo apt update && sudo apt full-upgrade -y

# Cria o diretório /data
if [[ -d /data ]]; then
  echo "/data já existe."
else
  sudo mkdir /data
fi

# Muda a propriedade do diretório /data para o usuário admin
sudo chown admin:admin /data

# Modifica o arquivo /etc/default/ufw para desativar o IPv6
sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw

# Desativa o log do ufw
sudo ufw logging off

# Permite conexões SSH na porta 22 de qualquer lugar
sudo ufw allow 22/tcp comment 'allow SSH from anywhere'

# Habilita o ufw
sudo ufw enable

# Instala o nginx-full
sudo apt install nginx-full

# Gera o certificado autoassinado e a chave privada
sudo openssl req -x509 -nodes -newkey rsa:4096 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/CN=localhost" -days 3650

# Faz backup do arquivo de configuração original do Nginx
sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# Cria um novo arquivo de configuração do Nginx
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

# Cria os diretórios streams-available e streams-enabled
sudo mkdir -p /etc/nginx/streams-available /etc/nginx/streams-enabled

# Remove os arquivos de configuração padrão dos sites disponíveis e habilitados
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

# Testa a configuração do Nginx
sudo nginx -t

# Recarrega o Nginx
sudo systemctl reload nginx

# Atualiza a lista de pacotes e faz upgrade
sudo apt update && sudo apt full-upgrade -y

# Instala apt-transport-https
sudo apt install -y apt-transport-https

# Cria o arquivo de repositório do Tor e adiciona o conteúdo
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main
deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main" | sudo tee /etc/apt/sources.list.d/tor.list

# Baixa e instala a chave GPG do repositório Tor
sudo su -c "wget -qO- $TOR_GPGLINK | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null"

# Atualiza a lista de pacotes e instala o Tor e a chave do Tor Project
sudo apt update && sudo apt install -y tor deb.torproject.org-keyring

# Edita o arquivo de configuração do Tor para descomentar a linha ControlPort 9051
sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/' /etc/tor/torrc

# Recarrega o serviço do Tor
sudo systemctl reload tor

# Verifica se o Tor está ouvindo nas portas corretas
if sudo ss -tulpn | grep -q "127.0.0.1:9050" && sudo ss -tulpn | grep -q "127.0.0.1:9051"; then
  echo "Tor está configurado corretamente e ouvindo nas portas 9050 e 9051."
  # Adiciona o repositório e instala o i2pd
  wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
  sudo apt update && sudo apt install -y i2pd
  echo "i2pd instalado com sucesso."
else
  echo "Erro: Tor não está ouvindo nas portas corretas."
fi

# Navega para o diretório /tmp
if [[ ! -d /tmp ]]; then
  mkdir /tmp
  else
  echo "Diretório /tmp já existe."
fi

# Baixa os arquivos necessários
wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/lnd-linux-amd64-v$LND_VERSION-beta.tar.gz
wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt.ots
wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt
wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig.ots
wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig

# Verifica o checksum dos arquivos
sha256sum --check manifest-v$LND_VERSION-beta.txt --ignore-missing

# Importa a chave GPG do roasbeef e verifica a assinatura
curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
gpg --verify manifest-roasbeef-v$LND_VERSION-beta.sig manifest-v$LND_VERSION-beta.txt

# Extrai os binários
tar -xzf lnd-linux-amd64-v$LND_VERSION-beta.tar.gz

# Instala os binários
sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-v$LND_VERSION-beta/lnd lnd-linux-amd64-v$LND_VERSION-beta/lncli

# Limpa os arquivos temporários
sudo rm -r lnd-linux-amd64-v$LND_VERSION-beta lnd-linux-amd64-v$LND_VERSION-beta.tar.gz manifest-roasbeef-v$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots

sudo usermod -aG debian-tor admin
sudo chmod 640 /run/tor/control.authcookie
sudo chmod 750 /run/tor

# Adiciona o usuário lnd aos grupos bitcoin e debian-tor
sudo usermod -a -G debian-tor admin

# Cria o diretório /data/lnd e define as permissões
sudo mkdir -p /data/lnd
sudo chown -R admin:admin /data/lnd

# Cria links simbólicos
ln -s /data/lnd /home/lnd/.lnd
ln -s /data/bitcoin /home/lnd/.bitcoin

# Lista os arquivos e diretórios com detalhes
ls -la

# Instala o PostgreSQL
sudo apt update && sudo apt full-upgrade
sudo install -d /usr/share/postgresql-common/pgdg
sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo apt update && sudo apt install postgresql postgresql-contrib

# Cria o diretório /data/postgresql
if [[ -d /data/postgresdb ]]; then
  echo "/data/postgresdb já existe."
else
  sudo mkdir -p /data/postgresdb/17
  sudo chown -R admin:admin /data/postgresdb
  sudo chmod -R 700 /data/postgresdb
  sudo -u postgres /usr/lib/postgresql/17/bin/initdb -D /data/postgresdb/17
  sudo sed -i "s|^#data_directory =.*|data_directory = '/data/postgresdb/17'|" /etc/postgresql/17/main/postgresql.conf
  sudo systemctl start postgresql
  sudo systemctl enable postgresql
fi

# Cria o usuário admin no PostgreSQL
sudo -u postgres psql -c "CREATE ROLE admin WITH LOGIN CREATEDB PASSWORD 'admin';"

# Exibe aviso ao usuário sobre a senha
echo "AVISO: Salve a senha que você escolher para a carteira Lightning. Caso contrário, você pode perder seus fundos. A senha deve ter pelo menos 8 caracteres."

# Solicita a senha ao usuário
while true; do
    read -p "Escolha uma senha para a carteira Lightning: " password
    echo
    if [ ${#password} -ge 8 ]; then
        break
    else
        echo "A senha deve ter pelo menos 8 caracteres. Tente novamente."
    fi
done

# Salva a senha no arquivo password.txt
echo "$password" > /data/lnd/password.txt

# Define permissões adequadas para o arquivo de senha
chmod 600 /data/lnd/password.txt

# Solicita ao usuário as variáveis necessárias
read -p "Digite o alias: " alias
read -p "Digite o bitcoind.rpcuser: " bitcoind_rpcuser
read -s -p "Digite o bitcoind.rpcpass: " bitcoind_rpcpass

# Cria o arquivo de configuração lnd.conf
cat << EOF > /data/lnd/lnd.conf
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

[db]
## Database
db.backend=postgres

[postgres]
db.postgres.dsn=postgresql://admin:admin@127.0.0.1:5432/lndb?sslmode=disable
db.postgres.timeout=0

## High fee environment setting (Optional)
# (default: CONSERVATIVE) Uncomment the next 2 lines
#[Bitcoind]
#bitcoind.estimatemode=ECONOMICAL

[tor]
tor.active=true
tor.v3=true
tor.streamisolation=true
EOF

echo "Configuração concluída com sucesso!"

# Allow user "admin" to work with LND
ln -s /data/lnd /home/admin/.lnd
sudo chmod -R g+X /data/lnd
sudo chmod 640 /run/tor/control.authcookie
sudo chmod 750 /run/tor

# Cria o arquivo de serviço systemd para o lnd
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

# Allow user "admin" to work with LND
ln -s /data/lnd /home/admin/.lnd
sudo chmod -R g+X /data/lnd
sudo chmod 640 /run/tor/control.authcookie
sudo chmod 750 /run/tor

# Habilita e inicia o serviço lnd
sudo systemctl enable lnd
sudo systemctl start lnd

echo "Execute o comando: lncli --tlscertpath /data/lnd/tls.cert.tmp create, Digite a senha 2x para confirmar e pressione "n" e "enter", para criar uma nova carteira."
