#!/bin/bash

# Script para verificar o status dos serviços da interface BRLN

echo "🔍 Verificando status dos serviços BRLN..."
echo "=================================================="

# Verificar Apache
echo -n "🌐 Apache: "
if systemctl is-active --quiet apache2; then
    echo "✅ Ativo"
else
    echo "❌ Inativo"
fi

# Verificar Flask
echo -n "🐍 Flask API: "
if systemctl is-active --quiet brln-flask; then
    echo "✅ Ativo"
else
    echo "❌ Inativo"
fi

# Verificar Docker
echo -n "🐳 Docker: "
if systemctl is-active --quiet docker; then
    echo "✅ Ativo"
else
    echo "❌ Inativo"
fi

# Verificar conectividade das APIs
echo ""
echo "🔗 Testando conectividade..."
echo "=================================================="

LOCAL_IP=$(hostname -I | awk '{print $1}')

# Teste Interface Web
echo -n "🌐 Interface Web (porta 80): "
if curl -s --connect-timeout 3 "http://$LOCAL_IP" > /dev/null; then
    echo "✅ Acessível"
else
    echo "❌ Inacessível"
fi

# Teste Flask API
echo -n "🐍 Flask API (porta 5001): "
if curl -s --connect-timeout 3 "http://$LOCAL_IP:5001/containers/status" > /dev/null; then
    echo "✅ Acessível"
else
    echo "❌ Inacessível"
fi

# Verificar containers Docker
echo ""
echo "🐳 Status dos Containers..."
echo "=================================================="

containers=("bitcoin" "lnd" "elements" "lnbits" "thunderhub" "lndg" "peerswap" "tor")

for container in "${containers[@]}"; do
    echo -n "📦 $container: "
    if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
        echo "✅ Rodando"
    elif docker ps -a --format "table {{.Names}}" | grep -q "^$container$"; then
        echo "🟡 Parado"
    else
        echo "❌ Não encontrado"
    fi
done

echo ""
echo "📊 Resumo dos Logs..."
echo "=================================================="

# Últimas linhas do log do Flask
echo "🐍 Últimas 5 linhas do Flask:"
sudo journalctl -u brln-flask.service -n 5 --no-pager | grep -v "^--" || echo "   Nenhum log encontrado"

echo ""
echo "🌐 Últimas 3 linhas do Apache:"
sudo tail -n 3 /var/log/apache2/error.log 2>/dev/null || echo "   Arquivo de log não encontrado"

echo ""
echo "✅ Verificação concluída!"
echo ""
echo "💡 Para mais detalhes:"
echo "   • Logs Flask: sudo journalctl -u brln-flask.service -f"
echo "   • Logs Apache: sudo tail -f /var/log/apache2/error.log"
echo "   • Status Docker: docker ps -a"
