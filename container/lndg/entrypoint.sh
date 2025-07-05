#!/bin/bash

set -e

# Função para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Aguarda o LND estar disponível
wait_for_lnd() {
    log "Aguardando LND estar disponível..."
    while ! nc -z lnd 10009; do
        log "LND não está disponível ainda, aguardando..."
        sleep 5
    done
    log "LND está disponível!"
}

# Aguarda o PostgreSQL estar disponível
wait_for_postgres() {
    log "Aguardando PostgreSQL estar disponível..."
    while ! nc -z postgres 5432; do
        log "PostgreSQL não está disponível ainda, aguardando..."
        sleep 5
    done
    log "PostgreSQL está disponível!"
}

# Configuração inicial
setup_lndg() {
    log "Configurando LNDG..."
    
    # Aguarda serviços dependentes
    wait_for_lnd
    wait_for_postgres
    
    # Cria diretório de dados se não existir
    mkdir -p /app/data
    
    # Verifica se já foi inicializado
    if [ ! -f "/app/data/.initialized" ]; then
        log "Primeira execução - inicializando LNDG..."
        
        # Executa inicialização com whitenoise
        python initialize.py --whitenoise \
            -net "${LND_NETWORK:-mainnet}" \
            -rpc "${LND_HOST:-lnd:10009}" \
            -db "${DB_HOST:-postgres}"
        
        # Marca como inicializado
        touch /app/data/.initialized
        log "LNDG inicializado com sucesso!"
    else
        log "LNDG já foi inicializado anteriormente."
    fi
}

# Inicia o controlador em background
start_controller() {
    log "Iniciando controlador LNDG..."
    python controller.py &
    CONTROLLER_PID=$!
    log "Controlador iniciado com PID: $CONTROLLER_PID"
}

# Inicia o servidor web
start_server() {
    log "Iniciando servidor web LNDG na porta 8889..."
    exec python manage.py runserver 0.0.0.0:8889
}

# Função de cleanup
cleanup() {
    log "Recebido sinal de término, encerrando processos..."
    if [ ! -z "$CONTROLLER_PID" ]; then
        kill $CONTROLLER_PID 2>/dev/null || true
    fi
    exit 0
}

# Configura handler para sinais
trap cleanup SIGTERM SIGINT

# Executa configuração
setup_lndg

# Inicia controlador
start_controller

# Inicia servidor (processo principal)
start_server
