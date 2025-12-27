#!/bin/bash

# Apache Web Server functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

setup_apache_web() {
  echo -e "${GREEN}🌐 Configurando servidor web Apache...${NC}"

  # Instalar Apache se não estiver instalado
  if ! command -v apache2 &> /dev/null; then
    echo "📦 Instalando Apache2..."
    sudo apt update >> /dev/null 2>&1
    sudo apt install apache2 -y >> /dev/null 2>&1 # & spinner
  else
    echo "✅ Apache2 já está instalado."
  fi

  # Parar e desabilitar Next.js frontend se estiver rodando
  if sudo systemctl is-active --quiet brln-frontend 2>/dev/null; then
    echo "⏹️ Parando serviço Next.js frontend..."
    sudo systemctl stop brln-frontend 2>/dev/null || true
    sudo systemctl disable brln-frontend 2>/dev/null || true
  fi

  # Habilitar módulos necessários do Apache
  echo "🔌 Habilitando módulos Apache necessários..."
  sudo a2enmod rewrite >> /dev/null 2>&1
  sudo a2enmod ssl >> /dev/null 2>&1
  sudo a2enmod proxy >> /dev/null 2>&1
  sudo a2enmod proxy_http >> /dev/null 2>&1
  sudo a2enmod proxy_wstunnel >> /dev/null 2>&1
  sudo a2enmod headers >> /dev/null 2>&1

  # Criar estrutura de diretórios no Apache
  echo "📁 Criando estrutura de diretórios..."
  sudo mkdir -p /var/www/html/pages

  # Copiar arquivos do projeto para Apache mantendo estrutura
  echo "📂 Copiando arquivos da interface web..."
  sudo cp -r "$SCRIPT_DIR/pages"/* /var/www/html/pages/ >> /dev/null 2>&1
  sudo cp "$SCRIPT_DIR/main.html" /var/www/html/index.html >> /dev/null 2>&1

  # Copiar simple-lnwallet se existir
  if [ -d "$SCRIPT_DIR/simple-lnwallet" ]; then
    echo "📱 Copiando simple-lnwallet..."
    sudo cp -r "$SCRIPT_DIR/simple-lnwallet" /var/www/html/ >> /dev/null 2>&1
  fi

  # Copiar favicon e outros assets estáticos
  echo "📄 Copiando assets estáticos..."
  if [ -f "$SCRIPT_DIR/favicon.ico" ]; then
    sudo cp -f "$SCRIPT_DIR/favicon.ico" /var/www/html/ >> /dev/null 2>&1
  fi
  
  # Copiar arquivos CSS, JS, imagens adicionais
  for ext in css js png jpg jpeg gif svg webp; do
    if ls "$SCRIPT_DIR"/*.$ext 1> /dev/null 2>&1; then
      sudo cp -f "$SCRIPT_DIR"/*.$ext /var/www/html/ 2>/dev/null || true
    fi
  done

  # Ajustar permissões dos arquivos
  echo "🔑 Ajustando permissões dos arquivos..."
  sudo chown -R www-data:www-data /var/www/html/
  sudo chmod -R 755 /var/www/html/

  # Configurar proxy reverso Apache
  echo "⚙️ Configurando proxy reverso Apache..."
  setup_https_proxy

  # Verificar configuração Apache
  echo "✅ Verificando configuração Apache..."
  if sudo apache2ctl configtest >> /dev/null 2>&1; then
    echo "✅ Configuração Apache válida"
  else
    echo -e "${YELLOW}⚠️ Possíveis problemas na configuração Apache${NC}"
    sudo apache2ctl configtest
  fi

  # Reiniciar Apache
  echo "🔄 Reiniciando Apache..."
  sudo systemctl enable apache2 >> /dev/null 2>&1
  sudo systemctl restart apache2 >> /dev/null 2>&1

  if sudo systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✅ Apache configurado com sucesso!${NC}"
    local server_ip=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
    echo -e "${GREEN}🌐 Interface disponível em: http://$server_ip${NC}"
  else
    echo -e "${RED}❌ Erro ao iniciar Apache${NC}"
    sudo systemctl status apache2
    return 1
  fi
}

deploy_to_apache() {
  echo -e "${GREEN}📋 Realizando deploy para Apache...${NC}"
  
  # Verificar se o Apache está rodando
  if ! sudo systemctl is-active --quiet apache2; then
    echo -e "${YELLOW}⚠️ Apache não está rodando. Tentando iniciar...${NC}"
    sudo systemctl start apache2
    if ! sudo systemctl is-active --quiet apache2; then
      echo -e "${RED}❌ Não foi possível iniciar o Apache${NC}"
      return 1
    fi
  fi

  # Criar backup da configuração atual se existir
  if [ -d "/var/www/html.backup" ]; then
    sudo rm -rf /var/www/html.backup.old
    sudo mv /var/www/html.backup /var/www/html.backup.old
  fi
  sudo cp -r /var/www/html /var/www/html.backup >> /dev/null 2>&1

  # Deploy dos arquivos
  echo "📂 Copiando arquivos atualizados..."
  
  # Copiar páginas
  if [ -d "$SCRIPT_DIR/pages" ]; then
    sudo rm -rf /var/www/html/pages
    sudo mkdir -p /var/www/html/pages
    sudo cp -r "$SCRIPT_DIR/pages"/* /var/www/html/pages/ >> /dev/null 2>&1
  fi

  # Copiar arquivo principal
  if [ -f "$SCRIPT_DIR/main.html" ]; then
    sudo cp "$SCRIPT_DIR/main.html" /var/www/html/index.html >> /dev/null 2>&1
  fi

  # Copiar simple-lnwallet
  if [ -d "$SCRIPT_DIR/simple-lnwallet" ]; then
    sudo rm -rf /var/www/html/simple-lnwallet
    sudo cp -r "$SCRIPT_DIR/simple-lnwallet" /var/www/html/ >> /dev/null 2>&1
  fi

  # Ajustar permissões
  sudo chown -R www-data:www-data /var/www/html/
  sudo chmod -R 755 /var/www/html/

  # Recarregar configuração do Apache
  sudo systemctl reload apache2 >> /dev/null 2>&1

  echo -e "${GREEN}✅ Deploy realizado com sucesso!${NC}"
}

setup_https_proxy() {
  # Configurar proxy reverso se existir script de configuração
  if [ -f "$SCRIPT_DIR/../conf_files/setup-apache-proxy.sh" ]; then
    echo "⚙️ Configurando proxy reverso Apache..."
    sudo "$SCRIPT_DIR/../conf_files/setup-apache-proxy.sh" >> /dev/null 2>&1 & spinner
  else
    echo -e "${YELLOW}⚠️ Script de configuração HTTPS não encontrado${NC}"
    # Criar configuração básica de proxy
    setup_basic_proxy
  fi
}

setup_basic_proxy() {
  echo "⚙️ Configurando proxy básico para BRLN-OS..."
  
  # Criar configuração de proxy básico
  sudo tee /etc/apache2/sites-available/brln-proxy.conf > /dev/null << EOF
<VirtualHost *:80>
    ServerName $ip_local
    DocumentRoot /var/www/html
    
    # Proxy configuration for BRLN-OS services
    ProxyPreserveHost On
    ProxyRequests Off
    
    # API Proxy
    ProxyPass /api/ http://localhost:2121/api/
    ProxyPassReverse /api/ http://localhost:2121/api/
    
    # Lightning Monitor
    ProxyPass /lightning/ http://localhost:5000/
    ProxyPassReverse /lightning/ http://localhost:5000/
    
    # WebSocket support
    RewriteEngine on
    RewriteCond %{HTTP:UPGRADE} websocket [NC]
    RewriteCond %{HTTP:CONNECTION} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:2121/\$1" [P,L]
    
    ErrorLog \${APACHE_LOG_DIR}/brln_error.log
    CustomLog \${APACHE_LOG_DIR}/brln_access.log combined
</VirtualHost>
EOF

  # Habilitar o site
  sudo a2ensite brln-proxy
  sudo systemctl reload apache2
  echo -e "${GREEN}✅ Proxy básico configurado!${NC}"
}

setup_apache_ssl() {
  echo -e "${GREEN}🔐 Configurando SSL para Apache...${NC}"
  
  # Gerar certificados auto-assinados se não existirem
  if [ ! -f /etc/ssl/certs/brln-selfsigned.crt ]; then
    echo "📜 Gerando certificados SSL auto-assinados..."
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/brln-selfsigned.key \
      -out /etc/ssl/certs/brln-selfsigned.crt \
      -subj "/C=BR/ST=Brasil/L=Local/O=BRLN-OS/CN=$ip_local" >> /dev/null 2>&1
  fi

  # Configurar SSL virtual host
  echo "⚙️ Configurando virtual host SSL..."
  sudo tee /etc/apache2/sites-available/brln-ssl.conf > /dev/null << EOF
<VirtualHost *:443>
    ServerName $ip_local
    DocumentRoot /var/www/html
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/brln-selfsigned.crt
    SSLCertificateKeyFile /etc/ssl/private/brln-selfsigned.key
    
    # Proxy configuration for BRLN-OS services
    ProxyPreserveHost On
    ProxyRequests Off
    
    # API Proxy
    ProxyPass /api/ http://localhost:2121/api/
    ProxyPassReverse /api/ http://localhost:2121/api/
    
    # Lightning Monitor
    ProxyPass /lightning/ http://localhost:5000/
    ProxyPassReverse /lightning/ http://localhost:5000/
    
    # WebSocket support with SSL
    RewriteEngine on
    RewriteCond %{HTTP:UPGRADE} websocket [NC]
    RewriteCond %{HTTP:CONNECTION} upgrade [NC]
    RewriteRule ^/?(.*) "wss://localhost:2121/\$1" [P,L]
    
    # Headers for security
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    
    ErrorLog \${APACHE_LOG_DIR}/brln_error.log
    CustomLog \${APACHE_LOG_DIR}/brln_access.log combined
</VirtualHost>
EOF

  # Habilitar SSL e o site
  sudo a2enmod ssl
  sudo a2ensite brln-ssl
  sudo systemctl reload apache2

  # Abrir porta 443
  if ! sudo ufw status | grep -q "443/tcp"; then
    sudo ufw allow from $subnet to any port 443 proto tcp comment 'allow Apache SSL from local network'
  fi

  echo -e "${GREEN}✅ SSL configurado com sucesso!${NC}"
  echo -e "${YELLOW}🔐 Interface SSL disponível em: https://$ip_local${NC}"
}