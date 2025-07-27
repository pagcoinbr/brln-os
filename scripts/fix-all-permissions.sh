#!/bin/bash

# Script para verificar e corrigir permissões dos diretórios do Bitcoin e LND
set -euo pipefail

# Source das funções básicas
source "$(dirname "$0")/.env"
basics

# Variáveis
REPO_DIR="/root/brln-os"
CONTAINER_DIR="$REPO_DIR/container"
SCRIPTS_DIR="$REPO_DIR/scripts"

# Função principal
main() {
    echo ""
    log "🔧 CORREÇÃO DE PERMISSÕES - BITCOIN E LND"
    log "=========================================="
    echo ""
    
    info "Este script irá verificar e corrigir as permissões dos diretórios:"
    echo "• /data/bitcoin (para o Bitcoin Core)"
    echo "• /data/lnd (para o Lightning Network Daemon)"
    echo ""
    
    read -p "Deseja continuar? (Y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        warning "Operação cancelada pelo usuário."
        exit 0
    fi
    
    echo ""
    log "📋 ETAPA 1/2: Corrigindo permissões do Bitcoin Core..."
    echo "=================================================="
    
    if [[ -f "$SCRIPTS_DIR/fix-bitcoin-permissions.sh" ]]; then
        "$SCRIPTS_DIR/fix-bitcoin-permissions.sh"
    else
        error "❌ Script fix-bitcoin-permissions.sh não encontrado!"
        exit 1
    fi
    
    echo ""
    log "📋 ETAPA 2/2: Corrigindo permissões do LND..."
    echo "============================================="
    
    if [[ -f "$SCRIPTS_DIR/fix-lnd-permissions.sh" ]]; then
        "$SCRIPTS_DIR/fix-lnd-permissions.sh"
    else
        error "❌ Script fix-lnd-permissions.sh não encontrado!"
        exit 1
    fi
    
    echo ""
    log "🎉 CORREÇÃO CONCLUÍDA!"
    log "======================"
    echo ""
    info "✅ Permissões do Bitcoin Core corrigidas"
    info "✅ Permissões do LND corrigidas"
    echo ""
    info "💡 Agora você pode iniciar os containers com segurança:"
    echo "   cd $CONTAINER_DIR"
    echo "   docker-compose up -d bitcoin lnd"
    echo ""
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
