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

# Configuration functions for the Configuration submenu
run_utils() {
  echo -e "${GREEN}🛠️ Executando utilitários do sistema...${NC}"
  echo ""
  echo -e "${BLUE}📋 Opções disponíveis:${NC}"
  echo -e "${GREEN}1.${NC} Configurar Firewall (UFW)"
  echo -e "${GREEN}2.${NC} Limpar arquivos temporários"
  echo -e "${GREEN}3.${NC} Verificar status dos serviços"
  echo -e "${GREEN}4.${NC} Atualizar sistema"
  echo ""
  echo -n "Escolha uma opção (1-4): "
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
      systemctl status bitcoind lnd elementsd --no-pager -l 2>/dev/null || echo "Alguns serviços podem não estar instalados"
      echo -e "${GREEN}✅ Verificação concluída!${NC}"
      ;;
    4)
      echo -e "${YELLOW}🔄 Atualizando sistema...${NC}"
      update_and_upgrade
      echo -e "${GREEN}✅ Sistema atualizado!${NC}"
      ;;
    *)
      echo -e "${RED}❌ Opção inválida!${NC}"
      ;;
  esac
}

run_generate_protobuf() {
  echo -e "${GREEN}🗂️ Gerador de Protocol Buffers${NC}"
  echo ""
  
  # Verificar se os diretórios existem
  API_DIR="$SCRIPT_DIR/api/v1"
  PROTO_DIR="$API_DIR/proto"
  
  if [[ ! -d "$API_DIR" ]]; then
    echo -e "${RED}❌ Diretório da API não encontrado: $API_DIR${NC}"
    return 1
  fi
  
  if [[ ! -d "$PROTO_DIR" ]]; then
    echo -e "${RED}❌ Diretório proto não encontrado: $PROTO_DIR${NC}"
    return 1
  fi
  
  echo -e "${BLUE}📋 Opções de geração:${NC}"
  echo -e "${GREEN}1.${NC} Gerar usando generate-protobuf.sh (completo)"
  echo -e "${GREEN}2.${NC} Gerar usando gen-proto.sh (simples)"
  echo -e "${GREEN}3.${NC} Verificar arquivos proto existentes"
  echo ""
  echo -n "Escolha uma opção (1-3): "
  read proto_choice
  
  case $proto_choice in
    1)
      echo -e "${YELLOW}🔨 Executando geração completa...${NC}"
      if [[ -f "$SCRIPT_DIR/scripts/generate-protobuf.sh" ]]; then
        cd "$SCRIPT_DIR"
        bash "scripts/generate-protobuf.sh"
        echo -e "${GREEN}✅ Geração completa concluída!${NC}"
      else
        echo -e "${RED}❌ Arquivo generate-protobuf.sh não encontrado${NC}"
      fi
      ;;
    2)
      echo -e "${YELLOW}🔨 Executando geração simples...${NC}"
      if [[ -f "$SCRIPT_DIR/scripts/gen-proto.sh" ]]; then
        cd "$SCRIPT_DIR"
        bash "scripts/gen-proto.sh"
        echo -e "${GREEN}✅ Geração simples concluída!${NC}"
      else
        echo -e "${RED}❌ Arquivo gen-proto.sh não encontrado${NC}"
      fi
      ;;
    3)
      echo -e "${YELLOW}📁 Verificando arquivos proto...${NC}"
      echo -e "${BLUE}Arquivos .proto encontrados:${NC}"
      find "$PROTO_DIR" -name "*.proto" -type f 2>/dev/null | sed 's|.*/||' | sort || echo "Nenhum arquivo .proto encontrado"
      echo ""
      echo -e "${BLUE}Arquivos _pb2.py gerados:${NC}"
      find "$API_DIR" -name "*_pb2.py" -type f 2>/dev/null | sed 's|.*/||' | sort || echo "Nenhum arquivo _pb2.py encontrado"
      echo -e "${GREEN}✅ Verificação concluída!${NC}"
      ;;
    *)
      echo -e "${RED}❌ Opção inválida!${NC}"
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

menu_configuration() {
  clear
  echo -e "${CYAN}"
  echo "╔══════════════════════════════════════════════════════════════════════╗"
  echo "║                        ⚙️ CONFIGURAÇÕES ⚙️                        ║"
  echo "╚══════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo -e "${YELLOW}┌─ Opções de Configuração ─┐${NC}"
  echo -e "${GREEN}1.${NC} 🛠️ Utilitários"
  echo -e "${GREEN}2.${NC} 🗂️ Gerar Protocol Buffers"
  echo -e "${GREEN}3.${NC} 🔐 Gerenciador de Senhas"
  echo ""
  echo -e "${BLUE}0.${NC} Voltar ao menu principal"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) run_utils; read -p "Pressione Enter para continuar..."; menu_configuration ;;
    2) run_generate_protobuf; read -p "Pressione Enter para continuar..."; menu_configuration ;;
    3) source "$SCRIPT_DIR/scripts/password_manager_menu.sh"; show_password_menu; menu_configuration ;;
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
    3) cd "$SCRIPT_DIR" && if [[ -f "scripts/gen-proto.sh" ]]; then bash scripts/gen-proto.sh; elif [[ -f "scripts/generate-protobuf.sh" ]]; then bash scripts/generate-protobuf.sh; fi; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    4) echo -e "${GREEN}📊 Status dos serviços:${NC}"; systemctl status bitcoind lnd elementsd --no-pager -l; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    5) echo -e "${GREEN}📋 Logs recentes:${NC}"; journalctl -u bitcoind -u lnd -u elementsd --since "1 hour ago" --no-pager; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    0) menu_configuration ;;
    *) echo "Opção inválida!"; sleep 2; menu_utilities ;;
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
    3) cd "$SCRIPT_DIR" && if [[ -f "scripts/gen-proto.sh" ]]; then bash scripts/gen-proto.sh; elif [[ -f "scripts/generate-protobuf.sh" ]]; then bash scripts/generate-protobuf.sh; fi; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    4) echo -e "${GREEN}📊 Status dos serviços:${NC}"; systemctl status bitcoind lnd elementsd --no-pager -l; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    5) echo -e "${GREEN}📋 Logs recentes:${NC}"; journalctl -u bitcoind -u lnd -u elementsd --since "1 hour ago" --no-pager; read -p "Pressione Enter para continuar..."; menu_utilities ;;
    0) menu_configuration ;;
    *) echo "Opção inválida!"; sleep 2; menu_utilities ;;
  esac
}

install_complete_system() {
  echo -e "${GREEN}🚀 Iniciando instalação completa do sistema...${NC}"
  echo -e "${BLUE}📋 Executando scripts na ordem correta...${NC}"
  
  # Detect if running from web terminal (GoTTY)
  SKIP_WEB_SERVICES=false
  if [[ -n "$GOTTY_CLIENT_ADDRESS" ]] || pgrep -f "gotty.*menu.sh" > /dev/null 2>&1; then
    SKIP_WEB_SERVICES=true
    echo -e "${YELLOW}⚠️  Detectado terminal web - Apache e GoTTY serão ignorados para evitar desconexão${NC}"
    sleep 2
  fi
  
  # Execute installation scripts in order
  echo -e "${YELLOW}⚙️ Configurando sistema...${NC}"
  update_and_upgrade
  
  if [[ "$SKIP_WEB_SERVICES" == "false" ]]; then
    echo -e "${YELLOW}🌐 Configurando Apache...${NC}"
    setup_apache_web
  else
    echo -e "${BLUE}⏭️  Pulando configuração do Apache (já em execução)${NC}"
  fi
  
  echo -e "${YELLOW}₿ Instalando Bitcoin & Lightning...${NC}"
  install_complete_stack
  
  echo -e "${YELLOW}🔧 Gerando protobuf...${NC}"
  cd "$SCRIPT_DIR"
  if [[ -f "$SCRIPT_DIR/scripts/gen-proto.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/gen-proto.sh"
  elif [[ -f "$SCRIPT_DIR/scripts/generate-protobuf.sh" ]]; then
    bash "$SCRIPT_DIR/scripts/generate-protobuf.sh"
  fi
  
  if [[ "$SKIP_WEB_SERVICES" == "false" ]]; then
    echo -e "${YELLOW}💻 Configurando terminal web...${NC}"
    terminal_web
  else
    echo -e "${BLUE}⏭️  Pulando configuração do terminal web (já em execução)${NC}"
  fi
  
  echo -e "${YELLOW}🔥 Instalando Elements...${NC}"
  install_elements
  configure_elements
  create_elements_service
  
  echo -e "${YELLOW}⚡ Configurando Lightning Apps...${NC}"
  install_bos
  install_thunderhub
  lnbits_install
  install_brln_api
  
  echo -e "${YELLOW}🔄 Instalando PeerSwap...${NC}"
  install_peerswap
  
  echo -e "${GREEN}✅ Instalação completa finalizada!${NC}"
  read -p "Pressione Enter para continuar..."
}

menu() {
  clear
  echo -e "${CYAN}"
  show_banner
  echo -e "${NC}"
  echo ""
  
  # Check if installation directories exist
  local install_disabled=false
  if [[ -d "/data/lnd" && -d "/data/bitcoin" ]]; then
    install_disabled=true
  fi
  
  echo -e "${YELLOW}┌─ MENU PRINCIPAL ─┐${NC}"
  
  if [[ "$install_disabled" == true ]]; then
    echo -e "${GRAY}1.${NC} 🚀 Instalação Completa ${GRAY}(já realizada)${NC}"
  else
    echo -e "${GREEN}1.${NC} 🚀 Instalação Completa"
  fi
  
  echo -e "${GREEN}2.${NC} ⚙️ Configurações"
  echo ""
  echo -e "${RED}0.${NC} Sair"
  echo ""
  echo -n "Escolha uma opção: "
  
  read choice
  case $choice in
    1) 
      if [[ "$install_disabled" == true ]]; then
        echo -e "${YELLOW}⚠️ A instalação já foi realizada. Use a opção Configurações.${NC}"
        sleep 2
        menu
      else
        install_complete_system
        menu
      fi
      ;;
    2) menu_configuration ;;
    0) echo -e "${GREEN}👋 Obrigado por usar BRLN-OS!${NC}"; exit 0 ;;
    *) echo "Opção inválida!"; sleep 2; menu ;;
  esac
}

# Start the main menu
menu
  update_and_upgrade
}