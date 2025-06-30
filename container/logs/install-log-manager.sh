#!/bin/bash

# Script de instalação do Docker Log Manager
# Instala e configura o serviço systemd para gerenciamento de logs

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

# Verificar se está rodando como root ou com sudo
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        error "Este script precisa ser executado como root ou com sudo"
        exit 1
    fi
}

# Instalar o serviço
install_service() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log "=== Instalando Docker Log Manager ==="
    
    # Verificar se os arquivos existem
    if [[ ! -f "$script_dir/docker-log-manager.sh" ]]; then
        error "Arquivo docker-log-manager.sh não encontrado"
        exit 1
    fi
    
    if [[ ! -f "$script_dir/docker-log-manager.service" ]]; then
        error "Arquivo docker-log-manager.service não encontrado"
        exit 1
    fi
    
    # Tornar o script executável
    chmod +x "$script_dir/docker-log-manager.sh"
    info "Permissões de execução definidas para docker-log-manager.sh"
    
    # Copiar arquivo de serviço para systemd
    cp "$script_dir/docker-log-manager.service" /etc/systemd/system/
    info "Arquivo de serviço copiado para /etc/systemd/system/"
    
    # Recarregar systemd
    systemctl daemon-reload
    info "Systemd recarregado"
    
    # Habilitar serviço para iniciar automaticamente
    systemctl enable docker-log-manager.service
    info "Serviço habilitado para inicialização automática"
    
    log "=== Instalação concluída ==="
    info "Para controlar o serviço, use:"
    info "  sudo systemctl start docker-log-manager    # Iniciar"
    info "  sudo systemctl stop docker-log-manager     # Parar"
    info "  sudo systemctl restart docker-log-manager  # Reiniciar"
    info "  sudo systemctl status docker-log-manager   # Status"
    info "  sudo journalctl -u docker-log-manager -f   # Ver logs do serviço"
}

# Desinstalar o serviço
uninstall_service() {
    log "=== Desinstalando Docker Log Manager ==="
    
    # Parar e desabilitar serviço
    systemctl stop docker-log-manager.service 2>/dev/null || true
    systemctl disable docker-log-manager.service 2>/dev/null || true
    info "Serviço parado e desabilitado"
    
    # Remover arquivo de serviço
    rm -f /etc/systemd/system/docker-log-manager.service
    info "Arquivo de serviço removido"
    
    # Recarregar systemd
    systemctl daemon-reload
    info "Systemd recarregado"
    
    log "=== Desinstalação concluída ==="
}

# Mostrar status do serviço
show_status() {
    info "=== Status do Docker Log Manager ==="
    
    if systemctl is-active --quiet docker-log-manager.service; then
        info "Serviço está ATIVO"
    else
        warning "Serviço está INATIVO"
    fi
    
    if systemctl is-enabled --quiet docker-log-manager.service; then
        info "Serviço está HABILITADO para inicialização automática"
    else
        warning "Serviço está DESABILITADO para inicialização automática"
    fi
    
    echo ""
    systemctl status docker-log-manager.service --no-pager || true
}

# Função principal
main() {
    check_privileges
    
    case "${1:-install}" in
        install)
            install_service
            ;;
        uninstall)
            uninstall_service
            ;;
        status)
            show_status
            ;;
        start)
            log "Iniciando Docker Log Manager..."
            systemctl start docker-log-manager.service
            info "Serviço iniciado"
            ;;
        stop)
            log "Parando Docker Log Manager..."
            systemctl stop docker-log-manager.service
            info "Serviço parado"
            ;;
        restart)
            log "Reiniciando Docker Log Manager..."
            systemctl restart docker-log-manager.service
            info "Serviço reiniciado"
            ;;
        logs)
            info "Mostrando logs do serviço (Ctrl+C para sair):"
            journalctl -u docker-log-manager.service -f
            ;;
        *)
            echo "Uso: $0 {install|uninstall|start|stop|restart|status|logs}"
            echo ""
            echo "Comandos:"
            echo "  install   - Instala o serviço systemd (padrão)"
            echo "  uninstall - Remove o serviço systemd"
            echo "  start     - Inicia o serviço"
            echo "  stop      - Para o serviço"
            echo "  restart   - Reinicia o serviço"
            echo "  status    - Mostra status do serviço"
            echo "  logs      - Mostra logs do serviço em tempo real"
            echo ""
            echo "Após a instalação, os logs estarão disponíveis em:"
            echo "  $(dirname "${BASH_SOURCE[0]}")/stdout.log - Todos os logs"
            echo "  $(dirname "${BASH_SOURCE[0]}")/stderr.log - Apenas erros"
            echo "  $(dirname "${BASH_SOURCE[0]}")/[container].log - Logs por container"
            exit 1
            ;;
    esac
}

main "$@"
