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

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                          🇧🇷 BRLN-OS 🇧🇷                          ║"
    echo "║                      Bitcoin Lightning Node OS                       ║"
    echo "║                        Version: $SCRIPT_VERSION                        ║"
    echo "║                                                                      ║"
    echo "║               Modularized Bitcoin & Lightning Stack                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
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
            echo -e "${GREEN}🚀 Instalação rápida...${NC}"
            submenu_opcoes
            ;;
        "help"|"--help"|"-h")
            echo -e "${YELLOW}Uso:${NC}"
            echo "  $0              - Executa instalação/atualização padrão"
            echo "  $0 menu         - Mostra menu interativo"
            echo "  $0 update       - Atualiza sistema"
            echo "  $0 install      - Instalação rápida"
            echo "  $0 help         - Mostra esta ajuda"
            echo ""
            echo -e "${BLUE}Componentes modulares disponíveis:${NC}"
            echo "  - Bitcoin Core & LND"
            echo "  - Apache Web Server"  
            echo "  - Lightning Apps (ThunderHub, LNbits, BOS)"
            echo "  - Terminal Web Interface (Gotty)"
            echo "  - System Tools & Security"
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