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

ELEMENTS_UID=1001
LND_UID=1000

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
sudo chown -R $LND_UID:$LND_UID /data/lnd
sudo chown -R $ELEMENTS_UID:$ELEMENTS_UID /data/elements
sudo chmod -R 755 /data

# Criar diretório específico para LND e subdiretórios
log "Configurando estrutura do LND..."
sudo mkdir -p /data/lnd/{data/chain/bitcoin/mainnet,logs/bitcoin/mainnet}
sudo chown -R $LND_UID:$LND_UID /data/lnd
sudo chmod -R 755 /data/lnd

# Verificar e copiar arquivos de configuração do LND
log "Configurando arquivos do LND..."
if [[ -f "/root/brlnfullauto/container/lnd/lnd.conf.example" ]]; then
    sudo cp /root/brlnfullauto/container/lnd/lnd.conf.example /data/lnd/lnd.conf
    sudo chown $LND_UID:$LND_UID /data/lnd/lnd.conf
    sudo chmod 644 /data/lnd/lnd.conf
    info "Arquivo lnd.conf copiado para /data/lnd/"
else
    warning "Arquivo lnd/lnd.conf não encontrado"
fi

if [[ -f "lnd/password.txt" ]]; then
    sudo cp lnd/password.txt /data/lnd/
    sudo chown $LND_UID:$LND_UID /data/lnd/password.txt
    sudo chmod 600 /data/lnd/password.txt
    info "Arquivo password.txt copiado para /data/lnd/"
else
    warning "Arquivo lnd/password.txt não encontrado"
fi

# Configurar Elements
log "Configurando estrutura do Elements..."
sudo mkdir -p /data/elements/{blocks,chainstate,database,wallets,liquidv1}
sudo chown -R $ELEMENTS_UID:$ELEMENTS_UID /data/elements
sudo chmod -R 755 /data/elements

if [[ -f "elements/elements.conf" ]]; then
    # Para elements, vamos criar um link simbólico em vez de copiar
    if [[ ! -f "/root/brlnfullauto/container/elements/elements.conf.example" ]]; then
        sudo cp /root/brlnfullauto/container/elements/elements.conf.example /data/elements/elements.conf
        sudo chown $ELEMENTS_UID:$ELEMENTS_UID /data/elements/elements.conf
        sudo chmod 644 /data/elements/elements.conf
        info "Arquivo elements.conf copiado para /data/elements/"
    fi
else
    warning "Arquivo elements/elements.conf não encontrado"
fi

# Verificar se todos os arquivos de configuração necessários existem
log "Verificando arquivos de configuração necessários..."

required_files=(
    "/root/brlnfullauto/container/elements/elements.conf"
    "/root/brlnfullauto/container/elements/pssword.txt"
    "/root/brlnfullauto/container/elements/elements.conf"
    "/root/brlnfullauto/container/elements/peerswap.conf"
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

# Corrigir permissões existentes se os diretórios já existirem
log "Corrigindo permissões existentes..."
if [[ -d "/data/lnd" ]]; then
    sudo chown -R $LND_UID:$LND_UID /data/lnd
    sudo chmod -R 755 /data/lnd
    info "Permissões do LND corrigidas"
fi

if [[ -d "/data/elements" ]]; then
    sudo chown -R $ELEMENTS_UID:$ELEMENTS_UID /data/elements
    sudo chmod -R 755 /data/elements
    info "Permissões do Elements corrigidas"
fi

if [[ -d "/data/.elements" ]]; then
    sudo chown -R $ELEMENTS_UID:$ELEMENTS_UID /data/.elements
    sudo chmod -R 755 /data/.elements
    info "Permissões do .elements corrigidas"
fi

if [[ -d "/data/liquidv1" ]]; then
    sudo chown -R $ELEMENTS_UID:$ELEMENTS_UID /data/liquidv1
    sudo chmod -R 755 /data/liquidv1
    info "Permissões do liquidv1 corrigidas"
fi

# Configurar sistema de logs
log "Configurando sistema de logs..."
if [[ -f "logs/install-log-manager.sh" ]]; then
    cd logs
    chmod +x install-log-manager.sh
    sudo ./install-log-manager.sh
    cd ..
    info "Sistema de logs configurado e instalado"
else
    warning "Script install-log-manager.sh não encontrado em logs/"
fi

# Apresentar menu de opções
echo -e "${BLUE}=== Menu de Instalação ===${NC}"
echo "Digite abaixo os serviços que deseja instalar:"
echo "Opções disponíveis: lnd, lnbits, elements, peerswap, peerswapweb"
echo "Separe-os usando espaços (ex: lnd elements peerswap)"
read -p "Escolha: " SERVICES

log "=== Configuração concluída ==="
docker-compose down -v || true
docker-compose build ${SERVICES}
docker-compose up -d ${SERVICES}
info "Containers iniciados. O sistema de logs está coletando informações em tempo real."
info "Verifique os logs em: container/logs/"
info "Serviços iniciados: ${SERVICES}"

