#!/bin/bash

# Frontend Maintenance Script for BRLN-OS
# Maintains Apache/Nginx web services and deploys frontend updates
# Version: 1.0

set -e  # Exit on any error

# Get the directory where this script is located
MAINTENANCE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the parent directory (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

# Source configuration and utilities
if [[ -f "$MAINTENANCE_SCRIPT_DIR/config.sh" ]]; then
    source "$MAINTENANCE_SCRIPT_DIR/config.sh"
else
    # Basic configuration fallback
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

if [[ -f "$MAINTENANCE_SCRIPT_DIR/utils.sh" ]]; then
    source "$MAINTENANCE_SCRIPT_DIR/utils.sh"
fi

if [[ -f "$MAINTENANCE_SCRIPT_DIR/apache.sh" ]]; then
    source "$MAINTENANCE_SCRIPT_DIR/apache.sh"
fi

# Main maintenance function
frontend_maintenance() {
    echo -e "${GREEN}🔧 Iniciando manutenção do frontend e API...${NC}"
    
    # Check and handle web servers
    check_and_manage_webservers
    
    # Deploy/update frontend files
    deploy_frontend_files
    
    # Check and maintain API services
    maintain_api_services
    
    # Verify services
    verify_frontend_status
    
    echo -e "${GREEN}✅ Manutenção do frontend e API concluída!${NC}"
}

# Function to check and manage web servers
check_and_manage_webservers() {
    echo -e "${BLUE}🌐 Verificando servidores web...${NC}"
    
    local nginx_running=false
    local apache_running=false
    
    # Check if nginx is running
    if pgrep -x "nginx" > /dev/null; then
        nginx_running=true
        echo -e "${YELLOW}📋 Nginx está rodando${NC}"
    fi
    
    # Check if apache is running
    if pgrep -x "apache2" > /dev/null; then
        apache_running=true
        echo -e "${YELLOW}📋 Apache está rodando${NC}"
    fi
    
    # Handle conflicts - prefer Apache for BRLN-OS
    if [[ "$nginx_running" == true && "$apache_running" == true ]]; then
        echo -e "${YELLOW}⚠️ Conflito detectado: Apache e Nginx rodando simultaneamente${NC}"
        echo -e "${BLUE}🔄 Parando Nginx para evitar conflitos...${NC}"
        sudo systemctl stop nginx || true
        sudo systemctl disable nginx || true
        echo -e "${GREEN}✅ Nginx parado${NC}"
    elif [[ "$nginx_running" == true && "$apache_running" == false ]]; then
        echo -e "${YELLOW}⚠️ Nginx rodando, mas Apache é preferido para BRLN-OS${NC}"
        echo -e "${BLUE}🔄 Parando Nginx e iniciando Apache...${NC}"
        sudo systemctl stop nginx || true
        sudo systemctl disable nginx || true
    fi
    
    # Ensure Apache is installed and configured
    install_and_configure_apache_complete
    
    # Start Apache if not running
    if ! pgrep -x "apache2" > /dev/null; then
        echo -e "${BLUE}🚀 Iniciando Apache...${NC}"
        sudo systemctl enable apache2
        sudo systemctl start apache2
    else
        echo -e "${BLUE}🔄 Reiniciando Apache para aplicar configurações...${NC}"
        sudo systemctl restart apache2
    fi
}

# Function to install and configure Apache
install_and_configure_apache_complete() {
    echo -e "${GREEN}📦 Verificando instalação do Apache com configuração completa...${NC}"
    
    # Install Apache if not present
    if ! command -v apache2 &> /dev/null; then
        echo -e "${BLUE}📥 Instalando Apache2...${NC}"
        sudo apt update
        sudo apt install apache2 -y
        echo -e "${GREEN}✅ Apache2 instalado${NC}"
    else
        echo -e "${GREEN}✅ Apache2 já está instalado${NC}"
    fi
    
    # Configure SSL with full proxy and WebSocket support
    if [[ -f "$MAINTENANCE_SCRIPT_DIR/apache.sh" ]]; then
        source "$MAINTENANCE_SCRIPT_DIR/apache.sh"
        configure_ssl_complete
        
        # Update network configuration for localhost and Tailscale only
        echo -e "${BLUE}🌐 Configurando acesso local...${NC}"
        update_apache_network_config
    else
        echo -e "${RED}❌ Arquivo apache.sh não encontrado em $MAINTENANCE_SCRIPT_DIR${NC}"
        return 1
    fi
    
    # Copy BRLN-OS files
    if [[ -f "$MAINTENANCE_SCRIPT_DIR/apache.sh" ]]; then
        source "$MAINTENANCE_SCRIPT_DIR/apache.sh"
        copy_brln_files_to_apache
    else
        echo -e "${RED}❌ Arquivo apache.sh não encontrado em $MAINTENANCE_SCRIPT_DIR${NC}"
        return 1
    fi
    
    # Test configuration
    if sudo apache2ctl configtest > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Configuração Apache completa válida${NC}"
    else
        echo -e "${RED}❌ Erro na configuração Apache${NC}"
        sudo apache2ctl configtest
        return 1
    fi
}

# Function to configure SSL-only access with full proxy support
configure_ssl_only() {
    echo -e "${BLUE}🔐 Configurando acesso SSL-only com proxy completo...${NC}"
    
    # Use complete SSL configuration from apache.sh
    configure_ssl_complete
    
    echo -e "${GREEN}✅ SSL configurado - apenas HTTPS com proxy API habilitado${NC}"
}

# Function to maintain Apache configuration
maintain_apache_config() {
  echo "🔧 Verificando configuração Apache..."
  
  # Verificar se Apache está rodando
  if ! sudo systemctl is-active --quiet apache2; then
    echo "⚠️ Apache não está rodando. Tentando reiniciar..."
    sudo systemctl start apache2
  fi
  
  # Verificar se módulos necessários estão habilitados
  verify_apache_modules_if_needed
  
  # Verificar configuração SSL
  if [ ! -f /etc/apache2/sites-available/brln-ssl-api.conf ]; then
    echo "📝 Recriando configuração SSL com proxy..."
    configure_ssl_complete
  elif ! sudo apache2ctl configtest 2>/dev/null; then
    echo "⚠️ Configuração Apache inválida. Recriando..."
    configure_ssl_complete
  fi
  
  # Verificar se proxy está funcionando
  if ! curl -s -k https://localhost/api/v1/health >/dev/null 2>&1; then
    echo "🔄 Proxy API não responde. Reconfigurando..."
    sudo systemctl reload apache2
  fi
  
  echo -e "${GREEN}✅ Configuração Apache verificada${NC}"
}

verify_apache_modules_if_needed() {
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
      sudo a2enmod "$module" >/dev/null 2>&1
    done
    sudo systemctl reload apache2
  fi
}

# Function to create SSL site configuration
create_ssl_site() {
    echo -e "${BLUE}📜 Criando configuração SSL...${NC}"
    
    # Generate self-signed certificate if it doesn't exist
    if [[ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ]]; then
        sudo make-ssl-cert generate-default-snakeoil --force-overwrite
    fi
    
    # Create SSL site configuration
    sudo tee /etc/apache2/sites-available/brln-ssl.conf > /dev/null << 'EOF'
<VirtualHost *:443>
    DocumentRoot /var/www/html
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
    
    # Security headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options SAMEORIGIN
    Header always set X-Content-Type-Options nosniff
    
    # API Proxy for BRLN services
    ProxyPreserveHost On
    ProxyRequests Off
    
    # Lightning API
    ProxyPass /api/ http://localhost:2121/api/
    ProxyPassReverse /api/ http://localhost:2121/api/
    
    # WebSocket support
    RewriteEngine on
    RewriteCond %{HTTP:UPGRADE} websocket [NC]
    RewriteCond %{HTTP:CONNECTION} upgrade [NC]
    RewriteRule ^/?(.*) "ws://localhost:2121/$1" [P,L]
    
    ErrorLog ${APACHE_LOG_DIR}/brln_error.log
    CustomLog ${APACHE_LOG_DIR}/brln_access.log combined
</VirtualHost>
EOF
    
    sudo a2ensite brln-ssl
}

# Function to deploy frontend files
deploy_frontend_files() {
    echo -e "${GREEN}📂 Atualizando arquivos do frontend...${NC}"
    
    # Create backup of current files
    if [[ -d /var/www/html/pages ]]; then
        sudo cp -r /var/www/html /var/www/html.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    fi
    
    # Create directory structure
    sudo mkdir -p /var/www/html/pages
    
    # Deploy main files
    if [[ -f "$SCRIPT_DIR/main.html" ]]; then
        echo -e "${BLUE}📄 Copiando main.html -> index.html${NC}"
        sudo cp "$SCRIPT_DIR/main.html" /var/www/html/index.html
    fi
    
    # Deploy pages directory
    if [[ -d "$SCRIPT_DIR/pages" ]]; then
        echo -e "${BLUE}📁 Copiando estrutura de páginas...${NC}"
        sudo rm -rf /var/www/html/pages/*
        sudo cp -r "$SCRIPT_DIR/pages"/* /var/www/html/pages/
    fi
    
    # Deploy simple-lnwallet if exists
    if [[ -d "$SCRIPT_DIR/simple-lnwallet" ]]; then
        echo -e "${BLUE}📱 Copiando simple-lnwallet...${NC}"
        sudo rm -rf /var/www/html/simple-lnwallet
        sudo cp -r "$SCRIPT_DIR/simple-lnwallet" /var/www/html/
    fi
    
    # Deploy static assets
    echo -e "${BLUE}📦 Copiando assets estáticos...${NC}"
    for asset in favicon.ico *.css *.js *.png *.jpg *.jpeg *.gif *.svg; do
        if [[ -f "$SCRIPT_DIR/$asset" ]]; then
            sudo cp "$SCRIPT_DIR/$asset" /var/www/html/
        fi
    done
    
    # Set correct permissions
    echo -e "${BLUE}🔑 Ajustando permissões...${NC}"
    sudo chown -R www-data:www-data /var/www/html/
    sudo chmod -R 755 /var/www/html/
    
    # Reload Apache to apply changes
    sudo systemctl reload apache2
    
    echo -e "${GREEN}✅ Arquivos do frontend atualizados${NC}"
}

# Function to verify frontend status
verify_frontend_status() {
    echo -e "${BLUE}🔍 Verificando status dos serviços...${NC}"
    
    # Check Apache status
    if sudo systemctl is-active --quiet apache2; then
        echo -e "${GREEN}✅ Apache está rodando${NC}"
        
        # Check listening ports
        local ssl_port=$(netstat -tlnp 2>/dev/null | grep apache | grep :443 || true)
        local http_port=$(netstat -tlnp 2>/dev/null | grep apache | grep :80 || true)
        
        if [[ -n "$ssl_port" ]]; then
            echo -e "${GREEN}✅ SSL (porta 443) ativo${NC}"
        fi
        
        if [[ -n "$http_port" ]]; then
            echo -e "${YELLOW}⚠️ HTTP (porta 80) também ativo - considere desabilitar${NC}"
        fi
        
        # Get server IP
        local server_ip=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
        echo -e "${GREEN}🌐 Frontend disponível em: https://$server_ip${NC}"
        
    else
        echo -e "${RED}❌ Apache não está rodando${NC}"
        sudo systemctl status apache2
        return 1
    fi
    
    # Check for conflicting services
    if pgrep -x "nginx" > /dev/null; then
        echo -e "${YELLOW}⚠️ Nginx ainda está rodando - pode causar conflitos${NC}"
    fi
    
    # Check API services status
    verify_api_services
}

# Function to maintain API services
maintain_api_services() {
    echo -e "${GREEN}🔧 Mantendo serviços da API...${NC}"
    
    local api_services=("brln-api" "messager-monitor")
    
    for service in "${api_services[@]}"; do
        echo -e "${BLUE}🔍 Verificando serviço: $service${NC}"
        
        if sudo systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✅ $service está rodando${NC}"
            # Restart to ensure latest code
            echo -e "${BLUE}🔄 Reiniciando $service para aplicar atualizações...${NC}"
            sudo systemctl restart "$service"
            
            # Wait a moment and check if it's still running
            sleep 2
            if sudo systemctl is-active --quiet "$service"; then
                echo -e "${GREEN}✅ $service reiniciado com sucesso${NC}"
            else
                echo -e "${RED}❌ Erro ao reiniciar $service${NC}"
                sudo systemctl status "$service"
            fi
        else
            echo -e "${YELLOW}⚠️ $service não está rodando - tentando iniciar...${NC}"
            
            # Check if service file exists
            if [[ -f "/etc/systemd/system/$service.service" ]]; then
                sudo systemctl enable "$service"
                sudo systemctl start "$service"
                
                sleep 2
                if sudo systemctl is-active --quiet "$service"; then
                    echo -e "${GREEN}✅ $service iniciado com sucesso${NC}"
                else
                    echo -e "${RED}❌ Falha ao iniciar $service${NC}"
                    sudo systemctl status "$service"
                fi
            else
                echo -e "${YELLOW}⚠️ Arquivo de serviço $service.service não encontrado${NC}"
                install_api_service "$service"
            fi
        fi
    done
    
    # Update API requirements if needed
    update_api_requirements
}

# Function to install missing API service
install_api_service() {
    local service_name="$1"
    echo -e "${BLUE}📦 Instalando serviço: $service_name${NC}"
    
    local service_file="$SCRIPT_DIR/services/$service_name.service"
    
    if [[ -f "$service_file" ]]; then
        sudo cp "$service_file" "/etc/systemd/system/"
        sudo systemctl daemon-reload
        sudo systemctl enable "$service_name"
        sudo systemctl start "$service_name"
        
        sleep 2
        if sudo systemctl is-active --quiet "$service_name"; then
            echo -e "${GREEN}✅ $service_name instalado e iniciado${NC}"
        else
            echo -e "${RED}❌ Erro ao iniciar $service_name após instalação${NC}"
            sudo systemctl status "$service_name"
        fi
    else
        echo -e "${RED}❌ Arquivo de serviço não encontrado: $service_file${NC}"
    fi
}

# Function to update API requirements
update_api_requirements() {
    echo -e "${BLUE}🐍 Verificando dependências Python da API...${NC}"
    
    local requirements_file="$SCRIPT_DIR/api/v1/requirements.txt"
    local venv_path="$HOME/envflask"
    
    if [[ -f "$requirements_file" ]]; then
        # Check if virtual environment exists
        if [[ ! -d "$venv_path" ]]; then
            echo -e "${BLUE}📦 Criando ambiente virtual Python...${NC}"
            python3 -m venv "$venv_path"
        fi
        
        # Activate virtual environment and update packages
        echo -e "${BLUE}📦 Atualizando dependências Python...${NC}"
        source "$venv_path/bin/activate"
        pip install --upgrade pip > /dev/null 2>&1
        pip install -r "$requirements_file" > /dev/null 2>&1
        deactivate
        
        echo -e "${GREEN}✅ Dependências Python atualizadas${NC}"
    else
        echo -e "${YELLOW}⚠️ requirements.txt não encontrado em: $requirements_file${NC}"
    fi
}

# Function to verify API services status
verify_api_services() {
    echo -e "${BLUE}🔍 Verificando status dos serviços da API...${NC}"
    
    local api_services=("brln-api" "messager-monitor")
    
    for service in "${api_services[@]}"; do
        if sudo systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✅ $service está rodando${NC}"
            
            # Check if API is responding (for brln-api)
            if [[ "$service" == "brln-api" ]]; then
                local api_response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:2121/api/v1/system/health 2>/dev/null || echo "000")
                if [[ "$api_response" == "200" ]]; then
                    echo -e "${GREEN}✅ API respondendo em http://localhost:2121${NC}"
                else
                    echo -e "${YELLOW}⚠️ API pode não estar respondendo corretamente${NC}"
                fi
            fi
        else
            echo -e "${RED}❌ $service não está rodando${NC}"
        fi
    done
}

# Help function
show_help() {
    cat << EOF
BRLN-OS Frontend & API Maintenance Script

Uso:
  $0 [OPÇÃO]

OPÇÕES:
  maintenance, -m    Executa manutenção completa (frontend + API)
  deploy, -d         Atualiza apenas os arquivos do frontend
  api, -a            Mantém apenas os serviços da API
  check, -c          Verifica status dos serviços web e API
  ssl-only           Configura acesso SSL-only (desabilita HTTP)
  help, -h           Mostra esta ajuda

EXEMPLOS:
  $0 maintenance     # Manutenção completa (frontend + API)
  $0 deploy          # Deploy dos arquivos do frontend
  $0 api             # Manutenção apenas da API
  $0 check           # Verifica status de todos os serviços
  $0 ssl-only        # Configura SSL-only

SERVIÇOS GERENCIADOS:
  Frontend:          Apache Web Server, páginas HTML/CSS/JS
  API:               brln-api, messager-monitor
  Conflitos:         Remove conflitos entre Nginx/Apache

EOF
}

# Main execution
case "${1:-maintenance}" in
    "maintenance"|"-m")
        frontend_maintenance
        ;;
    "deploy"|"-d")
        deploy_frontend_files
        ;;
    "api"|"-a")
        maintain_api_services
        verify_api_services
        ;;
    "check"|"-c")
        verify_frontend_status
        ;;
    "ssl-only")
        configure_ssl_only
        sudo systemctl reload apache2
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Opção desconhecida: $1${NC}"
        echo -e "${YELLOW}Use '$0 help' para ver opções disponíveis.${NC}"
        exit 1
        ;;
esac