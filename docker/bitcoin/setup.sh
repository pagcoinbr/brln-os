#!/bin/bash
set -e

ARCH=${ARCH:-x86_64}
BTC_VERSION=${BTC_VERSION:-28.1}
LOCAL_PATH="/local_binaries"
TARGET_DIR="/usr/local/bin"

echo "=== Diagnóstico ==="
echo "Verificando LOCAL_PATH: $LOCAL_PATH"
ls -la $LOCAL_PATH || echo "Diretório não encontrado ou vazio"

# Verifica se temos os arquivos .tar.gz disponíveis
TAR_FILE="$LOCAL_PATH/bitcoin-$BTC_VERSION-$ARCH-linux-gnu.tar.gz"
if [ -f "$TAR_FILE" ]; then
    echo "Encontrado arquivo tar.gz local: $TAR_FILE"
    echo "Extraindo..."
    mkdir -p /tmp/bitcoin-extract
    tar -xzf "$TAR_FILE" -C /tmp/bitcoin-extract
    
    echo "Instalando binários..."
    cp /tmp/bitcoin-extract/bitcoin-$BTC_VERSION/bin/bitcoind "$TARGET_DIR/"
    cp /tmp/bitcoin-extract/bitcoin-$BTC_VERSION/bin/bitcoin-cli "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/bitcoind" "$TARGET_DIR/bitcoin-cli"
    rm -rf /tmp/bitcoin-extract
elif [ -d "$LOCAL_PATH" ] && [ -f "$LOCAL_PATH/bitcoin-$BTC_VERSION/bin/bitcoind" ]; then
    echo "Usando binários locais do Bitcoin Core..."
    cp "$LOCAL_PATH/bitcoin-$BTC_VERSION/bin/bitcoind" "$TARGET_DIR/"
    cp "$LOCAL_PATH/bitcoin-$BTC_VERSION/bin/bitcoin-cli" "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/bitcoind" "$TARGET_DIR/bitcoin-cli"
else
    echo "Binários locais não encontrados. Baixando do site oficial..."
    DOWNLOAD_URL="https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/bitcoin-$BTC_VERSION-$ARCH-linux-gnu.tar.gz"
    
    echo "Baixando Bitcoin Core $BTC_VERSION para $ARCH de $DOWNLOAD_URL..."
    curl -SL "$DOWNLOAD_URL" | tar -xzC /tmp
    
    echo "Instalando binários..."
    cp /tmp/bitcoin-$BTC_VERSION/bin/bitcoind "$TARGET_DIR/"
    cp /tmp/bitcoin-$BTC_VERSION/bin/bitcoin-cli "$TARGET_DIR/"
    chmod +x "$TARGET_DIR/bitcoind" "$TARGET_DIR/bitcoin-cli"
    rm -rf /tmp/bitcoin-$BTC_VERSION
fi

# Verificar se os binários foram instalados corretamente
if [ -x "$TARGET_DIR/bitcoind" ] && [ -x "$TARGET_DIR/bitcoin-cli" ]; then
    echo "Binários instalados com sucesso em $TARGET_DIR"
    echo "Verificando se estão no PATH..."
    which bitcoind || echo "AVISO: bitcoind não está no PATH!"
    which bitcoin-cli || echo "AVISO: bitcoin-cli não está no PATH!"
    
    # Criar links simbólicos para garantir que estejam no PATH padrão
    echo "Criando links simbólicos em /usr/bin..."
    ln -sf "$TARGET_DIR/bitcoind" /usr/bin/bitcoind
    ln -sf "$TARGET_DIR/bitcoin-cli" /usr/bin/bitcoin-cli
    
    # Mostrar versão para confirmar funcionalidade
    echo "Versão do Bitcoin Core instalada:"
    "$TARGET_DIR/bitcoind" --version | head -n 1 || echo "Erro ao executar bitcoind --version"
else
    echo "ERRO: Falha ao instalar os binários do Bitcoin Core!"
    echo "Conteúdo de $TARGET_DIR:"
    ls -la "$TARGET_DIR"
    exit 1
fi

echo "Instalação do Bitcoin Core concluída."
