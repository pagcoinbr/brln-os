#!/bin/bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io
sudo apt install -y nodejs npm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
npm init -y
npm install next@13.1.6 react@18.2.0 react-dom@18.2.0
npm audit fix
npm install --save-dev jest
npm audit fix
npm install pg
npm pkg set scripts.dev="next dev"
npm pkg set scripts.test="jest"

# Setup do serviço BRLN Frontend
echo "Configurando serviço BRLN Frontend..."

# Get original user (not root) and home directory
CURRENT_USER=${SUDO_USER:-$(whoami)}
CURRENT_HOME=$(eval echo ~$CURRENT_USER)
PROJECT_DIR="$CURRENT_HOME/brln-os"

# Create service file with current user
sudo tee /etc/systemd/system/brln-frontend.service > /dev/null <<EOF
[Unit]
Description=BRLN OS - Bitcoin & Lightning Manager
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/npm run dev
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=PORT=3000
Environment=HOSTNAME=0.0.0.0
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable brln-frontend.service
sudo systemctl start brln-frontend.service

echo "Serviço BRLN Frontend configurado e iniciado com sucesso!"
sudo systemctl status brln-frontend.service