#!/bin/bash
set -e

# Script de inicialização para Bitcoin Core com geração automática de rpcauth

echo "Iniciando Bitcoin Core..."

# Definir diretório de dados
DATA_DIR="/home/bitcoin/.bitcoin"

# Criar diretório se não existir
mkdir -p "$DATA_DIR"

# Função para gerar rpcauth
generate_rpcauth() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "ERRO: BITCOIN_RPC_USER e BITCOIN_RPC_PASSWORD devem estar definidos"
        exit 1
    fi
    
    echo "Gerando rpcauth para usuário: $username"
    python3 /usr/local/bin/rpcauth.py "$username" "$password"
}

# Verificar se as variáveis de ambiente estão definidas
if [ -n "$BITCOIN_RPC_USER" ] && [ -n "$BITCOIN_RPC_PASSWORD" ]; then
    echo "Configurando credenciais RPC personalizadas..."
    
    # Gerar rpcauth
    RPCAUTH_LINE=$(generate_rpcauth "$BITCOIN_RPC_USER" "$BITCOIN_RPC_PASSWORD" | grep "rpcauth=" | head -1)
    
    if [ -n "$RPCAUTH_LINE" ]; then
        echo "RPC auth gerado: $RPCAUTH_LINE"
        
        # Substituir placeholder no arquivo de configuração
        if [ -f "$DATA_DIR/bitcoin.conf" ]; then
            sed -i "s|rpcauth=<PLACEHOLDER_RPCAUTH>|$RPCAUTH_LINE|g" "$DATA_DIR/bitcoin.conf"
            echo "Configuração RPC atualizada em bitcoin.conf"
        else
            echo "AVISO: Arquivo bitcoin.conf não encontrado em $DATA_DIR"
        fi
    else
        echo "ERRO: Falha ao gerar rpcauth"
        exit 1
    fi
else
    echo "Usando autenticação via cookie (BITCOIN_RPC_USER/BITCOIN_RPC_PASSWORD não definidos)"
    # Remover linha rpcauth se estiver presente
    if [ -f "$DATA_DIR/bitcoin.conf" ]; then
        sed -i '/^rpcauth=/d' "$DATA_DIR/bitcoin.conf"
        echo "Removida configuração rpcauth, usando cookie"
    fi
fi

# Iniciar i2pd em background se configurado
if [ -f "/etc/i2pd/i2pd.conf" ]; then
    echo "Iniciando i2pd..."
    i2pd --conf=/etc/i2pd/i2pd.conf --daemon
    sleep 2
fi

# Aguardar Tor estar disponível
echo "Aguardando Tor estar disponível..."
while ! nc -z tor 9050; do
    echo "Tor não está pronto, aguardando..."
    sleep 2
done
echo "Tor está disponível!"

# Definir argumentos extras do Bitcoin
BITCOIN_ARGS="$BITCOIN_EXTRA_ARGS"

# Iniciar bitcoind
echo "Iniciando bitcoind..."
echo "Argumentos: $BITCOIN_ARGS"

exec bitcoind \
    -datadir="$DATA_DIR" \
    -conf="$DATA_DIR/bitcoin.conf" \
    $BITCOIN_ARGS
