#!/bin/bash

# Script de entrypoint para ThunderHub
set -e

# Configurações
THUNDERHUB_DIR="/home/thunderhub/thunderhub"
CONFIG_DIR="/data/thunderhub/config"
LOG_DIR="/data/thunderhub/logs"
ENV_FILE="${THUNDERHUB_DIR}/.env.local"
CONFIG_FILE="${CONFIG_DIR}/thubConfig.yaml"
LND_DIR="/data/lnd"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ThunderHub: $1${NC}"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] ThunderHub: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] ThunderHub: $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] ThunderHub: $1${NC}"
}

# Função para configurar ThunderHub
configure_thunderhub() {
    log "Configurando ThunderHub..."
    
    # Criar diretórios se não existirem
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${LOG_DIR}"
    
    # Obter configurações do ambiente
    LND_HOST="${LND_HOST:-lnd}"
    LND_PORT="${LND_PORT:-10009}"
    LND_NETWORK="${LND_NETWORK:-mainnet}"
    THUB_PASSWORD="${THUB_PASSWORD:-changeme123}"
    
    # Criar arquivo .env.local se não existir
    if [[ ! -f "${ENV_FILE}" ]]; then
        log "Criando arquivo de configuração ambiente..."
        cat > "${ENV_FILE}" <<EOF
PORT=${THUNDERHUB_PORT}
ACCOUNT_CONFIG_PATH="${CONFIG_FILE}"
LOG_LEVEL=info
NODE_ENV=production
EOF
    fi
    
    # Criar arquivo de configuração de contas
    log "Criando configuração de contas..."
    cat > "${CONFIG_FILE}" <<EOF
masterPassword: '${THUB_PASSWORD}'
accounts:
  - name: 'BRLNBolt'
    serverUrl: '${LND_HOST}:${LND_PORT}'
    macaroonPath: '${LND_DIR}/data/chain/bitcoin/${LND_NETWORK}/admin.macaroon'
    certificatePath: '${LND_DIR}/tls.cert'
    password: '${THUB_PASSWORD}'
EOF

    log "ThunderHub configurado!"
}

# Função para verificar configuração
check_configuration() {
    log "Verificando configuração..."
    
    # Obter configurações do ambiente
    LND_NETWORK="${LND_NETWORK:-mainnet}"
    
    # Verificar se os arquivos do LND existem
    log "Verificando certificado TLS: ${LND_DIR}/tls.cert"
    if [[ ! -f "${LND_DIR}/tls.cert" ]]; then
        error "Certificado TLS do LND não encontrado: ${LND_DIR}/tls.cert"
        ls -la "${LND_DIR}/" || true
        return 1
    fi
    
    log "Verificando macaroon: ${LND_DIR}/data/chain/bitcoin/${LND_NETWORK}/admin.macaroon"
    if [[ ! -f "${LND_DIR}/data/chain/bitcoin/${LND_NETWORK}/admin.macaroon" ]]; then
        error "Macaroon do LND não encontrado: ${LND_DIR}/data/chain/bitcoin/${LND_NETWORK}/admin.macaroon"
        ls -la "${LND_DIR}/data/chain/bitcoin/${LND_NETWORK}/" || true
        return 1
    fi
    
    # Verificar se o arquivo de configuração foi criado
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        error "Arquivo de configuração não encontrado: ${CONFIG_FILE}"
        return 1
    fi
    
    log "Configuração verificada com sucesso!"
    log "Conteúdo do arquivo de configuração:"
    cat "${CONFIG_FILE}"
}

# Função para iniciar ThunderHub
start_thunderhub() {
    log "Iniciando ThunderHub..."
    
    cd "${THUNDERHUB_DIR}"
    
    # Definir variáveis de ambiente
    export NODE_ENV=production
    export PORT=${THUNDERHUB_PORT}
    export ACCOUNT_CONFIG_PATH="${CONFIG_FILE}"
    export LOG_LEVEL=info
    
    # Iniciar ThunderHub
    exec npm start
}

# Função principal
main() {
    log "=== Iniciando ThunderHub ==="
    
    # Configurar ThunderHub
    configure_thunderhub
    
    # Verificar configuração
    check_configuration
    
    # Iniciar ThunderHub
    start_thunderhub
}

# Trap para limpeza
cleanup() {
    log "Parando ThunderHub..."
    exit 0
}

trap cleanup SIGTERM SIGINT

# Executar função principal
main "$@"