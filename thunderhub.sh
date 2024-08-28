#!/bin/bash

# Configurações do Nginx para ThunderHub

# Cria o arquivo de configuração do Nginx para ThunderHub
sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/thunderhub-reverse-proxy.conf
server {
  listen 4002 ssl;
  error_page 497 =301 https://\$host:\$server_port\$request_uri;

  location / {
    proxy_pass http://127.0.0.1:3000;
  }
}
EOF'

# Cria o link simbólico para ativar o site no Nginx
sudo ln -s /etc/nginx/sites-available/thunderhub-reverse-proxy.conf /etc/nginx/sites-enabled/

# Verifica a configuração do Nginx e recarrega o serviço
sudo nginx -t
sudo systemctl reload nginx

# Permite o tráfego na porta 4002 através do UFW
sudo ufw allow 4002/tcp comment 'allow ThunderHub SSL from anywhere'

# Define a versão do ThunderHub
VERSION=0.13.31

# Importa a chave GPG do repositório do ThunderHub
curl https://github.com/apotdevin.gpg | gpg --import

# Clona o repositório do ThunderHub na versão especificada e entra no diretório
git clone --branch v$VERSION https://github.com/apotdevin/thunderhub.git && cd thunderhub

# Verifica a integridade do commit
git verify-commit v$VERSION

# Corrige vulnerabilidades de pacotes
npm audit fix

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Instala as dependências do ThunderHub
npm install

# Executa a build do ThunderHub
npm run build

# Verifica a versão instalada no package.json
head -n 3 /home/admin/miniboltfullauto/thunderhub/package.json | grep version

# Cria o serviço systemd para o ThunderHub
sudo bash -c 'cat <<EOF > /etc/systemd/system/thunderhub.service
# MiniBolt: systemd unit for ThunderHub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub
Requires=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/home/admin/miniboltfullauto/thunderhub
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

echo "Este ultimo script ainda não foi testado e pode não estar funcional"

echo "Seu node Lightning está pronto, se quiser fazer uma doação para o projeto basta enviar alguns satoshis para o seguinte endereço <bitcreek@pay.br-ln.com>. Boa sorte e boas transações!"

