#!/bin/sh

# Configure BOS (Balance of Satoshis) para conectar com LND
# Script de configuração inicial

set -e

echo "=== Configurando BOS para conectar com LND ==="

# Verificar se o BOS está instalado
if ! command -v bos > /dev/null 2>&1; then
    echo "ERRO: BOS não está instalado!"
    exit 1
fi

# Criar diretório de configuração do BOS se não existir
BOS_CONFIG_DIR="$HOME/.bos"
mkdir -p "$BOS_CONFIG_DIR"

# Verificar se os arquivos necessários do LND existem
LND_DATA_DIR="/home/bos/.lnd"
TLS_CERT="$LND_DATA_DIR/tls.cert"
ADMIN_MACAROON="$LND_DATA_DIR/data/chain/bitcoin/mainnet/admin.macaroon"

echo "Verificando arquivos do LND..."

# Aguardar os arquivos necessários
while [ ! -f "$TLS_CERT" ] || [ ! -f "$ADMIN_MACAROON" ]; do
    echo "Aguardando arquivos do LND serem criados..."
    echo "  TLS cert: $(if [ -f "$TLS_CERT" ]; then echo "✓"; else echo "✗"; fi)"
    echo "  Admin macaroon: $(if [ -f "$ADMIN_MACAROON" ]; then echo "✓"; else echo "✗"; fi)"
    sleep 5
done

echo "Arquivos do LND encontrados!"

# Criar configuração do BOS
echo "Criando configuração do BOS..."

# Criar o arquivo de configuração do BOS
cat > "$BOS_CONFIG_DIR/config.json" << EOF
{
  "nodes": [
    {
      "node": "default",
      "grpc": "lnd:10009",
      "cert": "$TLS_CERT",
      "macaroon": "$ADMIN_MACAROON"
    }
  ]
}
EOF

echo "Configuração criada em $BOS_CONFIG_DIR/config.json"

# Testar a conexão
echo "Testando conexão com LND..."

# Aguardar um pouco mais para o LND estar completamente pronto
sleep 10

# Tentar conectar algumas vezes
max_test_attempts=10
test_attempt=0

while [ $test_attempt -lt $max_test_attempts ]; do
    echo "Tentativa de teste $((test_attempt + 1))/$max_test_attempts..."
    
    if bos balance 2>/dev/null; then
        echo "✓ Conexão com LND estabelecida com sucesso!"
        echo "✓ BOS configurado corretamente!"
        break
    else
        echo "Falha na conexão, tentando novamente em 10 segundos..."
        sleep 10
        test_attempt=$((test_attempt + 1))
    fi
done

if [ $test_attempt -eq $max_test_attempts ]; then
    echo "⚠ Não foi possível estabelecer conexão imediatamente."
    echo "⚠ Isso pode ser normal se o LND ainda está sincronizando."
    echo "⚠ Tente executar 'bos balance' manualmente mais tarde."
fi

echo ""
echo "=== Configuração do BOS Concluída ==="
echo ""
echo "Para usar o BOS:"
echo "  docker exec -it bos bos balance     # Ver saldo"
echo "  docker exec -it bos bos utxos       # Ver UTXOs"
echo "  docker exec -it bos bos peers       # Ver peers"
echo "  docker exec -it bos bos forwards    # Ver forwards"
echo "  docker exec -it bos sh              # Entrar no container"
echo ""
