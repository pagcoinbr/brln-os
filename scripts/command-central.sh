#! /bin/bash

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

# Função para alterar a rede Bitcoin/LND
change_network() {
    local current_network
    local bitcoin_conf="/data/bitcoin/bitcoin.conf"
    local lnd_conf="/data/lnd/lnd.conf"
    local env_file="$(dirname "$0")/../container/.env"
    
    echo
    warning "🔧 Alteração de Rede Bitcoin/LND"
    echo
    
    # Detectar rede atual
    if grep -q "testnet=1" "$bitcoin_conf" 2>/dev/null; then
        current_network="testnet"
    else
        current_network="mainnet"
    fi
    
    info "Rede atual: $current_network"
    echo
    
    info "Escolha a nova rede:"
    info "   1- Mainnet (rede principal)"
    info "   2- Testnet (rede de teste)"
    error "   0- Voltar ao menu"
    echo
    
    read -p "👉 Digite sua escolha: " network_choice
    echo
    
    case $network_choice in
        1)
            if [[ "$current_network" == "mainnet" ]]; then
                warning "⚠️  Já está configurado para mainnet!"
                return
            fi
            new_network="mainnet"
            ;;
        2)
            if [[ "$current_network" == "testnet" ]]; then
                warning "⚠️  Já está configurado para testnet!"
                return
            fi
            new_network="testnet"
            ;;
        0)
            return
            ;;
        *)
            error "❌ Opção inválida!"
            return
            ;;
    esac
    
    echo
    warning "⚠️  ATENÇÃO: Esta operação irá:"
    warning "   • Parar todos os containers relacionados"
    warning "   • Alterar as configurações de rede"
    warning "   • Reiniciar os serviços"
    warning "   • Pode demorar alguns minutos"
    echo
    
    read -p "👉 Deseja continuar? (s/N): " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        info "Operação cancelada."
        return
    fi
    
    echo
    log "🔄 Iniciando alteração para $new_network..."
    
    # Parar containers
    log "Parando containers..."
    cd "$(dirname "$0")/../container"
    sudo docker-compose down
    
    # Atualizar arquivo .env
    if [[ -f "$env_file" ]]; then
        sed -i "s/BITCOIN_NETWORK=.*/BITCOIN_NETWORK=$new_network/" "$env_file"
    else
        echo "BITCOIN_NETWORK=$new_network" > "$env_file"
    fi
    
    # Executar script de mudança de rede
    local network_script="$(dirname "$0")/switch-network.sh"
    if [[ -f "$network_script" ]]; then
        log "Executando script de mudança de rede..."
        bash "$network_script" "$new_network"
    else
        error "Script switch-network.sh não encontrado!"
        return 1
    fi
    
    # Reiniciar containers
    log "Reiniciando containers..."
    sudo docker-compose up -d bitcoin lnd
    
    echo
    success "✅ Rede alterada para $new_network com sucesso!"
    warning "⏳ Os containers podem levar alguns minutos para sincronizar."
    echo
    
    read -p "Pressione Enter para continuar..."
}

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
  info "   8- Alterar Rede (Mainnet/Testnet)"
  info "   9- Desempenho"
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
      change_network
      menu
      ;;
    9)
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
