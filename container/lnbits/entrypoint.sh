#!/bin/bash

# Script de entrada para o LNbits
# Configura host e port para aceitar conexões externas

set -e

echo "🚀 Iniciando LNbits..."
echo "📍 Host: 0.0.0.0"
echo "🔌 Port: 5000"
echo "📂 Diretório da aplicação: $(pwd)"

# Define o diretório de dados
DATA_DIR="${LNBITS_DATA_FOLDER:-/data/lnbits}"
echo "📁 Diretório de dados: ${DATA_DIR}"

# Verifica e cria o diretório de dados se não existir
if [ ! -d "${DATA_DIR}" ]; then
    echo "📂 Criando diretório de dados: ${DATA_DIR}"
    mkdir -p "${DATA_DIR}"
fi

# Verifica as permissões do diretório de dados
echo "🔍 Verificando permissões do diretório de dados..."
if [ ! -w "${DATA_DIR}" ]; then
    echo "⚠️  Diretório de dados não tem permissão de escrita"
    echo "👤 Usuário atual: $(whoami) (UID: $(id -u))"
    echo "📂 Permissões do diretório ${DATA_DIR}:"
    ls -ld "${DATA_DIR}" || echo "❌ Não foi possível verificar permissões"
    
    # Tenta ajustar permissões se possível
    echo "🔧 Tentando ajustar permissões..."
    chmod 755 "${DATA_DIR}" 2>/dev/null || echo "⚠️  Não foi possível alterar permissões do diretório"
    
    # Verifica novamente
    if [ ! -w "${DATA_DIR}" ]; then
        echo "❌ Ainda não é possível escrever no diretório de dados"
        echo "💡 Dica: Verifique se o volume está montado com as permissões corretas"
        echo "💡 Execute no host: sudo chown -R 1004:1004 <caminho_host_do_volume>"
        echo "💡 Ou: docker exec -it --user root <container_name> chown -R lnbits:lnbits /data/lnbits"
    fi
else
    echo "✅ Diretório de dados tem permissão de escrita"
fi
echo "📄 Verificando arquivos importantes:"
ls -la pyproject.toml || echo "❌ pyproject.toml não encontrado"
ls -la poetry.lock || echo "❌ poetry.lock não encontrado"
echo "🔍 Conteúdo do diretório atual:"
ls -la .

# Verificar e preparar arquivo de autenticação
AUTH_KEY_FILE="${DATA_DIR}/.lnbits_auth_key"
echo "🔐 Verificando arquivo de autenticação: ${AUTH_KEY_FILE}"
if [ ! -f "${AUTH_KEY_FILE}" ]; then
    echo "📝 Arquivo de autenticação não existe, será criado pelo LNbits"
else
    echo "✅ Arquivo de autenticação já existe"
    ls -la "${AUTH_KEY_FILE}"
fi

# Verificar se podemos criar arquivos no diretório de dados
echo "🧪 Testando criação de arquivo no diretório de dados..."
TEST_FILE="${DATA_DIR}/.test_write"
if touch "${TEST_FILE}" 2>/dev/null; then
    echo "✅ Teste de escrita bem-sucedido"
    rm -f "${TEST_FILE}"
else
    echo "❌ Falha no teste de escrita"
    echo "💡 O LNbits pode falhar ao tentar criar arquivos de configuração"
fi

# Verificar se poetry está disponível
if command -v poetry &> /dev/null; then
    echo "✅ Poetry encontrado"
    exec poetry run lnbits --host 0.0.0.0 --port 5000
elif command -v uvicorn &> /dev/null; then
    echo "✅ Uvicorn encontrado, iniciando diretamente"
    export PYTHONPATH=/app/lnbits:$PYTHONPATH
    exec uvicorn lnbits.app:app --host 0.0.0.0 --port 5000
else
    echo "❌ Nem Poetry nem Uvicorn encontrados"
    echo "Tentando executar com python direto..."
    export PYTHONPATH=/app/lnbits:$PYTHONPATH
    cd /app/lnbits
    exec python -m lnbits
fi

