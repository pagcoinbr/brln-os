#!/bin/bash

# Script para alternar entre modo de spinner e modo de logs visíveis
# Uso: ./toggle-debug.sh [on|off|status]

SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/.debug_mode"
RUN_SCRIPT="$SCRIPT_DIR/../run.sh"

# Função para mostrar o status atual
show_status() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo -e "\033[0;32m✓ Modo DEBUG ATIVO\033[0m - Logs visíveis, spinners desabilitados"
    else
        echo -e "\033[0;33m✓ Modo NORMAL ATIVO\033[0m - Spinners habilitados, logs ocultos"
    fi
}

# Função para ativar modo debug (mostrar logs)
enable_debug() {
    touch "$CONFIG_FILE"
    echo -e "\033[0;32m✓ Modo DEBUG ATIVADO\033[0m"
    echo "  • Logs de instalação serão exibidos"
    echo "  • Spinners serão desabilitados"
    echo "  • Para desativar execute: ./toggle-debug.sh off"
}

# Função para desativar modo debug (usar spinners)
disable_debug() {
    rm -f "$CONFIG_FILE"
    echo -e "\033[0;33m✓ Modo NORMAL ATIVADO\033[0m"
    echo "  • Spinners habilitados"
    echo "  • Logs ocultos para melhor experiência visual"
    echo "  • Para ativar debug execute: ./toggle-debug.sh on"
}

# Função para modificar o comportamento do spinner
patch_spinner_function() {
    local debug_mode="$1"
    local basic_script="$SCRIPT_DIR/basic.sh"
    
    if [[ "$debug_mode" == "true" ]]; then
        # Criar versão debug do spinner (apenas executa o comando sem spinner)
        cat > "$SCRIPT_DIR/basic-debug.sh" << 'EOF'
spinner() {
    local pid=${1:-$!}
    echo -e "\033[0;36m[DEBUG]\033[0m Executando comando com logs visíveis..."
    wait "$pid" 2>/dev/null
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "\033[0;32m✔️ Comando executado com sucesso!\033[0m"
    else
        echo -e "\033[0;31m❌ Comando falhou com código: $exit_code\033[0m"
    fi
    
    return $exit_code
}

# Função para substituir redirecionamentos nos comandos
debug_command() {
    local cmd="$1"
    # Remove redirecionamentos > /dev/null 2>&1 e >> /dev/null 2>&1
    cmd=$(echo "$cmd" | sed 's/ >> \/dev\/null 2>&1//g' | sed 's/ > \/dev\/null 2>&1//g')
    eval "$cmd"
}

EOF
        # Adiciona o resto das funções do basic.sh (sem a função spinner original)
        grep -v "^spinner()" "$basic_script" | grep -A 1000 "^basics()" >> "$SCRIPT_DIR/basic-debug.sh"
    else
        # Remove arquivo debug se existir
        rm -f "$SCRIPT_DIR/basic-debug.sh"
    fi
}

# Função para criar script wrapper que detecta modo debug
create_debug_wrapper() {
    cat > "$SCRIPT_DIR/run-with-debug.sh" << 'EOF'
#!/bin/bash

# Wrapper que detecta modo debug e ajusta o comportamento
SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/.debug_mode"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "\033[0;36m[DEBUG MODE]\033[0m Executando com logs visíveis..."
    export DEBUG_MODE=true
    # Substitui temporariamente .env por .env-debug
    if [[ -f "$SCRIPT_DIR/.env-debug" ]]; then
        mv "$SCRIPT_DIR/.env" "$SCRIPT_DIR/.env-original" 2>/dev/null || true
        cp "$SCRIPT_DIR/.env-debug" "$SCRIPT_DIR/.env"
    fi
else
    echo -e "\033[0;33m[NORMAL MODE]\033[0m Executando com spinners..."
    export DEBUG_MODE=false
    # Restaura .env original se existir
    if [[ -f "$SCRIPT_DIR/.env-original" ]]; then
        mv "$SCRIPT_DIR/.env-original" "$SCRIPT_DIR/.env"
    fi
fi

# Executa o script principal
bash "$SCRIPT_DIR/../run.sh" "$@"
RESULT=$?

# Restaura basic.sh original após execução (modo debug)
if [[ -f "$CONFIG_FILE" && -f "$SCRIPT_DIR/basic-original.sh" ]]; then
    mv "$SCRIPT_DIR/basic-original.sh" "$SCRIPT_DIR/basic.sh"
fi

exit $RESULT
EOF
    chmod +x "$SCRIPT_DIR/run-with-debug.sh"
}

# Função principal
main() {
    case "${1:-status}" in
        "on"|"enable"|"debug")
            enable_debug
            patch_spinner_function "true"
            ;;
        "off"|"disable"|"normal")
            disable_debug
            patch_spinner_function "false"
            ;;
        "status"|"check"|"")
            show_status
            ;;
        "help"|"-h"|"--help")
            echo "Uso: $0 [comando]"
            echo ""
            echo "Comandos:"
            echo "  on, enable, debug    - Ativa modo debug (mostra logs)"
            echo "  off, disable, normal - Desativa modo debug (usa spinners)"
            echo "  status, check        - Mostra status atual"
            echo "  help                 - Mostra esta ajuda"
            echo ""
            echo "Modo DEBUG:"
            echo "  • Logs de instalação ficam visíveis"
            echo "  • Spinners são desabilitados"
            echo "  • Útil para debugging e desenvolvimento"
            echo ""
            echo "Modo NORMAL:"
            echo "  • Interface com spinners animados"
            echo "  • Logs ocultos para melhor UX"
            echo "  • Modo padrão para usuários finais"
            ;;
        *)
            echo "❌ Comando inválido: $1"
            echo "Use '$0 help' para ver os comandos disponíveis"
            exit 1
            ;;
    esac
}

# Cria o wrapper na primeira execução
create_debug_wrapper

# Executa função principal
main "$@"
