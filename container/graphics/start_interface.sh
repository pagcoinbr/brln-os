#!/bin/bash

# Script de inicialização rápida da interface BRLN
# Executa após a instalação do interface.sh

echo "🚀 Iniciando Interface BRLN..."
echo "====================================="

# Carregar variáveis de ambiente
if [ -f ~/brlnfullauto/shell/.env ]; then
    source ~/brlnfullauto/shell/.env
    echo "✅ Variáveis de ambiente carregadas"
else
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

# Verificar se Docker está rodando
if ! systemctl is-active --quiet docker; then
    echo "🐳 Iniciando Docker..."
    sudo systemctl start docker
    sleep 3
fi

# Verificar se Apache está rodando
if ! systemctl is-active --quiet apache2; then
    echo "🌐 Iniciando Apache..."
    sudo systemctl start apache2
    sleep 2
fi

# Verificar se Flask está rodando
if ! systemctl is-active --quiet brln-flask; then
    echo "🐍 Iniciando Flask API..."
    sudo systemctl start brln-flask
    sleep 3
fi

# Aguardar todos os serviços iniciarem
echo "⏳ Aguardando serviços iniciarem..."
sleep 5

# Verificar status final
echo ""
echo "🔍 Verificação final dos serviços:"
echo "====================================="

bash /home/admin/brlnfullauto/container/graphics/check_services.sh

LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Interface BRLN pronta para uso!"
echo "====================================="
echo ""
echo "🌐 Acesse: http://$LOCAL_IP"
echo "🐍 API: http://$LOCAL_IP:5001"
echo ""
echo "🔧 Comandos úteis:"
echo "  • Verificar status: bash ~/brlnfullauto/container/graphics/check_services.sh"
echo "  • Logs Flask: sudo journalctl -u brln-flask.service -f"
echo "  • Reiniciar Flask: sudo systemctl restart brln-flask"
echo "  • Parar tudo: sudo systemctl stop apache2 brln-flask"
echo ""
