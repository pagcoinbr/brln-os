#!/bin/bash
# PeerSwap & PeerSwap Web Installation Script
# BRLN-OS PeerSwap Configuration and Management

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

# Source required configurations
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/utils.sh"

# PeerSwap versions
PEERSWAP_VERSION="4.0rc1"
PSWEB_VERSION="1.7.8"

install_peerswap() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}      🔄 INSTALAÇÃO DO PEERSWAP v${PEERSWAP_VERSION}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if already installed
  if command -v peerswapd &> /dev/null; then
    echo -e "${YELLOW}⚠️  PeerSwap já está instalado${NC}"
    peerswapd --version || echo "Versão instalada"
    echo ""
    read -p "Deseja reinstalar? (s/n): " reinstall
    if [[ "$reinstall" != "s" && "$reinstall" != "S" ]]; then
      echo -e "${BLUE}Instalação cancelada.${NC}"
      return 0
    fi
  fi

  # Create peerswap user if doesn't exist
  if ! id "peerswap" &>/dev/null; then
    echo -e "${BLUE}👤 Criando usuário 'peerswap'...${NC}"
    sudo adduser --disabled-password --gecos "" peerswap
    echo -e "${GREEN}✓ Usuário 'peerswap' criado${NC}"
    echo ""
  else
    echo -e "${GREEN}✓ Usuário 'peerswap' já existe${NC}"
    echo ""
  fi
  
  atual_user="peerswap"

  # Install dependencies
  echo -e "${BLUE}🛠️  Instalando dependências...${NC}"
  sudo apt update
  sudo apt install -y build-essential git
  echo -e "${GREEN}✓ Dependências instaladas${NC}"
  echo ""

  # Check Go version
  echo -e "${BLUE}🔍 Verificando Go...${NC}"
  if command -v go &> /dev/null; then
    GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+' | sed 's/go//')
    echo -e "${GREEN}✓ Go $GO_VERSION encontrado${NC}"
  else
    echo -e "${YELLOW}⚠️  Go não encontrado. Instalando...${NC}"
    install_go
  fi
  echo ""

  # Create peerswap directory
  echo -e "${BLUE}📁 Criando diretórios...${NC}"
  sudo -u peerswap mkdir -p /home/peerswap/.peerswap
  echo -e "${GREEN}✓ Diretório criado: /home/peerswap/.peerswap${NC}"
  echo ""

  # Clone and compile PeerSwap as peerswap user
  echo -e "${BLUE}📥 Clonando repositório PeerSwap...${NC}"
  
  # Remove old clone if exists
  sudo -u peerswap rm -rf /home/peerswap/peerswap
  
  if sudo -u peerswap git clone https://github.com/ElementsProject/peerswap.git /home/peerswap/peerswap; then
    echo -e "${GREEN}✓ Repositório clonado${NC}"
  else
    echo -e "${RED}❌ Erro ao clonar repositório${NC}"
    return 1
  fi
  echo ""

  cd /home/peerswap/peerswap
  
  # Checkout specific version
  echo -e "${BLUE}🔖 Checkout versão v${PEERSWAP_VERSION}...${NC}"
  if sudo -u peerswap git checkout v$PEERSWAP_VERSION; then
    echo -e "${GREEN}✓ Versão v${PEERSWAP_VERSION} selecionada${NC}"
  else
    echo -e "${YELLOW}⚠️  Usando branch main${NC}"
  fi
  echo ""
  
  # Compile
  echo -e "${BLUE}🔨 Compilando PeerSwap (isso pode levar alguns minutos)...${NC}"
  if sudo -u peerswap make lnd-release; then
    echo -e "${GREEN}✓ Compilação concluída${NC}"
  else
    echo -e "${RED}❌ Erro na compilação${NC}"
    return 1
  fi
  echo ""

  # Verify binaries were created
  if [[ -f "/home/peerswap/go/bin/peerswapd" ]]; then
    echo -e "${GREEN}✓ Binário instalado em /home/peerswap/go/bin/peerswapd${NC}"
  else
    echo -e "${RED}❌ Binário não encontrado${NC}"
    return 1
  fi

  # Add Go bin to PATH if not already there
  if ! sudo -u peerswap grep -q "\$HOME/go/bin" /home/peerswap/.bashrc; then
    echo -e "${BLUE}🔧 Adicionando Go bin ao PATH...${NC}"
    echo 'export PATH=$PATH:$HOME/go/bin' | sudo -u peerswap tee -a /home/peerswap/.bashrc
    echo -e "${GREEN}✓ PATH atualizado${NC}"
  fi

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   PeerSwap ${PEERSWAP_VERSION} instalado com sucesso!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Binário instalado em:${NC}"
  echo -e "   ${BLUE}~/go/bin/peerswapd${NC}"
  echo -e "   ${BLUE}~/go/bin/pscli${NC}"
  echo ""
}

install_go() {
  echo "📦 Instalando Go..."
  
  # Detectar arquitetura
  ARCH=$(uname -m)
  case $ARCH in
    x86_64) GO_ARCH="amd64" ;;
    aarch64) GO_ARCH="arm64" ;;
    armv7l) GO_ARCH="armv6l" ;;
    *) echo -e "${RED}❌ Arquitetura não suportada: $ARCH${NC}"; return 1 ;;
  esac
  
  GO_VERSION="1.21.5"
  cd /tmp
  wget -nv "https://golang.org/dl/go$GO_VERSION.linux-$GO_ARCH.tar.gz"
  
  # Remover instalação anterior
  sudo rm -rf /usr/local/go
  
  # Instalar nova versão
  sudo tar -C /usr/local -xzf "go$GO_VERSION.linux-$GO_ARCH.tar.gz"
  
  # Configurar PATH
  echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
  export PATH=$PATH:/usr/local/go/bin
  
  # Cleanup
  rm "go$GO_VERSION.linux-$GO_ARCH.tar.gz"
  
  echo -e "${GREEN}✅ Go $GO_VERSION instalado!${NC}"
}

configure_peerswap() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        ⚙️  CONFIGURAÇÃO DO PEERSWAP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Ensure peerswap user and directory exist
  if ! id "peerswap" &>/dev/null; then
    echo -e "${RED}❌ Usuário 'peerswap' não existe!${NC}"
    echo -e "${YELLOW}Execute a instalação do PeerSwap primeiro${NC}"
    return 1
  fi
  
  sudo -u peerswap mkdir -p /home/peerswap/.peerswap

  # Get Elements RPC password from password manager
  echo -e "${BLUE}🔐 Recuperando credenciais do Elements...${NC}"
  source "$SCRIPT_DIR/brln-tools/secure_password_manager.sh"
  
  elements_rpc_password=$(python3 "$SCRIPT_DIR/brln-tools/secure_password_manager.py" get elements_rpc_password)
  
  if [[ -z "$elements_rpc_password" ]]; then
    echo -e "${YELLOW}⚠️  Senha do Elements RPC não encontrada no gerenciador${NC}"
    echo -e "${YELLOW}Tentando ler de /data/elements/elements.conf...${NC}"
    elements_rpc_password=$(grep rpcpassword /data/elements/elements.conf | cut -d'=' -f2)
    
    if [[ -z "$elements_rpc_password" ]]; then
      echo -e "${RED}❌ Não foi possível obter a senha do Elements RPC${NC}"
      echo -e "${YELLOW}Configure o Elements primeiro ou insira a senha manualmente${NC}"
      read -p "Senha RPC do Elements: " elements_rpc_password
    fi
  fi
  echo -e "${GREEN}✓ Credenciais recuperadas${NC}"
  echo ""

  # Get admin/main user for LND paths
  if [[ "$SUDO_USER" ]]; then
    lnd_user="$SUDO_USER"
  else
    # Try to find the user with LND installation
    lnd_user=$(find /home -maxdepth 2 -name ".lnd" -type d | head -n1 | cut -d'/' -f3)
    if [[ -z "$lnd_user" ]]; then
      lnd_user="admin"  # fallback
    fi
  fi

  # Create configuration file
  echo -e "${BLUE}📝 Criando arquivo de configuração...${NC}"
  sudo -u peerswap tee /home/peerswap/.peerswap/peerswap.conf > /dev/null << EOF
lnd.tlscertpath=/home/$lnd_user/.lnd/tls.cert
lnd.macaroonpath=/home/$lnd_user/.lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon
elementsd.rpcuser=elements
elementsd.rpcpass=$elements_rpc_password
elementsd.rpchost=http://127.0.0.1
elementsd.rpcport=7041
elementsd.rpcwallet=peerswap
elementsd.liquidswaps=true
bitcoinswaps=false
EOF

  # Set permissions
  sudo chmod 600 /home/peerswap/.peerswap/peerswap.conf
  sudo chown peerswap:peerswap /home/peerswap/.peerswap/peerswap.conf
  echo -e "${GREEN}✓ Arquivo de configuração criado${NC}"
  echo -e "${GREEN}✓ Permissões ajustadas (600)${NC}"
  echo ""

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   PeerSwap configurado com sucesso!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Informações de configuração:${NC}"
  echo -e "   ${BLUE}Arquivo de config:${NC} /home/peerswap/.peerswap/peerswap.conf"
  echo -e "   ${BLUE}Usuário LND:${NC}       $lnd_user"
  echo -e "   ${BLUE}Liquid Swaps:${NC}      Habilitado"
  echo -e "   ${BLUE}Bitcoin Swaps:${NC}     Desabilitado"
  echo -e "   ${BLUE}Elements Wallet:${NC}   peerswap"
  echo ""
  echo -e "${YELLOW}💡 Próximo passo: Crie a wallet 'peerswap' no Elements${NC}"
  echo ""
}

create_peerswap_service() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🔧 CRIANDO SERVIÇO SYSTEMD${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  echo -e "${BLUE}📄 Criando arquivo de serviço...${NC}"
  source "$SCRIPT_DIR/scripts/services.sh"
  create_peerswapd_service

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Arquivo de serviço criado${NC}"
  else
    echo -e "${RED}❌ Erro ao criar arquivo de serviço${NC}"
    return 1
  fi
  echo ""

  # Reload systemd and enable service
  echo -e "${BLUE}🔄 Habilitando serviço...${NC}"
  sudo systemctl daemon-reload
  sudo systemctl enable peerswapd
  echo -e "${GREEN}✓ Serviço habilitado${NC}"
  echo ""

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Serviço systemd criado e habilitado!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Comandos úteis:${NC}"
  echo -e "   ${BLUE}Iniciar:${NC}    sudo systemctl start peerswapd"
  echo -e "   ${BLUE}Parar:${NC}      sudo systemctl stop peerswapd"
  echo -e "   ${BLUE}Status:${NC}     sudo systemctl status peerswapd"
  echo -e "   ${BLUE}Logs:${NC}       journalctl -u peerswapd -f"
  echo ""
}

install_psweb() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}      🌐 INSTALAÇÃO DO PEERSWAP WEB UI${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if already installed
  if command -v psweb &> /dev/null; then
    echo -e "${YELLOW}⚠️  PeerSwap Web já está instalado${NC}"
    echo ""
    read -p "Deseja reinstalar? (s/n): " reinstall
    if [[ "$reinstall" != "s" && "$reinstall" != "S" ]]; then
      echo -e "${BLUE}Instalação cancelada.${NC}"
      return 0
    fi
  fi

  # Ensure peerswap user exists
  if ! id "peerswap" &>/dev/null; then
    echo -e "${RED}❌ Usuário 'peerswap' não existe!${NC}"
    echo -e "${YELLOW}Execute a instalação do PeerSwap primeiro${NC}"
    return 1
  fi

  # Check Go version
  echo -e "${BLUE}🔍 Verificando Go...${NC}"
  if command -v go &> /dev/null; then
    GO_VERSION=$(go version | grep -o 'go[0-9]\+\.[0-9]\+' | sed 's/go//')
    echo -e "${GREEN}✓ Go $GO_VERSION encontrado${NC}"
  else
    echo -e "${YELLOW}⚠️  Go não encontrado. Instalando...${NC}"
    install_go
  fi
  echo ""

  # Clone PeerSwap Web UI as peerswap user
  echo -e "${BLUE}📥 Clonando repositório PeerSwap Web UI...${NC}"
  
  # Remove old clone if exists
  sudo -u peerswap rm -rf /home/peerswap/peerswap-web
  
  if sudo -u peerswap git clone https://github.com/Impa10r/peerswap-web /home/peerswap/peerswap-web; then
    echo -e "${GREEN}✓ Repositório clonado${NC}"
  else
    echo -e "${RED}❌ Erro ao clonar repositório${NC}"
    return 1
  fi
  echo ""

  cd /home/peerswap/peerswap-web
  
  # Compile PeerSwap Web
  echo -e "${BLUE}🔨 Compilando PeerSwap Web (isso pode levar alguns minutos)...${NC}"
  if sudo -u peerswap make -j$(nproc) install-lnd; then
    echo -e "${GREEN}✓ Compilação concluída${NC}"
  else
    echo -e "${RED}❌ Erro na compilação${NC}"
    return 1
  fi
  echo ""

  # Verify binary was created
  if [[ -f "/home/peerswap/go/bin/psweb" ]]; then
    echo -e "${GREEN}✓ Binário instalado em /home/peerswap/go/bin/psweb${NC}"
  else
    echo -e "${RED}❌ Binário não encontrado${NC}"
    return 1
  fi

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   PeerSwap Web UI instalado com sucesso!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Informações de configuração:${NC}"
  echo -e "   ${BLUE}Usuário:${NC}         peerswap"
  echo -e "   ${BLUE}Binário:${NC}         /home/peerswap/go/bin/psweb"
  echo -e "   ${BLUE}Porta:${NC}           1984"
  echo ""
  echo -e "${CYAN}✨ Recursos do PeerSwap Web UI:${NC}"
  echo -e "   ${BLUE}1️⃣${NC}  Transforme BTC em L-BTC via Liquid Peg-in"
  echo -e "   ${BLUE}2️⃣${NC}  Rebalanceie canais rapidamente com L-BTC"
  echo -e "   ${BLUE}3️⃣${NC}  Gerencie automaticamente fees com autofee"
  echo ""
}

# configure_psweb is not needed - psweb auto-configures on first run

create_psweb_service() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🔧 CRIANDO SERVIÇO SYSTEMD${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  echo -e "${BLUE}📄 Criando arquivo de serviço...${NC}"
  source "$SCRIPT_DIR/scripts/services.sh"
  create_psweb_service

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Arquivo de serviço criado${NC}"
  else
    echo -e "${RED}❌ Erro ao criar arquivo de serviço${NC}"
    return 1
  fi
  echo ""

  # Reload systemd and enable service
  echo -e "${BLUE}🔄 Habilitando serviço...${NC}"
  sudo systemctl daemon-reload
  sudo systemctl enable psweb
  echo -e "${GREEN}✓ Serviço habilitado${NC}"
  echo ""

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Serviço systemd criado e habilitado!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Comandos úteis:${NC}"
  echo -e "   ${BLUE}Iniciar:${NC}    sudo systemctl start psweb"
  echo -e "   ${BLUE}Parar:${NC}      sudo systemctl stop psweb"
  echo -e "   ${BLUE}Status:${NC}     sudo systemctl status psweb"
  echo -e "   ${BLUE}Logs:${NC}       journalctl -u psweb -f"
  echo ""
}

start_peerswap() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🚀 INICIANDO PEERSWAP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if LND is running
  if ! sudo systemctl is-active --quiet lnd; then
    echo -e "${RED}❌ LND não está em execução!${NC}"
    echo -e "${YELLOW}Inicie o LND primeiro: sudo systemctl start lnd${NC}"
    echo ""
    return 1
  fi
  
  # Check if Elements is running
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${RED}❌ Elements não está em execução!${NC}"
    echo -e "${YELLOW}Inicie o Elements primeiro: sudo systemctl start elementsd${NC}"
    echo ""
    return 1
  fi
  
  # Check if already running
  if sudo systemctl is-active --quiet peerswapd; then
    echo -e "${YELLOW}ℹ️  PeerSwap já está em execução${NC}"
    echo ""
    show_peerswap_status
    return 0
  fi

  echo -e "${BLUE}▶️  Iniciando serviço...${NC}"
  sudo systemctl start peerswapd
  
  # Wait for service to start
  echo -e "${YELLOW}⏳ Aguardando inicialização...${NC}"
  sleep 5
  
  if sudo systemctl is-active --quiet peerswapd; then
    echo -e "${GREEN}✓ PeerSwap iniciado com sucesso!${NC}"
    echo ""
    show_peerswap_status
  else
    echo -e "${RED}❌ Falha ao iniciar PeerSwap!${NC}"
    echo ""
    echo -e "${YELLOW}Verificando logs:${NC}"
    sudo journalctl -u peerswapd -n 20 --no-pager
    return 1
  fi
}

start_psweb() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🚀 INICIANDO PEERSWAP WEB UI${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if PeerSwap is running
  if ! sudo systemctl is-active --quiet peerswapd; then
    echo -e "${RED}❌ PeerSwap não está em execução!${NC}"
    echo -e "${YELLOW}Inicie o PeerSwap primeiro: sudo systemctl start peerswapd${NC}"
    echo ""
    return 1
  fi
  
  # Check if already running
  if sudo systemctl is-active --quiet psweb; then
    echo -e "${YELLOW}ℹ️  PeerSwap Web já está em execução${NC}"
    echo ""
    local_ip=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}🌐 Interface disponível em:${NC}"
    echo -e "   ${BLUE}http://${local_ip}:1984${NC}"
    echo ""
    return 0
  fi

  echo -e "${BLUE}▶️  Iniciando serviço...${NC}"
  sudo systemctl start psweb
  
  # Wait for service to start
  echo -e "${YELLOW}⏳ Aguardando inicialização...${NC}"
  sleep 5
  
  if sudo systemctl is-active --quiet psweb; then
    echo -e "${GREEN}✓ PeerSwap Web iniciado com sucesso!${NC}"
    echo ""
    
    local_ip=$(hostname -I | awk '{print $1}')
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   PeerSwap Web UI disponível!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}🌐 Acesse via navegador:${NC}"
    echo -e "   ${BLUE}http://${local_ip}:1984${NC}"
    echo ""
    echo -e "${YELLOW}💡 Dica: Configure o firewall se necessário:${NC}"
    echo -e "   ${BLUE}sudo ufw allow 1984/tcp${NC}"
    echo ""
  else
    echo -e "${RED}❌ Falha ao iniciar PeerSwap Web!${NC}"
    echo ""
    echo -e "${YELLOW}Verificando logs:${NC}"
    sudo journalctl -u psweb -n 20 --no-pager
    return 1
  fi
}

show_peerswap_status() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        📊 STATUS DO PEERSWAP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check service status
  if sudo systemctl is-active --quiet peerswapd; then
    echo -e "   ${GREEN}●${NC} Serviço: ${GREEN}Ativo${NC}"
  else
    echo -e "   ${RED}●${NC} Serviço: ${RED}Inativo${NC}"
    echo ""
    return 1
  fi
  
  # Check if pscli is available
  if [[ -f "/home/peerswap/go/bin/pscli" ]]; then
    echo -e "   ${GREEN}●${NC} CLI: ${GREEN}Disponível${NC}"
    echo ""
    
    # Try to get info from pscli
    if timeout 5 sudo -u peerswap /home/peerswap/go/bin/pscli listpeers; then
      local peers=$(sudo -u peerswap /home/peerswap/go/bin/pscli listpeers | grep -c '"node_id"' || echo "0")
      echo -e "${CYAN}Informações:${NC}"
      echo -e "   ${BLUE}Peers:${NC}       $peers"
    else
      echo -e "${YELLOW}⚠️  Aguardando conexão com daemon...${NC}"
    fi
  else
    echo -e "   ${YELLOW}●${NC} CLI: ${YELLOW}Não encontrado${NC}"
  fi
  
  # Check PeerSwap Web if installed
  if sudo systemctl list-unit-files | grep -q psweb; then
    echo ""
    echo -e "${CYAN}PeerSwap Web:${NC}"
    if sudo systemctl is-active --quiet psweb; then
      local_ip=$(hostname -I | awk '{print $1}')
      echo -e "   ${GREEN}●${NC} Status: ${GREEN}Ativo${NC}"
      echo -e "   ${BLUE}URL:${NC}    http://${local_ip}:1984"
    else
      echo -e "   ${RED}●${NC} Status: ${RED}Inativo${NC}"
    fi
  fi
  
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

create_elements_wallet_for_peerswap() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        👛 CONFIGURAR WALLET PEERSWAP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if Elements is running
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${RED}❌ Elements não está em execução!${NC}"
    echo -e "${YELLOW}Inicie o Elements primeiro: sudo systemctl start elementsd${NC}"
    echo ""
    return 1
  fi

  # Check if RPC is available
  if ! timeout 5 elements-cli -datadir=/data/elements getnetworkinfo; then
    echo -e "${RED}❌ Elements RPC não está disponível${NC}"
    echo -e "${YELLOW}Aguarde a inicialização do Elements${NC}"
    echo ""
    return 1
  fi

  # Check if wallet already exists
  if elements-cli -datadir=/data/elements listwallets | grep -q '"peerswap"'; then
    echo -e "${GREEN}✓ Wallet 'peerswap' já existe${NC}"
  else
    echo -e "${BLUE}💼 Criando wallet 'peerswap'...${NC}"
    
    if elements-cli -datadir=/data/elements createwallet "peerswap" false false "" false false true; then
      echo -e "${GREEN}✓ Wallet 'peerswap' criada com sucesso!${NC}"
    else
      echo -e "${RED}❌ Erro ao criar wallet${NC}"
      return 1
    fi
  fi
  echo ""

  # Generate address for the wallet
  echo -e "${BLUE}🏠 Gerando endereço L-BTC...${NC}"
  local address=$(elements-cli -datadir=/data/elements -rpcwallet=peerswap getnewaddress)
  if [[ -n "$address" ]]; then
    echo -e "${GREEN}✓ Endereço gerado:${NC}"
    echo ""
    echo -e "   ${YELLOW}$address${NC}"
    echo ""
  fi

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Wallet PeerSwap configurada!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}💡 Envie L-BTC para este endereço para começar a usar swaps${NC}"
  echo ""
}

stop_peerswap() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}        ⏹️  PARANDO PEERSWAP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  if ! sudo systemctl is-active --quiet peerswapd; then
    echo -e "${YELLOW}ℹ️  PeerSwap já está parado${NC}"
    echo ""
    return 0
  fi
  
  echo -e "${BLUE}⏸️  Parando serviços...${NC}"
  sudo systemctl stop peerswapd
  
  # Also stop psweb if running
  if sudo systemctl is-active --quiet psweb; then
    sudo systemctl stop psweb
  fi
  
  # Wait for service to stop
  sleep 3
  
  if ! sudo systemctl is-active --quiet peerswapd; then
    echo -e "${GREEN}✓ PeerSwap parado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao parar PeerSwap${NC}"
    return 1
  fi
  
  echo ""
}

# Menu PeerSwap
peerswap_menu() {
  while true; do
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}        🔄 PEERSWAP MANAGEMENT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}1)${NC} Instalar PeerSwap"
    echo -e "  ${BLUE}2)${NC} Configurar PeerSwap"
    echo -e "  ${BLUE}3)${NC} Criar Serviço Systemd"
    echo -e "  ${BLUE}4)${NC} Configurar Wallet Elements"
    echo -e "  ${BLUE}5)${NC} Iniciar PeerSwap"
    echo -e "  ${BLUE}6)${NC} Status PeerSwap"
    echo -e "  ${BLUE}7)${NC} Parar PeerSwap"
    echo ""
    echo -e "  ${CYAN}Web Interface:${NC}"
    echo -e "  ${BLUE}8)${NC} Instalar PeerSwap Web"
    echo -e "  ${BLUE}9)${NC} Criar Serviço PeerSwap Web"
    echo -e "  ${BLUE}10)${NC} Iniciar PeerSwap Web"
    echo ""
    echo -e "  ${BLUE}0)${NC} Voltar"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Escolha uma opção: " option

    case $option in
      1) install_peerswap ;;
      2) configure_peerswap ;;
      3) create_peerswap_service ;;
      4) create_elements_wallet_for_peerswap ;;
      5) start_peerswap ;;
      6) show_peerswap_status ;;
      7) stop_peerswap ;;
      8) install_psweb ;;
      9) create_psweb_service ;;
      10) start_psweb ;;
      0) break ;;
      *) echo -e "${RED}❌ Opção inválida!${NC}" ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para continuar..."
  done
}

# Export functions
export -f install_peerswap
export -f install_go
export -f configure_peerswap
export -f create_peerswap_service
export -f install_psweb
# export -f configure_psweb  # Function not needed - psweb auto-configures
export -f create_psweb_service
export -f start_peerswap
export -f start_psweb
export -f show_peerswap_status
export -f create_elements_wallet_for_peerswap
export -f stop_peerswap
export -f peerswap_menu

# ============================================================================
# RESUMO DO SCRIPT PEERSWAP.SH
# ============================================================================
#
# DESCRIÇÃO:
# - Automatiza instalação, configuração e gerenciamento do PeerSwap (daemons de
#   swap entre Bitcoin/Elements) e sua interface web (psweb).
#
# FUNCIONALIDADES PRINCIPAIS:
# - install_peerswap(): Clona e compila o PeerSwap, configura usuário e dependências
# - configure_peerswap(): Gera peerswap.conf com caminhos para tls + macaroons
# - start/stop/status/service creation: Integra com systemd e psweb
#
# USO:
# - Executar para habilitar swaps líquidos e componentes relacionados no BRLN-OS
#
# ============================================================================
