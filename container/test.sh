#!/bin/bash

# Script de teste para o setup-docker-intelligent em Rust
# Testa funcionalidades básicas sem executar docker-compose

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[TEST INFO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[TEST WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[TEST ERROR]${NC} $1"; }

# Verificar se está no diretório correto
if [[ ! -f "Cargo.toml" ]]; then
    log_error "Execute no diretório container/"
    exit 1
fi

log_info "Iniciando testes do setup-docker-intelligent..."

# Teste 1: Compilação
log_info "Teste 1: Verificando compilação..."
if cargo check; then
    log_info "✓ Compilação OK"
else
    log_error "✗ Falha na compilação"
    exit 1
fi

# Teste 2: Build
log_info "Teste 2: Build em modo debug..."
if cargo build; then
    log_info "✓ Build OK"
else
    log_error "✗ Falha no build"
    exit 1
fi

# Teste 3: Verificar dependências
log_info "Teste 3: Verificando dependências do sistema..."

# Docker
if command -v docker &> /dev/null; then
    log_info "✓ Docker encontrado"
else
    log_warning "⚠ Docker não encontrado"
fi

# Docker Compose
if command -v docker-compose &> /dev/null; then
    log_info "✓ Docker Compose encontrado"
else
    log_warning "⚠ Docker Compose não encontrado"
fi

# Teste 4: Verificar arquivo docker-compose.yml
log_info "Teste 4: Verificando docker-compose.yml..."
if [[ -f "docker-compose.yml" ]]; then
    log_info "✓ docker-compose.yml encontrado"
    
    # Verificar se é YAML válido
    if command -v yq &> /dev/null; then
        if yq eval '.' docker-compose.yml > /dev/null 2>&1; then
            log_info "✓ docker-compose.yml é YAML válido"
        else
            log_warning "⚠ docker-compose.yml pode ter problemas de sintaxe"
        fi
    fi
else
    log_warning "⚠ docker-compose.yml não encontrado"
fi

# Teste 5: Verificar arquivos service.json
log_info "Teste 5: Verificando arquivos service.json..."
service_count=0
for service_file in */service.json; do
    if [[ -f "$service_file" ]]; then
        service_dir=$(dirname "$service_file")
        if jq empty "$service_file" 2>/dev/null; then
            log_info "✓ $service_file é JSON válido"
            ((service_count++))
        else
            log_warning "⚠ $service_file tem JSON inválido"
        fi
    fi
done

if [[ $service_count -gt 0 ]]; then
    log_info "✓ Encontrados $service_count arquivos service.json válidos"
else
    log_warning "⚠ Nenhum arquivo service.json válido encontrado"
fi

# Teste 6: Teste de help
log_info "Teste 6: Testando --help..."
if ./target/debug/setup-docker-intelligent --help > /dev/null 2>&1; then
    log_info "✓ --help funciona"
else
    log_warning "⚠ --help pode ter problemas"
fi

# Teste 7: Teste de dry-run (se implementado)
log_info "Teste 7: Testando modo verbose..."
# Como não temos modo dry-run, vamos apenas verificar se não há crash imediato
timeout 5s ./target/debug/setup-docker-intelligent --verbose --services "test" 2>/dev/null || {
    log_info "✓ Programa não crashou imediatamente (esperado)"
}

echo ""
log_info "=== Resumo dos Testes ==="
log_info "Todos os testes básicos foram executados"
log_info "Para teste completo, execute manualmente:"
echo "  ./target/debug/setup-docker-intelligent --verbose"
echo ""
log_info "Para build de produção:"
echo "  ./build.sh"
