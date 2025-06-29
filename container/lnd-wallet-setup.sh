#!/bin/bash

# Script para configuração automática da carteira LND
# Monitora os logs do container LND e executa criação da carteira quando necessário

set -e

# Configurações
CONTAINER_NAME="lnd"
PASSWORD_FILE="/home/admin/brlnfullauto/container/password.txt"
LOG_FILE="/tmp/lnd-setup.log"
WALLET_SEED_FILE="/tmp/lnd-wallet-seed.txt"
MAX_WAIT_TIME=300  # 5 minutos máximo de espera
CHECK_INTERVAL=5   # Verifica a cada 5 segundos

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Verificar se Docker está instalado e rodando
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker não está instalado!"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        error "Docker não está rodando!"
        exit 1
    fi
    
    # Verificar se Docker Compose está disponível
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose não está instalado!"
        exit 1
    fi
    
    # Verificar se o arquivo de senha existe
    if [[ ! -f "$PASSWORD_FILE" ]]; then
        error "Arquivo de senha não encontrado: $PASSWORD_FILE"
        exit 1
    fi
    
    # Verificar se expect está instalado (para automação interativa)
    if ! command -v expect >/dev/null 2>&1; then
        warning "Expect não está instalado. Instalando..."
        sudo apt-get update && sudo apt-get install -y expect
    fi
    
    # Verificar se jq está instalado (para parsing JSON)
    if ! command -v jq >/dev/null 2>&1; then
        warning "jq não está instalado. Instalando..."
        sudo apt-get update && sudo apt-get install -y jq
    fi
    
    log "Todas as dependências estão OK!"
}

# Função para verificar se o container está rodando
check_container_status() {
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        error "Container ${CONTAINER_NAME} não está rodando!"
        return 1
    fi
    return 0
}

# Função para monitorar logs do LND
monitor_lnd_logs() {
    log "Monitorando logs do LND para detectar necessidade de criação de carteira..."
    
    local wait_time=0
    local wallet_created=false
    local wallet_unlocked=false
    
    while [[ $wait_time -lt $MAX_WAIT_TIME ]]; do
        if ! check_container_status; then
            error "Container parou de funcionar!"
            return 1
        fi
        
        # Capturar logs recentes
        local recent_logs=$(docker logs --tail 20 "$CONTAINER_NAME" 2>&1)
        
        # Verificar se precisa criar carteira
        if echo "$recent_logs" | grep -q "Waiting for wallet encryption password"; then
            if [[ "$wallet_created" == false ]]; then
                log "LND está esperando criação de carteira. Iniciando processo..."
                create_wallet
                wallet_created=true
                continue
            fi
        fi
        
        # Verificar se precisa desbloquear carteira
        if echo "$recent_logs" | grep -q "Waiting for wallet unlock"; then
            if [[ "$wallet_unlocked" == false ]]; then
                log "LND está esperando desbloqueio de carteira. Desbloqueando..."
                unlock_wallet
                wallet_unlocked=true
                continue
            fi
        fi
        
        # Verificar se LND está funcionando corretamente
        if echo "$recent_logs" | grep -q "LND successfully started"; then
            log "LND foi iniciado com sucesso!"
            return 0
        fi
        
        # Verificar se há erros críticos
        if echo "$recent_logs" | grep -q "fatal\|panic\|unable to start"; then
            error "Erro crítico detectado nos logs do LND:"
            echo "$recent_logs" | grep -E "fatal|panic|unable to start" | tail -5
            return 1
        fi
        
        info "Aguardando LND inicializar... (${wait_time}s/${MAX_WAIT_TIME}s)"
        sleep $CHECK_INTERVAL
        wait_time=$((wait_time + CHECK_INTERVAL))
    done
    
    error "Timeout: LND não iniciou dentro do tempo esperado"
    return 1
}

# Função para criar carteira
create_wallet() {
    log "Criando nova carteira LND..."
    
    local password=$(cat "$PASSWORD_FILE" | tr -d '\n\r')
    
    # Script expect para automação da criação de carteira
    expect << EOF
set timeout 60
spawn docker exec -it $CONTAINER_NAME /opt/lnd/lncli create
expect "Input wallet password:"
send "$password\r"
expect "Confirm password:"
send "$password\r"
expect "Do you have an existing cipher seed mnemonic you want to use?"
send "n\r"
expect "Your cipher seed can optionally be encrypted."
send "n\r"
expect {
    "!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!" {
        log_file $WALLET_SEED_FILE
        expect "Your cipher seed is:"
        expect -re "(\[0-9\]+: \[a-z\]+ *)+"
        log_file
        send "\r"
        exp_continue
    }
    "wallet already exists" {
        send_user "Carteira já existe, tentando desbloquear...\n"
    }
}
expect eof
EOF

    if [[ $? -eq 0 ]]; then
        log "Carteira criada com sucesso!"
        if [[ -f "$WALLET_SEED_FILE" ]]; then
            warning "IMPORTANTE: Seed da carteira salva em $WALLET_SEED_FILE"
            warning "FAÇA BACKUP DESTA SEED IMEDIATAMENTE!"
        fi
    else
        error "Falha ao criar carteira"
        return 1
    fi
}

# Função para desbloquear carteira
unlock_wallet() {
    log "Desbloqueando carteira LND..."
    
    local password=$(cat "$PASSWORD_FILE" | tr -d '\n\r')
    
    # Script expect para automação do desbloqueio
    expect << EOF
set timeout 30
spawn docker exec -it $CONTAINER_NAME /opt/lnd/lncli unlock
expect "Input wallet password:"
send "$password\r"
expect eof
EOF

    if [[ $? -eq 0 ]]; then
        log "Carteira desbloqueada com sucesso!"
    else
        error "Falha ao desbloquear carteira"
        return 1
    fi
}

# Função para verificar status do LND após setup
verify_lnd_status() {
    log "Verificando status do LND..."
    
    sleep 10  # Aguardar LND inicializar completamente
    
    if docker exec "$CONTAINER_NAME" /opt/lnd/lncli getinfo >/dev/null 2>&1; then
        log "LND está funcionando corretamente!"
        
        # Mostrar informações básicas
        info "Informações do nó:"
        docker exec "$CONTAINER_NAME" /opt/lnd/lncli getinfo | jq -r '.alias, .identity_pubkey, .block_height'
        
        return 0
    else
        error "LND não está respondendo corretamente"
        return 1
    fi
}

# Função principal
main() {
    log "=== Iniciando configuração automática do LND ==="
    
    # Limpar log anterior
    > "$LOG_FILE"
    
    # Verificar dependências
    check_dependencies
    
    # Verificar se container está rodando
    if ! check_container_status; then
        error "Inicie o container LND primeiro: docker-compose up -d lnd"
        exit 1
    fi
    
    # Monitorar e configurar LND
    if monitor_lnd_logs; then
        log "Configuração do LND concluída com sucesso!"
        
        # Verificar status final
        verify_lnd_status
        
        log "=== Setup LND finalizado ==="
        info "Logs salvos em: $LOG_FILE"
        
        if [[ -f "$WALLET_SEED_FILE" ]]; then
            warning "LEMBRE-SE: Faça backup da seed em $WALLET_SEED_FILE"
        fi
        
    else
        error "Falha na configuração do LND"
        exit 1
    fi
}

# Verificar se script está sendo executado como root
if [[ $EUID -eq 0 ]]; then
    warning "Este script não deveria ser executado como root"
fi

# Executar função principal
main "$@"
