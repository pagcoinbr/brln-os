#! /bin/bash

# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 07/10/2024

GITHUB_CRIPTOSHARK=https://github.com/cryptosharks131/lndg.git

# Atualiza os pacotes do sistema
sudo apt update && sudo apt full-upgrade -y

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

# Usa um script para o backend
sudo bash systemd.sh

# Cria o service para o frontend
sudo cat <<EOF > /etc/systemd/system/uwsgi.service
[Unit]
Description=Lndg uWSGI app
After=syslog.target

[Service]
ExecStart=/home/admin/lndg/.venv/bin/python /home/admin/lndg/manage.py runserver 0.0.0.0:8889
User=admin
Group=www-data
Restart=on-failure
KillSignal=SIGQUIT
Type=notify
StandardError=syslog
NotifyAccess=all
Environment="PATH=/home/admin/lndg/.venv/bin"

[Install]
WantedBy=multi-user.target
EOF

# Recarrega o systemd
sudo systemctl daemon-reload
sudo systemctl status uwsgi.service
