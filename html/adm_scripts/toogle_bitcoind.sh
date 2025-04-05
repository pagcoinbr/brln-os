#!/bin/bash

disable_bitcoind() {
    sudo systemctl stop bitcoind
    sudo systemctl disable bitcoind
}

if disable_bitcoind; then
    echo '{"status":"ok", "mensagem":"Bitcoind foi DESLIGADO com sucesso"}'
else
    echo '{"status":"erro", "mensagem":"Falha ao desligar o Bitcoind"}'
fi
