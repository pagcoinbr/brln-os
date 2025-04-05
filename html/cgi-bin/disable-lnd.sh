#!/bin/bash
echo "Content-type: application/json"
echo ""

if sudo systemctl stop lnd && sudo systemctl disable lnd; then
    echo '{"status":"ok", "mensagem":"LND foi DESLIGADO com sucesso"}'
else
    echo '{"status":"erro", "mensagem":"Erro ao desligar o LND"}'
fi
