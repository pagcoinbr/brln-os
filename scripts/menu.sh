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

menu_bitcoin_stack() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                    🔶 BITCOIN LIGHTNING STACK 🔶                    ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Bitcoin Core & Lightning Network ─┐${NC}"
  echo -e "${GREEN}1.${NC} Instalar Bitcoin Core"
  echo -e "${GREEN}2.${NC} Instalar LND (Lightning Network)"
  echo -e "${GREEN}3.${NC} Instalar Stack Completo (Bitcoin + LND)"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) install_bitcoind; read -p "Pressione Enter para continuar..."; menu_bitcoin_stack ;;
    2) download_lnd; read -p "Pressione Enter para continuar..."; menu_bitcoin_stack ;;
    3) install_complete_stack; read -p "Pressione Enter para continuar..."; menu_bitcoin_stack ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_bitcoin_stack ;;
  esac
}

menu_lightning_apps() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                      ⚡ LIGHTNING APPS ⚡                           ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Aplicações Lightning Network ─┐${NC}"
  echo -e "${GREEN}1.${NC} Instalar ThunderHub (Interface Web LND)"
  echo -e "${GREEN}2.${NC} Instalar LNbits (Lightning Wallet)"
  echo -e "${GREEN}3.${NC} Instalar Balance of Satoshis (BOS)"
  echo -e "${GREEN}4.${NC} Configurar Lightning Monitor"
  echo -e "${GREEN}5.${NC} Instalar BRLN API"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) install_thunderhub; read -p "Pressione Enter para continuar..."; menu_lightning_apps ;;
    2) lnbits_install; read -p "Pressione Enter para continuar..."; menu_lightning_apps ;;
    3) install_bos; read -p "Pressione Enter para continuar..."; menu_lightning_apps ;;
    4) setup_lightning_monitor; read -p "Pressione Enter para continuar..."; menu_lightning_apps ;;
    5) install_brln_api; read -p "Pressione Enter para continuar..."; menu_lightning_apps ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_lightning_apps ;;
  esac
}

menu_web_interface() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                      🌐 INTERFACE WEB 🌐                           ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Configuração Interface Web ─┐${NC}"
  echo -e "${GREEN}1.${NC} Configurar Apache Web Server"
  echo -e "${GREEN}2.${NC} Configurar SSL/HTTPS"
  echo -e "${GREEN}3.${NC} Deploy para Apache"
  echo -e "${GREEN}4.${NC} Instalar Terminal Web (Gotty)"
  echo -e "${GREEN}5.${NC} Atualizar Interface Gráfica"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) setup_apache_web; read -p "Pressione Enter para continuar..."; menu_web_interface ;;
    2) setup_apache_ssl; read -p "Pressione Enter para continuar..."; menu_web_interface ;;
    3) deploy_to_apache; read -p "Pressione Enter para continuar..."; menu_web_interface ;;
    4) terminal_web; read -p "Pressione Enter para continuar..."; menu_web_interface ;;
    5) gui_update; read -p "Pressione Enter para continuar..."; menu_web_interface ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_web_interface ;;
  esac
}

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

menu_elements() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                      🔥 ELEMENTS CORE 🔥                            ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Elements/Liquid Network ─┐${NC}"
  echo -e "${GREEN}1.${NC} Instalar Elements Core"
  echo -e "${GREEN}2.${NC} Configurar Elements"
  echo -e "${GREEN}3.${NC} Iniciar Elements"
  echo -e "${GREEN}4.${NC} Status Elements"
  echo -e "${GREEN}5.${NC} Criar Wallet"
  echo -e "${GREEN}6.${NC} Menu Completo Elements"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) install_elements; read -p "Pressione Enter para continuar..."; menu_elements ;;
    2) configure_elements; read -p "Pressione Enter para continuar..."; menu_elements ;;
    3) start_elements; read -p "Pressione Enter para continuar..."; menu_elements ;;
    4) show_elements_status; read -p "Pressione Enter para continuar..."; menu_elements ;;
    5) create_elements_wallet; read -p "Pressione Enter para continuar..."; menu_elements ;;
    6) elements_menu; menu_elements ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_elements ;;
  esac
}

menu_peerswap() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                      🔄 PEERSWAP & PSWEB 🔄                         ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ PeerSwap Lightning-Liquid Bridge ─┐${NC}"
  echo -e "${GREEN}1.${NC} Instalar PeerSwap"
  echo -e "${GREEN}2.${NC} Instalar PeerSwap Web"
  echo -e "${GREEN}3.${NC} Configurar PeerSwap"
  echo -e "${GREEN}4.${NC} Iniciar Serviços"
  echo -e "${GREEN}5.${NC} Status PeerSwap"
  echo -e "${GREEN}6.${NC} Menu Completo PeerSwap"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) install_peerswap; read -p "Pressione Enter para continuar..."; menu_peerswap ;;
    2) install_psweb; read -p "Pressione Enter para continuar..."; menu_peerswap ;;
    3) configure_peerswap; read -p "Pressione Enter para continuar..."; menu_peerswap ;;
    4) start_peerswap; start_psweb; read -p "Pressione Enter para continuar..."; menu_peerswap ;;
    5) show_peerswap_status; read -p "Pressione Enter para continuar..."; menu_peerswap ;;
    6) peerswap_menu; menu_peerswap ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_peerswap ;;
  esac
}

menu() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                          🇧🇷 BRLN-OS 🇧🇷                          ║"
  echo "║                      Bitcoin Lightning Node OS                       ║"
  echo "║                        Versão: $SCRIPT_VERSION                         ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
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