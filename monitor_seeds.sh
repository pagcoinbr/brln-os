#!/bin/bash

# Script para monitorar logs em tempo real e capturar seeds/senhas
# Este script pode ser executado durante a instalação para capturar seeds conforme são geradas

set -e

COMPOSE_DIR="/home/admin/brlnfullauto/container"
SEEDS_FILE="/home/admin/brlnfullauto/seeds_backup.txt"
MONITORING_LOG="/tmp/seed_monitor.log"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Função para capturar seeds em tempo real
monitor_seeds() {
    log "🔍 Monitorando logs em tempo real para capturar seeds..."
    
    cd "$COMPOSE_DIR"
    
    # Criar arquivo de backup de seeds
    cat > "$SEEDS_FILE" << 'EOF'
# 🌱 SEEDS E FRASES DE RECUPERAÇÃO - BRLN Full Auto
# ⚠️ CRÍTICO: Mantenha este arquivo seguro e faça backup offline!
# 
# Gerado automaticamente durante a instalação

EOF
    
    # Função para processar linha de log
    process_log_line() {
        local line="$1"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Procurar por seeds/mnemonics
        if echo "$line" | grep -iE "(cipher seed|mnemonic|seed phrase|recovery phrase)" >/dev/null; then
            echo "[$timestamp] SEED DETECTADA: $line" >> "$MONITORING_LOG"
            
            # Adicionar ao arquivo de seeds
            echo "" >> "$SEEDS_FILE"
            echo "## 🌱 Seed detectada em $timestamp" >> "$SEEDS_FILE"
            echo '```' >> "$SEEDS_FILE"
            echo "$line" >> "$SEEDS_FILE"
            echo '```' >> "$SEEDS_FILE"
            
            # Alertar usuário
            echo ""
            warning "🚨 SEED DETECTADA! Salva em: $SEEDS_FILE"
            echo ""
        fi
        
        # Procurar por senhas geradas
        if echo "$line" | grep -iE "(senha gerada|password generated|generated password)" >/dev/null; then
            echo "[$timestamp] SENHA GERADA: $line" >> "$MONITORING_LOG"
            
            # Adicionar ao arquivo de seeds
            echo "" >> "$SEEDS_FILE"
            echo "## 🔑 Senha gerada em $timestamp" >> "$SEEDS_FILE"
            echo '```' >> "$SEEDS_FILE"
            echo "$line" >> "$SEEDS_FILE"
            echo '```' >> "$SEEDS_FILE"
            
            # Alertar usuário
            echo ""
            info "🔑 SENHA GERADA! Salva em: $SEEDS_FILE"
            echo ""
        fi
    }
    
    # Monitorar logs em tempo real
    if command -v docker-compose &> /dev/null; then
        docker-compose logs -f --tail=0 | while IFS= read -r line; do
            process_log_line "$line"
        done
    else
        docker compose logs -f --tail=0 | while IFS= read -r line; do
            process_log_line "$line"
        done
    fi
}

# Função para mostrar ajuda
show_help() {
    echo "🌱 BRLN Full Auto - Monitor de Seeds e Senhas"
    echo ""
    echo "Este script monitora os logs do Docker Compose em tempo real"
    echo "e captura automaticamente seeds e senhas conforme são geradas."
    echo ""
    echo "Uso:"
    echo "  $0 [opção]"
    echo ""
    echo "Opções:"
    echo "  monitor    - Monitorar logs em tempo real (padrão)"
    echo "  extract    - Extrair seeds dos logs existentes"
    echo "  help       - Mostrar esta ajuda"
    echo ""
    echo "Arquivos gerados:"
    echo "  • seeds_backup.txt - Backup das seeds encontradas"
    echo "  • passwords.md - Arquivo completo de senhas"
    echo ""
    echo "⚠️ IMPORTANTE: Execute este script DURANTE a instalação"
    echo "para capturar seeds conforme são geradas!"
    echo ""
}

# Função para extrair seeds dos logs existentes
extract_existing_seeds() {
    log "🔍 Extraindo seeds dos logs existentes..."
    
    cd "$COMPOSE_DIR"
    
    # Capturar logs existentes
    local temp_log="/tmp/existing_logs.txt"
    if command -v docker-compose &> /dev/null; then
        docker-compose logs --no-color > "$temp_log" 2>&1
    else
        docker compose logs --no-color > "$temp_log" 2>&1
    fi
    
    # Criar arquivo de seeds
    cat > "$SEEDS_FILE" << 'EOF'
# 🌱 SEEDS E FRASES DE RECUPERAÇÃO - BRLN Full Auto
# ⚠️ CRÍTICO: Mantenha este arquivo seguro e faça backup offline!
# 
# Extraído dos logs existentes

EOF
    
    local found_seeds=0
    
    # Procurar por seeds nos logs
    if grep -iE "(cipher seed|mnemonic|seed phrase|recovery phrase)" "$temp_log" >/dev/null; then
        echo "" >> "$SEEDS_FILE"
        echo "## 🌱 Seeds encontradas nos logs" >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        grep -iE "(cipher seed|mnemonic|seed phrase|recovery phrase)" "$temp_log" >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        ((found_seeds++))
    fi
    
    # Procurar por senhas geradas
    if grep -iE "(senha gerada|password generated|generated password)" "$temp_log" >/dev/null; then
        echo "" >> "$SEEDS_FILE"
        echo "## 🔑 Senhas geradas encontradas nos logs" >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        grep -iE "(senha gerada|password generated|generated password)" "$temp_log" >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        ((found_seeds++))
    fi
    
    # Procurar por palavras da seed (24 palavras em sequência)
    if grep -A 30 -B 5 "cipher seed" "$temp_log" | grep -E "^[0-9]+\." >/dev/null; then
        echo "" >> "$SEEDS_FILE"
        echo "## 🔤 Palavras da seed encontradas" >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        grep -A 30 -B 5 "cipher seed" "$temp_log" | grep -E "^[0-9]+\." >> "$SEEDS_FILE"
        echo '```' >> "$SEEDS_FILE"
        ((found_seeds++))
    fi
    
    if [[ $found_seeds -eq 0 ]]; then
        echo "" >> "$SEEDS_FILE"
        echo "## ℹ️ Nenhuma seed encontrada nos logs" >> "$SEEDS_FILE"
        echo "" >> "$SEEDS_FILE"
        echo "Isso pode ocorrer se:" >> "$SEEDS_FILE"
        echo "- A carteira já foi criada anteriormente" >> "$SEEDS_FILE"
        echo "- Os logs foram limpos" >> "$SEEDS_FILE"
        echo "- A seed foi exibida em uma sessão anterior" >> "$SEEDS_FILE"
        echo "" >> "$SEEDS_FILE"
        echo "Para obter a seed, você pode:" >> "$SEEDS_FILE"
        echo "1. Executar este script durante a próxima instalação" >> "$SEEDS_FILE"
        echo "2. Recriar a carteira manualmente" >> "$SEEDS_FILE"
        echo "3. Consultar a documentação oficial" >> "$SEEDS_FILE"
        
        warning "Nenhuma seed encontrada nos logs existentes"
    else
        log "✅ $found_seeds item(s) encontrado(s) e salvo(s) em: $SEEDS_FILE"
    fi
    
    # Limpar arquivo temporário
    rm -f "$temp_log"
}

# Função principal
main() {
    local action="${1:-monitor}"
    
    case "$action" in
        "monitor")
            log "=== BRLN Full Auto - Monitor de Seeds (Tempo Real) ==="
            echo ""
            info "🔍 Monitorando logs em tempo real..."
            info "📁 Seeds serão salvas em: $SEEDS_FILE"
            echo ""
            warning "⚠️ Mantenha este script executando durante a instalação!"
            echo ""
            info "💡 Para parar o monitoramento, pressione Ctrl+C"
            echo ""
            
            # Configurar trap para cleanup
            trap 'log "Monitor interrompido pelo usuário"; exit 0' INT TERM
            
            monitor_seeds
            ;;
        
        "extract")
            log "=== BRLN Full Auto - Extração de Seeds (Logs Existentes) ==="
            echo ""
            extract_existing_seeds
            echo ""
            log "✅ Extração concluída!"
            info "📁 Resultados salvos em: $SEEDS_FILE"
            ;;
        
        "help"|"-h"|"--help")
            show_help
            ;;
        
        *)
            error "Ação desconhecida: $action"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Verificar se o diretório do docker-compose existe
if [[ ! -d "$COMPOSE_DIR" ]]; then
    error "Diretório não encontrado: $COMPOSE_DIR"
    exit 1
fi

# Executar função principal
main "$@"
