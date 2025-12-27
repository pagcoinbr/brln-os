#!/bin/bash

# Menu system for BRLN-OS
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/apache.sh"
source "$(dirname "${BASH_SOURCE[0]}")/gotty.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bitcoin.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lightning.sh"
source "$(dirname "${BASH_SOURCE[0]}")/elements.sh"
source "$(dirname "${BASH_SOURCE[0]}")/peerswap.sh"
source "$(dirname "${BASH_SOURCE[0]}")/system.sh"



menu_system_tools() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                     🛠️ FERRAMENTAS SISTEMA 🛠️                      ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Ferramentas e Utilitários ─┐${NC}"
  echo -e "${GREEN}1.${NC} Configurar Firewall (UFW)"
  echo -e "${GREEN}2.${NC} Fechar todas as portas exceto SSH"
  echo -e "${GREEN}3.${NC} Instalar Tor"
  echo -e "${GREEN}4.${NC} Instalar Tailscale VPN"
  echo -e "${GREEN}5.${NC} Atualizar Sistema"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) configure_ufw; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    2) close_ports_except_ssh; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    3) install_tor; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    4) tailscale_vpn; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    5) update_and_upgrade; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_system_tools ;;
  esac
}

# Display banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ██████╗ ██████╗ ██╗     ███╗   ██╗       ██████╗ ███████╗"
    echo "  ██╔══██╗██╔══██╗██║     ████╗  ██║      ██╔═══██╗██╔════╝"
    echo "  ██████╔╝██████╔╝██║     ██╔██╗ ██║█████╗██║   ██║███████╗"
    echo "  ██╔══██╗██╔══██╗██║     ██║╚██╗██║╚════╝██║   ██║╚════██║"
    echo "  ██████╔╝██║  ██║███████╗██║ ╚████║      ╚██████╔╝███████║"
    echo "  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝       ╚═════╝ ╚══════╝"
    echo ""
    echo "               ⚡ Bitcoin Multi-Node OS ⚡"
    echo "                 Version: $SCRIPT_VERSION"
    echo ""
    echo -e "${NC}"
    echo ""
}

menu() {
  if [ ls /usr/local/bin/bitcoind ]
  clear
  echo -e "${CYAN}"
  show_banner
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ MENU PRINCIPAL ─┐${NC}"
  echo -e "${GREEN}1.${NC} 🔶 Bitcoin & Lightning Stack"
  echo -e "${GREEN}2.${NC} ⚡ Lightning Applications"
  echo -e "${GREEN}3.${NC} 🔥 Elements/Liquid Network"
  echo -e "${GREEN}4.${NC} 🔄 PeerSwap & PeerSwap Web"
  echo -e "${GREEN}5.${NC} 🌐 Interface Web"
  echo -e "${GREEN}6.${NC} 🛠️ Ferramentas do Sistema"
  echo ""
  echo -e "${RED}0.${NC} Sair"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) menu_bitcoin_stack ;;
    2) menu_lightning_apps ;;
    3) menu_elements ;;
    4) menu_peerswap ;;
    5) menu_web_interface ;;
    6) menu_system_tools ;;
    0) echo -e "${GREEN}👋 Obrigado por usar BRLN-OS!${NC}"; exit 0 ;;
    *) echo "Opção inválida!"; sleep 2; menu ;;
  esac
}

# Quick install function for compatibility
submenu_opcoes() {
  echo -e "${GREEN}🚀 Instalação rápida iniciada...${NC}"
  update_and_upgrade
}