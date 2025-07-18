#!/bin/bash

# Script para alternar entre mainnet e testnet
# Uso: ./switch-network.sh [mainnet|testnet]

set -e

# Source das funções básicas
source "$(dirname "$0")/.env" 2>/dev/null || {
    log() { echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    error() { echo -e "\033[0;31m[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    warning() { echo -e "\033[1;33m[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    success() { echo -e "\033[0;32m[SUCCESS $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
}

# Verificar parâmetros
if [[ $# -ne 1 ]]; then
    error "Uso: $0 [mainnet|testnet]"
    exit 1
fi

NETWORK="$1"
BITCOIN_CONF="/data/bitcoin/bitcoin.conf"
LND_CONF="/data/lnd/lnd.conf"

# Validar rede
if [[ "$NETWORK" != "mainnet" && "$NETWORK" != "testnet" ]]; then
    error "Rede inválida: $NETWORK. Use 'mainnet' ou 'testnet'"
    exit 1
fi

log "Configurando para rede: $NETWORK"

# Função para configurar bitcoin.conf
configure_bitcoin() {
    log "Configurando bitcoin.conf para $NETWORK..."
    
    # Fazer backup
    cp "$BITCOIN_CONF" "$BITCOIN_CONF.backup.$(date +%s)"
    
    if [[ "$NETWORK" == "mainnet" ]]; then
        # Configurar para mainnet
        sed -i 's/testnet=1/# testnet=1/' "$BITCOIN_CONF"
        sed -i 's/^bind=0.0.0.0:18333/bind=0.0.0.0:8333/' "$BITCOIN_CONF"
        sed -i 's/^rpcport=18332/rpcport=8332/' "$BITCOIN_CONF"
        sed -i 's/^rpcbind=0.0.0.0:18332/rpcbind=0.0.0.0:8332/' "$BITCOIN_CONF"
        sed -i 's/^zmqpubrawblock=tcp:\/\/0.0.0.0:28432/zmqpubrawblock=tcp:\/\/0.0.0.0:28332/' "$BITCOIN_CONF"
        sed -i 's/^zmqpubrawtx=tcp:\/\/0.0.0.0:28433/zmqpubrawtx=tcp:\/\/0.0.0.0:28333/' "$BITCOIN_CONF"
        
        # Remover seção [test] se existir
        sed -i '/^\[test\]/,/^$/d' "$BITCOIN_CONF"
        
    else
        # Configurar para testnet
        sed -i 's/# testnet=1/testnet=1/' "$BITCOIN_CONF"
        if ! grep -q "testnet=1" "$BITCOIN_CONF"; then
            echo "testnet=1" >> "$BITCOIN_CONF"
        fi
        
        sed -i 's/^bind=0.0.0.0:8333/bind=0.0.0.0:18333/' "$BITCOIN_CONF"
        sed -i 's/^rpcport=8332/rpcport=18332/' "$BITCOIN_CONF"
        sed -i 's/^rpcbind=0.0.0.0:8332/rpcbind=0.0.0.0:18332/' "$BITCOIN_CONF"
        sed -i 's/^zmqpubrawblock=tcp:\/\/0.0.0.0:28332/zmqpubrawblock=tcp:\/\/0.0.0.0:28432/' "$BITCOIN_CONF"
        sed -i 's/^zmqpubrawtx=tcp:\/\/0.0.0.0:28333/zmqpubrawtx=tcp:\/\/0.0.0.0:28433/' "$BITCOIN_CONF"
        
        # Adicionar seção [test] se não existir
        if ! grep -q "^\[test\]" "$BITCOIN_CONF"; then
            cat >> "$BITCOIN_CONF" << EOF

# Configurações específicas para testnet
[test]
# P2P bind (testnet default port is 18333)
bind=0.0.0.0:18333

# RPC Configuration for Testnet
# RPC port for testnet (default: 18332)
rpcport=18332
rpcbind=0.0.0.0:18332
rpcallowip=0.0.0.0/0

# ZMQ settings (testnet ports)
zmqpubrawblock=tcp://0.0.0.0:28432
zmqpubrawtx=tcp://0.0.0.0:28433
EOF
        fi
    fi
    
    success "bitcoin.conf configurado para $NETWORK"
}

# Função para configurar lnd.conf
configure_lnd() {
    log "Configurando lnd.conf para $NETWORK..."
    
    # Fazer backup
    cp "$LND_CONF" "$LND_CONF.backup.$(date +%s)"
    
    if [[ "$NETWORK" == "mainnet" ]]; then
        # Configurar para mainnet
        sed -i 's/bitcoin.mainnet=false/bitcoin.mainnet=true/' "$LND_CONF"
        sed -i 's/bitcoin.testnet=true/bitcoin.testnet=false/' "$LND_CONF"
        
        # Ajustar portas ZMQ para mainnet
        sed -i 's/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/' "$LND_CONF"
        sed -i 's/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/' "$LND_CONF"
        
    else
        # Configurar para testnet
        sed -i 's/bitcoin.mainnet=true/bitcoin.mainnet=false/' "$LND_CONF"
        sed -i 's/bitcoin.testnet=false/bitcoin.testnet=true/' "$LND_CONF"
        
        # Ajustar portas ZMQ para testnet
        sed -i 's/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/' "$LND_CONF"
        sed -i 's/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/' "$LND_CONF"
    fi
    
    success "lnd.conf configurado para $NETWORK"
}

# Função para configurar docker-compose
configure_docker_compose() {
    local env_file="$(dirname "$0")/../container/.env"
    log "Configurando variável de ambiente BITCOIN_NETWORK..."
    
    # Criar ou atualizar arquivo .env
    if [[ -f "$env_file" ]]; then
        sed -i "s/BITCOIN_NETWORK=.*/BITCOIN_NETWORK=$NETWORK/" "$env_file"
    else
        echo "BITCOIN_NETWORK=$NETWORK" > "$env_file"
    fi
    
    success "Variável BITCOIN_NETWORK configurada para $NETWORK"
}

# Executar configurações
main() {
    log "=== Iniciando mudança de rede para $NETWORK ==="
    
    # Verificar se os arquivos de configuração existem
    if [[ ! -f "$BITCOIN_CONF" ]]; then
        error "Arquivo bitcoin.conf não encontrado: $BITCOIN_CONF"
        exit 1
    fi
    
    if [[ ! -f "$LND_CONF" ]]; then
        error "Arquivo lnd.conf não encontrado: $LND_CONF"
        exit 1
    fi
    
    configure_bitcoin
    configure_lnd
    configure_docker_compose
    
    echo
    success "✅ Configuração de rede alterada para $NETWORK com sucesso!"
    warning "⚠️  Lembre-se de reiniciar os containers para aplicar as mudanças:"
    warning "   cd container && sudo docker-compose restart bitcoin lnd"
    echo
}

# Executar função principal
main "$@"
