#!/bin/bash

# Script de limpeza completa do BRLN Full Auto Container Stack
# Remove todos os containers, imagens, volumes e serviços relacionados

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funções de logging
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
██████╗ ██████╗ ██╗     ███╗   ██╗     ██████╗██╗     ███████╗ █████╗ ███╗   ██╗██╗   ██╗██████╗ 
██╔══██╗██╔══██╗██║     ████╗  ██║    ██╔════╝██║     ██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗
██████╔╝██████╔╝██║     ██╔██╗ ██║    ██║     ██║     █████╗  ███████║██╔██╗ ██║██║   ██║██████╔╝
██╔══██╗██╔══██╗██║     ██║╚██╗██║    ██║     ██║     ██╔══╝  ██╔══██║██║╚██╗██║██║   ██║██╔═══╝ 
██████╔╝██║  ██║███████╗██║ ╚████║    ╚██████╗███████╗███████╗██║  ██║██║ ╚████║╚██████╔╝██║     
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝     ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     

    🧹 Limpeza Completa do Sistema - Docker & Serviços
EOF
echo -e "${NC}"

echo ""
warning "⚠️  ATENÇÃO: Este script irá remover TODOS os containers, imagens, volumes e redes Docker!"
warning "⚠️  Todos os dados dos containers serão PERDIDOS permanentemente!"
warning "⚠️  Também irá parar e desabilitar serviços Apache e Flask!"
echo ""
echo -e "${RED}Esta ação é IRREVERSÍVEL!${NC}"
echo ""

read -p "Tem certeza que deseja continuar? Digite 'SIM' para confirmar: " -r
echo
if [[ ! $REPLY == "SIM" ]]; then
    echo -e "${RED}Operação cancelada pelo usuário.${NC}"
    exit 0
fi

echo ""
log "🧹 Iniciando limpeza completa do sistema..."

# 1. Parar serviços do sistema que podem interferir
log "🛑 Parando serviços do sistema..."
sudo systemctl stop apache2 brln-flask 2>/dev/null || true
sudo systemctl disable apache2 brln-flask 2>/dev/null || true

# 2. Parar containers usando docker-compose (se existir)
if [[ -d "container" ]]; then
    log "🐳 Parando containers via docker-compose..."
    cd container
    if [[ -f "docker-compose.yml" ]]; then
        sudo docker-compose down -v --remove-orphans 2>/dev/null || true
        docker-compose down -v --remove-orphans 2>/dev/null || true
    fi
    cd ..
fi

# 3. Parar todos os containers Docker (força bruta)
log "🛑 Parando todos os containers Docker..."
if sudo docker ps -q | grep -q .; then
    sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
fi
if docker ps -q 2>/dev/null | grep -q .; then
    docker stop $(docker ps -aq) 2>/dev/null || true
fi

# 4. Remover todos os containers
log "🗑️ Removendo todos os containers..."
if sudo docker ps -aq | grep -q .; then
    sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
fi
if docker ps -aq 2>/dev/null | grep -q .; then
    docker rm $(docker ps -aq) 2>/dev/null || true
fi

# 5. Remover todas as imagens Docker
log "🖼️ Removendo todas as imagens Docker..."
if sudo docker images -q | grep -q .; then
    sudo docker rmi $(sudo docker images -q) 2>/dev/null || true
fi
if docker images -q 2>/dev/null | grep -q .; then
    docker rmi $(docker images -q) 2>/dev/null || true
fi

# 6. Limpeza completa do sistema Docker
log "🧽 Executando limpeza profunda do Docker..."
sudo docker system prune -af --volumes 2>/dev/null || true
sudo docker volume prune -f 2>/dev/null || true
sudo docker network prune -f 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
docker volume prune -f 2>/dev/null || true
docker network prune -f 2>/dev/null || true

# 7. Remover arquivos de configuração e dados gerados
log "📁 Removendo arquivos de configuração temporários..."
rm -f seeds.txt 2>/dev/null || true
rm -f /tmp/setup.log 2>/dev/null || true

# 8. Limpar diretórios de dados do Flask e Apache
log "🗂️ Limpando configurações de serviços..."
sudo rm -rf /opt/brln-flask 2>/dev/null || true
sudo rm -f /etc/systemd/system/brln-flask.service 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

# 9. Restaurar página padrão do Apache (opcional)
sudo rm -rf /var/www/html/cgi-bin 2>/dev/null || true
if [[ -f "/var/www/html/index.html" ]]; then
    sudo mv /var/www/html/index.html /var/www/html/index.html.brln.backup 2>/dev/null || true
fi

# 10. Verificação final
log "🔍 Verificando limpeza..."
echo ""
info "📊 Status após limpeza:"

# Verificar containers
CONTAINERS=$(sudo docker ps -a 2>/dev/null | wc -l)
if [[ $CONTAINERS -le 1 ]]; then
    echo -e "  • Containers: ${GREEN}✓ Limpo${NC}"
else
    echo -e "  • Containers: ${YELLOW}⚠ $((CONTAINERS-1)) restantes${NC}"
fi

# Verificar imagens
IMAGES=$(sudo docker images 2>/dev/null | wc -l)
if [[ $IMAGES -le 1 ]]; then
    echo -e "  • Imagens: ${GREEN}✓ Limpo${NC}"
else
    echo -e "  • Imagens: ${YELLOW}⚠ $((IMAGES-1)) restantes${NC}"
fi

# Verificar volumes
VOLUMES=$(sudo docker volume ls 2>/dev/null | wc -l)
if [[ $VOLUMES -le 1 ]]; then
    echo -e "  • Volumes: ${GREEN}✓ Limpo${NC}"
else
    echo -e "  • Volumes: ${YELLOW}⚠ $((VOLUMES-1)) restantes${NC}"
fi

# Verificar portas
PORTS_80=$(sudo ss -tlnp | grep ':80' | wc -l)
PORTS_5001=$(sudo ss -tlnp | grep ':5001' | wc -l)

if [[ $PORTS_80 -eq 0 ]]; then
    echo -e "  • Porta 80: ${GREEN}✓ Livre${NC}"
else
    echo -e "  • Porta 80: ${YELLOW}⚠ Em uso${NC}"
fi

if [[ $PORTS_5001 -eq 0 ]]; then
    echo -e "  • Porta 5001: ${GREEN}✓ Livre${NC}"
else
    echo -e "  • Porta 5001: ${YELLOW}⚠ Em uso${NC}"
fi

# Verificar serviços
APACHE_STATUS=$(systemctl is-active apache2 2>/dev/null || echo "inactive")
FLASK_STATUS=$(systemctl is-active brln-flask 2>/dev/null || echo "inactive")

if [[ $APACHE_STATUS == "inactive" ]]; then
    echo -e "  • Apache: ${GREEN}✓ Parado${NC}"
else
    echo -e "  • Apache: ${YELLOW}⚠ $APACHE_STATUS${NC}"
fi

if [[ $FLASK_STATUS == "inactive" ]]; then
    echo -e "  • Flask: ${GREEN}✓ Parado${NC}"
else
    echo -e "  • Flask: ${YELLOW}⚠ $FLASK_STATUS${NC}"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "✅ Limpeza completa finalizada!"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

info "💡 Próximos passos:"
echo "  1. O sistema está limpo e pronto para nova instalação"
echo "  2. Execute './setup.sh' para reinstalar do zero"
echo "  3. Certifique-se de anotar as seeds quando solicitado"
echo ""

warning "📝 Lembretes importantes:"
echo "  • Todos os dados foram removidos permanentemente"
echo "  • Você precisará reconfigurar tudo novamente"
echo "  • Faça backup das seeds antes de executar este script novamente"
echo ""
