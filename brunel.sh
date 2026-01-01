#!/bin/bash

# Suppress interactive prompts during installation
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

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
# clear
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

# Function to detect and configure user environment (now uses shared logic)
configure_user_environment() {
    echo -e "${YELLOW}👤 Configurando ambiente de usuário...${NC}"
    
    # Use shared path detection function from utils.sh
    configure_brln_paths
    
    # Set compatibility variables for existing code
    atual_user="$ATUAL_USER"
    VENV_DIR="$VENV_DIR_API"
    API_USER="$ATUAL_USER"
    
    echo -e "${BLUE}Ambiente virtual: $VENV_DIR${NC}"
    
    # Check if python3-venv is installed
    if ! dpkg -l | grep -q python3-venv; then
        echo -e "${YELLOW}📦 Instalando python3-venv...${NC}"
        sudo apt update
        sudo apt install -y python3-venv
        echo -e "${GREEN}✅ python3-venv instalado${NC}"
    else
        echo -e "${GREEN}✅ python3-venv já instalado${NC}"
    fi
    
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
    
    # Check if pip is installed
    if ! command -v pip &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando pip...${NC}"
        sudo apt update
        sudo apt install -y python3-pip
        echo -e "${GREEN}✅ pip instalado${NC}"
    else
        echo -e "${GREEN}✅ pip já instalado${NC}"
    fi
    
    # Install/upgrade basic dependencies
    pip install --upgrade pip
    
    # Install API dependencies if requirements file exists
    if [[ -f "$SCRIPT_DIR/api/v1/requirements.txt" ]]; then
        pip install -r "$SCRIPT_DIR/api/v1/requirements.txt"
        echo -e "${GREEN}✅ Dependências da API instaladas${NC}"
    fi
    
    # Install additional Flask dependencies
    pip install flask flask-cors grpcio grpcio-tools
    echo -e "${GREEN}✅ Dependências Flask e gRPC instaladas${NC}"
    
    # Export variables for use by other functions
    export USER_HOME
    export VENV_DIR
    export API_USER
}

# Function to setup API user and directories
setup_api_user() {
    echo -e "${YELLOW}👤 Configurando usuário API...${NC}"
    
    # Create brln-api user if it doesn't exist
    if ! id "brln-api" &>/dev/null; then
        echo -e "${BLUE}Criando usuário brln-api...${NC}"
        sudo adduser --disabled-password --gecos "" brln-api
    fi
    
    # Add admin user to brln-api group for management access
    sudo adduser $atual_user brln-api || true
    
    # Give brln-api user read access to the project directory
    sudo setfacl -R -m u:brln-api:rx /home/admin/brln-os || true
    
    # Create API data directory
    echo -e "${BLUE}Configurando diretório de dados da API...${NC}"
    sudo mkdir -p /data/brln-wallet
    sudo chown -R brln-api:brln-api /data/brln-wallet
    sudo chmod 755 /data/brln-wallet
    
    echo -e "${GREEN}✅ Usuário API configurado${NC}"
}

# Function to configure API service
configure_api_service() {
    echo -e "${YELLOW}⚙️ Configurando serviço API...${NC}"
    
    # Setup API user first
    setup_api_user
    
    # Create service using services.sh
    source "$SCRIPT_DIR/scripts/services.sh"
    create_brln_api_service
    
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
    sudo apt update && sudo apt upgrade -y
    
    # Install Apache and Python dependencies
    echo -e "${YELLOW}📦 Instalando Apache e dependências Python...${NC}"
    sudo apt install apache2 curl wget python3-venv expect golang-go -y
    
    # Enable Apache modules
    echo -e "${YELLOW}⚙️ Habilitando módulos do Apache...${NC}"
    sudo a2enmod cgid dir ssl rewrite proxy proxy_http headers
    
    # Restart Apache
    echo -e "${YELLOW}🔄 Reiniciando o serviço Apache...${NC}"
    sudo systemctl restart apache2
    
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
        cd "$SCRIPT_DIR/api/v1" && source "$VENV_DIR/bin/activate" && bash "$SCRIPTS_DIR/gen-proto.sh" 2>&1
        PROTO_STATUS=$?
        if [[ $PROTO_STATUS -eq 0 ]]; then
            echo -e "${GREEN}✅ Arquivos proto gerados${NC}"
        else
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${RED}❌ ERRO: Falha na geração dos arquivos proto${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}   Código de saída: $PROTO_STATUS${NC}"
            echo -e "${YELLOW}   💡 Verifique os erros detalhados acima${NC}"
            echo -e "${YELLOW}   💡 Logs podem estar em /tmp ou no output do script${NC}"
            echo -e "${YELLOW}   💡 Execute manualmente para mais detalhes:${NC}"
            echo -e "${YELLOW}      cd $SCRIPT_DIR/api/v1${NC}"
            echo -e "${YELLOW}      source $VENV_DIR/bin/activate${NC}"
            echo -e "${YELLOW}      bash $SCRIPTS_DIR/gen-proto.sh${NC}"
            echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        fi
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ ERRO: Script gen-proto.sh não encontrado${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   Procurando: $SCRIPTS_DIR/gen-proto.sh${NC}"
        echo -e "${YELLOW}   💡 Verifique se o BRLN-OS está instalado corretamente${NC}"
        echo -e "${YELLOW}   💡 Execute: ls -la $SCRIPTS_DIR/gen-proto.sh${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    # Configure systemd service with correct user and paths
    configure_api_service
    
    # Start the API service within script context
    echo -e "${YELLOW}🚀 Iniciando serviço API...${NC}"
    sudo systemctl start brln-api
    
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
        curl -fsSL https://tailscale.com/install.sh | sh
        echo -e "${GREEN}✅ Tailscale instalado!${NC}"
    else
        echo -e "${GREEN}✅ Tailscale já instalado${NC}"
    fi
    
    # Check if qrencode is installed
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando qrencode...${NC}"
        sudo apt install qrencode -y
    fi
    
    echo -e "${YELLOW}🔗 Iniciando Tailscale...${NC}"
    
    # Start Tailscale and capture the auth URL (store for final summary only)
    auth_output=$(timeout 30s sudo tailscale up 2>&1 || true)
    
    if echo "$auth_output" | grep -q "https://login.tailscale.com"; then
        TAILSCALE_AUTH_URL=$(echo "$auth_output" | grep -o 'https://login.tailscale.com[^[:space:]]*')
        export TAILSCALE_AUTH_URL
        echo -e "${GREEN}✅ Tailscale iniciado!${NC}"
        echo -e "${BLUE}🔗 Link de autenticação capturado (autentique para obter IP)${NC}"
    else
        echo -e "${GREEN}✅ Tailscale já conectado!${NC}"
    fi
    
    # Wait for Tailscale IP to be available (up to 10 seconds)
    echo -e "${YELLOW}⏳ Aguardando IP do Tailscale...${NC}"
    for i in {1..10}; do
        tailscale_ip=$(tailscale ip -4 2>/dev/null | head -1)
        if [[ -n "$tailscale_ip" && "$tailscale_ip" != "127.0.0.1" ]]; then
            TAILSCALE_IP="$tailscale_ip"
            export TAILSCALE_IP
            echo -e "${GREEN}✅ IP Tailscale obtido: $TAILSCALE_IP${NC}"
            return 0
        fi
        [[ $i -lt 10 ]] && sleep 1
    done
    
    echo -e "${YELLOW}⚠️ IP Tailscale não disponível (autenticação necessária)${NC}"
}

# Function to show installation summary with QR codes
show_installation_summary() {
    #clear
    
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
        
        # Display Tailscale QR code centered (properly handling ANSI codes)
        if [[ -s "$tailscale_qr_file" ]]; then
            local term_width=$(tput cols 2>/dev/null || echo 80)
            
            # Read and center each line of the QR code
            while IFS= read -r line; do
                # Remove ANSI escape codes to get true length
                local visible_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
                local visible_length=${#visible_line}
                local qr_padding=$(( (term_width - visible_length) / 2 ))
                
                # Print padding and then the line with ANSI codes intact
                if [[ $qr_padding -gt 0 ]]; then
                    printf "%${qr_padding}s%s\n" "" "$line"
                else
                    echo "$line"
                fi
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
}

# Main execution flow
update_and_upgrade
tailscale_vpn
configure_ssl_complete
configure_secure_firewall

# Install BRLN API for system management with user detection
echo
echo -e "${YELLOW}🔌 Configurando BRLN API para gerenciamento do sistema...${NC}"
install_brln_api_with_user_env

terminal_web

# Final Installation Summary Screen
show_installation_summary