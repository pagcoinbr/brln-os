#!/bin/bash

# Bitcoin installation and configuration functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_bitcoind() {
  echo -e "${GREEN}₿ Instalando Bitcoin Core...${NC}"
  
  # Create bitcoin user if it doesn't exist
  if ! id "bitcoin" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash bitcoin
  fi
  
  # Download and install Bitcoin Core
  cd /tmp
  if [[ $arch == "x86_64" ]]; then
    wget -q https://bitcoincore.org/bin/bitcoin-core-${BTC_VERSION}/bitcoin-${BTC_VERSION}-x86_64-linux-gnu.tar.gz
    tar -xzf bitcoin-${BTC_VERSION}-x86_64-linux-gnu.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${BTC_VERSION}/bin/*
  else
    wget -q https://bitcoincore.org/bin/bitcoin-core-${BTC_VERSION}/bitcoin-${BTC_VERSION}-arm-linux-gnueabihf.tar.gz
    tar -xzf bitcoin-${BTC_VERSION}-arm-linux-gnueabihf.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-${BTC_VERSION}/bin/*
  fi
  
  # Create Bitcoin data directory
  sudo mkdir -p /home/bitcoin/.bitcoin
  sudo chown bitcoin:bitcoin /home/bitcoin/.bitcoin
  
  # Copy configuration if exists
  if [[ -f "$SCRIPT_DIR/conf_files/bitcoin.conf" ]]; then
    sudo cp "$SCRIPT_DIR/conf_files/bitcoin.conf" /home/bitcoin/.bitcoin/
    sudo chown bitcoin:bitcoin /home/bitcoin/.bitcoin/bitcoin.conf
  fi
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/bitcoind.service" ]]; then
    safe_cp "$SERVICES_DIR/bitcoind.service" /etc/systemd/system/bitcoind.service
    sudo systemctl daemon-reload
    sudo systemctl enable bitcoind
  fi
  
  echo -e "${GREEN}✅ Bitcoin Core instalado com sucesso!${NC}"
}

configure_lnd() {
  echo -e "${GREEN}⚡ Configurando LND...${NC}"
  
  # Create lnd user if it doesn't exist
  if ! id "lnd" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash lnd
  fi
  
  # Create LND data directory
  sudo mkdir -p /home/lnd/.lnd
  sudo chown lnd:lnd /home/lnd/.lnd
  
  # Copy configuration if exists
  if [[ -f "$SCRIPT_DIR/conf_files/lnd.conf" ]]; then
    sudo cp "$SCRIPT_DIR/conf_files/lnd.conf" /home/lnd/.lnd/
    sudo chown lnd:lnd /home/lnd/.lnd/lnd.conf
  fi
  
  echo -e "${GREEN}✅ LND configurado!${NC}"
}

download_lnd() {
  echo -e "${GREEN}⚡ Baixando e instalando LND...${NC}"
  
  cd /tmp
  if [[ $arch == "x86_64" ]]; then
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/lnd-linux-amd64-v${LND_VERSION}-beta.tar.gz
    tar -xzf lnd-linux-amd64-v${LND_VERSION}-beta.tar.gz
  else
    wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/lnd-linux-armv7-v${LND_VERSION}-beta.tar.gz
    tar -xzf lnd-linux-armv7-v${LND_VERSION}-beta.tar.gz
  fi
  
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-*/lnd lnd-linux-*/lncli
  
  # Configure LND
  configure_lnd
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/lnd.service" ]]; then
    safe_cp "$SERVICES_DIR/lnd.service" /etc/systemd/system/lnd.service
    sudo systemctl daemon-reload
    sudo systemctl enable lnd
  fi
  
  echo -e "${GREEN}✅ LND instalado com sucesso!${NC}"
}

install_complete_stack() {
  echo -e "${GREEN}🔄 Instalando stack completo Bitcoin + Lightning...${NC}"
  
  # Install Bitcoin Core
  install_bitcoind
  
  # Install LND
  download_lnd
  
  echo -e "${GREEN}✅ Stack completo instalado!${NC}"
  echo -e "${BLUE}💡 Use 'systemctl start bitcoind' e 'systemctl start lnd' para iniciar os serviços${NC}"
}