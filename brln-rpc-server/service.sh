#!/bin/bash

# Script para gerenciar o serviço LND RPC JS
# Uso: ./service.sh [install|uninstall|start|stop|restart|status|logs]

SERVICE_NAME="lnd-rpc-js"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PROJECT_DIR="$(dirname "$(realpath "$0")")"
LOCAL_SERVICE_FILE="${PROJECT_DIR}/${SERVICE_NAME}.service"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se está rodando como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Este script precisa ser executado como root (sudo)"
        exit 1
    fi
}

# Instalar o serviço
install_service() {
    print_status "Instalando serviço ${SERVICE_NAME}..."
    
    # Verificar se o arquivo de serviço local existe
    if [ ! -f "$LOCAL_SERVICE_FILE" ]; then
        print_error "Arquivo de serviço não encontrado: $LOCAL_SERVICE_FILE"
        exit 1
    fi
    
    # Copiar arquivo de serviço para systemd
    cp "$LOCAL_SERVICE_FILE" "$SERVICE_FILE"
    
    # Recarregar systemd
    systemctl daemon-reload
    
    # Habilitar o serviço para iniciar automaticamente
    systemctl enable "$SERVICE_NAME"
    
    print_success "Serviço instalado e habilitado com sucesso!"
    print_status "Use 'sudo ./service.sh start' para iniciar o serviço"
}

# Desinstalar o serviço
uninstall_service() {
    print_status "Desinstalando serviço ${SERVICE_NAME}..."
    
    # Parar o serviço se estiver rodando
    systemctl stop "$SERVICE_NAME" 2>/dev/null
    
    # Desabilitar o serviço
    systemctl disable "$SERVICE_NAME" 2>/dev/null
    
    # Remover arquivo de serviço
    if [ -f "$SERVICE_FILE" ]; then
        rm "$SERVICE_FILE"
    fi
    
    # Recarregar systemd
    systemctl daemon-reload
    
    print_success "Serviço desinstalado com sucesso!"
}

# Iniciar o serviço
start_service() {
    print_status "Iniciando serviço ${SERVICE_NAME}..."
    
    if ! systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
        print_warning "Serviço não está instalado. Use 'sudo ./service.sh install' primeiro"
        exit 1
    fi
    
    systemctl start "$SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Serviço iniciado com sucesso!"
        show_status
    else
        print_error "Falha ao iniciar o serviço"
        exit 1
    fi
}

# Parar o serviço
stop_service() {
    print_status "Parando serviço ${SERVICE_NAME}..."
    systemctl stop "$SERVICE_NAME"
    print_success "Serviço parado!"
}

# Reiniciar o serviço
restart_service() {
    print_status "Reiniciando serviço ${SERVICE_NAME}..."
    systemctl restart "$SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Serviço reiniciado com sucesso!"
        show_status
    else
        print_error "Falha ao reiniciar o serviço"
        exit 1
    fi
}

# Mostrar status do serviço
show_status() {
    print_status "Status do serviço ${SERVICE_NAME}:"
    systemctl status "$SERVICE_NAME" --no-pager -l
}

# Mostrar logs do serviço
show_logs() {
    print_status "Logs do serviço ${SERVICE_NAME}:"
    echo "Use Ctrl+C para sair do modo de monitoramento"
    journalctl -u "$SERVICE_NAME" -f
}

# Função de ajuda
show_help() {
    echo "Gerenciador do Serviço LND RPC JS"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  install   - Instalar e habilitar o serviço"
    echo "  uninstall - Desinstalar o serviço"
    echo "  start     - Iniciar o serviço"
    echo "  stop      - Parar o serviço"
    echo "  restart   - Reiniciar o serviço"
    echo "  status    - Mostrar status do serviço"
    echo "  logs      - Mostrar logs em tempo real"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  sudo $0 install"
    echo "  sudo $0 start"
    echo "  sudo $0 status"
    echo "  sudo $0 logs"
}

# Verificar argumentos
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Processar comando
case "$1" in
    install)
        check_root
        install_service
        ;;
    uninstall)
        check_root
        uninstall_service
        ;;
    start)
        check_root
        start_service
        ;;
    stop)
        check_root
        stop_service
        ;;
    restart)
        check_root
        restart_service
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Comando inválido: $1"
        show_help
        exit 1
        ;;
esac
