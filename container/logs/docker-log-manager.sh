#!/bin/bash

# Docker Log Manager - Sistema de filtragem de logs em tempo real
# Criado para o projeto BRLN

set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR"
DOCKER_COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
STDOUT_LOG="$LOG_DIR/stdout.log"
STDERR_LOG="$LOG_DIR/stderr.log"
PID_FILE="$LOG_DIR/docker-log-manager.pid"

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

# Função para limpeza ao sair
cleanup() {
    log "Parando docker-log-manager..."
    
    # Parar todos os processos filhos
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Remover PID file
    rm -f "$PID_FILE"
    
    exit 0
}

# Configurar trap para limpeza
trap cleanup SIGTERM SIGINT EXIT

# Função para verificar se o docker-compose está rodando
check_docker_compose() {
    cd "$DOCKER_COMPOSE_DIR"
    if ! docker-compose ps | grep -q "Up"; then
        warning "Nenhum container do docker-compose está rodando"
        return 1
    fi
    return 0
}

# Função para obter lista de containers ativos
get_active_containers() {
    cd "$DOCKER_COMPOSE_DIR"
    docker-compose ps --format "table {{.Service}}" | tail -n +2 | grep -v "^$"
}

# Função para criar logs específicos por container
create_container_logs() {
    local containers
    containers=$(get_active_containers)
    
    if [[ -z "$containers" ]]; then
        warning "Nenhum container ativo encontrado"
        return
    fi
    
    info "Criando logs específicos para containers: $(echo "$containers" | tr '\n' ' ')"
    
    # Para cada container, criar um filtro específico
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            local container_log="$LOG_DIR/${container}.log"
            
            # Criar filtro para este container em background
            (
                tail -f "$STDOUT_LOG" 2>/dev/null | grep "^${container}" > "$container_log"
            ) &
            
            info "Log específico criado para container: $container -> ${container}.log"
        fi
    done <<< "$containers"
}

# Função para criar filtro de erros
create_error_filter() {
    info "Criando filtro de erros -> stderr.log"
    
    (
        tail -f "$STDOUT_LOG" 2>/dev/null | grep -iE "(error|erro|failed|exception|fatal|panic|critical)" > "$STDERR_LOG"
    ) &
}

# Função para iniciar captura principal
start_main_capture() {
    cd "$DOCKER_COMPOSE_DIR"
    
    info "Iniciando captura principal de logs -> stdout.log"
    
    # Criar arquivo de log principal se não existir
    touch "$STDOUT_LOG"
    
    # Capturar todos os logs do docker-compose em background
    (
        docker-compose logs -f --timestamps 2>&1 | tee -a "$STDOUT_LOG"
    ) &
    
    # Aguardar um pouco para o arquivo começar a ser populado
    sleep 2
}

# Função para rotacionar logs
rotate_logs() {
    local max_size="100M"
    
    for log_file in "$LOG_DIR"/*.log; do
        if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null) -gt 104857600 ]]; then
            warning "Rotacionando log: $(basename "$log_file")"
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
        fi
    done
}

# Função principal
main() {
    log "=== Iniciando Docker Log Manager ==="
    
    # Verificar se já está rodando
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        error "Docker Log Manager já está rodando (PID: $(cat "$PID_FILE"))"
        exit 1
    fi
    
    # Salvar PID
    echo $$ > "$PID_FILE"
    
    # Verificar se docker-compose está disponível
    if ! command -v docker-compose &> /dev/null; then
        error "docker-compose não está instalado ou não está no PATH"
        exit 1
    fi
    
    # Verificar se estamos no diretório correto
    if [[ ! -f "$DOCKER_COMPOSE_DIR/docker-compose.yml" ]]; then
        error "docker-compose.yml não encontrado em $DOCKER_COMPOSE_DIR"
        exit 1
    fi
    
    # Verificar se há containers rodando
    if ! check_docker_compose; then
        warning "Aguardando containers do docker-compose..."
        sleep 5
    fi
    
    # Iniciar captura principal
    start_main_capture
    
    # Aguardar logs começarem a aparecer
    sleep 3
    
    # Criar filtro de erros
    create_error_filter
    
    # Criar logs específicos por container
    create_container_logs
    
    info "Sistema de logs configurado com sucesso!"
    info "Logs disponíveis em: $LOG_DIR"
    info "- stdout.log: Todos os logs"
    info "- stderr.log: Apenas erros"
    info "- [container].log: Logs específicos por container"
    
    # Loop principal - monitorar e rotacionar logs
    while true; do
        sleep 300  # 5 minutos
        rotate_logs
        
        # Verificar se containers ainda estão rodando
        if ! check_docker_compose; then
            warning "Containers não estão mais rodando, aguardando..."
            sleep 30
        fi
    done
}

# Função para parar o serviço
stop() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Parando Docker Log Manager (PID: $pid)"
            kill -TERM "$pid"
            
            # Aguardar até 10 segundos para parar graciosamente
            for i in {1..10}; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            
            # Forçar parada se necessário
            if kill -0 "$pid" 2>/dev/null; then
                warning "Forçando parada do processo"
                kill -KILL "$pid" 2>/dev/null || true
            fi
            
            rm -f "$PID_FILE"
            log "Docker Log Manager parado"
        else
            warning "Processo não encontrado, removendo PID file"
            rm -f "$PID_FILE"
        fi
    else
        warning "Docker Log Manager não está rodando"
    fi
}

# Função para mostrar status
status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            info "Docker Log Manager está rodando (PID: $pid)"
            info "Logs ativos:"
            ls -la "$LOG_DIR"/*.log 2>/dev/null || warning "Nenhum arquivo de log encontrado"
        else
            warning "PID file existe mas processo não está rodando"
            rm -f "$PID_FILE"
        fi
    else
        warning "Docker Log Manager não está rodando"
    fi
}

# Processar argumentos da linha de comando
case "${1:-start}" in
    start)
        main
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        main
        ;;
    status)
        status
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status}"
        echo ""
        echo "Comandos:"
        echo "  start   - Inicia o sistema de logs (padrão)"
        echo "  stop    - Para o sistema de logs"
        echo "  restart - Reinicia o sistema de logs"
        echo "  status  - Mostra status do sistema"
        exit 1
        ;;
esac
