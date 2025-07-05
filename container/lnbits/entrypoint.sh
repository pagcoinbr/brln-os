#!/bin/bash

# Script de entrada para o LNbits
# Configura host e port para aceitar conexões externas

set -e

echo "🚀 Iniciando LNbits..."
echo "📍 Host: 0.0.0.0"
echo "🔌 Port: 5000"
echo "📂 Diretório da aplicação: $(pwd)"
echo "📁 Diretório de dados: ${LNBITS_DATA_FOLDER:-/data/lnbits}"
echo "📄 Verificando arquivos importantes:"
ls -la pyproject.toml || echo "❌ pyproject.toml não encontrado"
ls -la poetry.lock || echo "❌ poetry.lock não encontrado"
echo "🔍 Conteúdo do diretório atual:"
ls -la .

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

