#!/bin/bash

# Script criado por PagcoinBTC
# Ultima edição: 02/11/2024

# Define as variáveis
LNDG_DIR=/home/admin/lndg
VERSION_THUB=0.13.31

system_update() {
  sudo apt update && sudo apt full-upgrade -y
  lncli connect 03477b0f9679de60b3a803b47294e37b4c14a383564afded973114134623d2ec82@owczcn2vcq5gs5bn5rv3vadtcob3yq34ywnqwglnkejsftdlkc5a4vyd.onion:9735
}

install_nodejs() {
  curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
  sudo apt-get install nodejs -y
  
}

install_bos() {
  read -p "Digite o nome do seu node (sem tags como | BRLN): " nome_do_seu_node
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
  mkdir -p ~/.bos/$nome_do_seu_node
  base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
  base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64
  cert_base64=$(cat /data/lnd/tls.cert.base64)
  macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)
  bash -c "cat <<EOF > ~/.bos/$nome_do_seu_node/credentials.json
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
}

install_thunderhub() {
  node -v
  npm -v
  read -p "Digite a senha para ThunderHub: " senha
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
masterPassword: 'PASSWORD'
accounts:
  - name: 'MiniBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '[E] ThunderHub password'
EOF"
sed -i "7s|\[E\] ThunderHub password|$senha|" thubConfig.yaml
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
}

install_lndg () {
sudo ufw allow 8889/tcp comment 'allow lndg SSL from anywhere'
cd
git clone https://github.com/cryptosharks131/lndg.git
cd lndg
sudo apt install -y virtualenv
virtualenv -p python3 .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/pip install whitenoise
.venv/bin/python initialize.py --whitenoise
sudo tee /etc/systemd/system/lndg-controller.service > /dev/null <<EOF
[Unit]
Description=Controlador de backend para Lndg

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
ExecStart=$LNDG_DIR/.venv/bin/python $LNDG_DIR/controller.py
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
ExecStart=$LNDG_DIR/.venv/bin/python $LNDG_DIR/manage.py runserver 0.0.0.0:8889
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
}

meu_primeiro_canal () {
# Solicita o valor local do canal
read -p "Digite o tamanho do canal (min. 50.000 sats): " chansize

# Solicita a taxa de satoshis por vbyte
read -p "Digite a taxa de satoshis por vbyte: " satpervbyte

# Conecta ao nó remoto
lncli connect 03477b0f9679de60b3a803b47294e37b4c14a383564afded973114134623d2ec82@owczcn2vcq5gs5bn5rv3vadtcob3yq34ywnqwglnkejsftdlkc5a4vyd.onion:9735

# Executa o comando lncli openchannel com os valores fornecidos
lncli openchannel --node_key 03477b0f9679de60b3a803b47294e37b4c14a383564afded973114134623d2ec82 --local_amt $chansize --sat_per_vbyte $satpervbyte

# Verifica se o comando foi executado com sucesso
if [ $? -eq 0 ]; then
  echo "Canal aberto com sucesso!"
else
  echo "Falha ao abrir o canal."
fi
}

main () {
  system_update
  install_nodejs
  install_bos
  install_thunderhub
  install_lndg
}

menu() {
  echo "Escolha uma opção:"
  echo "1) Instalação automática do toolbox"
  echo "2) Abrir canal com a BRLN HUB"
  echo "3) Atualizar pacotes do sistema"
  echo "4) Instalar NodeJS"
  echo "5) Instalar Balance of Satoshis"
  echo "6) Instalar ThunderHub"
  echo "7) Instalar LNDG"
  echo "8) Instalar LNbits (Instável)"
  echo "0) Sair"
  read -p "Opção: " option

  case $option in
    1)
      main
      ;;
    2)
      meu_primeiro_canal
      ;;
    3)
      system_update
      ;;
    4)
      install_nodejs
      ;;
    5)
      install_bos
      ;;
    6)
      install_thunderhub
      ;;
    7)
      install_lndg
      ;;
    8)
      install_lnbits
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
