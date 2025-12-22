#!/bin/bash

# Lightning Network applications installation functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_nodejs() {
  echo -e "${GREEN}📦 Instalando Node.js...${NC}"
  if ! command -v npm &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install nodejs -y >> /dev/null 2>&1 & spinner
  else
    echo "✅ Node.js já está instalado."
  fi
}

install_bos() {
  echo -e "${GREEN}⚡ Instalando Balance of Satoshis...${NC}"
  
  # Install Node.js first
  install_nodejs
  
  # Install BOS globally
  sudo npm install -g balanceofsatoshis >> /dev/null 2>&1 & spinner
  
  # Install systemd service if exists
  if [[ -f "$SERVICES_DIR/bos-telegram.service" ]]; then
    safe_cp "$SERVICES_DIR/bos-telegram.service" /etc/systemd/system/bos-telegram.service
    sudo systemctl daemon-reload
    sudo systemctl enable bos-telegram
  fi
  
  echo -e "${GREEN}✅ Balance of Satoshis instalado!${NC}"
}

install_thunderhub() {
  echo -e "${GREEN}⚡ Instalando ThunderHub...${NC}"
  
  # Install Node.js first
  install_nodejs
  
  # Create thunderhub user
  if ! id "thunderhub" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash thunderhub
  fi
  
  # Clone and setup ThunderHub
  cd /home/thunderhub
  sudo -u thunderhub git clone https://github.com/apotdevin/thunderhub.git
  cd thunderhub
  sudo -u thunderhub npm install >> /dev/null 2>&1 & spinner
  sudo -u thunderhub npm run build >> /dev/null 2>&1 & spinner
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/thunderhub.service" ]]; then
    safe_cp "$SERVICES_DIR/thunderhub.service" /etc/systemd/system/thunderhub.service
    sudo systemctl daemon-reload
    sudo systemctl enable thunderhub
  fi
  
  echo -e "${GREEN}✅ ThunderHub instalado!${NC}"
}

lnbits_install() {
  echo -e "${GREEN}⚡ Instalando LNbits...${NC}"
  
  # Create lnbits user
  if ! id "lnbits" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash lnbits
  fi
  
  # Install Python dependencies
  sudo apt install python3-pip python3-venv -y >> /dev/null 2>&1 & spinner
  
  # Clone LNbits
  cd /home/lnbits
  sudo -u lnbits git clone https://github.com/lnbits/lnbits.git
  cd lnbits
  
  # Setup virtual environment
  sudo -u lnbits python3 -m venv venv
  sudo -u lnbits ./venv/bin/pip install -r requirements.txt >> /dev/null 2>&1 & spinner
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/lnbits.service" ]]; then
    safe_cp "$SERVICES_DIR/lnbits.service" /etc/systemd/system/lnbits.service
    sudo systemctl daemon-reload
    sudo systemctl enable lnbits
  fi
  
  echo -e "${GREEN}✅ LNbits instalado!${NC}"
}

setup_lightning_monitor() {
  echo -e "${GREEN}📊 Configurando Lightning Monitor...${NC}"
  
  # Setup virtual environment for Flask API
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi
  
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"
  
  # Install Flask dependencies
  if [[ -f "$SCRIPT_DIR/api/v1/requirements.txt" ]]; then
    pip install -r "$SCRIPT_DIR/api/v1/requirements.txt" >> /dev/null 2>&1 & spinner
  fi
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/lightning-monitor.service" ]]; then
    safe_cp "$SERVICES_DIR/lightning-monitor.service" /etc/systemd/system/lightning-monitor.service
    sudo systemctl daemon-reload
    sudo systemctl enable lightning-monitor
  fi
  
  echo -e "${GREEN}✅ Lightning Monitor configurado!${NC}"
}

install_brln_api() {
  echo -e "${GREEN}🔌 Instalando BRLN API...${NC}"
  
  # Setup Lightning Monitor (includes Flask environment)
  setup_lightning_monitor
  
  # Install gRPC dependencies
  source "$FLASKVENV_DIR/bin/activate"
  pip install grpcio grpcio-tools >> /dev/null 2>&1 & spinner
  
  # Generate gRPC files if proto files exist
  if [[ -d "$SCRIPT_DIR/api/v1/proto" ]]; then
    echo "🔧 Gerando arquivos gRPC..."
    cd "$SCRIPT_DIR/api/v1"
    python -m grpc_tools.protoc \
      --python_out=. \
      --grpc_python_out=. \
      --proto_path=proto \
      proto/*.proto >> /dev/null 2>&1
  fi
  
  # Install API service
  if [[ -f "$SERVICES_DIR/brln-api.service" ]]; then
    safe_cp "$SERVICES_DIR/brln-api.service" /etc/systemd/system/brln-api.service
    sudo systemctl daemon-reload
    sudo systemctl enable brln-api
  fi
  
  echo -e "${GREEN}✅ BRLN API instalada!${NC}"
}