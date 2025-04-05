#!/bin/bash
echo "Content-type: application/json"
echo ""

if sudo systemctl start bitcoind && sudo systemctl enable bitcoind; then
    echo '{"status":"ok", "mensagem":"Bitcoind foi LIGADO com sucesso"}'
else
    echo '{"status":"erro", "mensagem":"Erro ao ligar o Bitcoind"}'
fi
