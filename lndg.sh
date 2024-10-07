#! /bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 07/10/2024

GITHUB_CRIPTOSHARK=https://github.com/cryptosharks131/lndg.git

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

# Volta a home
cd

# Clona o repositório
git clone $GITHUB_CRIPTOSHARK && cd lndg

# Baixe o ambiente virtual
sudo apt install virtualenv

# Configure o ambiente virtual
virtualenv -p python3 .venv

# Instalar dependências
.venv/bin/pip install -r requirements.txt

# Instalar o whitenoise
.venv/bin/pip install whitenoise

# Rodar o script com flag especial
.venv/bin/python initialize.py --whitenoise

# Cria o service para o backend
sudo cat <<EOF > /etc/systemd/system/lndg-controller.service
[Unit]
Description=Controlador de backend para Lndg

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
ExecStart=/home/admin/lndg/.venv/bin/python /home/admin/lndg/controller.py
StandardOutput=append:/var/log/lndg-controller.log
StandardError=append:/var/log/lndg-controller.log
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF

# Cria o service para o frontend
sudo cat <<EOF > /etc/systemd/system/lndg.service
[Unit]
Description=LNDG Django Server
After=network.target

# Recarrega o systemd
sudo systemctl daemon-reload
sudo systemctl restart lndg-controller.service
sudo systemctl status lndg-controller.service

[Service]
Environment=PYTHONUNBUFFERED=1
User=admin
Group=admin
WorkingDirectory=/home/admin/lndg
ExecStart=/home/admin/lndg/.venv/bin/python /home/admin/lndg/manage.py runserver 0.0.0.0:8889
StandardOutput=append:/var/log/lndg.log
StandardError=append:/var/log/lndg.log
Restart=always
RestartSec=5
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

# Recarrega o systemd
sudo systemctl daemon-reload
sudo systemctl restart lndg.service
sudo systemctl status lndg.service
