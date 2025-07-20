#!/bin/bash

# Script para gerar os arquivos de serviço do systemd com usuário personalizável
# Uso: ./generate-services.sh [usuário] [diretório_instalação]

# Define o usuário (usa o parâmetro ou o usuário atual)
TARGET_USER=${1:-$USER}

# Define o diretório de instalação
if [[ "$TARGET_USER" == "root" ]]; then
    INSTALL_DIR="/root/brln-os"
else
    INSTALL_DIR="/home/$TARGET_USER/brln-os"
fi

# Permite override do diretório via parâmetro
INSTALL_DIR=${2:-$INSTALL_DIR}
SERVICES_DIR="$INSTALL_DIR/services"

# Cria o diretório de serviços se não existir
mkdir -p "$SERVICES_DIR"

echo "Gerando serviços para o usuário: $TARGET_USER"
echo "Diretório de instalação: $INSTALL_DIR"

# Gera o arquivo brln-rpc-server.service (substituindo o control-systemd Flask)
cat > "$SERVICES_DIR/brln-rpc-server.service" << EOF
[Unit]
Description=BRLN RPC Server - Multi-chain payment server (Bitcoin, Lightning, Liquid)
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER
WorkingDirectory=$INSTALL_DIR/brln-rpc-server
Environment=NODE_ENV=production
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStartPre=/bin/bash -c 'cd $INSTALL_DIR/brln-rpc-server && npm install --production'
ExecStart=/usr/bin/node $INSTALL_DIR/brln-rpc-server/server.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=brln-rpc-server

[Install]
WantedBy=multi-user.target
EOF

# Gera o arquivo command-center.service
cat > "$SERVICES_DIR/command-center.service" << EOF
[Unit]
Description=Terminal Web com logs do Bitcoind via GoTTY
After=network.target

[Service]
User=$TARGET_USER
WorkingDirectory=$INSTALL_DIR
Environment=TERM=xterm
ExecStart=/usr/local/bin/gotty -p 3434 -w bash $INSTALL_DIR/scripts/command-central.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Gera o arquivo gotty-fullauto.service
cat > "$SERVICES_DIR/gotty-fullauto.service" << EOF
[Unit]
Description=Terminal Web para BRLN FullAuto
After=network.target

[Service]
User=$TARGET_USER
WorkingDirectory=$INSTALL_DIR
Environment=TERM=xterm
ExecStart=/usr/local/bin/gotty -p 3131 -w bash $INSTALL_DIR/brunel.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Serviços gerados com sucesso em: $SERVICES_DIR"
echo "Arquivos criados:"
echo "  - brln-rpc-server.service (Novo servidor JavaScript multi-chain)"
echo "  - command-center.service"
echo "  - gotty-fullauto.service"
echo ""
echo "Para instalar os serviços no systemd, execute:"
echo "  sudo cp $SERVICES_DIR/*.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable brln-rpc-server command-center gotty-fullauto"
