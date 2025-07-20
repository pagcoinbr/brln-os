#!/bin/bash

# Script para iniciar o servidor BRLN JavaScript
# Substituindo o sistema Python Flask

SCRIPT_DIR="/root/brln-os/brln-rpc-server"
LOG_FILE="/var/log/brln-server.log"

# Garantir que o diretório existe
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "Erro: Diretório $SCRIPT_DIR não encontrado!" >&2
    exit 1
fi

# Navegar para o diretório
cd "$SCRIPT_DIR"

# Verificar se o arquivo servidor existe
if [ ! -f "brln-server.js" ]; then
    echo "Erro: brln-server.js não encontrado em $SCRIPT_DIR!" >&2
    exit 1
fi

# Criar diretório de logs se não existir
mkdir -p "$(dirname "$LOG_FILE")"

# Funcões para controle do processo
start_server() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Iniciando servidor BRLN..." | tee -a "$LOG_FILE"
    
    # Verificar se já está rodando
    if pgrep -f "brln-server.js" > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Servidor já está rodando!" | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Iniciar servidor em background
    nohup node brln-server.js >> "$LOG_FILE" 2>&1 &
    echo $! > /tmp/brln-server.pid
    
    sleep 2
    
    # Verificar se iniciou corretamente
    if pgrep -f "brln-server.js" > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Servidor iniciado com sucesso!" | tee -a "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - PID: $(cat /tmp/brln-server.pid)" | tee -a "$LOG_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Servidor rodando em http://localhost:5001" | tee -a "$LOG_FILE"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Falha ao iniciar servidor!" | tee -a "$LOG_FILE"
        return 1
    fi
}

stop_server() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Parando servidor BRLN..." | tee -a "$LOG_FILE"
    
    # Tentar parar pelo PID salvo
    if [ -f /tmp/brln-server.pid ]; then
        PID=$(cat /tmp/brln-server.pid)
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Sinal de parada enviado para PID $PID" | tee -a "$LOG_FILE"
        fi
        rm -f /tmp/brln-server.pid
    fi
    
    # Garantir que todos os processos sejam finalizados
    pkill -f "brln-server.js"
    
    sleep 2
    
    if ! pgrep -f "brln-server.js" > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Servidor parado com sucesso!" | tee -a "$LOG_FILE"
        return 0
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Forçando parada do servidor..." | tee -a "$LOG_FILE"
        pkill -9 -f "brln-server.js"
        rm -f /tmp/brln-server.pid
        return 0
    fi
}

restart_server() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Reiniciando servidor BRLN..." | tee -a "$LOG_FILE"
    stop_server
    sleep 1
    start_server
}

status_server() {
    if pgrep -f "brln-server.js" > /dev/null; then
        PID=$(pgrep -f "brln-server.js")
        echo "Servidor BRLN está rodando (PID: $PID)"
        echo "URL: http://localhost:5001"
        
        # Testar conectividade
        if command -v curl &> /dev/null; then
            if curl -s http://localhost:5001/health > /dev/null; then
                echo "Status: Respondendo ✅"
            else
                echo "Status: Não respondendo ❌"
            fi
        fi
        return 0
    else
        echo "Servidor BRLN não está rodando ❌"
        return 1
    fi
}

# Verificar se dependências estão instaladas
check_deps() {
    if ! command -v node &> /dev/null; then
        echo "Erro: Node.js não encontrado. Instale o Node.js primeiro!" >&2
        exit 1
    fi
    
    if [ ! -d "node_modules" ]; then
        echo "Instalando dependências Node.js..."
        npm install
    fi
}

# Comando principal
case "${1:-start}" in
    start)
        check_deps
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        check_deps
        restart_server
        ;;
    status)
        status_server
        ;;
    logs)
        tail -f "$LOG_FILE"
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Comandos disponíveis:"
        echo "  start    - Iniciar o servidor BRLN"
        echo "  stop     - Parar o servidor BRLN"
        echo "  restart  - Reiniciar o servidor BRLN"
        echo "  status   - Verificar status do servidor"
        echo "  logs     - Mostrar logs em tempo real"
        echo ""
        echo "O servidor JavaScript substitui o sistema Python Flask anterior"
        echo "e roda na porta 5001 para compatibilidade com a interface web."
        exit 1
        ;;
esac

exit $?
