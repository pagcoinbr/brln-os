#!/bin/bash

# Script de configuração principal do BRLN Full Auto Container Stack
# Este script simplifica o processo de instalação para usuários finais

set -e

# Solicitar autenticação sudo no início do script
if ! sudo -v; then
    echo -e "${RED}Falha na autenticação sudo. Saindo...${NC}"
    exit 1
fi
# Manter a sessão sudo ativa durante a execução do script
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

spinner() {
    local pid=${1:-$!}
    local delay=0.2
    local max=${SPINNER_MAX:-20}
    local count=0
    local spinstr='|/-\\'
    local j=0

    tput civis

    # Monitorar processo
    while kill -0 "$pid" 2>/dev/null; do
        local emoji=""
        for ((i=0; i<=count; i++)); do
            emoji+="⚡"
        done

        local spin_char="${spinstr:j:1}"
        j=$(( (j + 1) % 4 ))
        count=$(( (count + 1) % (max + 1) ))

        printf "\r\033[KInstalando seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
        sleep "$delay"
    done

    wait "$pid" 2>/dev/null
    exit_code=$?

    tput cnorm
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[K${GREEN}✔️ Processo finalizado com sucesso!${NC}\n"
    else
        printf "\r\033[K${RED}❌ Processo finalizado com erro (código: $exit_code)${NC}\n"
    fi

    return $exit_code
}

# Funções de logging
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warning() { echo -e "${YELLOW}[WARNING] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Verificar se há containers ativos e parar se necessário
if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
    warning "Existem containers Docker ativos. Parando todos os containers..."
    echo "Este processo pode apagar os volumes de projetos em execução, tenha cuidado ao prosseguir."
    read -p "Deseja continuar e parar todos os containers? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operação cancelada pelo usuário.${NC}"
        exit 1
    else
        log "Parando todos os containers e removendo volumes..."
        cd container || exit 1
        docker-compose down -v
        cd - || exit 1
        log "Todos os containers foram parados e volumes removidos."
    fi
fi

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
██████╗ ██████╗ ██╗     ███╗   ██╗    ███████╗██╗   ██╗██╗     ██╗         █████╗ ██╗   ██╗████████╗ ██████╗ 
██╔══██╗██╔══██╗██║     ████╗  ██║    ██╔════╝██║   ██║██║     ██║        ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗
██████╔╝██████╔╝██║     ██╔██╗ ██║    █████╗  ██║   ██║██║     ██║        ███████║██║   ██║   ██║   ██║   ██║
██╔══██╗██╔══██╗██║     ██║╚██╗██║    ██╔══╝  ██║   ██║██║     ██║        ██╔══██║██║   ██║   ██║   ██║   ██║
██████╔╝██║  ██║███████╗██║ ╚████║    ██║     ╚██████╔╝███████╗███████╗   ██║  ██║╚██████╔╝   ██║   ╚██████╔╝
╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝    ╚═╝      ╚═════╝ ╚══════╝╚══════╝   ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ 
██╗     ██╗ ██████╗ ██╗  ██╗████████╗███╗   ██╗██╗███╗   ██╗ ██████╗     ███╗   ██╗ ██████╗ ██████╗ ███████╗
██║     ██║██╔════╝ ██║  ██║╚══██╔══╝████╗  ██║██║████╗  ██║██╔════╝     ████╗  ██║██╔═══██╗██╔══██╗██╔════╝
██║     ██║██║  ███╗███████║   ██║   ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗    ██╔██╗ ██║██║   ██║██║  ██║█████╗  
██║     ██║██║   ██║██╔══██║   ██║   ██║╚██╗██║██║██║╚██╗██║██║   ██║    ██║╚██╗██║██║   ██║██║  ██║██╔══╝  
███████╗██║╚██████╔╝██║  ██║   ██║   ██║ ╚████║██║██║ ╚████║╚██████╔╝    ██║ ╚████║╚██████╔╝██████╔╝███████╗
╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝     ╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝ 

                                                                                                                
    🚀 Container Stack - Bitcoin, Lightning & Liquid Network
EOF
echo -e "${NC}"

echo ""
log "Iniciando configuração do BRLN Full Auto Container Stack..."

# Verificar se estamos no diretório correto
if [[ ! -d "container" ]]; then
    error "Diretório 'container' não encontrado!"
    error "Execute este script no diretório raiz do projeto brlnfullauto"
    echo ""
    echo "Exemplo:"
    echo "  git clone https://github.com/pagcoinbr/brlnfullauto.git"
    echo "  cd brlnfullauto"
    echo "  ./setup.sh"
    exit 1
fi

# Verificar se o script principal existe
if [[ ! -f "container/setup-docker-smartsystem.sh" ]]; then
    error "Script setup-docker-smartsystem.sh não encontrado em container/"
    exit 1
fi

# Verificar pré-requisitos
log "Verificando pré-requisitos do sistema..."

# Verificar se é Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    warning "Este script foi otimizado para Linux. Pode não funcionar corretamente em outros sistemas."
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    warning "Docker não encontrado!"
    echo ""
    echo "Para instalar o Docker, execute:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo ""
    read -p "Deseja que eu instale o Docker automaticamente? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        log "Docker instalado! Você pode precisar fazer logout/login para usar sem sudo"
    else
        error "Docker é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log "Docker encontrado: v$DOCKER_VERSION ✓"
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    warning "Docker Compose não encontrado!"
    echo ""
    echo "Para instalar o Docker Compose, execute:"
    echo "  sudo apt-get update && sudo apt-get install docker-compose-plugin"
    echo ""
    read -p "Deseja que eu instale o Docker Compose automaticamente? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker Compose..."
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin
        log "Docker Compose instalado! ✓"
    else
        error "Docker Compose é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log "Docker Compose encontrado: v$COMPOSE_VERSION ✓"
    else
        COMPOSE_VERSION=$(docker compose version --short)
        log "Docker Compose (plugin) encontrado: v$COMPOSE_VERSION ✓"
    fi
fi

# Verificar espaço em disco
log "Verificando espaço em disco..."
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [[ $AVAILABLE_GB -lt 100 ]]; then
    warning "Espaço em disco baixo: ${AVAILABLE_GB}GB disponível"
    warning "Recomendado: pelo menos 100GB para blockchain completa"
    echo ""
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Operação cancelada pelo usuário"
        exit 1
    fi
else
    log "Espaço em disco suficiente: ${AVAILABLE_GB}GB ✓"
fi

# Verificar permissões nos scripts
log "Configurando permissões dos scripts..."
chmod +x container/setup-docker-smartsystem.sh
if [[ -f "container/build.sh" ]]; then
    chmod +x container/build.sh
fi

# Entrar no diretório container
cd container

log "Iniciando configuração completa..."
echo ""
warning "⚠️  IMPORTANTE: Este processo pode demorar 30-60 minutos"
warning "⚠️  A sincronização inicial da blockchain pode levar várias horas"
warning "⚠️  Certifique-se de ter conexão estável com a internet"
echo ""
read -p "Deseja continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operação cancelada pelo usuário."
    exit 0
fi

log "Executando configuração completa..."
echo ""
read -p "Deseja exibir os logs em tempo real durante a configuração? (y/N): " -n 1 -r
echo

./setup-docker-smartsystem.sh > /tmp/setup.log 2>&1 &
SETUP_PID=$!

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Exibindo logs em tempo real..."
    tail -f /tmp/setup.log --pid=$SETUP_PID
    wait $SETUP_PID
    SETUP_EXIT_CODE=$?
else
    log "Executando configuração em background..."
    spinner $SETUP_PID
    SETUP_EXIT_CODE=$?
fi

# Verificar se houve erro no processo
if [[ $SETUP_EXIT_CODE -ne 0 ]]; then
    error "Erro durante a configuração. Verifique o log em /tmp/setup.log"
    echo ""
    error "Últimas linhas do log:"
    tail -20 /tmp/setup.log
    exit 1
fi

# Verificar se a configuração foi bem-sucedida
echo ""
log "Verificando status dos serviços..."
if command -v docker-compose &> /dev/null; then
    docker-compose ps
else
    docker compose ps
fi

echo ""
log "🎉 Configuração concluída!"
echo ""
info "📱 Interfaces web disponíveis:"
echo "  • LNDG Dashboard: http://localhost:8889"
echo "  • Thunderhub: http://localhost:3000"
echo "  • LNbits: http://localhost:5000"
echo "  • PeerSwap Web: http://localhost:1984"
echo ""
info "📋 Comandos úteis:"
echo "  • Ver logs: docker-compose logs -f [serviço]"
echo "  • Parar tudo: docker-compose down"
echo "  • Reiniciar: docker-compose restart [serviço]"
echo "  • Status: docker-compose ps"
echo ""
warning "🔐 IMPORTANTE: Salve as seeds das carteiras que apareceram nos logs!"
warning "🔐 Faça backup regular dos dados em /data/"
echo ""
log "Para mais informações, consulte o README.md"
