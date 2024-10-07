#!/bin/bash

# Criar link simbólico para a configuração
if [ ! -f /etc/nginx/sites-enabled/thunderhub-reverse-proxy.conf ]; then
  sudo ln -s /etc/nginx/sites-available/thunderhub-reverse-proxy.conf /etc/nginx/sites-enabled/
fi

# Testar a configuração do NGINX
sudo nginx -t
if [ $? -ne 0 ]; then
  echo "Erro na configuração do NGINX. Verifique o arquivo de configuração."
  exit 1
fi

# Recarregar a configuração do NGINX
sudo systemctl reload nginx

# Configurar o firewall para permitir tráfego na porta 4002
sudo ufw allow 4002/tcp comment 'allow ThunderHub SSL from anywhere'

# Verifica se os pré-requisitos estão instalados
node -v
npm -v

# Volta ao diretório home
cd

# Define a versão do ThunderHub
VERSION=0.13.31

# Importa a chave GPG do repositório do ThunderHub
curl https://github.com/apotdevin.gpg | gpg --import

# Clona o repositório do ThunderHub na versão especificada e entra no diretório
git clone --branch v$VERSION https://github.com/apotdevin/thunderhub.git && cd thunderhub

# Verifica a integridade do commit
git verify-commit v$VERSION

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Instala as dependências do ThunderHub
npm install

# Executa a build do ThunderHub
npm run build

# Verifica a versão instalada no package.json
head -n 3 /home/admin/thunderhub/package.json | grep version

# Copiar o modelo do ficheiro de configuração
cp .env .env.local

# Editar a linha 51 do arquivo .env.local para incluir a configuração desejada
# Usando sed para substituir a linha 51
sed -i '51s|.*|ACCOUNT_CONFIG_PATH="/home/admin/thunderhub/thubConfig.yaml"|' .env.local

# Cria a configuração da conta
# Criar um novo arquivo thubConfig.yaml

# Perguntar a senha ao usuário e armazená-la em uma variável
read -sp "Digite a senha para ThunderHub: " senha
echo

# Criar ou sobrescrever o arquivo thubConfig.yaml com o conteúdo inicial
cat <<EOL > thubConfig.yaml
masterPassword: 'PASSWORD'
accounts:
  - name: 'MiniBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '[E] ThunderHub password'
EOL

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

# Verifica o status do serviço ThunderHub
sudo systemctl status thunderhub
