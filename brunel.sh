#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Set working directory to the script's location
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Add current directory to PATH if not already there
if [[ ":$PATH:" != *":$SCRIPT_DIR:"* ]]; then
    export PATH="$SCRIPT_DIR:$PATH"
fi

# CD to the script directory to ensure relative paths work
cd "$SCRIPT_DIR"

# Function to center text output
center_text() {
    local text="$1"
    local color="${2:-$NC}"
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local text_length=${#text}
    local padding=$(( (term_width - text_length) / 2 ))
    
    if [[ $padding -gt 0 ]]; then
        printf "%${padding}s" ""
    fi
    echo -e "${color}${text}${NC}"
}

# Installation header
clear
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}BRLN-OS INSTALLER v2.0${NC}"
echo -e "${GREEN}Bitcoin dedicated OS${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Source required scripts
source "$SCRIPTS_DIR/config.sh"
source "$SCRIPTS_DIR/utils.sh" 
source "$SCRIPTS_DIR/apache.sh"
source "$SCRIPTS_DIR/gotty.sh"
source "$SCRIPTS_DIR/lightning.sh"

# Function to detect and configure user environment
configure_user_environment() {
    echo -e "${YELLOW}👤 Configurando ambiente de usuário...${NC}"
    
    # Detect current user
    atual_user=$(whoami)
    echo -e "${BLUE}Usuário atual: $atual_user${NC}"
    
    # Set paths based on user
    if [[ $atual_user == "admin" ]]; then
        USER_HOME="/home/admin"
        VENV_DIR="/home/admin/brln-os-envs/api-v1"
        API_USER="admin"
    else
        USER_HOME="/root"
        VENV_DIR="/root/brln-os-envs/api-v1"
        API_USER="root"
    fi
    
    echo -e "${BLUE}Diretório home: $USER_HOME${NC}"
    echo -e "${BLUE}Ambiente virtual: $VENV_DIR${NC}"
    
    # Create and activate virtual environment if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${YELLOW}📦 Criando ambiente virtual...${NC}"
        mkdir -p "$(dirname "$VENV_DIR")"
        python3 -m venv "$VENV_DIR"
        echo -e "${GREEN}✅ Ambiente virtual criado${NC}"
    else
        echo -e "${GREEN}✅ Ambiente virtual já existe${NC}"
    fi
    
    # Activate virtual environment and install dependencies
    echo -e "${YELLOW}⚡ Instalando dependências...${NC}"
    source "$VENV_DIR/bin/activate"
    
    # Install/upgrade basic dependencies
    pip install --upgrade pip > /dev/null 2>&1
    
    # Install API dependencies if requirements file exists
    if [[ -f "$SCRIPT_DIR/api/v1/requirements.txt" ]]; then
        pip install -r "$SCRIPT_DIR/api/v1/requirements.txt" > /dev/null 2>&1
        echo -e "${GREEN}✅ Dependências da API instaladas${NC}"
    fi
    
    # Install additional Flask dependencies
    pip install flask flask-cors grpcio grpcio-tools > /dev/null 2>&1
    echo -e "${GREEN}✅ Dependências Flask e gRPC instaladas${NC}"
    
    # Export variables for use by other functions
    export USER_HOME
    export VENV_DIR
    export API_USER
}

# Function to configure API service
configure_api_service() {
    echo -e "${YELLOW}⚙️ Configurando serviço API...${NC}"
    
    sudo tee /etc/systemd/system/brln-api.service > /dev/null << EOF
[Unit]
Description=BRLN-OS API gRPC - Comando Central
After=network.target lnd.service

[Service]
Type=simple
User=$API_USER
WorkingDirectory=$SCRIPT_DIR/api/v1
ExecStartPre=/bin/bash $SCRIPT_DIR/scripts/setup-api-env.sh
ExecStart=$VENV_DIR/bin/python3 $SCRIPT_DIR/api/v1/app.py
Restart=always
RestartSec=10
Environment=PYTHONPATH=$SCRIPT_DIR/api/v1

# Segurança
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable brln-api
    
    echo -e "${GREEN}✅ Serviço API configurado${NC}"
}

# Function to update and upgrade system with Apache setup
update_and_upgrade() {
    echo -e "${GREEN}🚀 Iniciando instalação da interface gráfica${NC}"
    sudo -v
    
    # Update system
    sudo apt update && sudo apt upgrade -y > /dev/null 2>&1
    
    # Install Apache and Python dependencies
    echo -e "${YELLOW}📦 Instalando Apache e dependências Python...${NC}"
    sudo apt install apache2 curl wget python3-venv expect -y > /dev/null 2>&1
    
    # Enable Apache modules
    echo -e "${YELLOW}⚙️ Habilitando módulos do Apache...${NC}"
    sudo a2enmod cgid dir ssl rewrite proxy proxy_http headers > /dev/null 2>&1
    
    # Restart Apache
    echo -e "${YELLOW}🔄 Reiniciando o serviço Apache...${NC}"
    sudo systemctl restart apache2 > /dev/null 2>&1
    
    echo -e "${GREEN}✅ Sistema atualizado e Apache configurado!${NC}"
}

# Function to install BRLN API with user environment detection
install_brln_api_with_user_env() {
    echo -e "${GREEN}🔌 Instalando BRLN API...${NC}"
    
    # Configure user environment first
    configure_user_environment
    
    # Setup API environment (creates venv and installs dependencies)
    echo -e "${YELLOW}🐍 Configurando ambiente Python da API...${NC}"
    if [[ -x "$SCRIPTS_DIR/setup-api-env.sh" ]]; then
        bash "$SCRIPTS_DIR/setup-api-env.sh"
        echo -e "${GREEN}✅ Ambiente Python configurado${NC}"
    fi
    
    # Generate gRPC proto files
    echo -e "${YELLOW}🔧 Gerando arquivos proto gRPC...${NC}"
    if [[ -x "$SCRIPTS_DIR/gen-proto.sh" ]]; then
        cd "$SCRIPT_DIR/api/v1" && source "$VENV_DIR/bin/activate" && bash "$SCRIPTS_DIR/gen-proto.sh"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Arquivos proto gerados${NC}"
        else
            echo -e "${YELLOW}⚠️ Aviso: Erro na geração de proto${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Script gen-proto.sh não encontrado${NC}"
    fi
    
    # Configure systemd service with correct user and paths
    configure_api_service
    
    # Start the API service within script context
    echo -e "${YELLOW}🚀 Iniciando serviço API...${NC}"
    sudo systemctl start brln-api >/dev/null 2>&1
    
    # Check if service started successfully (centralized check)
    for i in {1..5}; do
        if sudo systemctl is-active --quiet brln-api; then
            echo -e "${GREEN}✅ BRLN API iniciada com sucesso!${NC}"
            break
        elif [[ $i -eq 5 ]]; then
            echo -e "${RED}❌ Erro ao iniciar BRLN API${NC}"
            sudo journalctl -u brln-api -n 5 --no-pager
        else
            sleep 1
        fi
    done
}

# Function to configure SSL
configure_ssl_complete() {
    echo -e "${YELLOW}🔐 Configurando SSL completo...${NC}"
    
    # Copy BRLN-OS files to Apache first (using function from apache.sh)
    copy_brln_files_to_apache
    
    # Configure SSL certificates and HTTPS - using function from apache.sh
    copy_ssl_certificates
    setup_ssl_proxy_config
}

# Tailscale VPN function
tailscale_vpn() {
    echo -e "${YELLOW}🌐 Configurando Tailscale VPN...${NC}"
    
    # Install Tailscale
    if ! command -v tailscale &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando Tailscale...${NC}"
        curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
        echo -e "${GREEN}✅ Tailscale instalado!${NC}"
    else
        echo -e "${GREEN}✅ Tailscale já instalado${NC}"
    fi
    
    # Check if qrencode is installed
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando qrencode...${NC}"
        sudo apt install qrencode -y > /dev/null 2>&1
    fi
    
    echo -e "${YELLOW}🔗 Iniciando Tailscale...${NC}"
    
    # Start Tailscale and capture the auth URL (store for final summary only)
    auth_output=$(timeout 30s sudo tailscale up 2>&1 || true)
    
    if echo "$auth_output" | grep -q "https://login.tailscale.com"; then
        TAILSCALE_AUTH_URL=$(echo "$auth_output" | grep -o 'https://login.tailscale.com[^[:space:]]*')
        export TAILSCALE_AUTH_URL
        echo -e "${GREEN}✅ Tailscale iniciado!${NC}"
        echo -e "${BLUE}🔗 Link de autenticação capturado${NC}"
    else
        echo -e "${GREEN}✅ Tailscale já conectado!${NC}"
        tailscale_ip=$(tailscale ip -4 2>/dev/null | head -1)
        if [[ -n "$tailscale_ip" ]]; then
            TAILSCALE_IP="$tailscale_ip"
            export TAILSCALE_IP
            echo -e "${BLUE}🌐 IP Tailscale: $TAILSCALE_IP${NC}"
        fi
    fi
}

# Function to show installation summary with QR codes
show_installation_summary() {
    clear
    
    # ASCII Art Banner
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local banner_padding=$(( (term_width - 68) / 2 ))
    local pad=""
    if [[ $banner_padding -gt 0 ]]; then
        pad=$(printf "%${banner_padding}s" "")
    fi
    
    echo -e "${GREEN}"
    echo "${pad}    ██████╗ ██████╗ ██╗     ███╗   ██╗       ██████╗ ███████╗"
    echo "${pad}    ██╔══██╗██╔══██╗██║     ████╗  ██║      ██╔═══██╗██╔════╝"
    echo "${pad}    ██████╔╝██████╔╝██║     ██╔██╗ ██║█████╗██║   ██║███████╗"
    echo "${pad}    ██╔══██╗██╔══██╗██║     ██║╚██╗██║╚════╝██║   ██║╚════██║"
    echo "${pad}    ██████╔╝██║  ██║███████╗██║ ╚████║      ╚██████╔╝███████║"
    echo "${pad}    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝       ╚═════╝ ╚══════╝"
    echo -e "${NC}"
    
    echo
    center_text "✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!" "${GREEN}"
    center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${GREEN}"
    echo
    
    # Get local IP addresses
    local_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "localhost")
    tailscale_ip="${TAILSCALE_IP:-$(tailscale ip -4 2>/dev/null | head -1 || echo "")}"
    tailscale_auth="${TAILSCALE_AUTH_URL:-}"
    
    # Service Status Section
    center_text "📊 STATUS DOS SERVIÇOS" "${YELLOW}"
    
    # Check service status
    api_status=$(systemctl is-active brln-api 2>/dev/null || echo "inactive")
    apache_status=$(systemctl is-active apache2 2>/dev/null || echo "inactive")
    tailscale_status=$(systemctl is-active tailscaled 2>/dev/null || echo "inactive")
    
    [[ "$api_status" == "active" ]] && api_icon="${GREEN}●${NC}" || api_icon="${RED}●${NC}"
    [[ "$apache_status" == "active" ]] && apache_icon="${GREEN}●${NC}" || apache_icon="${RED}●${NC}"
    [[ "$tailscale_status" == "active" ]] && tailscale_icon="${GREEN}●${NC}" || tailscale_icon="${RED}●${NC}"
    
    local status_line="$apache_icon Apache2 (HTTPS)    $api_icon BRLN-API    $tailscale_icon Tailscale VPN"
    center_text "$status_line" ""
    echo
    
    # QR Code Section - Tailscale QR on left, Local HTTPS text on right
    echo
    center_text "🌐 TAILSCALE QR CODE" "${GREEN}"
    if [[ -n "$tailscale_ip" ]]; then
        center_text "https://$tailscale_ip" "${YELLOW}"
    elif [[ -n "$tailscale_auth" ]]; then
        center_text "Login na Tailnet" "${YELLOW}"
    else
        center_text "Indisponível" "${YELLOW}"
    fi
    echo
    center_text "🏠 ACESSO LOCAL (HTTPS)" "${GREEN}"
    center_text "https://$local_ip" "${YELLOW}"
    echo
    
    # Generate Tailscale QR code
    tailscale_qr_file=$(mktemp)

    if [[ -n "$tailscale_ip" ]]; then
        tailscale_url="https://$tailscale_ip"
    elif [[ -n "$tailscale_auth" ]]; then
        tailscale_url="$tailscale_auth"
    else
        tailscale_url=""
    fi

    if [[ -n "$tailscale_url" ]]; then
        qrencode -t ANSIUTF8 -m 1 -l M "$tailscale_url" > "$tailscale_qr_file" 2>/dev/null
        
        # Display Tailscale QR code centered
        if [[ -s "$tailscale_qr_file" ]]; then
            # Center each line of the QR code
            while IFS= read -r line; do
                center_text "$line" ""
            done < "$tailscale_qr_file"
        fi
        
        # Display Tailscale login link below QR if it's an auth URL
        if [[ -n "$tailscale_auth" ]]; then
            echo
            center_text "🔗 Link de autenticação Tailnet:" "${BLUE}"
            center_text "$tailscale_auth" "${YELLOW}"
        fi
    else
        echo
        center_text "Tailscale indisponível" "${YELLOW}"
        echo
    fi
    
    # Clean up temp file
    rm -f "$tailscale_qr_file"
    
    echo
    center_text "🎯 PRÓXIMOS PASSOS" "${YELLOW}"
    center_text "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "${YELLOW}"
    center_text "1. Escaneie o QR Code Tailscale ou acesse via HTTPS local" "${BLUE}"
    center_text "2. Acesse a interface web e clique em 'Configurações'" "${BLUE}"
    center_text "3. Use o 'Terminal Web' para gerenciar o sistema" "${BLUE}"
    center_text "4. Configure o Lightning Node através da interface" "${BLUE}"
    echo
}

# Main execution flow
update_and_upgrade
configure_ssl_complete
configure_secure_firewall
tailscale_vpn

# Install BRLN API for system management with user detection
echo
echo -e "${YELLOW}🔌 Configurando BRLN API para gerenciamento do sistema...${NC}"
install_brln_api_with_user_env

terminal_web

# Final Installation Summary Screen
show_installation_summary