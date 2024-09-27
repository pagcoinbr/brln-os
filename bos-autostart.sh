#!/bin/bash
# Script criado por PagcoinBTC
# PGP: 9585 831e 06ac 0821
# Ultima edição: 26/09/2024

# Solicita o código de conexão do Telegram
read -p "Telegram Connection code: " telegram_code

# Cria o arquivo bos-telegram.service em /etc/systemd/system/
sudo bash -c "cat <<EOF > /etc/systemd/system/bos-telegram.service
# Systemd unit for Bos-Telegram Bot
# /etc/systemd/system/bos-telegram.service
# Substitua as variáveis iniciadas com \$ com suas informações
# Não esquece de apagar o \$

[Unit]
Description=bos-telegram
Wants=lnd.service
After=lnd.service

[Service]
ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect $telegram_code
User=admin
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal
Environment=BOS_DEFAULT_LND_PATH=/data/lnd

[Install]
WantedBy=multi-user.target
EOF"

# Atualiza o daemon do systemd
sudo systemctl daemon-reload

# Inicia o serviço bos-telegram
sudo systemctl start bos-telegram.service

# Habilita o serviço para iniciar com o sistema
sudo systemctl enable bos-telegram.service

echo "Se o serviço estiver como <active>, tudo correu bem, aperte Ctrl + C par voltar o terminal"

# Mostra o status do serviço
sudo systemctl status bos-telegram.service
