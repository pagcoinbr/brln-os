#! /bin/bash

# Source das funções básicas
source "$(dirname "$0")/basic.sh"
basics

sudo -v
menu() {
  echo
  warning " ⚙️  Configurações:"
  echo
  info "   1- Terminal (Bash)"
  info "   2- Logs do Bitcoin Core"
  info "   3- Logs do LND"
  info "   4- Logs do Elements"
  info "   5- Editar lnd.conf"
  info "   6- Editar bitcoin.conf"
  info "   7- Editar elements.conf"
  info "   8- Desempenho"
  error "   0- Sair"
  echo 
  log " $SCRIPT_VERSION "
  echo
  read -p "👉   Digite sua escolha:   " option
  echo

  case $option in
    1)
      sudo -u $USER bash
      menu      
      ;;

    2)
      app="bitcoin"
      sudo docker logs $app -f
      menu
      ;;
    3)
      app="lnd"
      sudo docker logs $app -f
      menu
      ;;
    4)
      app="elements"
      sudo docker logs $app -f
      menu
      ;;
    5)
      app="lnd"
      sudo bash nano
      sudo docker restart $app
      menu
      ;;
    6)
      app="bitcoin"
      sudo bash nano
      sudo docker restart $app
      menu
      ;;
    7)
      app="elements"
      sudo bash nano
      sudo docker restart $app
      menu
      ;;
    8)
      sudo bash btop
      menu
      ;;
    0)
      echo -e "${MAGENTA}👋 Saindo... Até a próxima!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      ;;
    esac
  }

system_detector
ip_finder
menu
