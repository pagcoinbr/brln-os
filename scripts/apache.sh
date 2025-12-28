#!/bin/bash

# Apache Web Server functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Get dynamic Tailscale IP
get_tailscale_ip() {
  # Try to get Tailscale IP from interface
  local tailscale_ip=$(ip addr show tailscale0 2>/dev/null | grep -oP 'inet \K[^/]+' | head -1)
  if [[ -n "$tailscale_ip" && "$tailscale_ip" != "127.0.0.1" ]]; then
    echo "$tailscale_ip"
  else
    # Fallback: try to get from tailscale status
    local ts_ip=$(tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$ts_ip" && "$ts_ip" != "127.0.0.1" ]]; then
      echo "$ts_ip"
    fi
  fi
}

# Configure Apache ports for localhost and Tailscale only
configure_apache_local_ports() {
  local tailscale_ip=$(get_tailscale_ip)
  
  echo "🌐 Configurando Apache para acesso local apenas..."
  echo "   • Localhost: 127.0.0.1"
  if [[ -n "$tailscale_ip" ]]; then
    echo "   • Tailscale: $tailscale_ip"
  fi
  
  # Update ports.conf to listen only on localhost and Tailscale
  sudo tee /etc/apache2/ports.conf > /dev/null << EOF
# Apache ports configuration - Local access only
# Generated automatically by BRLN-OS

# Port 80 disabled to avoid conflict with Docker
# Listen 80

<IfModule mod_ssl.c>
    # Listen on localhost IPv4 and IPv6
    Listen 127.0.0.1:443
    Listen [::1]:443
    
    # Listen on Tailscale IP if available
$(if [[ -n "$tailscale_ip" ]]; then echo "    Listen $tailscale_ip:443"; fi)
</IfModule>

<IfModule mod_gnutls.c>
    # Listen on localhost IPv4 and IPv6  
    Listen 127.0.0.1:443
    Listen [::1]:443
    
    # Listen on Tailscale IP if available
$(if [[ -n "$tailscale_ip" ]]; then echo "    Listen $tailscale_ip:443"; fi)
</IfModule>
EOF
}

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

  # Configurar proxy reverso Apache com SSL completo
  echo "⚙️ Configurando proxy reverso Apache..."
  configure_ssl_complete

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
    # Criar configuração básica de proxy com SSL
    setup_ssl_proxy_config
  fi
}

setup_ssl_proxy_config() {
  echo "⚙️ Configurando proxy SSL com API para BRLN-OS..."
  
  # Configure Apache for local access only
  configure_apache_local_ports
  
  # Verificar e habilitar módulos necessários
  echo "🔌 Verificando módulos Apache..."
  sudo a2enmod ssl >> /dev/null 2>&1
  sudo a2enmod proxy >> /dev/null 2>&1
  sudo a2enmod proxy_http >> /dev/null 2>&1
  sudo a2enmod proxy_wstunnel >> /dev/null 2>&1
  sudo a2enmod headers >> /dev/null 2>&1
  sudo a2enmod rewrite >> /dev/null 2>&1
  
  # Backup da configuração atual
  if [ -f /etc/apache2/sites-enabled/default-ssl.conf ]; then
    sudo cp /etc/apache2/sites-enabled/default-ssl.conf /etc/apache2/sites-enabled/default-ssl.conf.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
  fi
  
  # Criar configuração SSL com proxy para API
  echo "📝 Criando configuração SSL com proxy..."
  sudo tee /etc/apache2/sites-available/brln-ssl-api.conf > /dev/null << EOF
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html

    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key

    # Security Headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"

    # API Proxy Configuration for BRLN-OS
    ProxyPreserveHost On
    ProxyRequests Off

    # API Endpoints - Proxy to port 2121
    ProxyPass /api/ http://localhost:2121/api/
    ProxyPassReverse /api/ http://localhost:2121/api/

    # WebSocket support for real-time features
    RewriteEngine on
    RewriteCond %{HTTP:UPGRADE} websocket [NC]
    RewriteCond %{HTTP:CONNECTION} upgrade [NC]
    RewriteRule ^/api/(.*) "ws://localhost:2121/api/\$1" [P,L]
    
    # Proxy WebSocket connections
    ProxyPass /ws/ ws://localhost:2121/ws/
    ProxyPassReverse /ws/ ws://localhost:2121/ws/

    # Additional proxy for potential services
    ProxyPass /lightning/ http://localhost:5000/
    ProxyPassReverse /lightning/ http://localhost:5000/

    # Terminal Web Proxy - Gotty on port 3131
    <Location "/terminal/">
        ProxyPass http://localhost:3131/
        ProxyPassReverse http://localhost:3131/
        Header always unset X-Frame-Options
        Header always set X-Frame-Options "SAMEORIGIN"
    </Location>
    
    # WebSocket support for terminal
    RewriteCond %{HTTP:UPGRADE} websocket [NC]
    RewriteCond %{HTTP:CONNECTION} upgrade [NC]
    RewriteRule ^/terminal/(.*) "ws://localhost:3131/\$1" [P,L]

    # Error and Access Logs
    ErrorLog \${APACHE_LOG_DIR}/brln_error.log
    CustomLog \${APACHE_LOG_DIR}/brln_access.log combined
</VirtualHost>
EOF

  # Desabilitar site HTTP padrão e SSL padrão
  sudo a2dissite 000-default 2>/dev/null || true
  sudo a2dissite default-ssl 2>/dev/null || true
  
  # Habilitar nova configuração SSL
  sudo a2ensite brln-ssl-api
  
  # Verificar configuração antes de recarregar
  if sudo apache2ctl configtest >> /dev/null 2>&1; then
    echo -e "${GREEN}✅ Configuração Apache válida${NC}"
    sudo systemctl reload apache2
    echo -e "${GREEN}✅ Proxy SSL com API configurado!${NC}"
  else
    echo -e "${RED}❌ Erro na configuração Apache${NC}"
    sudo apache2ctl configtest
    return 1
  fi
}

verify_apache_modules() {
  echo "🔍 Verificando módulos Apache necessários..."
  
  local modules=("ssl" "proxy" "proxy_http" "proxy_wstunnel" "headers" "rewrite")
  local missing_modules=()
  
  for module in "${modules[@]}"; do
    if ! sudo apache2ctl -M | grep -q "${module}_module"; then
      missing_modules+=("$module")
    fi
  done
  
  if [ ${#missing_modules[@]} -gt 0 ]; then
    echo "📦 Habilitando módulos: ${missing_modules[*]}"
    for module in "${missing_modules[@]}"; do
      sudo a2enmod "$module" >> /dev/null 2>&1
    done
  fi
  
  echo -e "${GREEN}✅ Todos os módulos necessários estão habilitados${NC}"
}

force_https_only() {
  echo "🔒 Configurando redirecionamento HTTP para HTTPS..."
  
  # Criar configuração HTTP que redireciona para HTTPS
  sudo tee /etc/apache2/sites-available/brln-http-redirect.conf > /dev/null << 'EOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html
    
    # Redirecionar tudo para HTTPS
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
    
    # Log de redirecionamentos
    ErrorLog ${APACHE_LOG_DIR}/brln_redirect_error.log
    CustomLog ${APACHE_LOG_DIR}/brln_redirect_access.log combined
</VirtualHost>
EOF
  
  # Habilitar redirecionamento HTTP
  sudo a2ensite brln-http-redirect
  
  echo -e "${GREEN}✅ Redirecionamento HTTPS configurado${NC}"
}

copy_ssl_certificates() {
  echo "🔐 Configurando certificados SSL..."
  
  # Gerar certificados auto-assinados se não existirem
  if [ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ]; then
    echo "📜 Gerando certificados SSL auto-assinados..."
    sudo make-ssl-cert generate-default-snakeoil --force-overwrite
  fi
  
  # Verificar se existem certificados personalizados no projeto
  if [ -f "$SCRIPT_DIR/../certs/server.crt" ] && [ -f "$SCRIPT_DIR/../certs/server.key" ]; then
    echo "📋 Copiando certificados personalizados..."
    sudo cp "$SCRIPT_DIR/../certs/server.crt" /etc/ssl/certs/brln-server.crt
    sudo cp "$SCRIPT_DIR/../certs/server.key" /etc/ssl/private/brln-server.key
    sudo chmod 644 /etc/ssl/certs/brln-server.crt
    sudo chmod 600 /etc/ssl/private/brln-server.key
    
    # Atualizar configuração para usar certificados personalizados
    sudo sed -i 's|ssl-cert-snakeoil.pem|brln-server.crt|g' /etc/apache2/sites-available/brln-ssl-api.conf
    sudo sed -i 's|ssl-cert-snakeoil.key|brln-server.key|g' /etc/apache2/sites-available/brln-ssl-api.conf
    echo -e "${GREEN}✅ Certificados personalizados instalados${NC}"
  else
    echo -e "${YELLOW}⚠️ Usando certificados auto-assinados${NC}"
  fi
}

configure_ssl_complete() {
  echo "🔐 Configurando SSL completo para BRLN-OS..."
  
  # Verificar módulos necessários
  verify_apache_modules
  
  # Configurar certificados
  copy_ssl_certificates
  
  # Configurar proxy SSL com API
  setup_ssl_proxy_config
  
  # Forçar HTTPS apenas
  force_https_only
  
  echo -e "${GREEN}✅ Configuração SSL completa!${NC}"
}

copy_brln_files() {
  echo "📂 Copiando arquivos necessários do BRLN-OS..."
  
  # Criar diretórios necessários
  sudo mkdir -p /var/www/html/{pages,api,assets}
  
  # Copiar páginas principais
  if [ -d "$SCRIPT_DIR/../pages" ]; then
    echo "📄 Copiando páginas..."
    sudo cp -r "$SCRIPT_DIR/../pages"/* /var/www/html/pages/ 2>/dev/null || true
  fi
  
  # Copiar arquivo principal
  if [ -f "$SCRIPT_DIR/../main.html" ]; then
    echo "🏠 Copiando página principal..."
    sudo cp "$SCRIPT_DIR/../main.html" /var/www/html/index.html 2>/dev/null || true
  fi
  
  # Copiar simple-lnwallet
  if [ -d "$SCRIPT_DIR/../simple-lnwallet" ]; then
    echo "💰 Copiando simple-lnwallet..."
    sudo cp -r "$SCRIPT_DIR/../simple-lnwallet" /var/www/html/ 2>/dev/null || true
  fi
  
  # Copiar assets estáticos
  echo "🎨 Copiando assets estáticos..."
  for ext in css js png jpg jpeg gif svg webp ico; do
    if ls "$SCRIPT_DIR/../"*.$ext 1> /dev/null 2>&1; then
      sudo cp "$SCRIPT_DIR/../"*.$ext /var/www/html/assets/ 2>/dev/null || true
    fi
  done
  
  # Ajustar permissões
  sudo chown -R www-data:www-data /var/www/html/
  sudo chmod -R 644 /var/www/html/
  sudo find /var/www/html/ -type d -exec chmod 755 {} \;
  
  echo -e "${GREEN}✅ Arquivos BRLN-OS copiados!${NC}"
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

# Frontend maintenance function - checks services and deploys updates
apache_maintenance() {
  echo -e "${GREEN}🔧 Executando manutenção do Apache...${NC}"
  
  # Check for service conflicts (Nginx vs Apache)
  if pgrep -x "nginx" > /dev/null && pgrep -x "apache2" > /dev/null; then
    echo -e "${YELLOW}⚠️ Conflito detectado: Nginx e Apache rodando simultaneamente${NC}"
    echo -e "${BLUE}🔄 Parando Nginx para evitar conflitos...${NC}"
    sudo systemctl stop nginx || true
    sudo systemctl disable nginx || true
    echo -e "${GREEN}✅ Nginx parado${NC}"
  elif pgrep -x "nginx" > /dev/null; then
    echo -e "${YELLOW}⚠️ Nginx rodando - parando para usar Apache${NC}"
    sudo systemctl stop nginx || true
    sudo systemctl disable nginx || true
  fi
  
  # Ensure Apache is running
  if ! pgrep -x "apache2" > /dev/null; then
    echo -e "${BLUE}🚀 Iniciando Apache...${NC}"
    sudo systemctl enable apache2
    sudo systemctl start apache2
  else
    echo -e "${BLUE}🔄 Reiniciando Apache...${NC}"
    sudo systemctl restart apache2
  fi
  
  # Deploy latest files
  deploy_to_apache
  
  # Verify status
  if sudo systemctl is-active --quiet apache2; then
    local server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo -e "${GREEN}✅ Manutenção concluída - Apache rodando${NC}"
    
    # Check SSL status
    if netstat -tlnp 2>/dev/null | grep apache | grep -q :443; then
      echo -e "${GREEN}🔐 SSL ativo em: https://$server_ip${NC}"
    fi
    if netstat -tlnp 2>/dev/null | grep apache | grep -q :80; then
      echo -e "${YELLOW}📡 HTTP ativo em: http://$server_ip${NC}"
    fi
  else
    echo -e "${RED}❌ Erro na manutenção - Apache não está rodando${NC}"
    return 1
  fi
}

# Update Apache configuration for current network setup
update_apache_network_config() {
  echo -e "${GREEN}🔄 Atualizando configuração de rede do Apache...${NC}"
  
  local current_tailscale_ip=$(get_tailscale_ip)
  
  if [[ -n "$current_tailscale_ip" ]]; then
    echo "🌐 IP Tailscale atual: $current_tailscale_ip"
  else
    echo "⚠️ Tailscale não detectado, configurando apenas localhost"
  fi
  
  # Reconfigure ports
  configure_apache_local_ports
  
  # Test Apache configuration
  if sudo apache2ctl configtest >> /dev/null 2>&1; then
    echo "✅ Configuração Apache válida"
    sudo systemctl reload apache2
    echo "✅ Apache recarregado com nova configuração de rede"
  else
    echo -e "${RED}❌ Erro na configuração Apache${NC}"
    sudo apache2ctl configtest
    return 1
  fi
}

# Show current Apache network configuration
show_apache_network_status() {
  echo -e "${BLUE}📊 Status da configuração de rede Apache:${NC}"
  
  local tailscale_ip=$(get_tailscale_ip)
  
  echo "🌐 IPs configurados:"
  echo "   • Localhost: 127.0.0.1:443"
  echo "   • IPv6 Local: [::1]:443"
  
  if [[ -n "$tailscale_ip" ]]; then
    echo "   • Tailscale: $tailscale_ip:443"
    echo "✅ Tailscale ativo"
  else
    echo "❌ Tailscale não detectado"
  fi
  
  echo ""
  echo "🔍 Portas Apache ativas:"
  sudo netstat -tlnp 2>/dev/null | grep apache2 | grep :443 || echo "❌ Apache não está ouvindo na porta 443"
}