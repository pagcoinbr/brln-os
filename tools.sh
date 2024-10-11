#!/bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 07/10/2024

# Define as variáveis
GITHUB_CRIPTOSHARK=https://github.com/cryptosharks131/lndg.git
LNDG_DIR=/home/admin/lndg
VERSION_THUB=0.13.31
read -sp "Digite a senha para ThunderHub: " senha
read -p "Digite o alias do seu node: " nome_do_seu_node

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Atualiza e instala o Node.js
curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
sudo apt-get install nodejs -y

# Inicio da instalação do bos (Balance os Satoshis)
# Configura npm para instalação do bos global sem sudo
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'

# Adiciona o caminho do npm global ao PATH no ~/.profile
if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
  echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
fi

# Carrega o perfil atualizado
source ~/.profile

# Instala o Balance of Satoshis (bos)
npm i -g balanceofsatoshis

# Verifica a instalação
bos --version

# Atualiza o arquivo /etc/hosts
sudo bash -c 'echo "127.0.0.1" >> /etc/hosts'

# Ajusta permissões do diretório LND
sudo chown -R $USER:$USER /data/lnd
sudo chmod -R 755 /data/lnd

# Exporta a variável de ambiente BOS_DEFAULT_LND_PATH
export BOS_DEFAULT_LND_PATH=/data/lnd

# Cria o diretório para o node do bos
mkdir -p ~/.bos/$nome_do_seu_node

# Gera os arquivos base64 do certificado TLS e do macaroon admin
base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64

# Cria o arquivo credentials.json com os valores codificados em base64
cert_base64=$(cat /data/lnd/tls.cert.base64)
macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)

bash -c "cat <<EOF > ~/.bos/$nome_do_seu_node/credentials.json
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOF"

# Cria o arquivo bos-telegram.service em /etc/systemd/system/
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

# Atualiza o daemon do systemd
sudo systemctl daemon-reload

# Inicia o serviço bos-telegram
sudo systemctl start bos-telegram.service

# Habilita o serviço para iniciar com o sistema
sudo systemctl enable bos-telegram.service

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Criar link simbólico para a configuração
sudo ln -s /etc/nginx/sites-available/thunderhub-reverse-proxy.conf /etc/nginx/sites-enabled/

# Recarregar a configuração do NGINX
sudo systemctl reload nginx

# Configurar o firewall para permitir tráfego na porta 4002
sudo ufw allow 4002/tcp comment 'allow ThunderHub SSL from anywhere'

# Verifica se os pré-requisitos estão instalados
node -v
npm -v

# Volta ao diretório home
cd

## Inicia a instalação do thunderhub
# Importa a chave GPG do repositório do ThunderHub
curl https://github.com/apotdevin.gpg | gpg --import

# Clona o repositório do ThunderHub na versão especificada e entra no diretório
git clone --branch v$VERSION_THUB https://github.com/apotdevin/thunderhub.git && cd thunderhub

# Verifica a integridade do commit
git verify-commit v$VERSION_THUB

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Instala as dependências do ThunderHub
npm install

# Executa a build do ThunderHub
npm run build

# Inicio da Instalação do Thunderhub
sudo tee /etc/nginx/sites-available/thunderhub-reverse-proxy.conf > /dev/null  <<EOF
server {
  listen 4002 ssl;
  error_page 497 =301 https://$host:$server_port$request_uri;

  location / {
    proxy_pass http://127.0.0.1:3000;
  }
}
EOF

# Verifica a versão instalada no package.json
head -n 3 /home/admin/thunderhub/package.json | grep version

# Copiar o modelo do ficheiro de configuração
cp .env .env.local

# Editar a linha 51 do arquivo .env.local para incluir a configuração desejada
# Usando sed para substituir a linha 51
sed -i '51s|.*|ACCOUNT_CONFIG_PATH="/home/admin/thunderhub/thubConfig.yaml"|' .env.local

# Cria a configuração da conta
# Criar um novo arquivo thubConfig.yaml

# Criar ou sobrescrever o arquivo thubConfig.yaml com o conteúdo inicial
bash -c "cat <<EOF > thubConfig.yaml
masterPassword: 'PASSWORD'
accounts:
  - name: 'MiniBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '[E] ThunderHub password'
EOF"

# Usar sed para substituir a senha na linha 7
# Procurar pela palavra "[E] ThunderHub password" e substituir pela senha fornecida
sed -i "7s|\[E\] ThunderHub password|$senha|" thubConfig.yaml

# Cria o serviço systemd para o ThunderHub
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

# Habilita o serviço para iniciar com o sistema e o inicia
sudo systemctl enable thunderhub
sudo systemctl start thunderhub
sudo systemctl reload nginx

# Verifica o status do serviço ThunderHub
sudo systemctl status thunderhub

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Verifica se o git está instalado, caso contrário, instala
if ! command -v git &> /dev/null
then
    echo "Git não encontrado, instalando..."
    sudo apt install git -y
fi

# Volta à home
cd

# Clona o repositório, se ainda não estiver clonado
if [ ! -d "$LNDG_DIR" ]; then
    git clone $GITHUB_CRIPTOSHARK && cd lndg
else
    echo "O repositório já foi clonado."
    cd lndg
fi

# Instala o virtualenv (ou python3-venv) se não estiver instalado
if ! command -v virtualenv &> /dev/null
then
    echo "Instalando virtualenv..."
    sudo apt install virtualenv -y
fi

# Configura o ambiente virtual
virtualenv -p python3 .venv

# Ativa o ambiente virtual e instala as dependências
source .venv/bin/activate
pip install -r requirements.txt
echo 'SUA SENHA DO LNDG ESTÁ SENDO CRIADA ISTO PODE DEMORAR ALGUNS MINUTOS
###APÓS A INSTALAÇÃO VENHA E COPIE A SENHA PARA ACESSAR O LNDG###'

# Executa o script de inicialização e captura a senha gerada
SENHA_LNDG=$(.venv/bin/python initialize.py --whitenoise)

# Cria o service para o backend
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

# Cria o service para o frontend
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

# Recarrega e reinicia os serviços
sudo systemctl daemon-reload
sudo systemctl restart lndg-controller.service
sudo systemctl restart lndg.service

# Cria o serviço do lnbits
sudo bash -c 'cat <<EOF > /etc/systemd/system/lnbits.service
[Unit]
Description=LNbits Service
After=network.target

[Service]
ExecStart=/home/admin/.local/bin/poetry run lnbits
WorkingDirectory=/home/admin/lnbits
User=admin
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Volta ao diretório home
cd 

# Instalação do lnbits por script
wget https://raw.githubusercontent.com/lnbits/lnbits/main/lnbits.sh && sudo apt install python3-poetry &&
chmod +x lnbits.sh &&
./lnbits.sh

# Inicia o serviço do lnbits
sudo systemctl enable lnbits.service
sudo systemctl start lnbits.service
echo "Sua senha de primeiro acesso ao lndg é $SENHA_LNDG"
