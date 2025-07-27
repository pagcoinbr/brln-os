#!/bin/bash

# Script para verificar e corrigir permissões dos diretórios do LND
set -euo pipefail

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

# Variáveis
REPO_DIR="/root/brln-os"
CONTAINER_DIR="$REPO_DIR/container"
LND_DATA_DIR="/data/lnd"

# Função para verificar se Docker está instalado
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker não está instalado!"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose não está instalado!"
        exit 1
    fi
    
    log "✅ Docker e Docker Compose encontrados"
}

# Função para obter UID/GID do usuário LND no container
get_lnd_uid_gid() {
    log "🔍 Verificando UID/GID do usuário LND no container..."
    
    cd "$CONTAINER_DIR"
    
    # Tentar obter UID/GID executando um container temporário
    local uid_gid_output
    uid_gid_output=$(docker-compose run --rm lnd id lnd 2>/dev/null || echo "")
    
    if [[ -n "$uid_gid_output" ]]; then
        # Extrair UID e GID do output (formato: uid=1000(lnd) gid=1000(lnd) ...)
        LND_UID=$(echo "$uid_gid_output" | grep -o 'uid=[0-9]*' | cut -d'=' -f2)
        LND_GID=$(echo "$uid_gid_output" | grep -o 'gid=[0-9]*' | cut -d'=' -f2)
        
        if [[ -n "$LND_UID" && -n "$LND_GID" ]]; then
            log "✅ Usuário LND encontrado: UID=$LND_UID, GID=$LND_GID"
            return 0
        fi
    fi
    
    error "❌ Não foi possível determinar UID/GID do usuário LND"
    error "Verifique se o Dockerfile.lnd está correto e se a imagem pode ser construída"
    exit 1
}

# Função para verificar permissões atuais
check_current_permissions() {
    log "📋 Verificando permissões atuais do diretório $LND_DATA_DIR..."
    
    if [[ ! -d "$LND_DATA_DIR" ]]; then
        warning "⚠️ Diretório $LND_DATA_DIR não existe. Será criado."
        return 1
    fi
    
    # Obter informações do diretório
    local dir_info=$(ls -ld "$LND_DATA_DIR" 2>/dev/null)
    local current_owner=$(stat -c '%u:%g' "$LND_DATA_DIR" 2>/dev/null)
    
    log "📂 Informações atuais do diretório:"
    log "   Caminho: $LND_DATA_DIR"
    log "   Permissões: $dir_info"
    log "   Proprietário (UID:GID): $current_owner"
    
    # Verificar se as permissões estão corretas
    if [[ "$current_owner" == "$LND_UID:$LND_GID" ]]; then
        log "✅ Permissões estão corretas!"
        return 0
    else
        warning "⚠️ Permissões precisam ser corrigidas"
        warning "   Atual: $current_owner"
        warning "   Necessário: $LND_UID:$LND_GID"
        return 1
    fi
}

# Função para criar e configurar diretórios
fix_directory_permissions() {
    log "🔧 Corrigindo permissões do diretório $LND_DATA_DIR..."
    
    # Criar diretório se não existir
    if [[ ! -d "$LND_DATA_DIR" ]]; then
        log "📁 Criando diretório $LND_DATA_DIR..."
        mkdir -p "$LND_DATA_DIR"
    fi
    
    # Criar subdirs necessários
    log "📁 Criando subdiretórios necessários..."
    mkdir -p "$LND_DATA_DIR/data"
    mkdir -p "$LND_DATA_DIR/data/chain"
    mkdir -p "$LND_DATA_DIR/data/chain/bitcoin"
    mkdir -p "$LND_DATA_DIR/data/chain/bitcoin/mainnet"
    mkdir -p "$LND_DATA_DIR/logs"
    
    # Corrigir ownership
    log "👤 Corrigindo proprietário para UID:GID $LND_UID:$LND_GID..."
    chown -R "$LND_UID:$LND_GID" "$LND_DATA_DIR"
    
    # Definir permissões adequadas
    log "🔐 Definindo permissões 755..."
    chmod -R 755 "$LND_DATA_DIR"
    
    # Verificar se foi aplicado corretamente
    local new_owner=$(stat -c '%u:%g' "$LND_DATA_DIR" 2>/dev/null)
    if [[ "$new_owner" == "$LND_UID:$LND_GID" ]]; then
        log "✅ Permissões corrigidas com sucesso!"
        log "   Novo proprietário: $new_owner"
    else
        error "❌ Falha ao corrigir permissões"
        error "   Esperado: $LND_UID:$LND_GID"
        error "   Atual: $new_owner"
        exit 1
    fi
}

# Função para verificar arquivos de configuração
check_config_files() {
    log "📄 Verificando arquivos de configuração..."
    
    local files_to_check=(
        "$LND_DATA_DIR/lnd.conf"
        "$LND_DATA_DIR/password.txt"
    )
    
    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]]; then
            local file_owner=$(stat -c '%u:%g' "$file" 2>/dev/null)
            if [[ "$file_owner" != "$LND_UID:$LND_GID" ]]; then
                log "🔧 Corrigindo proprietário de $file..."
                chown "$LND_UID:$LND_GID" "$file"
            fi
            log "✅ $file - proprietário correto"
        else
            info "ℹ️ $file - não existe (será criado pelo container)"
        fi
    done
}

# Função para exibir resumo final
show_summary() {
    echo ""
    log "📊 RESUMO DAS PERMISSÕES:"
    echo "=================================="
    
    # Mostrar informações do diretório principal
    local dir_info=$(ls -ld "$LND_DATA_DIR" 2>/dev/null)
    log "📂 Diretório principal: $LND_DATA_DIR"
    log "   $dir_info"
    
    # Mostrar subdirs importantes
    local subdirs=(
        "$LND_DATA_DIR/data"
        "$LND_DATA_DIR/data/chain/bitcoin/mainnet"
        "$LND_DATA_DIR/logs"
    )
    
    for subdir in "${subdirs[@]}"; do
        if [[ -d "$subdir" ]]; then
            local subdir_info=$(ls -ld "$subdir" 2>/dev/null)
            log "   └── $(basename "$subdir"): $(echo "$subdir_info" | awk '{print $1, $3":"$4}')"
        fi
    done
    
    # Mostrar arquivos de configuração
    echo ""
    log "📄 Arquivos de configuração:"
    local config_files=(
        "$LND_DATA_DIR/lnd.conf"
        "$LND_DATA_DIR/password.txt"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            local file_info=$(ls -l "$file" 2>/dev/null)
            log "   ✅ $(basename "$file"): $(echo "$file_info" | awk '{print $1, $3":"$4}')"
        else
            log "   ➖ $(basename "$file"): não existe"
        fi
    done
    
    echo "=================================="
    log "✅ Verificação de permissões concluída!"
    echo ""
}

# Função principal
main() {
    echo ""
    log "🔧 CORREÇÃO DE PERMISSÕES DO LND"
    log "=================================="
    echo ""
    
    # Verificar dependências
    check_docker
    
    # Obter UID/GID do usuário LND
    get_lnd_uid_gid
    
    # Verificar permissões atuais
    if ! check_current_permissions; then
        echo ""
        info "🔧 Permissões precisam ser corrigidas."
        read -p "Deseja corrigir as permissões agora? (Y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            warning "⚠️ Permissões não foram corrigidas. O LND pode falhar ao iniciar."
            exit 1
        fi
        
        # Corrigir permissões
        fix_directory_permissions
    fi
    
    # Verificar arquivos de configuração
    check_config_files
    
    # Exibir resumo
    show_summary
    
    echo ""
    info "💡 Agora você pode iniciar os containers com segurança:"
    echo "   cd $CONTAINER_DIR"
    echo "   docker-compose up -d lnd"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
