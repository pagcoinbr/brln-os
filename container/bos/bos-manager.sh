#!/bin/bash

# Script de configuração e gerenciamento do BOS
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/../docker-compose.yml"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[BOS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[BOS]${NC} $1"
}

error() {
    echo -e "${RED}[BOS]${NC} $1"
}

info() {
    echo -e "${BLUE}[BOS]${NC} $1"
}

# Função para verificar se o Docker está rodando
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker não está rodando ou não está acessível"
        exit 1
    fi
}

# Função para verificar se o LND está rodando
check_lnd() {
    if ! docker-compose -f "$COMPOSE_FILE" ps lnd | grep -q "Up"; then
        error "LND não está rodando. Inicie o LND primeiro:"
        echo "  docker-compose up -d lnd"
        exit 1
    fi
    log "LND está rodando ✅"
}

# Função para construir a imagem do BOS
build_bos() {
    log "Construindo imagem do BOS..."
    docker-compose -f "$COMPOSE_FILE" build bos
    log "Imagem do BOS construída com sucesso ✅"
}

# Função para iniciar o BOS
start_bos() {
    log "Iniciando BOS..."
    docker-compose -f "$COMPOSE_FILE" up -d bos
    log "BOS iniciado com sucesso ✅"
}

# Função para parar o BOS
stop_bos() {
    log "Parando BOS..."
    docker-compose -f "$COMPOSE_FILE" stop bos
    log "BOS parado ✅"
}

# Função para verificar status do BOS
status_bos() {
    info "Status do BOS:"
    docker-compose -f "$COMPOSE_FILE" ps bos
    
    if docker-compose -f "$COMPOSE_FILE" ps bos | grep -q "Up"; then
        log "BOS está rodando ✅"
        
        # Testar conectividade
        info "Testando conectividade com LND..."
        if docker exec bos bos balance --node=BRLN-Node >/dev/null 2>&1; then
            log "Conectividade com LND: OK ✅"
        else
            warn "Conectividade com LND: FALHA ❌"
        fi
    else
        warn "BOS não está rodando ❌"
    fi
}

# Função para ver logs do BOS
logs_bos() {
    info "Logs do BOS (use Ctrl+C para sair):"
    docker-compose -f "$COMPOSE_FILE" logs -f bos
}

# Função para acessar shell do BOS
shell_bos() {
    info "Acessando shell do BOS..."
    docker exec -it bos bash
}

# Função para configurar Telegram
setup_telegram() {
    info "Configuração do Bot Telegram"
    echo
    echo "1. Acesse: https://t.me/BotFather"
    echo "2. Crie um novo bot com /newbot"
    echo "3. Obtenha o token do bot"
    echo
    read -p "Cole o token do bot aqui: " telegram_token
    
    if [[ -z "$telegram_token" ]]; then
        error "Token não pode estar vazio"
        exit 1
    fi
    
    # Atualizar docker-compose.yml
    if grep -q "BOS_TELEGRAM_TOKEN=" "$COMPOSE_FILE"; then
        sed -i "s/BOS_TELEGRAM_TOKEN=.*/BOS_TELEGRAM_TOKEN=$telegram_token/" "$COMPOSE_FILE"
    else
        error "Variável BOS_TELEGRAM_TOKEN não encontrada no docker-compose.yml"
        exit 1
    fi
    
    # Configurar modo telegram
    sed -i "s/BOS_MODE=.*/BOS_MODE=telegram/" "$COMPOSE_FILE"
    
    log "Token do Telegram configurado ✅"
    
    # Reiniciar container
    warn "Reiniciando BOS para aplicar configurações..."
    docker-compose -f "$COMPOSE_FILE" restart bos
    
    log "Configuração concluída! Verifique se recebeu mensagem no Telegram ✅"
}

# Função para executar comandos BOS
run_command() {
    local cmd="$1"
    shift
    info "Executando: bos $cmd $@"
    docker exec bos bos "$cmd" --node=BRLN-Node "$@"
}

# Função para mostrar ajuda
show_help() {
    echo "🚀 Script de gerenciamento do Balance of Satoshis (BOS)"
    echo
    echo "Uso: $0 [COMANDO]"
    echo
    echo "Comandos:"
    echo "  build       - Construir imagem do BOS"
    echo "  start       - Iniciar BOS"
    echo "  stop        - Parar BOS"
    echo "  restart     - Reiniciar BOS"
    echo "  status      - Ver status do BOS"
    echo "  logs        - Ver logs do BOS"
    echo "  shell       - Acessar shell do BOS"
    echo "  telegram    - Configurar bot do Telegram"
    echo
    echo "Comandos BOS:"
    echo "  balance     - Ver balance do node"
    echo "  info        - Ver informações do node"
    echo "  forwards    - Ver forwards recentes"
    echo "  peers       - Ver peers conectados"
    echo
    echo "Exemplos:"
    echo "  $0 start"
    echo "  $0 status"
    echo "  $0 balance"
    echo "  $0 forwards --days 7"
}

# Função principal
main() {
    check_docker
    
    case "${1:-help}" in
        "build")
            check_lnd
            build_bos
            ;;
        "start")
            check_lnd
            start_bos
            ;;
        "stop")
            stop_bos
            ;;
        "restart")
            check_lnd
            docker-compose -f "$COMPOSE_FILE" restart bos
            log "BOS reiniciado ✅"
            ;;
        "status")
            status_bos
            ;;
        "logs")
            logs_bos
            ;;
        "shell")
            shell_bos
            ;;
        "telegram")
            setup_telegram
            ;;
        "balance"|"info"|"forwards"|"peers")
            shift
            run_command "$1" "$@"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            error "Comando desconhecido: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Executar função principal
main "$@"
