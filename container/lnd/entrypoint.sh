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

# Configurações dinâmicas baseadas na rede
BITCOIN_NETWORK=${BITCOIN_NETWORK:-testnet}  # Padrão: testnet
if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
    NETWORK_PATH="mainnet"
    ZMQ_RAWBLOCK_PORT="28332"
    ZMQ_RAWTX_PORT="28333"
    RPC_PORT="8332"
else
    NETWORK_PATH="testnet"
    ZMQ_RAWBLOCK_PORT="28432"
    ZMQ_RAWTX_PORT="28433"
    RPC_PORT="18332"
fi

LND_DIR="/home/lnd/.lnd"
PASSWORD_FILE="$LND_DIR/password.txt"
WALLET_DB="$LND_DIR/data/chain/bitcoin/$NETWORK_PATH/wallet.db"
SEED_FILE="$LND_DIR/seed.txt"
LOG_FILE="/tmp/lnd-entrypoint.log"
TLS_CERT_PATH=""  # Será definido dinamicamente
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

# Função para configurar lnd.conf dinamicamente
configure_network() {
    log "Configurando rede: $BITCOIN_NETWORK"
    
    local lnd_conf="$LND_DIR/lnd.conf"
    
    # Fazer backup se o arquivo existir
    if [[ -f "$lnd_conf" ]]; then
        cp "$lnd_conf" "$lnd_conf.backup.$(date +%s)"
        log "Backup criado do lnd.conf existente"
    fi
    
    # Configurar baseado na rede
    if [[ "$BITCOIN_NETWORK" == "mainnet" ]]; then
        log "Configurando para MAINNET"
        # Ajustar configurações para mainnet
        sed -i 's/bitcoin.mainnet=false/bitcoin.mainnet=true/' "$lnd_conf" 2>/dev/null || true
        sed -i 's/bitcoin.testnet=true/bitcoin.testnet=false/' "$lnd_conf" 2>/dev/null || true
        # Ajustar portas ZMQ para mainnet
        sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/" "$lnd_conf" 2>/dev/null || true
        sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/" "$lnd_conf" 2>/dev/null || true
    else
        log "Configurando para TESTNET"
        # Ajustar configurações para testnet
        sed -i 's/bitcoin.mainnet=true/bitcoin.mainnet=false/' "$lnd_conf" 2>/dev/null || true
        sed -i 's/bitcoin.testnet=false/bitcoin.testnet=true/' "$lnd_conf" 2>/dev/null || true
        # Ajustar portas ZMQ para testnet
        sed -i "s/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28332/bitcoind.zmqpubrawblock=tcp:\/\/bitcoin:28432/" "$lnd_conf" 2>/dev/null || true
        sed -i "s/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28333/bitcoind.zmqpubrawtx=tcp:\/\/bitcoin:28433/" "$lnd_conf" 2>/dev/null || true
    fi
    
    # Garantir que PostgreSQL esteja comentado e BoltDB ativo
    log "Desabilitando PostgreSQL e ativando BoltDB"
    sed -i 's/^db.backend=postgres/#db.backend=postgres/' "$lnd_conf" 2>/dev/null || true
    sed -i 's/^db.postgres.dsn=/#db.postgres.dsn=/' "$lnd_conf" 2>/dev/null || true
    sed -i 's/^db.postgres.timeout=/#db.postgres.timeout=/' "$lnd_conf" 2>/dev/null || true
    sed -i 's/^\[postgres\]/#[postgres]/' "$lnd_conf" 2>/dev/null || true
    
    # Atualizar credenciais RPC do Bitcoin Core
    log "Atualizando credenciais RPC do Bitcoin Core"
    
    # Usar variáveis de ambiente ou valores padrão
    local rpc_user=${BITCOIN_RPC_USER:-test}
    local rpc_pass=${BITCOIN_RPC_PASS:-test123}
    
    log "Aplicando credenciais RPC: usuário=$rpc_user"
    sed -i "s/bitcoind.rpcuser=<seu_user_rpc>/bitcoind.rpcuser=$rpc_user/" "$lnd_conf" 2>/dev/null || true
    sed -i "s/bitcoind.rpcpass=<sua_senha_rpc>/bitcoind.rpcpass=$rpc_pass/" "$lnd_conf" 2>/dev/null || true
    
    log "Configuração de rede aplicada: $BITCOIN_NETWORK"
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
    
    # Aguardar o certificado TLS ser criado (mais simples)
    local max_attempts=20
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -f "$LND_DIR/tls.cert" ]]; then
            log "Certificado TLS encontrado: $LND_DIR/tls.cert"
            TLS_CERT_PATH="$LND_DIR/tls.cert"
            break
        fi
        
        log "Aguardando certificado TLS... (tentativa $((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        error "Certificado TLS não foi gerado a tempo"
        return 1
    fi
    
    log "Criando carteira automaticamente..."
    
    # Exportar variáveis para o expect
    export LND_BIN_DATA TLS_CERT_PATH password
    
    # Criar carteira usando expect
    expect << 'EOF'
set timeout 60
spawn $env(LND_BIN_DATA)/lncli --rpcserver=localhost:10009 --tlscertpath=$env(TLS_CERT_PATH) create
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

# Função principal - SIMPLIFICADA mas com criação de carteira
main() {
    log "=== Iniciando LND ==="
    log "Rede configurada: $BITCOIN_NETWORK"
    
    # Configurar rede dinamicamente
    configure_network
    
    # Setup signal handlers
    setup_signal_handlers
    
    # Verificar se a carteira já existe
    if wallet_exists; then
        log "Carteira já existe para $BITCOIN_NETWORK. Iniciando LND normalmente..."
        # Usar exec para que o LND seja o processo principal
        exec $LND_BIN_DATA/lnd --configfile="$LND_DIR/lnd.conf"
    else
        log "Carteira não existe para $BITCOIN_NETWORK. Criando automaticamente..."
        
        # Iniciar LND em background para criar a carteira
        log "Iniciando LND em background para criação da carteira..."
        $LND_BIN_DATA/lnd --configfile="$LND_DIR/lnd.conf" &
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
        exec $LND_BIN_DATA/lnd --configfile="$LND_DIR/lnd.conf"
    fi
}

# Executar função principal
main "$@"
