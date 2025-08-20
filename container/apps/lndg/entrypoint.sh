#!/bin/bash

# Entrypoint script para LNDg
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Configurações
LND_RPC_HOST=${LND_RPC_HOST:-lnd:10009}
LND_NETWORK=${LND_NETWORK:-mainnet}
MAX_RETRIES=30
RETRY_INTERVAL=10

log "=== Iniciando LNDg ==="
log "LND RPC: $LND_RPC_HOST"
log "Network: $LND_NETWORK"

# Função para executar inicialização
run_initialize() {
    log "Executando inicialização do LNDg..."
    
    # Mudar para o diretório do LNDg
    cd /app/lndg
    
    # Criar virtual environment se não existir
    if [ ! -d ".venv" ]; then
        log "Criando virtual environment..."
        virtualenv -p python3 .venv
    fi
    
    # Instalar dependências no virtual environment
    log "Instalando dependências..."
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install -r requirements.txt
    .venv/bin/pip install whitenoise
    
    # Executar initialize.py usando o virtual environment
    log "Executando initialize.py..."
    if .venv/bin/python initialize.py -net "$LND_NETWORK" -rpc "$LND_RPC_HOST" -wn; then
        log "Initialize.py executado com sucesso!"
    else
        warning "Initialize.py falhou, mas continuando..."
    fi
    
    cd -
}

# Função para iniciar o servidor
start_server() {
    log "Iniciando servidor web LNDg na porta 8889..."
    cd /app/lndg
    exec .venv/bin/python manage.py runserver 0.0.0.0:8889
}

# Execução principal
main() {
    
    # Executar inicialização (não crítica)
    run_initialize
    
    # Aguardar um pouco antes de iniciar o servidor
    log "Aguardando 5 segundos antes de iniciar o servidor..."
    sleep 5
    
    # Iniciar servidor
    start_server
}

# Executar função principal
main "$@"
