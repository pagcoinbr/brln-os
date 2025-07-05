#!/bin/bash

# Script para build e instalação do setup-docker-intelligent em Rust
# Autor: GitHub Copilot
# Data: $(date +%Y-%m-%d)

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Funções de logging
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }

# Verificar se está no diretório correto
if [[ ! -f "Cargo.toml" ]]; then
    log_error "Cargo.toml não encontrado. Execute este script no diretório container/"
    exit 1
fi

# Verificar se Rust está instalado
if ! command -v cargo &> /dev/null; then
    log_warning "Rust não encontrado. Instalando..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    log_info "Rust instalado com sucesso"
fi

# Verificar versão do Rust
RUST_VERSION=$(rustc --version | cut -d' ' -f2)
log_info "Versão do Rust: $RUST_VERSION"

# Atualizar Rust se necessário
log_info "Atualizando Rust..."
rustup update

# Limpar builds anteriores
log_info "Limpando builds anteriores..."
cargo clean

# Build em modo release
log_info "Compilando em modo release..."
cargo build --release

if [[ $? -eq 0 ]]; then
    log_info "Build concluído com sucesso!"
    
    # Verificar se o executável foi criado
    if [[ -f "target/release/setup-docker-intelligent" ]]; then
        log_info "Executável criado: target/release/setup-docker-intelligent"
        
        # Mostrar tamanho do executável
        SIZE=$(du -h target/release/setup-docker-intelligent | cut -f1)
        log_info "Tamanho do executável: $SIZE"
        
        # Perguntar se quer instalar globalmente
        read -p "Deseja instalar globalmente? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Instalando globalmente..."
            sudo cp target/release/setup-docker-intelligent /usr/local/bin/
            sudo chmod +x /usr/local/bin/setup-docker-intelligent
            log_info "Instalado em /usr/local/bin/setup-docker-intelligent"
            log_info "Agora você pode executar 'setup-docker-intelligent' de qualquer lugar"
        fi
        
        # Mostrar instruções de uso
        echo ""
        echo -e "${BLUE}=== Como usar ===${NC}"
        echo "1. Modo interativo: ./target/release/setup-docker-intelligent"
        echo "2. Modo CLI: ./target/release/setup-docker-intelligent --services 'lnd,elements'"
        echo "3. Modo auto: ./target/release/setup-docker-intelligent --mode auto"
        echo "4. Com dependências: ./target/release/setup-docker-intelligent --services 'lnd' --deps"
        echo "5. Verbose: ./target/release/setup-docker-intelligent --verbose"
        echo ""
        echo "Para mais opções: ./target/release/setup-docker-intelligent --help"
        
    else
        log_error "Executável não encontrado após build"
        exit 1
    fi
else
    log_error "Falha no build"
    exit 1
fi

# Verificar dependências do sistema
echo ""
log_info "Verificando dependências do sistema..."

# Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log_info "Docker encontrado: $DOCKER_VERSION"
else
    log_warning "Docker não encontrado. Instale com: curl -fsSL https://get.docker.com | sh"
fi

# Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
    log_info "Docker Compose encontrado: $COMPOSE_VERSION"
else
    log_warning "Docker Compose não encontrado. Instale com: sudo apt-get install docker-compose"
fi

# jq
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version)
    log_info "jq encontrado: $JQ_VERSION"
else
    log_warning "jq não encontrado (opcional). Instale com: sudo apt-get install jq"
fi

# yq
if command -v yq &> /dev/null; then
    YQ_VERSION=$(yq --version | cut -d' ' -f3)
    log_info "yq encontrado: $YQ_VERSION"
else
    log_warning "yq não encontrado (opcional). Instale com: sudo apt-get install yq"
fi

echo ""
log_info "Setup concluído!"
log_info "Execute './target/release/setup-docker-intelligent --help' para ver todas as opções"
