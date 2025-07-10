#!/bin/bash
set -e

# Função para aguardar que o serviço esteja pronto
wait_for_service() {
    echo "Aguardando Elements daemon inicializar..."
    sleep 10
}

# Função para criar/carregar a carteira do peerswap
setup_peerswap_wallet() {
    echo "Configurando carteira do peerswap..."
    
    # Aguardar que o Elements esteja respondendo
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if elements-cli -rpcuser=elementsuser -rpcpassword=elementspassword123 -rpcport=7041 getblockchaininfo >/dev/null 2>&1; then
            echo "Elements daemon está respondendo!"
            break
        fi
        echo "Aguardando Elements responder... tentativa $((attempt + 1))/$max_attempts"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "ERRO: Elements daemon não está respondendo após $max_attempts tentativas"
        return 1
    fi
    
    # Verificar se a carteira peerswap já existe
    local wallet_exists
    wallet_exists=$(elements-cli -rpcuser=elementsuser -rpcpassword=elementspassword123 -rpcport=7041 listwallets | grep -c "peerswap" || true)
    
    if [ "$wallet_exists" -gt 0 ]; then
        echo "Carteira peerswap já está carregada!"
        return 0
    fi
    
    # Tentar carregar a carteira se ela existir
    if elements-cli -rpcuser=elementsuser -rpcpassword=elementspassword123 -rpcport=7041 loadwallet "peerswap" 2>/dev/null; then
        echo "Carteira peerswap carregada com sucesso!"
        return 0
    fi
    
    # Se não conseguiu carregar, tentar criar
    echo "Tentando criar carteira peerswap..."
    if elements-cli -rpcuser=elementsuser -rpcpassword=elementspassword123 -rpcport=7041 createwallet "peerswap" false false "" false false 2>/dev/null; then
        echo "Carteira peerswap criada com sucesso!"
        return 0
    else
        echo "Falha na criação, tentando carregar novamente..."
        if elements-cli -rpcuser=elementsuser -rpcpassword=elementspassword123 -rpcport=7041 loadwallet "peerswap" 2>/dev/null; then
            echo "Carteira peerswap existente carregada com sucesso!"
            return 0
        else
            echo "ERRO: Não foi possível criar ou carregar a carteira peerswap"
            echo "Isso pode indicar uma carteira corrompida. Execute o script de limpeza."
            return 1
        fi
    fi
}

# Se o comando for elementsd, executar com as configurações adequadas
if [ "$1" = "elementsd" ]; then
    echo "Iniciando Elements daemon..."
    
    # Iniciar o elementsd em background
    /opt/elements/elementsd \
        -conf="$ELEMENTS_DATA/elements.conf" \
        -datadir="$ELEMENTS_DATA" \
        -printtoconsole=1 &
    
    # Armazenar o PID do proceso
    ELEMENTSD_PID=$!
    
    # Aguardar que o Elements esteja pronto e configurar a carteira peerswap
    if setup_peerswap_wallet; then
        echo "Configuração da carteira peerswap concluída com sucesso!"
    else
        echo "AVISO: Falha na configuração da carteira peerswap, mas continuando..."
    fi
    
    # Aguardar o processo principal terminar
    wait $ELEMENTSD_PID
else
    # Executar qualquer outro comando passado
    exec "$@"
fi
