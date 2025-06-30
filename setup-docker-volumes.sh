#!/bin/bash

# Script para criar diretórios e arquivos necessários para o docker-compose
# com as permissões corretas

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

# Verificar se estamos no diretório correto
if [[ ! -f "docker-compose.yml" ]]; then
    error "docker-compose.yml não encontrado. Execute este script no diretório container/"
    exit 1
fi

log "=== Configurando diretórios e arquivos para Docker Compose ==="

# Criar diretórios de dados principais
log "Criando diretórios de dados principais..."
sudo mkdir -p /data/{lnd,elements}
sudo chown -R 1000:1000 /data/lnd
sudo chown -R 1000:1000 /data/elements
sudo chmod -R 755 /data

# Criar diretório específico para LND e subdiretórios
log "Configurando estrutura do LND..."
sudo mkdir -p /data/lnd/{data/chain/bitcoin/mainnet,logs/bitcoin/mainnet}
sudo chown -R 1000:1000 /data/lnd
sudo chmod -R 755 /data/lnd

# Verificar e copiar arquivos de configuração do LND
log "Configurando arquivos do LND..."
if [[ -f "lnd/lnd.conf" ]]; then
    sudo chown 1000:1000 /data/lnd/lnd.conf
    sudo chmod 644 /data/lnd/lnd.conf
else
    warning "Arquivo lnd/lnd.conf não encontrado"
fi

if [[ -f "lnd/password.txt" ]]; then
    sudo chown 1000:1000 /data/lnd/password.txt
    sudo chmod 600 /data/lnd/password.txt
else
    warning "Arquivo lnd/password.txt não encontrado"
fi

# Configurar Elements
log "Configurando estrutura do Elements..."
sudo mkdir -p /data/elements/{blocks,chainstate,database,wallets}
sudo chown -R 1000:1000 /data/elements
sudo chmod -R 755 /data/elements

if [[ -f "elements/elements.conf" ]]; then
    # Para elements, vamos criar um link simbólico em vez de copiar
    if [[ ! -f "/data/elements/elements.conf" ]]; then
        sudo cp elements/elements.conf /data/elements/
        sudo chown 1000:1000 /data/elements/elements.conf
        sudo chmod 644 /data/elements/elements.conf
        info "Arquivo elements.conf copiado para /data/elements/"
    fi
else
    warning "Arquivo elements/elements.conf não encontrado"
fi

# Criar diretórios para monitoramento se não existirem
log "Verificando diretórios de monitoramento..."
if [[ -d "monitoring" ]]; then
    for dir in provisioning dashboards; do
        if [[ -d "monitoring/$dir" ]]; then
            info "Diretório monitoring/$dir já existe"
        else
            warning "Diretório monitoring/$dir não existe - pode ser necessário criar"
        fi
    done
fi

# Verificar se todos os arquivos de configuração necessários existem
log "Verificando arquivos de configuração necessários..."

required_files=(
    "lnd/lnd.conf"
    "lnd/password.txt"
    "elements/elements.conf"
    "peerswap/peerswap.conf"
    "monitoring/prometheus.yml"
    "monitoring/loki-config.yml"
    "monitoring/promtail-config.yml"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [[ ${#missing_files[@]} -gt 0 ]]; then
    warning "Arquivos de configuração não encontrados:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    warning "Certifique-se de que estes arquivos existem antes de executar docker-compose"
fi

# Verificar e ajustar permissões de arquivos existentes
log "Verificando permissões de arquivos..."
if [[ -f "lnd/entrypoint.sh" ]]; then
    chmod +x lnd/entrypoint.sh
    info "Permissões de execução definidas para lnd/entrypoint.sh"
fi

# Verificar Dockerfiles
log "Verificando Dockerfiles..."
dockerfiles=(
    "lnd/Dockerfile.lnd"
    "elements/Dockerfile.elements"
    "peerswap/Dockerfile.peerswap"
    "tor/Dockerfile.tor"
    "i2pd/Dockerfile.i2pd"
)

for dockerfile in "${dockerfiles[@]}"; do
    if [[ ! -f "$dockerfile" ]]; then
        warning "Dockerfile não encontrado: $dockerfile"
    else
        info "Dockerfile encontrado: $dockerfile"
    fi
done

# Verificar binários necessários
log "Verificando binários necessários..."
if [[ -f "lnd/lnd-linux-amd64-v0.18.5-beta.tar.gz" ]]; then
    info "Binário do LND encontrado"
else
    warning "Binário do LND não encontrado: lnd/lnd-linux-amd64-v0.18.5-beta.tar.gz"
fi

if [[ -f "elements/elements-23.2.7-x86_64-linux-gnu.tar.gz" ]]; then
    info "Binário do Elements encontrado"
else
    warning "Binário do Elements não encontrado: elements/elements-23.2.7-x86_64-linux-gnu.tar.gz"
fi

if [[ -f "peerswap/peerswap-4.0rc1.tar.gz" ]]; then
    info "Binário do PeerSwap encontrado"
else
    warning "Binário do PeerSwap não encontrado: peerswap/peerswap-4.0rc1.tar.gz"
fi

log "=== Configuração concluída ==="
log "Agora você pode executar: docker-compose up -d"
log "Para monitorar os logs: docker-compose logs -f [nome_do_serviço]"

# Mostrar resumo
echo ""
info "=== RESUMO ==="
info "Diretórios criados em /data:"
ls -la /data/ 2>/dev/null || info "Diretório /data não acessível"
echo ""
info "Estrutura do LND:"
ls -la /data/lnd/ 2>/dev/null || info "Diretório /data/lnd não acessível"
