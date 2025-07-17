#!/bin/bash

# Script de entrypoint para LND com criação automática de carteira
set -e

# Source das funções básicas
source "/opt/lnd/scripts/basic.sh" 2>/dev/null || {
    # Fallback se o basic.sh não estiver disponível no container
    log() { echo -e "\033[0;32m[$(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    error() { echo -e "\033[0;31m[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    warning() { echo -e "\033[1;33m[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
    info() { echo -e "\033[0;34m[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1\033[0m"; }
}

# Configurações
LND_DIR="/home/lnd/.lnd"
PASSWORD_FILE="$LND_DIR/password.txt"
WALLET_DB="$LND_DIR/data/chain/bitcoin/mainnet/wallet.db"
SEED_FILE="$LND_DIR/seed.txt"
LOG_FILE="/tmp/lnd-entrypoint.log"
TLS_CERT_PATH=""  # Será definido dinamicamente
LND_BIN_DATA="/opt/lnd"
LND_DATA="/data/lnd"

warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

# Função para verificar se a carteira já existe
wallet_exists() {
    if [[ -f "$WALLET_DB" ]]; then
        return 0
    fi
    return 1
}

# Função para iniciar LND em background
start_lnd_background() {
    log "Iniciando LND em background..."
    $LND_BIN_DATA/lnd --configfile="$LND_DIR/lnd.conf" >> "$LOG_FILE" 2>&1 &
    LND_PID=$!
    tail -f "$LOG_FILE" 
    return 0
}

# Função para parar LND
stop_lnd() {
    if [[ -n "$LND_PID" ]]; then
        log "Parando LND..."
        kill $LND_PID 2>/dev/null || true
        wait $LND_PID 2>/dev/null || true
    fi
}

# Função para criar carteira automaticamente
create_wallet_auto() {
    log "Criando carteira automaticamente..."
    
    if [[ ! -f "$PASSWORD_FILE" ]]; then
        error "Arquivo de senha não encontrado: $PASSWORD_FILE"
        return 1
    fi
    
    local password=$(cat "$PASSWORD_FILE" | tr -d '\n\r')
    local max_attempts=15  # Reduzido de 30 para 15
    local attempt=0
    
    # Aguardar LND estar pronto para aceitar comandos
    while [[ $attempt -lt $max_attempts ]]; do
        # Verificar se a porta está respondendo primeiro
        if nc -z localhost 10009 2>/dev/null; then
            log "LND está respondendo na porta 10009!"
            
            # Procurar pelo arquivo de certificado TLS
            local tls_cert_path=""
            if [[ -f "$LND_DIR/tls.cert" ]]; then
                tls_cert_path="$LND_DIR/tls.cert"
            else
                tls_cert_path=$(find "$LND_DIR" -name "tls.cert.tmp" -o -name "tls.cert.*" 2>/dev/null | head -1)
            fi
            
            if [[ -n "$tls_cert_path" ]]; then
                log "Usando certificado TLS: $tls_cert_path"
                TLS_CERT_PATH="$tls_cert_path"
                break
            fi
        fi
        
        log "Aguardando LND estar pronto... (tentativa $((attempt + 1))/$max_attempts)"
        sleep 3  # Aumentado para 3 segundos
        attempt=$((attempt + 1))
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        error "LND não ficou pronto a tempo"
        return 1
    fi
    
    # Verificar se temos o caminho do certificado
    if [[ -z "$TLS_CERT_PATH" ]]; then
        # Última tentativa de encontrar o certificado
        TLS_CERT_PATH=$(find "$LND_DIR" -name "tls.cert.tmp" -o -name "tls.cert.*" -o -name "tls.cert" 2>/dev/null | head -1)
        if [[ -z "$TLS_CERT_PATH" ]]; then
            error "Certificado TLS não encontrado"
            return 1
        fi
    fi
    
    log "Usando certificado TLS: $TLS_CERT_PATH"
    
    # Exportar variáveis para o expect
    export LND_BIN_DATA TLS_CERT_PATH password
    
    # Criar carteira usando expect - versão simplificada
    expect << 'EOF'
set timeout 60
spawn $env(LND_BIN_DATA)/lncli --tlscertpath=$env(TLS_CERT_PATH) create
expect "Input wallet password:"
send "$env(password)\r"
expect "Confirm password:"
send "$env(password)\r"
expect "or 'n' to create a new seed (Enter y/x/n):"
send "n\r"
expect "proceed without a cipher seed passphrase):"
send "\r"
expect {
    "lnd successfully initialized!" {
        puts "SUCCESS: Carteira criada!"
    }
    "wallet already exists" {
        puts "INFO: Carteira já existe!"
    }
    "wallet already unlocked" {
        puts "INFO: Carteira já desbloqueada!"
    }
    timeout {
        puts "ERROR: Timeout na criação"
    }
    eof {
        puts "INFO: Processo finalizado"
    }
}
expect eof
EOF

    return $?
}

# Função para setup de trap para cleanup
setup_signal_handlers() {
    trap 'stop_lnd; exit 1' SIGTERM SIGINT
}

# Função principal
main() {
    log "=== Iniciando LND com configuração automática de carteira ==="
    
    # Setup signal handlers
    setup_signal_handlers
    
    # Verificar se a carteira já existe
    if wallet_exists; then
        log "Carteira já existe. Iniciando LND normalmente..."
        start_lnd_background
    else
        log "Carteira não existe. Criando automaticamente..."
        
        # Iniciar LND em background
        start_lnd_background &
        
        sleep 5

        create_wallet_auto 
        tail -f "$LOG_FILE"
    fi
}

# Executar função principal
main "$@"
