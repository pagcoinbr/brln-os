#!/bin/bash
set -e

echo "=== Iniciando entrypoint do Bitcoin Core ==="

# Verifica se o diretório do Bitcoin existe, senão cria
if [ ! -d "/root/.bitcoin" ]; then
    echo "Criando diretório /root/.bitcoin..."
    mkdir -p /root/.bitcoin
fi

# Diagnóstico
echo "Verificando diretório /root/.bitcoin..."
ls -la /root/.bitcoin

# Verifica se bitcoin.conf é um diretório - se for, algo está errado
if [ -d "/root/.bitcoin/bitcoin.conf" ]; then
    echo "ERRO: /root/.bitcoin/bitcoin.conf é um diretório! Removendo..."
    rm -rf "/root/.bitcoin/bitcoin.conf"
fi

# Se o arquivo de configuração não existir, cria um básico
if [ ! -f "/root/.bitcoin/bitcoin.conf" ]; then
    echo "Criando arquivo de configuração padrão..."
    cat > /root/.bitcoin/bitcoin.conf << EOF
# Configuração básica do Bitcoin Core
server=1
txindex=1
listen=1
zmqpubrawblock=tcp://0.0.0.0:28332
zmqpubrawtx=tcp://0.0.0.0:28333
EOF
    echo "Arquivo de configuração criado com sucesso."
else
    echo "Arquivo de configuração já existe."
fi

# Ajusta permissões
echo "Ajustando permissões..."
chown -R 1000:1000 /root/.bitcoin

# Verifica se o bitcoind existe e onde está
echo "Verificando localização do bitcoind..."
BITCOIND_PATH=$(which bitcoind 2>/dev/null || echo "not found")
if [ "$BITCOIND_PATH" = "not found" ]; then
    echo "AVISO: bitcoind não encontrado no PATH. Tentando caminhos alternativos..."
    
    # Tenta localizar em caminhos comuns
    for path in "/usr/local/bin/bitcoind" "/usr/bin/bitcoind" "/app/bitcoind"; do
        if [ -x "$path" ]; then
            BITCOIND_PATH="$path"
            echo "Encontrado bitcoind em: $BITCOIND_PATH"
            break
        fi
    done
    
    if [ "$BITCOIND_PATH" = "not found" ]; then
        echo "ERRO: Não foi possível encontrar o executável bitcoind!"
        echo "Conteúdo de /usr/local/bin:"
        ls -la /usr/local/bin
        echo "Conteúdo de /usr/bin:"
        ls -la /usr/bin
        exit 1
    fi
else
    echo "Bitcoind encontrado em: $BITCOIND_PATH"
fi

# Executa o Bitcoin Core com os argumentos adicionais
if [ "$(id -u)" = '0' ]; then
    echo "Executando como bitcoind user..."
    exec gosu 1000:1000 $BITCOIND_PATH -conf=/root/.bitcoin/bitcoin.conf -datadir=/root/.bitcoin $BITCOIN_EXTRA_ARGS
else
    exec $BITCOIND_PATH -conf=/root/.bitcoin/bitcoin.conf -datadir=/root/.bitcoin $BITCOIN_EXTRA_ARGS
fi
