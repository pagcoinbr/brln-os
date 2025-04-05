#!/bin/bash
echo "Content-type: application/json"
echo ""

if sudo systemctl start lnd && sudo systemctl enable lnd; then
    echo '{"status":"ok", "mensagem":"LND foi LIGADO com sucesso"}'
else
    echo '{"status":"erro", "mensagem":"Erro ao ligar o LND"}'
fi
