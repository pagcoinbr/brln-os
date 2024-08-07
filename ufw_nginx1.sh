#!/bin/bash

# Cria o diretório /data
sudo mkdir /data

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
