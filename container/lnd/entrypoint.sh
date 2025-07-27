#!/bin/bash

# Script de entrypoint para LND com criação automática de carteira
set -e

# Source das funções básicas
source "/opt/lnd/scripts/.env" 2>/dev/null || {
    # Fallback se o .env não estiver disponível no container
    log() { 
        local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
        echo -e "\033[0;32m$msg\033[0m"
        [[ -f "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    }
    error() { 
        local msg="[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $1"
        echo -e "\033[0;31m$msg\033[0m"
        [[ -f "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    }
    warning() { 
        local msg="[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $1"
        echo -e "\033[1;33m$msg\033[0m"
        [[ -f "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    }
    info() { 
        local msg="[INFO $(date '+%Y-%m-%d %H:%M:%S')] $1"
        echo -e "\033[0;34m$msg\033[0m"
        [[ -f "$LOG_FILE" ]] && echo "$msg" >> "$LOG_FILE"
    }
}

# Configurações fixas para mainnet
BITCOIN_NETWORK="mainnet"
NETWORK_PATH="mainnet"
ZMQ_RAWBLOCK_PORT="28332"
ZMQ_RAWTX_PORT="28333"
RPC_PORT="8332"

LND_DIR="/data/lnd"
PASSWORD_FILE="$LND_DIR/password.txt"
WALLET_DB="$LND_DIR/data/chain/bitcoin/$NETWORK_PATH/wallet.db"
SEED_FILE="$LND_DIR/seed.txt"
LOG_FILE="/tmp/lnd-entrypoint.log"
TLS_CERT_PATH="/data/lnd/tls.cert"  # Será definido dinamicamente
LND_BIN_DATA="/opt/lnd"
LND_DATA="/data/lnd"

# Inicializar arquivo de log
init_log_file() {
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
    echo "=== LND Entrypoint Log Started at $(date) ===" > "$LOG_FILE"
}

# Inicializar log file imediatamente
init_log_file

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
    
    # Criar o arquivo de log antes de iniciar o LND
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"  # Permissões de leitura e escrita para todos
    
    # Iniciar LND redirecionando output para o log
    $LND_BIN_DATA/lnd --configfile="$LND_DIR/lnd.conf" >> "$LOG_FILE" 2>&1 &
    LND_PID=$!
    
    # Aguardar um momento para garantir que o processo iniciou
    sleep 2
    
    # Verificar se o arquivo de log existe antes do tail
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        error "Arquivo de log não foi criado: $LOG_FILE"
        return 1
    fi
    
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

# Função para verificar se LND está respondendo via RPC
check_lnd_rpc() {
    local tls_cert_path="$1"
    if [[ -n "$tls_cert_path" && -f "$tls_cert_path" ]]; then
        # Tentar um comando simples para verificar se RPC está funcionando
        $LND_BIN_DATA/lncli --rpcserver=localhost:10009 --tlscertpath="$tls_cert_path" getinfo >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Função para criar carteira automaticamente - SIMPLIFICADA
create_wallet_auto() {
    log "Aguardando LND estar pronto para criar carteira..."
    
    if [[ ! -f "$PASSWORD_FILE" ]]; then
        error "Arquivo de senha não encontrado: $PASSWORD_FILE"
        return 1
    fi
    
    local password=$(cat "$PASSWORD_FILE" | tr -d '\n\r')
    
    # # Aguardar o certificado TLS ser criado (mais simples)
    # local max_attempts=20
    # local attempt=0
    
    # while [[ $attempt -lt $max_attempts ]]; do
    #     if [[ -f "$LND_DIR/tls.cert" ]]; then
    #         log "Certificado TLS encontrado: $LND_DIR/tls.cert"
    #         TLS_CERT_PATH="$LND_DIR/tls.cert"
    #         break
    #     fi
        
    #     log "Aguardando certificado TLS... (tentativa $((attempt + 1))/$max_attempts)"
    #     sleep 2
    #     attempt=$((attempt + 1))
    # done
    
    # if [[ $attempt -eq $max_attempts ]]; then
    #     error "Certificado TLS não foi gerado a tempo"
    #     return 1
    # fi
    
    log "Criando carteira automaticamente..."
    
    # Exportar variáveis para o expect
    export LND_BIN_DATA TLS_CERT_PATH password
    
    # Criar carteira usando expect
    expect << 'EOF'
set timeout 60
spawn $env(LND_BIN_DATA)/lncli --rpcserver=localhost:10009 --tlscertpath=/data/lnd/tls.cert create
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
    timeout {
        puts "ERROR: Timeout na criação da carteira"
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

# Função para criar diretórios necessários
ensure_directories() {
    log "Criando diretórios necessários para LND..."
    
    # Debug: mostrar informações do usuário atual
    log "Usuário atual: $(whoami) (UID: $(id -u), GID: $(id -g))"
    log "Permissões do diretório base: $(ls -ld $LND_DIR)"
    
    # Criar diretório principal do LND e subdirs necessários
    mkdir -p "$LND_DIR"
    mkdir -p "$LND_DIR/data"
    mkdir -p "$LND_DIR/data/chain"
    mkdir -p "$LND_DIR/data/chain/bitcoin"
    mkdir -p "$LND_DIR/data/chain/bitcoin/$NETWORK_PATH"
    mkdir -p "$LND_DIR/logs"
    
    # Definir permissões adequadas (sem sudo, pois estamos rodando como user lnd)
    chmod -R 755 "$LND_DIR"
    
    log "Diretórios criados com sucesso"
    log "Permissões finais: $(ls -ld $LND_DIR)"
}

# Função principal - MAINNET SOMENTE
main() {
    log "=== Iniciando LND ==="
    
    # Setup signal handlers
    setup_signal_handlers
    
    # Garantir que os diretórios existem
    ensure_directories
    
    # Verificar se existe arquivo de configuração, senão usar parâmetros diretos
    local config_file="$LND_DIR/lnd.conf"
    local lnd_args=""
    
    if [[ -f "$config_file" ]]; then
        log "Usando arquivo de configuração: $config_file"
        lnd_args="--lnddir=$LND_DIR --configfile=$config_file"
    else
        log "Arquivo de configuração não encontrado. Usando parâmetros diretos."
        lnd_args="--lnddir=$LND_DIR --bitcoin.mainnet --bitcoin.node=bitcoind --rpclisten=localhost:10009 --listen=localhost:9735"
    fi
    
    # Verificar se a carteira já existe
    if wallet_exists; then
        log "Carteira já existe para mainnet. Iniciando LND normalmente..."
        # Usar exec para que o LND seja o processo principal
        exec $LND_BIN_DATA/lnd $lnd_args
    else
        log "Carteira não existe para mainnet. Criando automaticamente..."
        
        # Iniciar LND em background para criar a carteira
        log "Iniciando LND em background para criação da carteira..."
        $LND_BIN_DATA/lnd $lnd_args &
        LND_PID=$!
        
        # Aguardar e criar carteira
        sleep 5
        create_wallet_auto
        
        # Parar o LND background
        log "Parando LND temporário..."
        kill $LND_PID 2>/dev/null || true
        wait $LND_PID 2>/dev/null || true
        
        # Reiniciar LND como processo principal
        log "Reiniciando LND como processo principal..."
        exec $LND_BIN_DATA/lnd $lnd_args --adminmacaroonpath="/data/lnd/data/chain/bitcoin/$NETWORK_PATH/admin.macaroon"
    fi
}

# Executar função principal
main "$@"
