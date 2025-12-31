#!/bin/bash

# System update and upgrade functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/apache.sh"

update_and_upgrade() {
  app="Interface Web Apache"
  echo "Configurando Apache Web Server..."
  sudo -v

  if [[ ! -d "$REPO_DIR" ]]; then
    echo -e "${RED}❌ Diretório do repositório não encontrado: $REPO_DIR${NC}"
    echo -e "${YELLOW}Defina a variável REPO_DIR corretamente antes de continuar.${NC}"
    return 1
  fi

  # Executa o git dentro do diretório, sem precisar dar cd
  # git -C "$REPO_DIR" stash || true
  git -C "$REPO_DIR" pull origin "$branch"

  if [[ -d "$FRONTEND_DIR" ]]; then
    echo "📥 Atualizando interface web via Apache..."
  else
    echo "📥 Atualizando interface web via Apache..."
  fi

  # Parar e desabilitar Next.js frontend se estiver rodando
  if sudo systemctl is-active --quiet brln-frontend; then
    echo "⏹️ Parando serviço Next.js frontend..."
    sudo systemctl stop brln-frontend || true
    sudo systemctl disable brln-frontend || true
  fi

  # Configurar Apache Web Server (skip if already running from web terminal)
  if type setup_apache_web &>/dev/null; then
    setup_apache_web
  else
    echo "⏭️  Pulando configuração Apache (função não disponível ou já configurado)"
  fi

  # Install/Update systemd service
  echo "Configurando serviço systemd..."
  # Skip brln-frontend.service since we're using Apache
  # safe_cp "$SERVICES_DIR/brln-frontend.service" /etc/systemd/system/brln-frontend.service
  # sudo systemctl daemon-reload

  # Garante que o pacote python3-venv esteja instalado (still needed for control scripts)
  if ! dpkg -l | grep -q python3-venv; then
    echo -e "${BLUE}📦 Instalando python3-venv...${NC}"
    sudo apt install python3-venv -y
  else
    echo "✅ python3-venv já está instalado."
  fi

  # Define o diretório do ambiente virtual
  FLASKVENV_DIR="$HOME/envflask"

  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    echo -e "${BLUE}🐍 Criando ambiente virtual Flask...${NC}"
    python3 -m venv "$FLASKVENV_DIR"
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instalar dependências Python se requirements.txt existir
  if [[ -f "$REPO_DIR/api/v1/requirements.txt" ]]; then
    echo -e "${BLUE}📦 Instalando dependências API...${NC}"
    pip install -r "$REPO_DIR/api/v1/requirements.txt"
  fi

  # Configurar permissões sudo para serviços
  echo "🔑 Configurando permissões sudo..."
  if [[ ! -f /etc/sudoers.d/admin-services ]]; then
    echo "$atual_user ALL=(ALL) NOPASSWD: /bin/systemctl start *, /bin/systemctl stop *, /bin/systemctl restart *, /bin/systemctl status *, /bin/systemctl enable *, /bin/systemctl disable *" | sudo tee /etc/sudoers.d/admin-services > /dev/null
  fi

  # Verificar configuração sudoers
  if sudo visudo -c -f /etc/sudoers.d/admin-services; then
    echo "✅ Configuração sudoers válida"
  else
    echo -e "${RED}❌ Erro na configuração sudoers${NC}"
    sudo rm -f /etc/sudoers.d/admin-services
  fi

  # Configurar crontab para atualização automática
  crontab_entry="0 2 * * * cd $REPO_DIR && git pull origin $branch > /tmp/git_pull.log 2>&1"
  if ! crontab -l | grep -Fq "$crontab_entry"; then
    (crontab -l; echo "$crontab_entry") | crontab -
    echo "📅 Crontab configurado para atualizações automáticas"
  else
    echo "✅ A entrada do crontab já existe. Nenhuma alteração feita."
  fi
  
  echo -e "${GREEN}✅ Sistema atualizado e configurado!${NC}"
}

setup_ufw_firewall() {
  echo -e "${GREEN}🔥 Configurando Firewall UFW...${NC}"
  
  # Check if UFW is installed
  if ! command -v ufw &> /dev/null; then
    echo -e "${BLUE}Instalando UFW...${NC}"
    sudo apt install -y ufw
  fi
  
  # Check IPv6 availability
  echo -e "${BLUE}Verificando disponibilidade de IPv6...${NC}"
  if ping6 -c2 2001:858:2:2:aabb:0:563b:1526 || \
     ping6 -c2 2620:13:4000:6000::1000:118; then
    echo -e "${GREEN}✓ IPv6 disponível${NC}"
    IPV6_AVAILABLE=true
  else
    echo -e "${YELLOW}⚠ IPv6 não disponível - desativando no UFW${NC}"
    IPV6_AVAILABLE=false
    
    # Disable IPv6 in UFW config
    sudo sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
  fi
  
  # Disable logging
  echo -e "${BLUE}Desativando logging do UFW...${NC}"
  sudo ufw logging off
  
  # Reset UFW to default (if needed)
  echo -e "${BLUE}Configurando regras padrão...${NC}"
  sudo ufw --force reset
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Allow SSH
  echo -e "${BLUE}Permitindo SSH (porta 22)...${NC}"
  sudo ufw allow 22/tcp comment 'allow SSH from anywhere'
  
  # Enable UFW
  echo -e "${BLUE}Ativando UFW...${NC}"
  echo "y" | sudo ufw enable
  
  # Show status
  echo -e "${GREEN}✓ UFW configurado e ativo${NC}"
  sudo ufw status verbose
  
  echo -e "${GREEN}✅ Firewall UFW configurado com sucesso!${NC}"
  echo -e "${CYAN}💡 Para ver o status: sudo ufw status verbose${NC}"
}

install_tor() {
  echo -e "${GREEN}🧅 Instalando Tor...${NC}"
  
  # Update system
  echo -e "${BLUE}Atualizando sistema...${NC}"
  sudo apt update && sudo apt full-upgrade -y
  
  # Install dependencies
  echo -e "${BLUE}Instalando dependências...${NC}"
  sudo apt install -y apt-transport-https
  
  # Detect architecture
  ARCH=$(dpkg --print-architecture)
  CODENAME=$(lsb_release -cs)
  
  # Create Tor repository file
  echo -e "${BLUE}Criando arquivo de repositório Tor...${NC}"
  sudo bash -c "cat > /etc/apt/sources.list.d/tor.list << EOF
deb     [arch=${ARCH} signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org ${CODENAME} main
deb-src [arch=${ARCH} signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org ${CODENAME} main
EOF"
  
  # Add GPG key
  echo -e "${BLUE}Adicionando chave GPG...${NC}"
  wget -qO- $TOR_GPGLINK | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg
  
  # Install Tor
  echo -e "${BLUE}Instalando Tor e keyring...${NC}"
  sudo apt update && sudo apt install -y tor deb.torproject.org-keyring
  
  # Verify installation
  if tor --version | head -n1; then
    echo -e "${GREEN}✓ Tor instalado com sucesso${NC}"
  fi
  
  # Configure Tor
  echo -e "${BLUE}Configurando Tor...${NC}"
  
  # Backup original config
  if [[ -f /etc/tor/torrc ]] && [[ ! -f /etc/tor/torrc.backup ]]; then
    sudo cp /etc/tor/torrc /etc/tor/torrc.backup
  fi
  
  # Enable ControlPort if not already enabled
  if ! grep -q "^ControlPort 9051" /etc/tor/torrc; then
    echo -e "${BLUE}Habilitando ControlPort 9051...${NC}"
    sudo sed -i 's/#ControlPort 9051/ControlPort 9051/' /etc/tor/torrc
    
    # If the line doesn't exist at all, add it
    if ! grep -q "ControlPort 9051" /etc/tor/torrc; then
      echo "ControlPort 9051" | sudo tee -a /etc/tor/torrc
    fi
  fi
  
  # Enable and restart Tor
  sudo systemctl enable tor
  sudo systemctl reload tor
  
  # Wait a moment for Tor to start
  sleep 2
  
  # Verify Tor is running and listening on correct ports
  echo -e "${BLUE}Verificando portas Tor...${NC}"
  if sudo ss -tulpn | grep LISTEN | grep tor | grep -q "9050\|9051"; then
    echo -e "${GREEN}✓ Tor está rodando nas portas 9050 e 9051${NC}"
    sudo ss -tulpn | grep LISTEN | grep tor
  else
    echo -e "${YELLOW}⚠ Aguardando Tor inicializar...${NC}"
    sleep 3
    sudo ss -tulpn | grep LISTEN | grep tor
  fi
  
  echo -e "${GREEN}✅ Tor instalado e configurado!${NC}"
  echo -e "${CYAN}💡 SOCKS Proxy: 127.0.0.1:9050${NC}"
  echo -e "${CYAN}💡 Control Port: 127.0.0.1:9051${NC}"
  echo -e "${CYAN}💡 Para monitorar logs: journalctl -fu tor@default${NC}"
}

install_i2p() {
  echo -e "${GREEN}🔒 Instalando I2P...${NC}"
  
  # Add I2P repository using their helper script
  echo -e "${BLUE}Adicionando repositório I2P...${NC}"
  wget -q -O - $I2P_REPO_HELPER | sudo bash -s -
  
  echo -e "${BLUE}📦 Atualizando repositórios...${NC}"
  sudo apt update
  
  # Install I2P
  echo -e "${BLUE}📦 Instalando i2pd...${NC}"
  sudo apt install -y i2pd
  
  # Verify installation
  if i2pd --version | head -n1; then
    echo -e "${GREEN}✓ i2pd instalado com sucesso${NC}"
  fi
  
  # Enable and start I2P
  sudo systemctl enable i2pd
  sudo systemctl start i2pd
  
  # Wait a moment for i2pd to start
  sleep 2
  
  # Verify i2pd is running
  echo -e "${BLUE}Verificando portas I2P...${NC}"
  if sudo ss -tulpn | grep i2pd | head -n 5; then
    echo -e "${GREEN}✓ i2pd está rodando${NC}"
  else
    echo -e "${YELLOW}⚠ Aguardando i2pd inicializar...${NC}"
    sleep 3
    sudo ss -tulpn | grep i2pd | head -n 5
  fi
  
  echo -e "${GREEN}✅ I2P instalado e iniciado!${NC}"
  echo -e "${CYAN}💡 HTTP Proxy: 127.0.0.1:4444${NC}"
  echo -e "${CYAN}💡 HTTPS Proxy: 127.0.0.1:4447${NC}"
  echo -e "${CYAN}💡 SOCKS Proxy: 127.0.0.1:4447${NC}"
  echo -e "${CYAN}💡 SAM Bridge: 127.0.0.1:7656${NC}"
  echo -e "${CYAN}💡 BOB Bridge: 127.0.0.1:2827${NC}"
  echo -e "${CYAN}💡 I2P Control: 127.0.0.1:7070${NC}"
  echo -e "${CYAN}💡 I2PControl: 127.0.0.1:7650${NC}"
  echo -e "${CYAN}💡 Para monitorar logs: sudo tail -f /var/log/i2pd/i2pd.log${NC}"
}

tailscale_vpn() {
  echo -e "${GREEN}🔒 Instalando Tailscale VPN...${NC}"
  
  # Download and install Tailscale
  curl -fsSL https://tailscale.com/install.sh | sh
  
  echo -e "${GREEN}✅ Tailscale instalado!${NC}"
  echo -e "${BLUE}💡 Execute 'sudo tailscale up' para conectar à sua rede Tailscale${NC}"
}