#!/bin/bash
set -e

# Script de inicialização para Elements/Liquid

echo "Iniciando Elements/Liquid..."

# Definir diretório de dados
DATA_DIR="/home/elements/.elements"

# Criar diretório se não existir
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/liquidv1/wallets"

# Função para gerar rpcauth
generate_rpcauth() {
    local username="$1"
    local password="$2"
    
    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "ERRO: ELEMENTS_RPC_USER e ELEMENTS_RPC_PASSWORD devem estar definidos"
        exit 1
    fi
    
    echo "Gerando rpcauth para usuário: $username"
    python3 /usr/local/bin/rpcauth.py "$username" "$password"
}

# Verificar se as variáveis de ambiente estão definidas
if [ -n "$ELEMENTS_RPC_USER" ] && [ -n "$ELEMENTS_RPC_PASSWORD" ]; then
    echo "Configurando credenciais RPC personalizadas..."
    
    # Gerar rpcauth
    RPCAUTH_LINE=$(generate_rpcauth "$ELEMENTS_RPC_USER" "$ELEMENTS_RPC_PASSWORD" | grep "rpcauth=" | head -1)
    
    if [ -n "$RPCAUTH_LINE" ]; then
        echo "RPC auth gerado: ${RPCAUTH_LINE:0:20}..."
        
        # Atualizar arquivo de configuração
        if [ -f "$DATA_DIR/elements.conf" ]; then
            # Remover configurações antigas de rpc
            sed -i '/^rpcuser=/d' "$DATA_DIR/elements.conf"
            sed -i '/^rpcpassword=/d' "$DATA_DIR/elements.conf"

            
            # Adicionar nova configuração rpcauth
            echo "# Configuração automática de RPC" >> "$DATA_DIR/elements.conf"
            echo "Configuração RPC atualizada com rpcauth"
        else
            echo "AVISO: Arquivo elements.conf não encontrado em $DATA_DIR"
        fi
    else
        echo "ERRO: Falha ao gerar rpcauth"
        exit 1
    fi
else
    echo "Usando autenticação via cookie (ELEMENTS_RPC_USER/ELEMENTS_RPC_PASSWORD não definidos)"
    # Remover linhas de autenticação se estiverem presentes
    if [ -f "$DATA_DIR/elements.conf" ]; then
        sed -i '/^rpcuser=/d' "$DATA_DIR/elements.conf"
        sed -i '/^rpcpassword=/d' "$DATA_DIR/elements.conf"
        echo "Removida configuração rpcauth/rpcuser, usando cookie"
    fi
fi

# Aguardar Bitcoin Core estar disponível
BITCOIN_HOST=${BITCOIN_RPC_HOST:-"bitcoind"}
BITCOIN_PORT=${BITCOIN_RPC_PORT:-"8332"}

# Configurar mainchain RPC se variáveis estão definidas
if [ -n "$BITCOIN_RPC_HOST" ] && [ -n "$BITCOIN_RPC_PORT" ]; then
    echo "Configurando conexão com Bitcoin Core remoto: $BITCOIN_RPC_HOST:$BITCOIN_RPC_PORT"
    
    # Atualizar configuração para usar Bitcoin Core remoto
    if [ -f "$DATA_DIR/elements.conf" ]; then
        # Verificar se já existe configuração automática
        if ! grep -q "# Configuração automática para Bitcoin Core remoto" "$DATA_DIR/elements.conf"; then
            echo "Aplicando configuração do Bitcoin Core remoto..."
            
            # Comentar configuração local
            sed -i 's/^mainchainrpchost=bitcoind/#mainchainrpchost=bitcoind/' "$DATA_DIR/elements.conf"
            sed -i 's/^mainchainrpcport=8332/#mainchainrpcport=8332/' "$DATA_DIR/elements.conf"
            sed -i 's/^mainchainrpcuser=brln/#mainchainrpcuser=brln/' "$DATA_DIR/elements.conf"
            sed -i 's/^mainchainrpcpassword=changeme/#mainchainrpcpassword=changeme/' "$DATA_DIR/elements.conf"
            
            # Remover placeholders de variáveis se existirem
            sed -i '/^mainchainrpchost=BITCOIN_RPC_HOST/d' "$DATA_DIR/elements.conf"
            sed -i '/^mainchainrpcport=BITCOIN_RPC_PORT/d' "$DATA_DIR/elements.conf"
            sed -i '/^mainchainrpcuser=BITCOIN_RPC_USER/d' "$DATA_DIR/elements.conf"
            sed -i '/^mainchainrpcpassword=BITCOIN_RPC_PASSWORD/d' "$DATA_DIR/elements.conf"
            
            # Adicionar configuração remota
            echo "" >> "$DATA_DIR/elements.conf"
            echo "# Configuração automática para Bitcoin Core remoto" >> "$DATA_DIR/elements.conf"
            echo "mainchainrpchost=$BITCOIN_RPC_HOST" >> "$DATA_DIR/elements.conf"
            echo "mainchainrpcport=$BITCOIN_RPC_PORT" >> "$DATA_DIR/elements.conf"
            
            if [ -n "$BITCOIN_RPC_USER" ] && [ -n "$BITCOIN_RPC_PASSWORD" ]; then
                echo "mainchainrpcuser=$BITCOIN_RPC_USER" >> "$DATA_DIR/elements.conf"
                echo "mainchainrpcpassword=$BITCOIN_RPC_PASSWORD" >> "$DATA_DIR/elements.conf"
                echo "Configurado RPC com credenciais personalizadas"
            else
                echo "mainchainrpcuser=brln" >> "$DATA_DIR/elements.conf"
                echo "mainchainrpcpassword=changeme_secure_bitcoin_rpc_password_here" >> "$DATA_DIR/elements.conf"
                echo "Usando credenciais padrão do Bitcoin Core"
            fi
            
            echo "Configuração do Bitcoin Core remoto aplicada"
        else
            echo "Configuração do Bitcoin Core remoto já aplicada, pulando..."
        fi
    fi
fi

# Definir argumentos extras do Elements
ELEMENTS_ARGS="$ELEMENTS_EXTRA_ARGS"

# Iniciar elementsd
echo "Iniciando elementsd..."
echo "Argumentos: $ELEMENTS_ARGS"

exec elementsd \
    -datadir="$DATA_DIR" \
    -conf="$DATA_DIR/elements.conf" \
    $ELEMENTS_ARGS
