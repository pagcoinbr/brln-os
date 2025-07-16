#!/bin/bash
# Script para ativar o ambiente virtual do cliente LND
source ./lnd_client_env/bin/activate
echo "🔌 Ambiente virtual ativado!"
echo "Para executar o cliente: python lnd_balance_client.py"
echo "Para desativar: deactivate"
