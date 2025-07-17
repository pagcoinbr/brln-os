#!/bin/bash

# Script para gerar os arquivos de serviço do systemd com usuário personalizável
# Uso: ./generate-services.sh [usuário]

# Define o usuário (usa o parâmetro ou o usuário atual)
TARGET_USER=${1:-$USER}
SERVICES_DIR="/home/$TARGET_USER/brln-os/services"

# Cria o diretório de serviços se não existir
mkdir -p "$SERVICES_DIR"

echo "Gerando serviços para o usuário: $TARGET_USER"

# Gera o arquivo control-systemd.service
cat > "$SERVICES_DIR/control-systemd.service" << EOF
[Unit]
Description=Servidor Flask para Controle do LNBits
After=network.target

[Service]
User=$TARGET_USER
WorkingDirectory=/home/$TARGET_USER/
Environment="PATH=/home/$TARGET_USER/envflask/bin"
ExecStart=/home/$TARGET_USER/envflask/bin/python3 /home/$TARGET_USER/brlnfullauto/control-systemd.py
Restart=always

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
WorkingDirectory=/home/$TARGET_USER
Environment=TERM=xterm
ExecStart=/usr/local/bin/gotty -p 3434 -w bash /home/$TARGET_USER/brlnfullauto/brunel.sh
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
WorkingDirectory=/home/$TARGET_USER
Environment=TERM=xterm
ExecStart=/usr/local/bin/gotty -p 3131 -w bash /home/$TARGET_USER/brlnfullauto/brunel.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "Serviços gerados com sucesso em: $SERVICES_DIR"
echo "Arquivos criados:"
echo "  - control-systemd.service"
echo "  - command-center.service"
echo "  - gotty-fullauto.service"
echo ""
echo "Para instalar os serviços no systemd, execute:"
echo "  sudo cp $SERVICES_DIR/*.service /etc/systemd/system/"
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable control-systemd command-center gotty-fullauto"
