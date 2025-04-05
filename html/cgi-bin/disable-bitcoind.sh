#!/bin/bash
echo "Content-type: application/json"
echo ""

if sudo systemctl stop bitcoind && sudo systemctl disable bitcoind; then
    echo '{"status":"ok", "mensagem":"Bitcoind foi DESLIGADO com sucesso"}'
else
    echo '{"status":"erro", "mensagem":"Erro ao desligar o Bitcoind"}'
fi
