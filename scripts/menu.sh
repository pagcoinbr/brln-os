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



run_logs_and_config() {
  bash "$SCRIPT_DIR/scripts/logs-and-config.sh"
}

# Configuration functions for the Configuration submenu
run_utils() {
  echo -e "${GREEN}🛠️ Executando utilitários do sistema...${NC}"
  echo ""
  echo -e "${BLUE}📋 Opções disponíveis:${NC}"
  echo -e "${GREEN}1.${NC} Configurar Firewall (UFW)"
  echo -e "${GREEN}2.${NC} Limpar arquivos temporários"
  echo -e "${GREEN}3.${NC} Verificar status dos serviços"
  echo -e "${GREEN}4.${NC} Atualizar sistema"
  echo -e "${GREEN}5.${NC} Gerar Protocol Buffers"
  echo ""
  echo -n "Escolha uma opção (1-5): "
  read util_choice
  
  case $util_choice in
    1)
      echo -e "${YELLOW}🔒 Configurando Firewall...${NC}"
      configure_ufw
      echo -e "${GREEN}✅ Firewall configurado!${NC}"
      ;;
    2)
      echo -e "${YELLOW}🧹 Limpando arquivos temporários...${NC}"
      sudo apt autoremove -y && sudo apt autoclean
      echo -e "${GREEN}✅ Limpeza concluída!${NC}"
      ;;
    3)
      echo -e "${YELLOW}📊 Verificando status dos serviços...${NC}"
      systemctl status bitcoind lnd elementsd --no-pager -l || echo "Alguns serviços podem não estar instalados"
      echo -e "${GREEN}✅ Verificação concluída!${NC}"
      ;;
    4)
      echo -e "${YELLOW}🔄 Atualizando sistema...${NC}"
      update_and_upgrade
      echo -e "${GREEN}✅ Sistema atualizado!${NC}"
      ;;
    5)
      echo -e "${YELLOW}🔨 Gerando Protocol Buffers...${NC}"
      if [[ -f "$SCRIPT_DIR/scripts/gen-proto.sh" ]]; then
        cd "$SCRIPT_DIR"
        bash "scripts/gen-proto.sh"
        echo -e "${GREEN}✅ Protocol Buffers gerados!${NC}"
      else
        echo -e "${RED}❌ Arquivo gen-proto.sh não encontrado${NC}"
      fi
      ;;
    *)
      echo -e "${RED}❌ Opção inválida!${NC}"
      ;;
  esac
}

run_services_manager() {
  echo -e "${GREEN}⚙️ Gerenciador de Serviços BRLN-OS${NC}"
  echo ""
  echo -e "${BLUE}📋 Opções disponíveis:${NC}"
  echo -e "${GREEN}1.${NC} Listar todos os serviços disponíveis"
  echo -e "${GREEN}2.${NC} Criar todos os serviços"
  echo -e "${GREEN}3.${NC} Criar serviço específico"
  echo -e "${GREEN}4.${NC} Ver status dos serviços ativos"
  echo ""
  echo -n "Escolha uma opção (1-4): "
  read service_choice
  
  case $service_choice in
    1)
      echo ""
      bash "$SCRIPT_DIR/scripts/services.sh" list
      ;;
    2)
      echo ""
      echo -e "${YELLOW}⚠️ Isto criará TODOS os serviços systemd do BRLN-OS${NC}"
      echo -n "Continuar? (s/N): "
      read confirm
      if [[ "$confirm" =~ ^[Ss]$ ]]; then
        bash "$SCRIPT_DIR/scripts/services.sh" all
        sudo systemctl daemon-reload
        echo -e "${GREEN}✅ Todos os serviços criados!${NC}"
      fi
      ;;
    3)
      echo ""
      echo -e "${BLUE}Serviços disponíveis:${NC}"
      echo "bitcoind, lnd, elementsd, peerswapd, psweb, brln-api,"
      echo "gotty, bos-telegram, thunderhub, lnbits, lndg, lndg-controller, messager-monitor"
      echo ""
      echo -n "Digite o nome do serviço: "
      read service_name
      if [[ -n "$service_name" ]]; then
        bash "$SCRIPT_DIR/scripts/services.sh" create "$service_name"
        sudo systemctl daemon-reload
      fi
      ;;
    4)
      echo ""
      echo -e "${BLUE}📊 Status dos serviços BRLN-OS:${NC}"
      echo ""
      services=("bitcoind" "lnd" "elementsd" "peerswapd" "psweb" "brln-api" "gotty-fullauto" "bos-telegram" "thunderhub" "lnbits" "lndg" "lndg-controller" "messager-monitor")
      for service in "${services[@]}"; do
        status=$(systemctl is-active "$service" 2>/dev/null || echo "not-found")
        case "$status" in
          active) echo -e "  ${GREEN}●${NC} $service - ativo" ;;
          inactive) echo -e "  ${YELLOW}●${NC} $service - inativo" ;;
          failed) echo -e "  ${RED}●${NC} $service - falhou" ;;
          *) echo -e "  ${GRAY}●${NC} $service - não instalado" ;;
        esac
      done
      ;;
    *)
      echo -e "${RED}❌ Opção inválida${NC}"
      ;;
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
  echo -e "${GREEN}4.${NC} Instalar I2P"
  echo -e "${GREEN}5.${NC} Instalar Tailscale VPN"
  echo -e "${GREEN}6.${NC} Atualizar Sistema"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) configure_ufw; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    2) close_ports_except_ssh; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    3) install_tor; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    4) install_i2p; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    5) tailscale_vpn; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    6) update_and_upgrade; read -p "Pressione Enter para continuar..."; menu_system_tools ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_system_tools ;;
  esac
}

# Display banner
show_banner() {
    #clear
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

menu_configuration() {
 # clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                        ⚙️ CONFIGURAÇÕES ⚙️                        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Opções de Configuração ─┐${NC}"
  echo -e "${GREEN}1.${NC} 🛠️ Utilitários"
  echo -e "${GREEN}2.${NC} � Gerenciador de Senhas"
  echo -e "${GREEN}3.${NC} ⚙️ Gerenciar Serviços Systemd"
  echo -e "${GREEN}4.${NC} 📊 Logs e Configurações"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) run_utils; read -p "Pressione Enter para continuar..."; menu_configuration ;;
    2) source "$SCRIPT_DIR/scripts/password_manager_menu.sh"; show_password_menu; menu_configuration ;;
    3) run_services_manager; read -p "Pressione Enter para continuar..."; menu_configuration ;;
    4) run_logs_and_config; menu_configuration ;;
    0) menu ;;
    *) echo "Opção inválida!"; sleep 2; menu_configuration ;;
  esac
}

menu_utilities() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                    🔧 UTILITÁRIOS E MANUTENÇÃO 🔧                   ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Utilitários do Sistema ─┐${NC}"
  echo -e "${GREEN}1.${NC} 🔄 Atualizar Sistema"
  echo -e "${GREEN}2.${NC} 🧹 Limpar arquivos temporários"
  echo -e "${GREEN}3.${NC} 📋 Gerar/Atualizar Protobuf"
  echo -e "${GREEN}4.${NC} 🔍 Verificar status dos serviços"
  echo -e "${GREEN}5.${NC} 📊 Monitoramento de logs"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) update_and_upgrade; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    2) echo -e "${GREEN}🧹 Limpando arquivos temporários...${NC}"; sudo apt autoremove -y && sudo apt autoclean; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    3) cd "$SCRIPT_DIR" && if [[ -f "scripts/gen-proto.sh" ]]; then bash scripts/gen-proto.sh; else echo -e "${RED}❌ gen-proto.sh não encontrado${NC}"; fi; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    4) echo -e "${GREEN}📊 Status dos serviços:${NC}"; systemctl status bitcoind lnd elementsd --no-pager -l; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    5) echo -e "${GREEN}📋 Logs recentes:${NC}"; journalctl -u bitcoind -u lnd -u elementsd --since "1 hour ago" --no-pager; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    0) menu_configuration ;;
    *) echo "Opção inválida!"; sleep 2; menu_utilities ;;
  esac
}

menu() {
  #clear
  echo -e "${CYAN}"
  show_banner
  echo -e "${NC}"
  echo ""
  
  echo -e "${YELLOW}┌─ MENU PRINCIPAL ─┐${NC}"
  echo -e "${GREEN}1.${NC} 💰 Gerenciador de Carteiras"
  echo -e "${GREEN}2.${NC} ⚙️ Configurações"
  echo -e "${GREEN}3.${NC} 🛠️ Ferramentas do Sistema"
  echo -e "${GREEN}4.${NC} 🔧 Utilitários e Manutenção"
  echo ""
  echo -e "${RED}0.${NC} Sair"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) bash "$SCRIPT_DIR/scripts/wallet-manager.sh"; menu ;;
    2) menu_configuration ;;
    3) menu_system_tools ;;
    4) menu_utilities ;;
    0) echo -e "${GREEN}👋 Obrigado por usar BRLN-OS!${NC}"; exit 0 ;;
    *) echo "Opção inválida!"; sleep 2; menu ;;
  esac
}

menu

# ============================================================================
# RESUMO DO SCRIPT MENU.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Sistema de menus interativos que reúne todas as ferramentas e submenus do
#   BRLN-OS (configuração, serviços, manutenção, utilitários).
#
# CARACTERÍSTICAS:
# - Integra e chama scripts: apache.sh, gotty.sh, bitcoin.sh, lightning.sh,
#   elements.sh, peerswap.sh, system.sh, etc.
# - Fornece navegação por funções administrativas sem necessidade de lembrar
#   comandos diretos.
#
# USO:
# - Executar diretamente: bash scripts/menu.sh ou executar o binário principal
#   (brunel.sh) que chama este menu.
#
# ============================================================================