#!/bin/bash

cd ~/lndg

echo "Parando serviços do LNDg..."
sudo systemctl stop lndg.service
sudo systemctl stop lndg-controller.service

echo "Atualizando repositório do LNDg via git pull..."
git pull

echo "Aplicando migrações do Django..."
.venv/bin/python manage.py migrate

echo "Recarregando daemons e iniciando serviços..."
sudo systemctl daemon-reload
sudo systemctl start lndg.service
sudo systemctl start lndg-controller.service

echo "✅ LNDg atualizado com sucesso!"
