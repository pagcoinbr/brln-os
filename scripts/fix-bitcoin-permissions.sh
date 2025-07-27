#!/bin/bash

# Script para verificar e corrigir permissões dos diretórios do Bitcoin
set -euo pipefail

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

# Variáveis
REPO_DIR="/root/brln-os"
CONTAINER_DIR="$REPO_DIR/container"
BITCOIN_DATA_DIR="/data/bitcoin"

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

# Função para obter UID/GID do usuário Bitcoin no container
get_bitcoin_uid_gid() {
    log "🔍 Verificando UID/GID do usuário Bitcoin no container..."
    
    cd "$CONTAINER_DIR"
    
    # Tentar obter UID/GID executando um container temporário
    local uid_gid_output
    uid_gid_output=$(docker-compose run --rm bitcoin id bitcoin 2>/dev/null || echo "")
    
    if [[ -n "$uid_gid_output" ]]; then
        # Extrair UID e GID do output (formato: uid=1007(bitcoin) gid=1007(bitcoin) ...)
        BITCOIN_UID=$(echo "$uid_gid_output" | grep -o 'uid=[0-9]*' | cut -d'=' -f2)
        BITCOIN_GID=$(echo "$uid_gid_output" | grep -o 'gid=[0-9]*' | cut -d'=' -f2)
        
        if [[ -n "$BITCOIN_UID" && -n "$BITCOIN_GID" ]]; then
            log "✅ Usuário Bitcoin encontrado: UID=$BITCOIN_UID, GID=$BITCOIN_GID"
            return 0
        fi
    fi
    
    error "❌ Não foi possível determinar UID/GID do usuário Bitcoin"
    error "Verifique se o Dockerfile.bitcoin está correto e se a imagem pode ser construída"
    exit 1
}

# Função para verificar permissões atuais
check_current_permissions() {
    log "📋 Verificando permissões atuais do diretório $BITCOIN_DATA_DIR..."
    
    if [[ ! -d "$BITCOIN_DATA_DIR" ]]; then
        warning "⚠️ Diretório $BITCOIN_DATA_DIR não existe. Será criado."
        return 1
    fi
    
    # Obter informações do diretório
    local dir_info=$(ls -ld "$BITCOIN_DATA_DIR" 2>/dev/null)
    local current_owner=$(stat -c '%u:%g' "$BITCOIN_DATA_DIR" 2>/dev/null)
    
    log "📂 Informações atuais do diretório:"
    log "   Caminho: $BITCOIN_DATA_DIR"
    log "   Permissões: $dir_info"
    log "   Proprietário (UID:GID): $current_owner"
    
    # Verificar se as permissões estão corretas
    if [[ "$current_owner" == "$BITCOIN_UID:$BITCOIN_GID" ]]; then
        log "✅ Permissões estão corretas!"
        return 0
    else
        warning "⚠️ Permissões precisam ser corrigidas"
        warning "   Atual: $current_owner"
        warning "   Necessário: $BITCOIN_UID:$BITCOIN_GID"
        return 1
    fi
}

# Função para criar e configurar diretórios
fix_directory_permissions() {
    log "🔧 Corrigindo permissões do diretório $BITCOIN_DATA_DIR..."
    
    # Criar diretório se não existir
    if [[ ! -d "$BITCOIN_DATA_DIR" ]]; then
        log "📁 Criando diretório $BITCOIN_DATA_DIR..."
        mkdir -p "$BITCOIN_DATA_DIR"
    fi
    
    # Criar subdirs necessários para Bitcoin Core
    log "📁 Criando subdiretórios necessários..."
    mkdir -p "$BITCOIN_DATA_DIR/blocks"
    mkdir -p "$BITCOIN_DATA_DIR/chainstate"
    mkdir -p "$BITCOIN_DATA_DIR/indexes"
    mkdir -p "$BITCOIN_DATA_DIR/wallets"
    mkdir -p "$BITCOIN_DATA_DIR/.cookie"
    
    # Corrigir ownership
    log "👤 Corrigindo proprietário para UID:GID $BITCOIN_UID:$BITCOIN_GID..."
    chown -R "$BITCOIN_UID:$BITCOIN_GID" "$BITCOIN_DATA_DIR"
    
    # Definir permissões adequadas
    log "🔐 Definindo permissões 755 para diretórios..."
    find "$BITCOIN_DATA_DIR" -type d -exec chmod 755 {} \;
    
    log "🔐 Definindo permissões 644 para arquivos..."
    find "$BITCOIN_DATA_DIR" -type f -exec chmod 644 {} \;
    
    # Verificar se foi aplicado corretamente
    local new_owner=$(stat -c '%u:%g' "$BITCOIN_DATA_DIR" 2>/dev/null)
    if [[ "$new_owner" == "$BITCOIN_UID:$BITCOIN_GID" ]]; then
        log "✅ Permissões corrigidas com sucesso!"
        log "   Novo proprietário: $new_owner"
    else
        error "❌ Falha ao corrigir permissões"
        error "   Esperado: $BITCOIN_UID:$BITCOIN_GID"
        error "   Atual: $new_owner"
        exit 1
    fi
}

# Função para verificar arquivos de configuração
check_config_files() {
    log "📄 Verificando arquivos de configuração..."
    
    local files_to_check=(
        "$BITCOIN_DATA_DIR/bitcoin.conf"
        "$BITCOIN_DATA_DIR/settings.json"
        "$BITCOIN_DATA_DIR/.cookie"
    )
    
    for file in "${files_to_check[@]}"; do
        if [[ -f "$file" ]]; then
            local file_owner=$(stat -c '%u:%g' "$file" 2>/dev/null)
            if [[ "$file_owner" != "$BITCOIN_UID:$BITCOIN_GID" ]]; then
                log "🔧 Corrigindo proprietário de $file..."
                chown "$BITCOIN_UID:$BITCOIN_GID" "$file"
                chmod 644 "$file"
            fi
            log "✅ $file - proprietário correto"
        else
            info "ℹ️ $file - não existe (será criado pelo container)"
        fi
    done
    
    # Verificar arquivos especiais (podem ter permissões diferentes)
    if [[ -f "$BITCOIN_DATA_DIR/.cookie" ]]; then
        chmod 600 "$BITCOIN_DATA_DIR/.cookie"
        log "🔐 Permissões especiais aplicadas ao arquivo .cookie"
    fi
}

# Função para exibir resumo final
show_summary() {
    echo ""
    log "📊 RESUMO DAS PERMISSÕES:"
    echo "=================================="
    
    # Mostrar informações do diretório principal
    local dir_info=$(ls -ld "$BITCOIN_DATA_DIR" 2>/dev/null)
    log "📂 Diretório principal: $BITCOIN_DATA_DIR"
    log "   $dir_info"
    
    # Mostrar subdirs importantes
    local subdirs=(
        "$BITCOIN_DATA_DIR/blocks"
        "$BITCOIN_DATA_DIR/chainstate"
        "$BITCOIN_DATA_DIR/indexes"
        "$BITCOIN_DATA_DIR/wallets"
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
        "$BITCOIN_DATA_DIR/bitcoin.conf"
        "$BITCOIN_DATA_DIR/settings.json"
        "$BITCOIN_DATA_DIR/.cookie"
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
    log "🔧 CORREÇÃO DE PERMISSÕES DO BITCOIN"
    log "===================================="
    echo ""
    
    # Verificar dependências
    check_docker
    
    # Obter UID/GID do usuário Bitcoin
    get_bitcoin_uid_gid
    
    # Verificar permissões atuais
    if ! check_current_permissions; then
        echo ""
        info "🔧 Permissões precisam ser corrigidas."
        read -p "Deseja corrigir as permissões agora? (Y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            warning "⚠️ Permissões não foram corrigidas. O Bitcoin Core pode falhar ao iniciar."
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
    info "💡 Agora você pode iniciar o container com segurança:"
    echo "   cd $CONTAINER_DIR"
    echo "   docker-compose up -d bitcoin"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
