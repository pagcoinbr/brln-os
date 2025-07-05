#!/bin/bash

# Script de teste para o LNDG Docker
# Este script verifica se o LNDG Docker está funcionando corretamente

echo "=== Teste do LNDG Docker ==="

# Verificar se Docker está disponível
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker não está instalado"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ Docker Compose não está instalado"
    exit 1
fi

echo "✅ Docker e Docker Compose estão disponíveis"

# Verificar se o diretório de dados existe
if [ ! -d "/data/lndg" ]; then
    echo "⚠️  Diretório /data/lndg não existe, criando..."
    sudo mkdir -p /data/lndg
    sudo chown -R 1005:1005 /data/lndg
fi

echo "✅ Diretório de dados configurado"

# Verificar se a imagem pode ser construída
cd ~/brlnfullauto/container

echo "🔨 Construindo imagem Docker..."
if docker build -f lndg/Dockerfile.lndg -t lndg:latest . >/dev/null 2>&1; then
    echo "✅ Imagem Docker construída com sucesso"
else
    echo "❌ Falha ao construir imagem Docker"
    exit 1
fi

# Verificar configuração do docker-compose
echo "🔍 Verificando configuração do docker-compose..."
if docker-compose config >/dev/null 2>&1; then
    echo "✅ Configuração do docker-compose é válida"
else
    echo "❌ Configuração do docker-compose inválida"
    exit 1
fi

# Verificar se os volumes estão configurados corretamente
echo "📁 Verificando volumes..."
if docker-compose config | grep -q "/data/lndg:/app/data:rw"; then
    echo "✅ Volume de dados configurado corretamente"
else
    echo "❌ Volume de dados não configurado"
fi

if docker-compose config | grep -q "/data/lnd:/root/.lnd:ro"; then
    echo "✅ Volume do LND configurado corretamente"
else
    echo "❌ Volume do LND não configurado"
fi

# Verificar portas
echo "🌐 Verificando configuração de portas..."
if docker-compose config | grep -q "8889:8889"; then
    echo "✅ Porta 8889 configurada corretamente"
else
    echo "❌ Porta 8889 não configurada"
fi

echo ""
echo "=== Resumo do Teste ==="
echo "✅ Todos os testes passaram!"
echo ""
echo "Para iniciar o LNDG Docker:"
echo "  cd ~/brlnfullauto/container"
echo "  docker-compose up -d lndg"
echo ""
echo "Para verificar logs:"
echo "  docker logs lndg"
echo ""
echo "Para acessar:"
echo "  http://localhost:8889"
