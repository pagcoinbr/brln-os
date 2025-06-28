#!/bin/bash
set -e

# Função para aguardar que o serviço esteja pronto
wait_for_service() {
    echo "Aguardando Elements daemon inicializar..."
    sleep 10
}

# Se o comando for elementsd, executar com as configurações adequadas
if [ "$1" = "elementsd" ]; then
    echo "Iniciando Elements daemon..."
    
    # Garantir que o diretório de dados existe e tem as permissões corretas
    mkdir -p "$ELEMENTS_DATA"    # Iniciar o elementsd
    exec /opt/elements/elementsd \
        -conf="$ELEMENTS_DATA/elements.conf" \
        -datadir="$ELEMENTS_DATA" \
        -printtoconsole=1
else
    # Executar qualquer outro comando passado
    exec "$@"
fi
