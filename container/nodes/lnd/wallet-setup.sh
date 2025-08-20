#!/bin/bash

# Script para criar ou recuperar carteira LND
# LND Wallet Setup Script - Create or Recover

set -e

echo "=================================="
echo "    LND Wallet Setup Script"
echo "=================================="
echo ""

# Verificar se o LND está rodando
echo "Verificando se o LND está rodando..."
if ! curl -s --insecure https://localhost:8080/v1/getinfo > /dev/null 2>&1; then
    echo "ERRO: LND não está rodando ou não é acessível!"
    echo "Certifique-se de que o container LND está ativo."
    exit 1
fi

# Verificar se já existe uma carteira
WALLET_STATUS=$(curl -s --insecure https://localhost:8080/v1/getinfo 2>/dev/null || echo "")
if echo "$WALLET_STATUS" | grep -q '"synced_to_chain"'; then
    echo "✓ Carteira já existe e está desbloqueada!"
    echo "Informações da carteira:"
    echo "$WALLET_STATUS" | jq '.'
    exit 0
fi

echo ""
echo "Escolha uma opção:"
echo "1) Criar nova carteira"
echo "2) Recuperar carteira existente (com seed)"
echo ""
read -p "Digite sua escolha (1 ou 2): " CHOICE

case $CHOICE in
    1)
        echo ""
        echo "=== Criando Nova Carteira ==="
        echo ""
        
        # Gerar seed
        echo "Gerando seed para nova carteira..."
        SEED_RESPONSE=$(curl -s --insecure https://localhost:8080/v1/genseed)
        
        if [ $? -ne 0 ]; then
            echo "ERRO: Falha ao gerar seed!"
            exit 1
        fi
        
        echo "✓ Seed gerado com sucesso!"
        echo ""
        echo "IMPORTANTE: Anote estas 24 palavras em local seguro!"
        echo "=============================================="
        echo "$SEED_RESPONSE" | jq -r '.cipher_seed_mnemonic[]' | nl
        echo "=============================================="
        echo ""
        echo "⚠️  ATENÇÃO: Estas palavras são a ÚNICA forma de recuperar sua carteira!"
        echo "⚠️  Guarde-as em local seguro e NUNCA as compartilhe!"
        echo ""
        read -p "Pressione Enter após anotar o seed..."
        
        # Pedir senha da carteira
        echo ""
        read -s -p "Digite a senha para a carteira (mínimo 8 caracteres): " WALLET_PASSWORD
        echo ""
        read -s -p "Confirme a senha: " WALLET_PASSWORD_CONFIRM
        echo ""
        
        if [ "$WALLET_PASSWORD" != "$WALLET_PASSWORD_CONFIRM" ]; then
            echo "ERRO: Senhas não coincidem!"
            exit 1
        fi
        
        if [ ${#WALLET_PASSWORD} -lt 8 ]; then
            echo "ERRO: Senha deve ter pelo menos 8 caracteres!"
            exit 1
        fi
        
        # Codificar senha em base64
        WALLET_PASSWORD_B64=$(echo -n "$WALLET_PASSWORD" | base64 -w 0)
        
        # Extrair seed do response
        SEED_MNEMONIC=$(echo "$SEED_RESPONSE" | jq -r '.cipher_seed_mnemonic | join(" ")')
        
        echo ""
        echo "Criando carteira..."
        
        # Criar carteira
        CREATE_RESPONSE=$(curl -s --insecure -X POST https://localhost:8080/v1/initwallet \
            -H "Content-Type: application/json" \
            -d "{
                \"wallet_password\": \"$WALLET_PASSWORD_B64\",
                \"cipher_seed_mnemonic\": [$(echo "$SEED_RESPONSE" | jq '.cipher_seed_mnemonic | join(",")')]
            }")
        
        if echo "$CREATE_RESPONSE" | grep -q "error\|code"; then
            echo "ERRO ao criar carteira:"
            echo "$CREATE_RESPONSE" | jq '.'
            exit 1
        fi
        
        echo "✓ Carteira criada com sucesso!"
        ;;
        
    2)
        echo ""
        echo "=== Recuperando Carteira Existente ==="
        echo ""
        
        # Pedir seed
        echo "Digite suas 24 palavras do seed (separadas por espaço):"
        read -r SEED_INPUT
        
        # Validar seed (deve ter 24 palavras)
        WORD_COUNT=$(echo "$SEED_INPUT" | wc -w)
        if [ "$WORD_COUNT" -ne 24 ]; then
            echo "ERRO: O seed deve ter exatamente 24 palavras! (Encontradas: $WORD_COUNT)"
            exit 1
        fi
        
        # Pedir senha da carteira
        echo ""
        read -s -p "Digite a senha da carteira: " WALLET_PASSWORD
        echo ""
        
        if [ ${#WALLET_PASSWORD} -lt 8 ]; then
            echo "ERRO: Senha deve ter pelo menos 8 caracteres!"
            exit 1
        fi
        
        # Codificar senha em base64
        WALLET_PASSWORD_B64=$(echo -n "$WALLET_PASSWORD" | base64 -w 0)
        
        # Converter seed para array JSON
        SEED_ARRAY="["
        for word in $SEED_INPUT; do
            SEED_ARRAY="$SEED_ARRAY\"$word\","
        done
        SEED_ARRAY="${SEED_ARRAY%,}]"  # Remove última vírgula
        
        echo ""
        echo "Recuperando carteira..."
        
        # Recuperar carteira
        RECOVER_RESPONSE=$(curl -s --insecure -X POST https://localhost:8080/v1/initwallet \
            -H "Content-Type: application/json" \
            -d "{
                \"wallet_password\": \"$WALLET_PASSWORD_B64\",
                \"cipher_seed_mnemonic\": $SEED_ARRAY,
                \"recovery_window\": 2500
            }")
        
        if echo "$RECOVER_RESPONSE" | grep -q "error\|code"; then
            echo "ERRO ao recuperar carteira:"
            echo "$RECOVER_RESPONSE" | jq '.'
            exit 1
        fi
        
        echo "✓ Carteira recuperada com sucesso!"
        ;;
        
    *)
        echo "Opção inválida!"
        exit 1
        ;;
esac

echo ""
echo "Aguardando carteira inicializar..."
sleep 5

# Verificar se a carteira está funcionando
echo "Verificando status da carteira..."
FINAL_STATUS=$(curl -s --insecure https://localhost:8080/v1/getinfo)

if echo "$FINAL_STATUS" | grep -q '"synced_to_chain"'; then
    echo ""
    echo "🎉 Carteira configurada com sucesso!"
    echo ""
    echo "Informações da carteira:"
    echo "$FINAL_STATUS" | jq '{
        identity_pubkey,
        alias,
        num_peers,
        block_height,
        synced_to_chain,
        synced_to_graph
    }'
    
    # Salvar senha no arquivo (se não existir)
    if [ ! -f /data/lnd/password.txt ]; then
        echo "$WALLET_PASSWORD" > /data/lnd/password.txt
        chmod 600 /data/lnd/password.txt
        echo ""
        echo "✓ Senha salva em /data/lnd/password.txt para desbloqueio automático"
    fi
else
    echo "⚠️  Carteira criada mas pode estar inicializando..."
    echo "Resposta do LND:"
    echo "$FINAL_STATUS"
fi

echo ""
echo "Setup da carteira concluído!"
