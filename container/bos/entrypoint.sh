#!/bin/bash

# Script de entrypoint para o Balance of Satoshis
set -e

# Variáveis de ambiente
export BOS_DEFAULT_LND_PATH=${LND_DIR:-/data/lnd}
export NODE_ALIAS=${NODE_ALIAS:-"BRLN-Node"}

# Função para aguardar o LND estar disponível
wait_for_lnd() {
    echo "🔍 Aguardando LND estar disponível..."
    
    # Aguardar até que o arquivo tls.cert esteja disponível
    while [ ! -f "${BOS_DEFAULT_LND_PATH}/tls.cert" ]; do
        echo "⏳ Aguardando certificado TLS do LND..."
        sleep 5
    done
    
    # Aguardar até que o macaroon esteja disponível
    while [ ! -f "${BOS_DEFAULT_LND_PATH}/data/chain/bitcoin/mainnet/admin.macaroon" ]; do
        echo "⏳ Aguardando macaroon admin do LND..."
        sleep 5
    done
    
    echo "✅ LND está disponível!"
}

# Função para configurar credenciais do BOS
setup_bos_credentials() {
    echo "🔧 Configurando credenciais do BOS..."
    
    # Criar diretório de configuração do BOS
    mkdir -p ~/.bos/$NODE_ALIAS
    
    # Gerar certificados em base64
    base64 -w0 ${BOS_DEFAULT_LND_PATH}/tls.cert > ${BOS_DEFAULT_LND_PATH}/tls.cert.base64
    base64 -w0 ${BOS_DEFAULT_LND_PATH}/data/chain/bitcoin/mainnet/admin.macaroon > ${BOS_DEFAULT_LND_PATH}/data/chain/bitcoin/mainnet/admin.macaroon.base64
    
    # Ler certificados
    cert_base64=$(cat ${BOS_DEFAULT_LND_PATH}/tls.cert.base64)
    macaroon_base64=$(cat ${BOS_DEFAULT_LND_PATH}/data/chain/bitcoin/mainnet/admin.macaroon.base64)
    
    # Criar arquivo de credenciais
    cat > ~/.bos/$NODE_ALIAS/credentials.json << EOF
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "lnd:10009"
}
EOF
    
    echo "✅ Credenciais do BOS configuradas!"
}

# Função para verificar conectividade com LND
test_bos_connection() {
    echo "🧪 Testando conexão com LND..."
    
    # Tentar obter informações do node
    if bos balance --node="$NODE_ALIAS" >/dev/null 2>&1; then
        echo "✅ Conexão com LND estabelecida com sucesso!"
        return 0
    else
        echo "❌ Falha na conexão com LND"
        return 1
    fi
}

# Função para executar BOS Telegram
run_bos_telegram() {
    if [ ! -z "$BOS_TELEGRAM_TOKEN" ]; then
        echo "🤖 Iniciando BOS Telegram com token fornecido..."
        exec bos telegram --use-small-units --connect "$BOS_TELEGRAM_TOKEN" --node="$NODE_ALIAS"
    else
        echo "⚠️  Token do Telegram não fornecido (BOS_TELEGRAM_TOKEN)"
        echo "💡 Para configurar o Telegram, execute o script de configuração:"
        echo "   docker exec -it bos /home/bos/bos_telegram.sh"
    fi
}

# Função para executar modo interativo
run_interactive() {
    echo "🎯 Iniciando BOS em modo interativo..."
    echo "📊 Use 'bos' para executar comandos do Balance of Satoshis"
    echo "🔗 Node configurado: $NODE_ALIAS"
    echo "📡 Socket LND: lnd:10009"
    echo ""
    
    # Manter container ativo
    exec /bin/bash
}

# Função principal
main() {
    echo "🚀 Iniciando Balance of Satoshis (BOS)..."
    echo "🔧 LND Path: $BOS_DEFAULT_LND_PATH"
    echo "🏷️  Node Alias: $NODE_ALIAS"
    
    # Aguardar LND
    wait_for_lnd
    
    # Configurar credenciais
    setup_bos_credentials
    
    # Testar conexão
    if ! test_bos_connection; then
        echo "❌ Não foi possível conectar ao LND. Verifique a configuração."
        exit 1
    fi
    
    # Verificar modo de execução
    case "${BOS_MODE:-interactive}" in
        "telegram")
            run_bos_telegram
            ;;
        "daemon")
            echo "🔄 Modo daemon - mantendo container ativo..."
            tail -f /dev/null
            ;;
        *)
            run_interactive
            ;;
    esac
}

# Executar função principal
main "$@"
