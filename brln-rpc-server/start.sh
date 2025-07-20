#!/bin/bash

# BRLN-RPC-Server Start Script
# Script para inicializar o servidor RPC JavaScript do BRLN-OS

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR"
LOG_DIR="$SERVER_DIR/logs"
PID_FILE="$SERVER_DIR/brln-rpc-server.pid"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:${NC} $1"
}

# Verificar se Node.js está instalado
check_nodejs() {
    if ! command -v node &> /dev/null; then
        error "Node.js não está instalado!"
        error "Instale o Node.js versão 16 ou superior:"
        error "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
        error "  sudo apt-get install -y nodejs"
        exit 1
    fi
    
    local node_version=$(node --version | sed 's/v//')
    log "Node.js versão: $node_version"
}

# Verificar dependências
check_dependencies() {
    log "🔍 Verificando dependências..."
    
    # Verificar se package.json existe
    if [ ! -f "$SERVER_DIR/package.json" ]; then
        error "package.json não encontrado em $SERVER_DIR"
        exit 1
    fi
    
    # Verificar se node_modules existe
    if [ ! -d "$SERVER_DIR/node_modules" ]; then
        log "📦 Instalando dependências npm..."
        cd "$SERVER_DIR"
        npm install --production
        if [ $? -ne 0 ]; then
            error "Falha ao instalar dependências npm"
            exit 1
        fi
    fi
    
    # Verificar se lightning.proto existe
    if [ ! -f "$SERVER_DIR/lightning.proto" ]; then
        log "📡 Baixando lightning.proto..."
        cd "$SERVER_DIR"
        wget -q https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/lightning.proto
        if [ $? -ne 0 ]; then
            error "Falha ao baixar lightning.proto"
            exit 1
        fi
    fi
}

# Criar diretórios necessários
create_directories() {
    log "📁 Criando diretórios necessários..."
    
    mkdir -p "$LOG_DIR"
    mkdir -p "$SERVER_DIR/config"
    mkdir -p "$SERVER_DIR/data"
}

# Verificar se servidor já está rodando
check_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            warn "Servidor já está rodando com PID $pid"
            warn "Use './start.sh stop' para parar ou './start.sh restart' para reiniciar"
            exit 1
        else
            # PID file existe mas processo não está rodando
            rm -f "$PID_FILE"
        fi
    fi
}

# Parar servidor
stop_server() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "🛑 Parando servidor (PID: $pid)..."
            kill "$pid"
            
            # Aguardar até 10 segundos para o processo terminar
            for i in {1..10}; do
                if ! ps -p "$pid" > /dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            
            # Se ainda estiver rodando, forçar
            if ps -p "$pid" > /dev/null 2>&1; then
                warn "Forçando término do processo..."
                kill -9 "$pid"
            fi
            
            rm -f "$PID_FILE"
            log "✅ Servidor parado com sucesso"
        else
            warn "PID file existe mas processo não está rodando"
            rm -f "$PID_FILE"
        fi
    else
        warn "Servidor não está rodando"
    fi
}

# Iniciar servidor
start_server() {
    log "🚀 Iniciando BRLN-RPC-Server..."
    
    cd "$SERVER_DIR"
    
    # Iniciar servidor em background
    nohup node server.js > "$LOG_DIR/startup.log" 2>&1 &
    local pid=$!
    
    # Salvar PID
    echo "$pid" > "$PID_FILE"
    
    # Verificar se iniciou corretamente
    sleep 2
    if ps -p "$pid" > /dev/null 2>&1; then
        log "✅ Servidor iniciado com sucesso!"
        log "   PID: $pid"
        log "   Logs: $LOG_DIR/"
        log "   URL: http://localhost:5001"
        log ""
        log "📋 Comandos úteis:"
        log "   ./start.sh status   - Ver status"
        log "   ./start.sh logs     - Ver logs em tempo real"
        log "   ./start.sh stop     - Parar servidor"
        log "   ./start.sh restart  - Reiniciar servidor"
    else
        error "Falha ao iniciar servidor"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Ver status
show_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "✅ Servidor está rodando (PID: $pid)"
            
            # Verificar se está respondendo
            if curl -s http://localhost:5001/health > /dev/null 2>&1; then
                log "🌐 Servidor respondendo na porta 5001"
            else
                warn "🌐 Servidor não está respondendo na porta 5001"
            fi
        else
            warn "❌ PID file existe mas processo não está rodando"
            rm -f "$PID_FILE"
        fi
    else
        warn "❌ Servidor não está rodando"
    fi
}

# Ver logs
show_logs() {
    if [ -f "$LOG_DIR/brln-rpc-server.log" ]; then
        log "📄 Mostrando logs em tempo real (Ctrl+C para sair)..."
        tail -f "$LOG_DIR/brln-rpc-server.log"
    else
        warn "Arquivo de log não encontrado"
    fi
}

# Função principal
main() {
    local action="${1:-start}"
    
    case "$action" in
        "start")
            check_nodejs
            create_directories
            check_dependencies
            check_running
            start_server
            ;;
        "stop")
            stop_server
            ;;
        "restart")
            stop_server
            sleep 2
            check_nodejs
            create_directories
            check_dependencies
            start_server
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "install")
            check_nodejs
            create_directories
            check_dependencies
            log "✅ Instalação concluída! Use './start.sh start' para iniciar"
            ;;
        *)
            echo "Uso: $0 {start|stop|restart|status|logs|install}"
            echo ""
            echo "Comandos:"
            echo "  start    - Iniciar servidor"
            echo "  stop     - Parar servidor"
            echo "  restart  - Reiniciar servidor"
            echo "  status   - Ver status do servidor"
            echo "  logs     - Ver logs em tempo real"
            echo "  install  - Apenas instalar dependências"
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@"
