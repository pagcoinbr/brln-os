#!/bin/bash

# Bitcoin installation and configuration functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_bitcoind() {
  echo -e "${GREEN}₿ Instalando Bitcoin Core...${NC}"
  
  # Create bitcoin user if it doesn't exist
  if ! id "bitcoin" &>/dev/null; then
    echo -e "${BLUE}Criando usuário bitcoin...${NC}"
    sudo adduser --gecos "" --disabled-password bitcoin
  fi
  
  # Add admin user to bitcoin group
  echo -e "${BLUE}Adicionando usuário admin ao grupo bitcoin...${NC}"
  sudo adduser $atual_user bitcoin 2>/dev/null || true
  
  # Add bitcoin user to debian-tor group for Tor control
  echo -e "${BLUE}Adicionando usuário bitcoin ao grupo debian-tor...${NC}"
  sudo adduser bitcoin debian-tor 2>/dev/null || true
  
  # Download and verify Bitcoin Core
  echo -e "${BLUE}Baixando Bitcoin Core v${BTC_VERSION}...${NC}"
  cd /tmp
  
  # Detect architecture and set download file
  if [[ $arch == "x86_64" ]]; then
    BTC_ARCH="x86_64-linux-gnu"
  elif [[ $arch == "arm64" ]]; then
    BTC_ARCH="aarch64-linux-gnu"
  else
    BTC_ARCH="arm-linux-gnueabihf"
  fi
  
  # Download binaries and checksums
  wget -q --show-progress https://bitcoincore.org/bin/bitcoin-core-${BTC_VERSION}/bitcoin-${BTC_VERSION}-${BTC_ARCH}.tar.gz
  wget -q https://bitcoincore.org/bin/bitcoin-core-${BTC_VERSION}/SHA256SUMS
  wget -q https://bitcoincore.org/bin/bitcoin-core-${BTC_VERSION}/SHA256SUMS.asc
  
  # Verify checksum
  echo -e "${BLUE}Verificando checksum...${NC}"
  if sha256sum --ignore-missing --check SHA256SUMS 2>&1 | grep -q "OK"; then
    echo -e "${GREEN}✓ Checksum verificado com sucesso${NC}"
  else
    echo -e "${RED}✗ Falha na verificação do checksum!${NC}"
    return 1
  fi
  
  # Import GPG keys and verify signature
  echo -e "${BLUE}Importando chaves GPG e verificando assinatura...${NC}"
  curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | 
    grep download_url | 
    grep -oE "https://[a-zA-Z0-9./-]+" | 
    while read url; do 
      curl -s "$url" | gpg --import 2>/dev/null
    done
  
  if gpg --verify SHA256SUMS.asc 2>&1 | grep -q "Good signature"; then
    echo -e "${GREEN}✓ Assinatura GPG verificada${NC}"
  else
    echo -e "${YELLOW}⚠ Aviso: Não foi possível verificar todas as assinaturas GPG${NC}"
  fi
  
  # Extract binaries
  echo -e "${BLUE}Extraindo binários...${NC}"
  tar -xzf bitcoin-${BTC_VERSION}-${BTC_ARCH}.tar.gz
  
  # Install only bitcoind and bitcoin-cli
  echo -e "${BLUE}Instalando bitcoind e bitcoin-cli...${NC}"
  sudo install -m 0755 -o root -g root -t /usr/local/bin \
    bitcoin-${BTC_VERSION}/bin/bitcoin-cli \
    bitcoin-${BTC_VERSION}/bin/bitcoind
  
  # Verify installation
  if bitcoind --version | grep -q "v${BTC_VERSION}"; then
    echo -e "${GREEN}✓ Bitcoin Core v${BTC_VERSION} instalado${NC}"
  fi
  
  # Clean up installation files
  echo -e "${BLUE}Limpando arquivos temporários...${NC}"
  rm -f bitcoin-${BTC_VERSION}-${BTC_ARCH}.tar.gz SHA256SUMS SHA256SUMS.asc
  rm -rf bitcoin-${BTC_VERSION}
  
  # Create /data/bitcoin directory structure
  echo -e "${BLUE}Criando estrutura de diretórios...${NC}"
  sudo mkdir -p /data/bitcoin
  sudo chown bitcoin:bitcoin /data/bitcoin
  
  # Create symbolic link from /home/bitcoin/.bitcoin to /data/bitcoin
  sudo -u bitcoin bash -c '
    if [ ! -L /home/bitcoin/.bitcoin ]; then
      ln -s /data/bitcoin /home/bitcoin/.bitcoin
    fi
  '
  
  # Generate RPC credentials
  echo -e "${BLUE}Gerando credenciais RPC...${NC}"
  
  # Generate password
  RPC_PASS=$(openssl rand -hex 32)
  
  # Generate rpcauth line
  sudo -u bitcoin bash -c "
    cd /home/bitcoin/.bitcoin
    wget -q https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
    
    # Generate rpcauth line
    RPCAUTH_LINE=\$(python3 rpcauth.py minibolt '$RPC_PASS' 2>/dev/null | grep 'rpcauth=')
    
    # Save password to file (will be needed by other services)
    echo '$RPC_PASS' > /home/bitcoin/.bitcoin/.rpcpass
    chmod 600 /home/bitcoin/.bitcoin/.rpcpass
    
    # Save rpcauth line for config
    echo \"\$RPCAUTH_LINE\" > /home/bitcoin/.bitcoin/.rpcauth
    chmod 600 /home/bitcoin/.bitcoin/.rpcauth
    
    rm -f rpcauth.py
  "
  
  # Store password securely in password manager
  source "$SCRIPT_DIR/brln-tools/password_manager.sh"
  store_password_full "bitcoin_rpc" "$RPC_PASS" "Bitcoin Core RPC credentials" "minibolt" 8332 "http://127.0.0.1:8332"
  echo -e "${GREEN}✓ Credenciais RPC salvas no gerenciador de senhas${NC}"
  
  # Copy or create configuration
  if [[ -f "$SCRIPT_DIR/conf_files/bitcoin.conf" ]]; then
    echo -e "${BLUE}Copiando arquivo de configuração...${NC}"
    sudo cp "$SCRIPT_DIR/conf_files/bitcoin.conf" /data/bitcoin/bitcoin.conf
    
    # Replace rpcauth placeholder with generated one
    RPCAUTH_LINE=$(sudo cat /home/bitcoin/.bitcoin/.rpcauth)
    sudo sed -i "s|^rpcauth=.*|$RPCAUTH_LINE|" /data/bitcoin/bitcoin.conf
    
    sudo chown bitcoin:bitcoin /data/bitcoin/bitcoin.conf
    sudo chmod 640 /data/bitcoin/bitcoin.conf
  else
    echo -e "${YELLOW}⚠ Arquivo bitcoin.conf não encontrado em conf_files/${NC}"
    echo -e "${YELLOW}  Por favor, crie manualmente o arquivo de configuração${NC}"
  fi
  
  # Create symbolic link for admin user
  if [ ! -L /home/$atual_user/.bitcoin ]; then
    sudo ln -s /data/bitcoin /home/$atual_user/.bitcoin 2>/dev/null || true
  fi
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/bitcoind.service" ]]; then
    echo -e "${BLUE}Instalando serviço systemd...${NC}"
    safe_cp "$SERVICES_DIR/bitcoind.service" /etc/systemd/system/bitcoind.service
    sudo systemctl daemon-reload
    sudo systemctl enable bitcoind
    echo -e "${GREEN}✓ Serviço bitcoind habilitado${NC}"
  fi
  
  echo -e "${GREEN}✅ Bitcoin Core instalado com sucesso!${NC}"
  echo -e "${CYAN}💡 Credenciais RPC armazenadas no gerenciador de senhas${NC}"
  echo -e "${CYAN}💡 Consultar: Menu > Configurações > Gerenciador de Senhas${NC}"
  echo -e "${CYAN}💡 Use 'sudo systemctl start bitcoind' para iniciar o serviço${NC}"
  echo -e "${CYAN}💡 Use 'journalctl -fu bitcoind' para monitorar os logs${NC}"
}

configure_lnd() {
  echo -e "${GREEN}⚡ Configurando LND...${NC}"
  
  # Create lnd user if it doesn't exist
  if ! id "lnd" &>/dev/null; then
    echo -e "${BLUE}Criando usuário lnd...${NC}"
    sudo adduser --disabled-password --gecos "" lnd
  fi
  
  # Add lnd user to bitcoin and debian-tor groups
  echo -e "${BLUE}Adicionando lnd aos grupos bitcoin e debian-tor...${NC}"
  sudo usermod -a -G bitcoin,debian-tor lnd 2>/dev/null || true
  
  # Add admin user to lnd group
  echo -e "${BLUE}Adicionando $atual_user ao grupo lnd...${NC}"
  sudo adduser $atual_user lnd 2>/dev/null || true
  
  # Create /data/lnd directory structure
  echo -e "${BLUE}Criando estrutura de diretórios...${NC}"
  sudo mkdir -p /data/lnd
  sudo chown -R lnd:lnd /data/lnd
  
  # Create symbolic links
  sudo -u lnd bash -c '
    if [ ! -L /home/lnd/.lnd ]; then
      ln -s /data/lnd /home/lnd/.lnd
    fi
    if [ ! -L /home/lnd/.bitcoin ]; then
      ln -s /data/bitcoin /home/lnd/.bitcoin
    fi
  '
  
  # Create wallet password file
  echo -e "${BLUE}Criando arquivo de senha da carteira...${NC}"
  
  # Generate wallet password
  WALLET_PASS=$(openssl rand -base64 24)
  
  sudo -u lnd bash -c "
    if [ ! -f /data/lnd/password.txt ]; then
      echo '$WALLET_PASS' > /data/lnd/password.txt
      chmod 600 /data/lnd/password.txt
    fi
  "
  
  # Store password securely in password manager
  source "$SCRIPT_DIR/brln-tools/password_manager.sh"
  store_password_full "lnd_wallet" "$WALLET_PASS" "LND Wallet Password" "lnd" 8080 "https://127.0.0.1:8080"
  echo -e "${GREEN}✓ Senha da carteira LND salva no gerenciador de senhas${NC}"
  
  # Copy or create configuration
  if [[ -f "$SCRIPT_DIR/conf_files/lnd.conf" ]]; then
    echo -e "${BLUE}Copiando arquivo de configuração...${NC}"
    sudo cp "$SCRIPT_DIR/conf_files/lnd.conf" /data/lnd/lnd.conf
    
    # Get Bitcoin RPC credentials if available
    if [[ -f /home/bitcoin/.bitcoin/.rpcpass ]]; then
      RPC_PASS=$(sudo cat /home/bitcoin/.bitcoin/.rpcpass)
      sudo sed -i "s|bitcoind.rpcpass=.*|bitcoind.rpcpass=$RPC_PASS|" /data/lnd/lnd.conf
    fi
    
    sudo chown lnd:lnd /data/lnd/lnd.conf
    sudo chmod 640 /data/lnd/lnd.conf
  else
    echo -e "${YELLOW}⚠ Arquivo lnd.conf não encontrado em conf_files/${NC}"
    echo -e "${YELLOW}  Por favor, crie manualmente o arquivo de configuração${NC}"
  fi
  
  echo -e "${GREEN}✓ LND configurado${NC}"
}

download_lnd() {
  echo -e "${GREEN}⚡ Baixando e instalando LND...${NC}"
  
  # Configure Bitcoin Core for LND (add ZMQ settings)
  echo -e "${BLUE}Configurando Bitcoin Core para LND (ZMQ)...${NC}"
  if [[ -f /data/bitcoin/bitcoin.conf ]]; then
    # Check if ZMQ is already configured
    if ! grep -q "zmqpubrawblock" /data/bitcoin/bitcoin.conf; then
      sudo bash -c 'cat >> /data/bitcoin/bitcoin.conf << EOF

# Enable ZMQ raw notification (for LND)
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
EOF'
      echo -e "${GREEN}✓ Configurações ZMQ adicionadas ao bitcoin.conf${NC}"
      
      # Restart bitcoind if running
      if systemctl is-active --quiet bitcoind; then
        echo -e "${BLUE}Reiniciando bitcoind para aplicar mudanças...${NC}"
        sudo systemctl restart bitcoind
        sleep 5
        
        # Verify ZMQ ports
        if sudo ss -tulpn | grep LISTEN | grep bitcoind | grep -q 2833; then
          echo -e "${GREEN}✓ Portas ZMQ 28332 e 28333 ativas${NC}"
        fi
      fi
    else
      echo -e "${GREEN}✓ ZMQ já está configurado${NC}"
    fi
  fi
  
  cd /tmp
  
  # Detect architecture and set download file
  if [[ $arch == "x86_64" ]]; then
    LND_ARCH="amd64"
  elif [[ $arch == "arm64" ]]; then
    LND_ARCH="arm64"
  else
    LND_ARCH="armv7"
  fi
  
  # Download binaries, checksums and signatures
  echo -e "${BLUE}Baixando LND v${LND_VERSION}-beta...${NC}"
  wget -q --show-progress https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta.tar.gz
  wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/manifest-v${LND_VERSION}-beta.txt.ots
  wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/manifest-v${LND_VERSION}-beta.txt
  wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/manifest-roasbeef-v${LND_VERSION}-beta.sig.ots
  wget -q https://github.com/lightningnetwork/lnd/releases/download/v${LND_VERSION}-beta/manifest-roasbeef-v${LND_VERSION}-beta.sig
  
  # Verify checksum
  echo -e "${BLUE}Verificando checksum...${NC}"
  if sha256sum --check manifest-v${LND_VERSION}-beta.txt --ignore-missing 2>&1 | grep -q "OK"; then
    echo -e "${GREEN}✓ Checksum verificado com sucesso${NC}"
  else
    echo -e "${RED}✗ Falha na verificação do checksum!${NC}"
    return 1
  fi
  
  # Import GPG key and verify signature
  echo -e "${BLUE}Importando chave GPG do desenvolvedor...${NC}"
  curl -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import 2>/dev/null
  
  echo -e "${BLUE}Verificando assinatura GPG...${NC}"
  if gpg --verify manifest-roasbeef-v${LND_VERSION}-beta.sig manifest-v${LND_VERSION}-beta.txt 2>&1 | grep -q "Good signature"; then
    echo -e "${GREEN}✓ Assinatura GPG verificada${NC}"
  else
    echo -e "${YELLOW}⚠ Aviso: Não foi possível verificar a assinatura GPG${NC}"
  fi
  
  # Verify OpenTimestamps (if ots is available)
  if command -v ots &> /dev/null; then
    echo -e "${BLUE}Verificando timestamp OpenTimestamps...${NC}"
    ots --no-cache verify manifest-roasbeef-v${LND_VERSION}-beta.sig.ots -f manifest-roasbeef-v${LND_VERSION}-beta.sig 2>/dev/null && \
      echo -e "${GREEN}✓ Timestamp verificado${NC}" || \
      echo -e "${YELLOW}⚠ Timestamp não disponível${NC}"
  fi
  
  # Extract binaries
  echo -e "${BLUE}Extraindo binários...${NC}"
  tar -xzf lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta.tar.gz
  
  # Install only lnd and lncli
  echo -e "${BLUE}Instalando lnd e lncli...${NC}"
  sudo install -m 0755 -o root -g root -t /usr/local/bin \
    lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta/lnd \
    lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta/lncli
  
  # Verify installation
  if lnd --version | grep -q "${LND_VERSION}"; then
    echo -e "${GREEN}✓ LND v${LND_VERSION}-beta instalado${NC}"
  fi
  
  # Clean up installation files
  echo -e "${BLUE}Limpando arquivos temporários...${NC}"
  rm -f lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta.tar.gz \
    manifest-roasbeef-v${LND_VERSION}-beta.sig \
    manifest-roasbeef-v${LND_VERSION}-beta.sig.ots \
    manifest-v${LND_VERSION}-beta.txt \
    manifest-v${LND_VERSION}-beta.txt.ots
  rm -rf lnd-linux-${LND_ARCH}-v${LND_VERSION}-beta
  
  # Configure LND
  configure_lnd
  
  # Install systemd service
  if [[ -f "$SERVICES_DIR/lnd.service" ]]; then
    echo -e "${BLUE}Instalando serviço systemd...${NC}"
    safe_cp "$SERVICES_DIR/lnd.service" /etc/systemd/system/lnd.service
    sudo systemctl daemon-reload
    sudo systemctl enable lnd
    echo -e "${GREEN}✓ Serviço lnd habilitado${NC}"
  fi
  
  echo -e "${GREEN}✅ LND instalado com sucesso!${NC}"
  echo -e "${CYAN}💡 Senha da carteira armazenada no gerenciador de senhas${NC}"
  echo -e "${CYAN}💡 Consultar: Menu > Configurações > Gerenciador de Senhas${NC}"
  echo -e "${CYAN}💡 Use 'sudo systemctl start lnd' para iniciar o serviço${NC}"
  echo -e "${CYAN}💡 Use 'journalctl -fu lnd' para monitorar os logs${NC}"
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