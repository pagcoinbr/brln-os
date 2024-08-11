#!/bin/bash

# Variáveis de configuração
THUNDERHUB_PORT=3010
THUNDERHUB_DIR=/home/admin/thunderhub
NODE_NETWORK=mainnet # ou testnet, se aplicável
NODE_CHAIN=bitcoin   # ou litecoin, se aplicável

# Verifique se o Node.js está instalado e atualizado
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Configure o firewall para permitir o acesso ao ThunderHub
sudo ufw allow from 192.168.0.0/16 to any port $THUNDERHUB_PORT comment 'allow ThunderHub on LAN'

# Se o Tor estiver ativado, crie um serviço oculto para o ThunderHub
/home/admin/config.scripts/internet.hiddenservice.sh thunderhub 80 $THUNDERHUB_PORT

# Clone o repositório do ThunderHub e instale as dependências
git clone https://github.com/apotdevin/thunderhub.git $THUNDERHUB_DIR
cd $THUNDERHUB_DIR
npm install --force

# Execute a build do ThunderHub
npm run build

# Crie o serviço systemd para o ThunderHub
echo "*** Install ThunderHub systemd for ${NODE_NETWORK} on ${NODE_CHAIN} ***"
sudo bash -c "cat > /etc/systemd/system/thunderhub.service <<EOF
# Systemd unit for ThunderHub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub daemon
Wants=lnd.service
After=lnd.service

[Service]
WorkingDirectory=$THUNDERHUB_DIR
ExecStart=/usr/bin/npm run start -- -p $THUNDERHUB_PORT
User=admin
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF"

# Ajuste as permissões e habilite o serviço
sudo chown root:root /etc/systemd/system/thunderhub.service
sudo systemctl enable thunderhub

# Inicie o serviço e verifique o status
sudo systemctl start thunderhub
sudo systemctl status thunderhub
