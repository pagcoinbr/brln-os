#!/bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 07/10/2024

GITHUB_CRIPTOSHARK=https://github.com/cryptosharks131/lndg.git
LNDG_DIR=/home/admin/lndg

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Verifica se o git está instalado, caso contrário, instala
if ! command -v git &> /dev/null
then
    echo "Git não encontrado, instalando..."
    sudo apt install git -y
fi

# Volta à home
cd

# Clona o repositório, se ainda não estiver clonado
if [ ! -d "$LNDG_DIR" ]; then
    git clone $GITHUB_CRIPTOSHARK && cd lndg
else
    echo "O repositório já foi clonado."
    cd lndg
fi

# Instala o virtualenv (ou python3-venv) se não estiver instalado
if ! command -v virtualenv &> /dev/null
then
    echo "Instalando virtualenv..."
    sudo apt install virtualenv -y
fi

# Configura o ambiente virtual
virtualenv -p python3 .venv

# Ativa o ambiente virtual e instala as dependências
source .venv/bin/activate
pip install -r requirements.txt
pip install whitenoise

# Executa o script de inicialização
.venv/bin/python initialize.py --whitenoise

# Cria o service para o backend
sudo tee /etc/systemd/system/lndg-controller.service > /dev/null <<EOF
[Unit]
Description=Controlador de backend para Lndg

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
ExecStart=$LNDG_DIR/.venv/bin/python $LNDG_DIR/controller.py
StandardOutput=append:/var/log/lndg-controller.log
StandardError=append:/var/log/lndg-controller.log
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF

# Cria o service para o frontend
sudo tee /etc/systemd/system/lndg.service > /dev/null <<EOF
[Unit]
Description=LNDG Django Server
After=network.target

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
WorkingDirectory=$LNDG_DIR
ExecStart=$LNDG_DIR/.venv/bin/python $LNDG_DIR/manage.py runserver 0.0.0.0:8889
StandardOutput=append:/var/log/lndg.log
StandardError=append:/var/log/lndg.log
Restart=always
RestartSec=5
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

# Recarrega e reinicia os serviços
sudo systemctl daemon-reload
sudo systemctl restart lndg-controller.service
sudo systemctl restart lndg.service

# Mostra o status dos serviços
sudo systemctl status lndg-controller.service
sudo systemctl status lndg.service
