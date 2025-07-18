#!/bin/bash

# Script para alterar a rede Bitcoin do sistema BRLN-OS
# Este script permite trocar entre testnet e mainnet

# Source das funções básicas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

# Verificar se as funções básicas estão disponíveis
if ! type basics &>/dev/null; then
    echo "❌ Erro: Funções básicas não encontradas. Execute este script do diretório scripts/"
    exit 1
fi

basics

REPO_DIR="/home/$USER/brln-os"

# Função para exibir status atual
show_current_status() {
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "📊 Status Atual da Configuração de Rede"
    info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Verificar arquivo .env
    if [[ -f "$REPO_DIR/container/.env" ]]; then
        current_network=$(grep "BITCOIN_NETWORK=" "$REPO_DIR/container/.env" | cut -d'=' -f2)
        log "🔗 Rede configurada no .env: $current_network"
    else
        warning "⚠️  Arquivo .env não encontrado"
        current_network="não definida"
    fi
    
    # Verificar lnd.conf
    if [[ -f "$REPO_DIR/container/lnd/lnd.conf" ]]; then
        mainnet_status=$(grep "bitcoin.mainnet=" "$REPO_DIR/container/lnd/lnd.conf" 2>/dev/null || echo "não encontrado")
        testnet_status=$(grep "bitcoin.testnet=" "$REPO_DIR/container/lnd/lnd.conf" 2>/dev/null || echo "não encontrado")
        log "🔧 LND mainnet: $mainnet_status"
        log "🔧 LND testnet: $testnet_status"
    else
        warning "⚠️  Arquivo lnd.conf não encontrado"
    fi
    
    # Status dos containers
    echo ""
    log "📦 Status dos containers:"
    if command -v docker &> /dev/null; then
        lnd_status=$(docker ps --filter "name=lnd" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tail -n +2 || echo "Não rodando")
        bitcoin_status=$(docker ps --filter "name=bitcoin" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | tail -n +2 || echo "Não rodando")
        
        if [[ -n "$lnd_status" ]]; then
            log "   LND: $lnd_status"
        else
            info "   LND: Não rodando"
        fi
        
        if [[ -n "$bitcoin_status" ]]; then
            log "   Bitcoin: $bitcoin_status"
        else
            info "   Bitcoin: Não rodando"
        fi
    else
        warning "   Docker não está disponível"
    fi
    echo ""
}

# Função para alterar rede
change_network() {
    echo ""
    info "═══════════════════════════════════════════════════════════════"
    log "🔄 Alteração da Rede Bitcoin"
    info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    echo "Escolha a nova rede:"
    echo ""
    echo "1. 🧪 TESTNET (Rede de testes)"
    echo "   • Bitcoins sem valor real"
    echo "   • Perfeito para testes e aprendizado"
    echo ""
    echo "2. 💰 MAINNET (Rede principal)"
    echo "   • Bitcoins com valor real"
    echo "   • Requer máxima segurança"
    echo ""
    
    while true; do
        read -p "Escolha a rede (1 para TESTNET, 2 para MAINNET): " -n 1 -r
        echo
        
        case $REPLY in
            "1" )
                new_network="testnet"
                log "🧪 TESTNET selecionada"
                break
                ;;
            "2" )
                new_network="mainnet"
                warning "⚠️  ATENÇÃO: MAINNET selecionada!"
                warning "• Os bitcoins terão valor monetário REAL"
                warning "• Mantenha suas chaves privadas SEGURAS"
                echo ""
                read -p "Você tem certeza que deseja usar MAINNET? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    break
                else
                    echo "Operação cancelada. Escolha novamente."
                    continue
                fi
                ;;
            * )
                echo "Por favor, escolha 1 para TESTNET ou 2 para MAINNET."
                ;;
        esac
    done
    
    # Verificar se já está na rede escolhida
    current_network=""
    if [[ -f "$REPO_DIR/container/.env" ]]; then
        current_network=$(grep "BITCOIN_NETWORK=" "$REPO_DIR/container/.env" | cut -d'=' -f2)
    fi
    
    if [[ "$current_network" == "$new_network" ]]; then
        log "ℹ️  Sistema já está configurado para $new_network"
        read -p "Deseja reconfigurar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Operação cancelada"
            return
        fi
    fi
    
    # Aplicar alterações
    apply_network_change "$new_network"
}

# Função para aplicar a mudança de rede
apply_network_change() {
    local target_network="$1"
    
    echo ""
    log "🔧 Aplicando alteração para $target_network..."
    
    # Parar containers se estiverem rodando
    log "🛑 Parando containers..."
    cd "$REPO_DIR/container"
    sudo docker-compose down lnd bitcoin 2>/dev/null || true
    
    # Atualizar .env
    echo "BITCOIN_NETWORK=$target_network" > ".env"
    log "✅ Arquivo .env atualizado"
    
    # Atualizar lnd.conf
    if [[ -f "lnd/lnd.conf" ]]; then
        log "🔧 Atualizando lnd.conf..."
        if [[ "$target_network" == "mainnet" ]]; then
            sed -i 's/bitcoin.mainnet=false/bitcoin.mainnet=true/' "lnd/lnd.conf"
            sed -i 's/bitcoin.testnet=true/bitcoin.testnet=false/' "lnd/lnd.conf"
            # Ajustar portas ZMQ para mainnet
            sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/" "lnd/lnd.conf" 2>/dev/null || true
            sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/" "lnd/lnd.conf" 2>/dev/null || true
        else
            sed -i 's/bitcoin.mainnet=true/bitcoin.mainnet=false/' "lnd/lnd.conf"
            sed -i 's/bitcoin.testnet=false/bitcoin.testnet=true/' "lnd/lnd.conf"
            # Ajustar portas ZMQ para testnet
            sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/" "lnd/lnd.conf" 2>/dev/null || true
            sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/" "lnd/lnd.conf" 2>/dev/null || true
        fi
        log "✅ lnd.conf atualizado"
    else
        warning "⚠️  Arquivo lnd.conf não encontrado"
    fi
    
    # Atualizar bitcoin.conf se necessário (para instalação local)
    if [[ -f "bitcoin/bitcoin.conf" ]]; then
        log "🔧 Atualizando bitcoin.conf..."
        if [[ "$target_network" == "mainnet" ]]; then
            if [[ -f "bitcoin/bitcoin.conf.mainnet.example" ]]; then
                cp "bitcoin/bitcoin.conf.mainnet.example" "bitcoin/bitcoin.conf"
                log "✅ bitcoin.conf configurado para mainnet"
            fi
        else
            if [[ -f "bitcoin/bitcoin.conf.testnet.example" ]]; then
                cp "bitcoin/bitcoin.conf.testnet.example" "bitcoin/bitcoin.conf"
                log "✅ bitcoin.conf configurado para testnet"
            fi
        fi
    fi
    
    echo ""
    log "🚀 Alteração concluída para $target_network!"
    echo ""
    warning "⚠️  IMPORTANTE:"
    warning "• Os containers foram parados"
    warning "• Você precisa reiniciar os serviços manualmente"
    warning "• Se mudou de testnet para mainnet, a sincronização será mais lenta"
    warning "• Se mudou de mainnet para testnet, os dados da wallet mainnet ficam preservados"
    echo ""
    
    read -p "Deseja iniciar os containers agora? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "🚀 Iniciando containers..."
        sudo docker-compose up -d bitcoin lnd
        log "✅ Containers iniciados!"
        echo ""
        info "💡 Use 'docker logs -f lnd' para acompanhar os logs do LND"
        info "💡 Use 'docker logs -f bitcoin' para acompanhar os logs do Bitcoin"
    else
        info "💡 Para iniciar os containers manualmente:"
        echo "   cd $REPO_DIR/container"
        echo "   sudo docker-compose up -d bitcoin lnd"
    fi
}

# Função principal
main() {
    echo ""
    info "🔗 Gerenciador de Rede Bitcoin BRLN-OS"
    echo ""
    
    show_current_status
    
    echo ""
    echo "O que você deseja fazer?"
    echo ""
    echo "1. 📊 Ver status atual"
    echo "2. 🔄 Alterar rede"
    echo "3. ❌ Sair"
    echo ""
    
    while true; do
        read -p "Escolha uma opção (1-3): " -n 1 -r
        echo
        
        case $REPLY in
            "1" )
                show_current_status
                ;;
            "2" )
                change_network
                break
                ;;
            "3" )
                log "👋 Saindo..."
                break
                ;;
            * )
                echo "Por favor, escolha uma opção válida (1-3)."
                ;;
        esac
    done
}

# Verificar se o script está sendo executado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
