#!/bin/bash

cd ~/lnbits

echo "Parando o serviço do LNbits..."
sudo systemctl stop lnbits

echo "Atualizando repositório LNbits..."
git pull

echo "Atualizando o Poetry e instalando dependências..."
poetry self update
poetry install

echo "Recarregando e reiniciando serviço do LNbits..."
sudo systemctl daemon-reload
sudo systemctl start lnbits

echo "✅ LNbits atualizado com sucesso!"
