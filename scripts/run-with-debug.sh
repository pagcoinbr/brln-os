#!/bin/bash

# Wrapper que detecta modo debug e ajusta o comportamento
SCRIPT_DIR="$(dirname "$0")"
CONFIG_FILE="$SCRIPT_DIR/.debug_mode"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "\033[0;36m[DEBUG MODE]\033[0m Executando com logs visíveis..."
    export DEBUG_MODE=true
    # Substitui temporariamente basic.sh por basic-debug.sh
    if [[ -f "$SCRIPT_DIR/basic-debug.sh" ]]; then
        mv "$SCRIPT_DIR/basic.sh" "$SCRIPT_DIR/basic-original.sh" 2>/dev/null || true
        cp "$SCRIPT_DIR/basic-debug.sh" "$SCRIPT_DIR/basic.sh"
    fi
else
    echo -e "\033[0;33m[NORMAL MODE]\033[0m Executando com spinners..."
    export DEBUG_MODE=false
    # Restaura basic.sh original se existir
    if [[ -f "$SCRIPT_DIR/basic-original.sh" ]]; then
        mv "$SCRIPT_DIR/basic-original.sh" "$SCRIPT_DIR/basic.sh"
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
