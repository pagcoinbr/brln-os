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

echo "=============================="
echo "    BRLN-OS INSTALLER"
echo "=============================="
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
        VENV_DIR="/home/admin/envflask"
        API_USER="admin"
    else
        USER_HOME="/root"
        VENV_DIR="/root/envflask"
        API_USER="root"
    fi
    
    echo -e "${BLUE}Diretório home: $USER_HOME${NC}"
    echo -e "${BLUE}Ambiente virtual: $VENV_DIR${NC}"
    
    # Create and activate virtual environment if it doesn't exist
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${YELLOW}📦 Criando ambiente virtual...${NC}"
        python3 -m venv "$VENV_DIR"
        echo -e "${GREEN}✅ Ambiente virtual criado em $VENV_DIR${NC}"
    else
        echo -e "${GREEN}✅ Ambiente virtual já existe em $VENV_DIR${NC}"
    fi
    
    # Activate virtual environment and install dependencies
    echo -e "${YELLOW}⚡ Ativando ambiente virtual e instalando dependências...${NC}"
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
    
    echo -e "${GREEN}✅ Serviço API configurado para usuário $API_USER${NC}"
}

# Function to update and upgrade system with Apache setup
update_and_upgrade() {
    echo -e "${GREEN}🚀 Iniciando instalação da interface gráfica com Apache...${NC}"
    sudo -v
    
    # Update system
    sudo apt update && sudo apt upgrade -y > /dev/null 2>&1
    
    # Install Apache
    echo -e "${YELLOW}📦 Instalando Apache...${NC}"
    sudo apt install apache2 curl wget -y > /dev/null 2>&1
    
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
    echo -e "${GREEN}🔌 Instalando BRLN API com configuração automática de usuário...${NC}"
    
    # Configure user environment first
    configure_user_environment
    
    # Generate gRPC proto files
    echo -e "${YELLOW}🔧 Gerando arquivos proto gRPC...${NC}"
    if [[ -x "$SCRIPTS_DIR/gen-proto.sh" ]]; then
        "$SCRIPTS_DIR/gen-proto.sh"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}✅ Arquivos proto gerados com sucesso!${NC}"
        else
            echo -e "${YELLOW}⚠️ Aviso: Erro na geração de arquivos proto, continuando...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Script gen-proto.sh não encontrado, prosseguindo...${NC}"
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
            echo -e "${RED}❌ Erro ao iniciar BRLN API após 5 tentativas${NC}"
            sudo journalctl -u brln-api -n 5 --no-pager
        else
            sleep 1
        fi
    done
}

# Function to configure SSL
configure_ssl_complete() {
    echo -e "${YELLOW}🔐 Configurando SSL completo...${NC}"
    
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
        echo -e "${GREEN}✅ Tailscale já está instalado!${NC}"
    fi
    
    # Check if qrencode is installed
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando qrencode...${NC}"
        sudo apt install qrencode -y > /dev/null 2>&1
    fi
    
    echo -e "${YELLOW}🔗 Iniciando Tailscale...${NC}"
    
    # Start Tailscale and capture the auth URL
    auth_output=$(timeout 30s sudo tailscale up 2>&1 || true)
    
    if echo "$auth_output" | grep -q "https://login.tailscale.com"; then
        auth_url=$(echo "$auth_output" | grep -o 'https://login.tailscale.com[^[:space:]]*')
        
        echo -e "${GREEN}✅ Tailscale iniciado!${NC}"
        echo -e "${BLUE}🔗 Link de autenticação: $auth_url${NC}"
        
        # Generate QR code for the auth URL
        echo -e "${YELLOW}📱 Gerando QR Code para autenticação:${NC}"
        qrencode -t ANSIUTF8 "$auth_url"
        echo
        echo -e "${BLUE}📱 Use o QR code acima ou acesse: ${YELLOW}$auth_url${NC}"
    else
        echo -e "${GREEN}✅ Tailscale já está conectado!${NC}"
        tailscale_ip=$(tailscale ip -4 2>/dev/null | head -1)
        if [[ -n "$tailscale_ip" ]]; then
            echo -e "${BLUE}🌐 IP Tailscale: $tailscale_ip${NC}"
        fi
    fi
}

# Function to show installation summary with QR codes
show_installation_summary() {
    clear
    echo
    echo -e "${GREEN}██████████████████████████████████████████████████████████████████████████████${NC}"
    echo -e "${GREEN}█                        ✅ BRLN-OS INSTALADO COM SUCESSO!                     █${NC}"
    echo -e "${GREEN}██████████████████████████████████████████████████████████████████████████████${NC}"
    
    # Get local IP addresses
    local_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "localhost")
    tailscale_ip=$(tailscale ip -4 2>/dev/null | head -1 || echo "")
    
    echo
    echo -e "${BLUE}🌐 ACESSO LOCAL: ${YELLOW}https://$local_ip${NC} | 🔐 Portas: 22(SSH), 443(HTTPS)"
    if [[ -n "$tailscale_ip" ]]; then
        echo -e "${BLUE}🌐 TAILSCALE: ${YELLOW}https://$tailscale_ip${NC} | 📱 Status: Conectado"
    else
        echo -e "${YELLOW}📱 TAILSCALE: Aguardando autenticação (QR code abaixo)${NC}"
    fi
    echo
    echo -e "${GREEN}📊 SERVIÇOS: ${YELLOW}Interface(/) | API(/api/v1/status) | Terminal(/terminal/)${NC}"
    echo
    
    # Generate compact QR codes side by side
    echo -e "${BLUE}        🏠 ACESSO LOCAL                    🌐 TAILSCALE${NC}"
    echo -e "${BLUE}    https://$local_ip           $(if [[ -n "$tailscale_ip" ]]; then echo "https://$tailscale_ip"; else echo "Login na Tailnet"; fi)${NC}"
    
    # Create temporary files for QR codes
    local_qr_file=$(mktemp)
    tailscale_qr_file=$(mktemp)
    
    # Generate compact QR codes
    qrencode -t ANSIUTF8 -s 1 "https://$local_ip" > "$local_qr_file" 2>/dev/null
    
    if [[ -z "$tailscale_ip" ]]; then
        auth_output=$(timeout 3s sudo tailscale up --reset 2>&1 || true)
        if echo "$auth_output" | grep -q "https://login.tailscale.com"; then
            tailscale_auth_url=$(echo "$auth_output" | grep -o 'https://login.tailscale.com[^[:space:]]*')
            qrencode -t ANSIUTF8 -s 1 "$tailscale_auth_url" > "$tailscale_qr_file" 2>/dev/null
        else
            echo "QR indisponível" > "$tailscale_qr_file"
        fi
    else
        qrencode -t ANSIUTF8 -s 1 "https://$tailscale_ip" > "$tailscale_qr_file" 2>/dev/null
    fi
    
    # Display compact QR codes side by side
    if [[ -s "$local_qr_file" ]] && [[ -s "$tailscale_qr_file" ]]; then
        paste <(cat "$local_qr_file") <(cat "$tailscale_qr_file") | sed 's/\t/  /' | head -15
    fi
    
    # Clean up temp files
    rm -f "$local_qr_file" "$tailscale_qr_file"
    
    echo
    echo -e "${GREEN}🎯 PRÓXIMOS PASSOS:${NC} ${YELLOW}1)${NC} Escaneie QR Local ${YELLOW}2)${NC} Clique 'Configurações' ${YELLOW}3)${NC} Use 'Terminal Web'"
    echo
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              Instalação concluída! Acesse a interface para continuar.           ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Main execution flow
update_and_upgrade
configure_ssl_complete
configure_secure_firewall
tailscale_vpn

# Install BRLN API for system management with user detection
echo -e "${YELLOW}🔌 Configurando BRLN API para gerenciamento do sistema...${NC}"
install_brln_api_with_user_env

terminal_web

# Final Installation Summary Screen
show_installation_summary