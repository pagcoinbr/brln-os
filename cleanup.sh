#!/bin/bash

# Script de limpeza do BRLN Full Auto Container Stack
# Remove instalações anteriores para permitir reinstalação limpa

# Cores
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
echo -e "${RED}"
cat << "EOF"
🧹 LIMPEZA DO SISTEMA BRLN
═══════════════════════════════════════════════════════════════
EOF
echo -e "${NC}"

echo ""
warning "⚠️  ATENÇÃO: Este script irá remover TODAS as instalações anteriores!"
warning "⚠️  Isso inclui containers Docker, dados da blockchain e configurações!"
warning "⚠️  Certifique-se de ter backup das suas chaves privadas (seeds)!"
echo ""

read -p "Tem certeza de que deseja continuar? Digite 'LIMPAR' para confirmar: " -r
if [[ $REPLY != "LIMPAR" ]]; then
    echo "Operação cancelada pelo usuário."
    exit 0
fi

echo ""
log "🧹 Iniciando limpeza completa do sistema..."

# 1. Parar e remover containers Docker
echo ""
log "🐳 Parando e removendo containers Docker..."

if [[ -d "container" ]]; then
    cd container
    
    # Parar todos os containers
    if command -v docker-compose &> /dev/null; then
        docker-compose down -v --remove-orphans 2>/dev/null
    else
        docker compose down -v --remove-orphans 2>/dev/null
    fi
    
    cd ..
fi

# Remover containers relacionados ao BRLN
CONTAINERS=$(docker ps -a --filter "name=bitcoin" --filter "name=lnd" --filter "name=elements" --filter "name=lnbits" --filter "name=thunderhub" --filter "name=lndg" --filter "name=peerswap" --filter "name=tor" -q)
if [[ -n "$CONTAINERS" ]]; then
    log "Removendo containers BRLN..."
    docker rm -f $CONTAINERS 2>/dev/null
fi

# Remover volumes Docker relacionados
VOLUMES=$(docker volume ls --filter "name=container_" -q)
if [[ -n "$VOLUMES" ]]; then
    log "Removendo volumes Docker..."
    docker volume rm $VOLUMES 2>/dev/null
fi

# Limpar imagens não utilizadas
log "Limpando imagens Docker não utilizadas..."
docker image prune -f 2>/dev/null

# 2. Remover serviços systemd
echo ""
log "⚙️ Removendo serviços systemd..."

# Parar e desabilitar serviços
if systemctl is-active --quiet brln-flask; then
    sudo systemctl stop brln-flask 2>/dev/null
fi
if systemctl is-enabled --quiet brln-flask; then
    sudo systemctl disable brln-flask 2>/dev/null
fi

# Remover arquivo de serviço
if [[ -f "/etc/systemd/system/brln-flask.service" ]]; then
    sudo rm -f /etc/systemd/system/brln-flask.service
    log "Serviço brln-flask removido"
fi

sudo systemctl daemon-reload 2>/dev/null

# 3. Limpar Apache
echo ""
log "🌐 Limpando configuração do Apache..."

# Parar Apache se estiver rodando
if systemctl is-active --quiet apache2; then
    sudo systemctl stop apache2 2>/dev/null
fi

# Remover arquivos da interface web
if [[ -d "/var/www/html" ]]; then
    sudo rm -rf /var/www/html/* 2>/dev/null
    log "Arquivos web removidos de /var/www/html"
fi

# Restaurar página padrão do Apache
if [[ -f "/var/www/html/index.html" ]]; then
    sudo rm -f /var/www/html/index.html
fi

# 4. Remover ambiente Python virtual
echo ""
log "🐍 Removendo ambiente Python..."

if [[ -d "container/graphics/venv" ]]; then
    rm -rf container/graphics/venv
    log "Ambiente virtual Python removido"
fi

# 5. Limpar dados da blockchain (opcional)
echo ""
warning "💾 Dados da blockchain encontrados..."
if [[ -d "container/bitcoin-data" ]] || [[ -d "container/lnd-data" ]] || [[ -d "container/elements-data" ]]; then
    echo ""
    echo "Os seguintes diretórios de dados foram encontrados:"
    [[ -d "container/bitcoin-data" ]] && echo "  • container/bitcoin-data (Bitcoin blockchain)"
    [[ -d "container/lnd-data" ]] && echo "  • container/lnd-data (Lightning Network)"
    [[ -d "container/elements-data" ]] && echo "  • container/elements-data (Liquid/Elements)"
    echo ""
    warning "⚠️  Remover estes dados significa perder toda a sincronização da blockchain!"
    warning "⚠️  Você terá que sincronizar tudo novamente (várias horas/dias)!"
    echo ""
    
    read -p "Deseja remover os dados da blockchain também? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removendo dados da blockchain..."
        [[ -d "container/bitcoin-data" ]] && rm -rf container/bitcoin-data
        [[ -d "container/lnd-data" ]] && rm -rf container/lnd-data
        [[ -d "container/elements-data" ]] && rm -rf container/elements-data
        log "Dados da blockchain removidos"
    else
        log "Dados da blockchain mantidos"
    fi
fi

# 6. Remover arquivos de configuração temporários
echo ""
log "📁 Limpando arquivos temporários..."

# Remover logs
[[ -f "/tmp/setup.log" ]] && rm -f /tmp/setup.log
[[ -f "seeds.txt" ]] && rm -f seeds.txt
[[ -f "passwords.txt" ]] && rm -f passwords.txt
[[ -f "passwords.md" ]] && rm -f passwords.md
[[ -f "startup.md" ]] && rm -f startup.md

# Limpar logs do sistema
sudo journalctl --vacuum-time=1d 2>/dev/null

# 7. Remover usuário www-data do grupo docker (se adicionado)
echo ""
log "👥 Limpando permissões de usuário..."
sudo gpasswd -d www-data docker 2>/dev/null

# 8. Verificação final
echo ""
log "🔍 Verificação final..."

# Verificar containers restantes
REMAINING_CONTAINERS=$(docker ps -a --filter "name=bitcoin" --filter "name=lnd" --filter "name=elements" --filter "name=lnbits" --filter "name=thunderhub" --filter "name=lndg" --filter "name=peerswap" --filter "name=tor" -q | wc -l)

# Verificar serviços
FLASK_SERVICE_EXISTS=$(systemctl list-unit-files | grep -c "brln-flask")

# Verificar arquivos web
WEB_FILES_COUNT=$(find /var/www/html -name "*.html" -o -name "*.js" -o -name "*.css" 2>/dev/null | wc -l)

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log "📊 Relatório de Limpeza:"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [[ $REMAINING_CONTAINERS -eq 0 ]]; then
    echo "✅ Containers Docker: Removidos"
else
    echo "⚠️  Containers Docker: $REMAINING_CONTAINERS containers ainda existem"
fi

if [[ $FLASK_SERVICE_EXISTS -eq 0 ]]; then
    echo "✅ Serviço Flask: Removido"
else
    echo "⚠️  Serviço Flask: Ainda existe"
fi

if [[ $WEB_FILES_COUNT -eq 0 ]]; then
    echo "✅ Arquivos Web: Removidos"
else
    echo "⚠️  Arquivos Web: $WEB_FILES_COUNT arquivos ainda existem"
fi

echo ""
if [[ $REMAINING_CONTAINERS -eq 0 && $FLASK_SERVICE_EXISTS -eq 0 && $WEB_FILES_COUNT -eq 0 ]]; then
    echo -e "${GREEN}🎉 Limpeza concluída com sucesso!${NC}"
    echo ""
    info "✨ Sistema limpo e pronto para nova instalação"
    echo ""
    info "Para reinstalar, execute:"
    echo "  ./setup.sh"
else
    warning "⚠️  Limpeza parcialmente concluída"
    echo ""
    info "Alguns itens podem precisar de remoção manual:"
    [[ $REMAINING_CONTAINERS -gt 0 ]] && echo "  • Containers: docker ps -a"
    [[ $FLASK_SERVICE_EXISTS -gt 0 ]] && echo "  • Serviços: systemctl list-unit-files | grep brln"
    [[ $WEB_FILES_COUNT -gt 0 ]] && echo "  • Arquivos web: ls -la /var/www/html/"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
