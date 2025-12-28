#!/bin/bash

# BRLN-OS - Bitcoin Lightning Node Operating System
# Main script that orchestrates all subscripts
# Version: v1.0-beta

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Check if scripts directory exists
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    echo "❌ Scripts directory not found at: $SCRIPTS_DIR"
    echo "Please ensure the scripts/ directory exists with all necessary files."
    exit 1
fi

# Source all required scripts
source "$SCRIPTS_DIR/config.sh"
source "$SCRIPTS_DIR/utils.sh" 
source "$SCRIPTS_DIR/apache.sh"
source "$SCRIPTS_DIR/gotty.sh"
source "$SCRIPTS_DIR/bitcoin.sh"
source "$SCRIPTS_DIR/lightning.sh"
source "$SCRIPTS_DIR/elements.sh"
source "$SCRIPTS_DIR/peerswap.sh"
source "$SCRIPTS_DIR/system.sh"
source "$SCRIPTS_DIR/menu.sh"

# Function to install qrencode if not available
install_qrencode() {
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}📦 Instalando qrencode para gerar QR codes...${NC}"
        sudo apt update > /dev/null 2>&1
        sudo apt install -y qrencode > /dev/null 2>&1
        echo -e "${GREEN}✅ qrencode instalado${NC}"
    fi
}

# Function to get local IP
get_local_ip() {
    local interface=$(ip route show default | awk '/default/ { print $5 }' | head -n 1)
    ip addr show $interface | awk '/inet / { print $2 }' | head -n 1 | cut -d'/' -f1
}

# Function to display QR codes
show_qr_codes() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                           QR CODES DE ACESSO                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}\n"
    
    local local_ip=$(get_local_ip)
    local tailscale_ip=$(get_tailscale_ip)
    
    # Install qrencode if needed
    install_qrencode
    
    echo -e "${GREEN}🌐 Acesso pela Rede Local:${NC}"
    echo -e "${YELLOW}https://$local_ip${NC}"
    echo ""
    qrencode -t ANSIUTF8 "https://$local_ip"
    echo ""
    
    if [[ -n "$tailscale_ip" && "$tailscale_ip" != "127.0.0.1" ]]; then
        echo -e "${GREEN}🔒 Acesso via Tailscale VPN:${NC}"
        echo -e "${YELLOW}https://$tailscale_ip${NC}"
        echo ""
        qrencode -t ANSIUTF8 "https://$tailscale_ip"
        echo ""
    else
        echo -e "${YELLOW}⚠️ Tailscale não configurado ou IP não detectado${NC}"
        echo -e "${BLUE}💡 Execute 'sudo tailscale up' para conectar à sua rede Tailscale${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}💻 O terminal web estará disponível em:${NC}"
    echo -e "${YELLOW}https://$local_ip/terminal/${NC}"
    if [[ -n "$tailscale_ip" && "$tailscale_ip" != "127.0.0.1" ]]; then
        echo -e "${YELLOW}https://$tailscale_ip/terminal/${NC}"
    fi
    echo ""
    
    echo -e "${GREEN}✅ Use os QR codes acima para acessar a interface web do seu dispositivo móvel${NC}"
    echo -e "${BLUE}🚀 A instalação completa pode ser feita através do terminal web${NC}"
}

# Basic installation function (Apache + Tailscale + QR codes)
submenu_opcoes() {
    echo -e "${GREEN}🚀 Iniciando instalação básica do BRLN-OS...${NC}"
    echo -e "${BLUE}📋 Esta instalação inclui apenas o essencial:${NC}"
    echo -e "${YELLOW}   • Atualização do sistema${NC}"
    echo -e "${YELLOW}   • Servidor Apache com SSL${NC}"
    echo -e "${YELLOW}   • Configuração de proxy${NC}"
    echo -e "${YELLOW}   • Instalação do Tailscale${NC}"
    echo -e "${YELLOW}   • Terminal web (Gotty)${NC}"
    echo ""
    echo -e "${CYAN}⏳ O restante da instalação será feito pelo terminal web...${NC}"
    echo ""
    
    # System update
    echo -e "${YELLOW}⚙️ Atualizando sistema...${NC}"
    update_and_upgrade
    
    # Install and configure Apache with SSL
    echo -e "${YELLOW}🌐 Configurando Apache com SSL...${NC}"
    setup_apache_web
    configure_ssl_complete
    
    # Install Tailscale
    echo -e "${YELLOW}🔒 Instalando Tailscale VPN...${NC}"
    tailscale_vpn
    
    # Configure terminal web
    echo -e "${YELLOW}💻 Configurando terminal web...${NC}"
    terminal_web
    
    # Update Apache network config to include Tailscale if available
    echo -e "${YELLOW}🔄 Atualizando configuração de rede...${NC}"
    update_apache_network_config
    
    echo -e "\n${GREEN}✅ Instalação básica concluída!${NC}"
    echo ""
    
    # Show QR codes
    show_qr_codes
    
    echo -e "\n${CYAN}🎯 PRÓXIMOS PASSOS:${NC}"
    echo -e "${GREEN}1.${NC} Escaneie um dos QR codes acima para acessar a interface web"
    echo -e "${GREEN}2.${NC} Use o terminal web para completar a instalação"
    echo -e "${GREEN}3.${NC} Configure Bitcoin, Lightning Network e outros componentes"
    echo ""
    echo -e "${BLUE}💡 Para acessar o terminal web diretamente: ssh para este servidor e execute 'bash brunel.sh menu'${NC}"
    
    read -p "Pressione Enter para continuar..."
}

# Main function
main() {
    # Show banner
    show_banner
    
    # Check if running with specific arguments
    case "${1:-}" in
        "update"|"upgrade")
            echo -e "${GREEN} Iniciando... ${NC}"
            update_and_upgrade
            ;;
        "menu")
            menu
            ;;
        "install")
            echo -e "${GREEN}Iniciando instalação...${NC}"
            submenu_opcoes
            ;;
        "help"|"--help"|"-h")
            echo -e "${YELLOW}Uso:${NC}"
            echo "  $0              - Executa atualização padrão do sistema"
            echo "  $0 menu         - Mostra menu interativo completo"
            echo "  $0 update       - Atualiza sistema"
            echo "  $0 install      - Instalação básica (Apache + Tailscale + QR codes)"
            echo "  $0 help         - Mostra esta ajuda"
            echo ""
            echo -e "${BLUE}Instalação básica inclui:${NC}"
            echo "  - Atualização do sistema"
            echo "  - Apache Web Server com SSL"  
            echo "  - Configuração de proxy reverso"
            echo "  - Tailscale VPN"
            echo "  - Terminal Web Interface (Gotty)"
            echo "  - QR codes para acesso móvel"
            echo ""
            echo -e "${CYAN}O restante da instalação é feito via terminal web${NC}"
            exit 0
            ;;
        "")
            # Default behavior - run update/upgrade
            echo -e "${GREEN} Iniciando... ${NC}"
            update_and_upgrade
            ;;
        *)
            echo -e "${RED}❌ Opção desconhecida: $1${NC}"
            echo -e "${YELLOW}Use '$0 help' para ver opções disponíveis.${NC}"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"