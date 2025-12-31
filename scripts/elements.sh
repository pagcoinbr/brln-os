#!/bin/bash
# Elements Core Installation Script
# BRLN-OS Elements Configuration and Management
# Based on: https://brlnbtc.substack.com/p/elements-peerswap-e-psweb-guia-pratico

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source required configurations
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/utils.sh"

# Elements version
ELEMENTS_VERSION="23.3.1"

install_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}      🔥 INSTALAÇÃO DO ELEMENTS CORE v${ELEMENTS_VERSION}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if already installed
  if command -v elementsd &> /dev/null; then
    echo -e "${YELLOW}⚠️  Elements já está instalado:${NC}"
    elementsd --version | head -n1
    echo ""
    read -p "Deseja reinstalar? (s/n): " reinstall
    if [[ "$reinstall" != "s" && "$reinstall" != "S" ]]; then
      echo -e "${BLUE}Instalação cancelada.${NC}"
      return 0
    fi
  fi

  # Create elements user if doesn't exist
  if ! id "elements" &>/dev/null; then
    echo -e "${BLUE}👤 Criando usuário 'elements'...${NC}"
    sudo adduser --disabled-password --gecos "" elements
    echo -e "${GREEN}✓ Usuário 'elements' criado${NC}"
    echo ""
  fi

  # Create data directory (~20GB needed)
  echo -e "${BLUE}📁 Criando diretório para blockchain (~20GB necessários)...${NC}"
  sudo mkdir -p /data/elements
  sudo chown -R elements:elements /data/elements
  echo -e "${GREEN}✓ Diretório /data/elements criado${NC}"
  echo ""

  # Detect architecture
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)
      ELEMENTS_ARCH="x86_64-linux-gnu"
      ;;
    aarch64|arm64)
      ELEMENTS_ARCH="aarch64-linux-gnu"
      ;;
    armv7l|armhf)
      ELEMENTS_ARCH="arm-linux-gnueabihf"
      ;;
    *)
      echo -e "${RED}❌ Arquitetura não suportada: $ARCH${NC}"
      echo -e "${YELLOW}Arquiteturas suportadas: x86_64, aarch64, armv7l${NC}"
      return 1
      ;;
  esac
  
  echo -e "${BLUE}🖥️  Arquitetura detectada: ${YELLOW}$ARCH${BLUE} → ${YELLOW}$ELEMENTS_ARCH${NC}"
  echo ""

  # Download binaries
  echo -e "${BLUE}📥 Baixando Elements Core v${ELEMENTS_VERSION}...${NC}"
  cd /tmp || return 1
  
  # Clean previous downloads
  rm -f elements-${ELEMENTS_VERSION}-*.tar.gz SHA256SUMS.asc || true
  
  # Download binary
  if ! wget -q --show-progress "https://github.com/ElementsProject/elements/releases/download/elements-${ELEMENTS_VERSION}/elements-${ELEMENTS_VERSION}-${ELEMENTS_ARCH}.tar.gz"; then
    echo -e "${RED}❌ Erro ao baixar Elements${NC}"
    return 1
  fi
  echo -e "${GREEN}✓ Binário baixado${NC}"
  
  # Download checksums
  if ! wget -q "https://github.com/ElementsProject/elements/releases/download/elements-${ELEMENTS_VERSION}/SHA256SUMS.asc"; then
    echo -e "${RED}❌ Erro ao baixar checksums${NC}"
    return 1
  fi
  echo -e "${GREEN}✓ Checksums baixados${NC}"
  echo ""

  # Verify SHA256 checksum
  echo -e "${BLUE}🔍 Verificando checksum SHA256...${NC}"
  if sha256sum --ignore-missing --check SHA256SUMS.asc | grep -q "elements-${ELEMENTS_VERSION}-${ELEMENTS_ARCH}.tar.gz: OK"; then
    echo -e "${GREEN}✓ Checksum SHA256 verificado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Falha na verificação do checksum SHA256!${NC}"
    return 1
  fi
  echo ""

  # Import GPG key for verification
  echo -e "${BLUE}🔐 Importando chave GPG do desenvolvedor...${NC}"
  # Key: BD0F3062F87842410B06A0432F656B0610604482 (Elements Project)
  if gpg --keyserver keyserver.ubuntu.com --recv-keys BD0F3062F87842410B06A0432F656B0610604482; then
    echo -e "${GREEN}✓ Chave GPG importada${NC}"
  else
    echo -e "${YELLOW}⚠️  Aviso: Não foi possível importar a chave GPG${NC}"
  fi
  echo ""

  # Verify GPG signature
  echo -e "${BLUE}🔏 Verificando assinatura GPG...${NC}"
  if gpg --verify SHA256SUMS.asc 2>&1 | grep -q "Good signature"; then
    echo -e "${GREEN}✓ Assinatura GPG verificada com sucesso!${NC}"
  else
    echo -e "${YELLOW}⚠️  Aviso: Não foi possível verificar a assinatura GPG${NC}"
    read -p "Deseja continuar mesmo assim? (s/n): " continue_anyway
    if [[ "$continue_anyway" != "s" && "$continue_anyway" != "S" ]]; then
      echo -e "${RED}Instalação cancelada.${NC}"
      return 1
    fi
  fi
  echo ""

  # Extract binaries
  echo -e "${BLUE}📦 Extraindo binários...${NC}"
  if tar -xzf "elements-${ELEMENTS_VERSION}-${ELEMENTS_ARCH}.tar.gz"; then
    echo -e "${GREEN}✓ Binários extraídos${NC}"
  else
    echo -e "${RED}❌ Erro ao extrair binários${NC}"
    return 1
  fi
  echo ""

  # Install binaries
  echo -e "${BLUE}💿 Instalando binários...${NC}"
  sudo install -m 0755 -o root -g root -t /usr/local/bin \
    "elements-${ELEMENTS_VERSION}/bin/elementsd" \
    "elements-${ELEMENTS_VERSION}/bin/elements-cli"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Binários instalados em /usr/local/bin${NC}"
  else
    echo -e "${RED}❌ Erro ao instalar binários${NC}"
    return 1
  fi
  echo ""

  # Cleanup
  rm -rf elements-${ELEMENTS_VERSION}* SHA256SUMS.asc

  # Verify installation
  echo -e "${BLUE}✅ Verificando instalação...${NC}"
  if elementsd --version; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}   Elements Core ${ELEMENTS_VERSION} instalado com sucesso!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
  else
    echo -e "${RED}❌ Erro na instalação do Elements${NC}"
    return 1
  fi
}

configure_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        ⚙️  CONFIGURAÇÃO DO ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Ensure data directory exists
  sudo mkdir -p /data/elements
  sudo chown -R elements:elements /data/elements
  
  # Create symbolic link from elements home to data directory
  echo -e "${BLUE}🔗 Criando link simbólico...${NC}"
  sudo -u elements ln -sf /data/elements /home/elements/.elements 2>/dev/null || true
  echo -e "${GREEN}✓ Link: /home/elements/.elements → /data/elements${NC}"
  echo ""

  # Generate RPC credentials
  echo -e "${BLUE}🔐 Gerando credenciais RPC...${NC}"
  elements_rpc_user="elements"
  elements_rpc_pass=$(openssl rand -base64 32)
  echo -e "${GREEN}✓ Credenciais geradas${NC}"
  echo ""

  # Get local network for rpcallowip
  local_network=$(ip route | grep 'scope link' | awk '{print $1}' | head -n1)
  if [[ -z "$local_network" ]]; then
    local_network="192.168.1.0/24"
  fi

  # Create configuration file
  echo -e "${BLUE}📝 Criando arquivo de configuração...${NC}"
  sudo tee /data/elements/elements.conf > /dev/null << EOF
# Configuração mínima para Elements/Liquid Mainnet
chain=liquidv1
daemon=0
server=1
listen=1
txindex=1
validatepegin=1

# Asset directories (opcional - para rastreamento específico de ativos)
assetdir=02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189:DePix
assetdir=ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2:USDT

# RPC local Elements
rpcuser=${elements_rpc_user}
rpcpassword=${elements_rpc_pass}
rpcport=7041
rpcallowip=${local_network}
rpcbind=0.0.0.0

# RPC conexão remota com Bitcoin Core (opcional - descomente se necessário)
# mainchainrpchost=bitcoin.br-ln.com
# mainchainrpcport=8085
# mainchainrpcuser=
# mainchainrpcpassword=

# Fees
fallbackfee=0.00001

# Data directory
datadir=/data/elements
EOF

  # Set permissions
  echo -e "${BLUE}🔒 Ajustando permissões...${NC}"
  sudo chown elements:elements /data/elements/elements.conf
  sudo chmod 600 /data/elements/elements.conf
  echo -e "${GREEN}✓ Permissões ajustadas (600)${NC}"
  echo ""

  # Store credentials in password manager
  echo -e "${BLUE}💾 Armazenando credenciais no gerenciador de senhas...${NC}"
  source "$SCRIPT_DIR/brln-tools/password_manager.sh"
  
  store_password_full "elements_rpc_user" "$elements_rpc_user" "Elements Core - RPC Username" "elements" 7041 "http://localhost:7041"
  store_password_full "elements_rpc_password" "$elements_rpc_pass" "Elements Core - RPC Password" "elements" 7041 "http://localhost:7041"
  
  echo -e "${GREEN}✓ Credenciais armazenadas no gerenciador de senhas${NC}"
  echo ""

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Elements Core configurado com sucesso!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Informações de configuração:${NC}"
  echo -e "   ${BLUE}Arquivo de config:${NC} /data/elements/elements.conf"
  echo -e "   ${BLUE}RPC Port:${NC} 7041"
  echo -e "   ${BLUE}P2P Port:${NC} 7042 (padrão)"
  echo -e "   ${BLUE}Chain:${NC} liquidv1 (Liquid Mainnet)"
  echo ""
  echo -e "${YELLOW}💡 Dica: Use o gerenciador de senhas para acessar as credenciais${NC}"
  echo ""
}

create_elements_service() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🔧 CRIANDO SERVIÇO SYSTEMD${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  echo -e "${BLUE}📄 Criando arquivo de serviço...${NC}"
  sudo tee /etc/systemd/system/elementsd.service > /dev/null << 'EOF'
[Unit]
Description=Elements daemon on mainnet
# Requires=bitcoind.service
# After=bitcoind.service

[Service]
ExecStart=/usr/local/bin/elementsd -datadir=/data/elements/
User=elements
Group=elements
Restart=on-failure
TimeoutStartSec=infinity
TimeoutStopSec=600

PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

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
  sudo systemctl enable elementsd
  echo -e "${GREEN}✓ Serviço habilitado${NC}"
  echo ""

  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Serviço systemd criado e habilitado!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${CYAN}📋 Comandos úteis:${NC}"
  echo -e "   ${BLUE}Iniciar:${NC}    sudo systemctl start elementsd"
  echo -e "   ${BLUE}Parar:${NC}      sudo systemctl stop elementsd"
  echo -e "   ${BLUE}Status:${NC}     sudo systemctl status elementsd"
  echo -e "   ${BLUE}Logs:${NC}       journalctl -u elementsd -f"
  echo ""
}

start_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        🚀 INICIANDO ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if already running
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${YELLOW}ℹ️  Elements já está em execução${NC}"
    echo ""
    show_elements_status
    return 0
  fi

  echo -e "${BLUE}▶️  Iniciando serviço...${NC}"
  sudo systemctl start elementsd
  
  # Wait for service to start
  echo -e "${YELLOW}⏳ Aguardando inicialização...${NC}"
  sleep 5
  
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✓ Elements iniciado com sucesso!${NC}"
    echo ""
    show_elements_status
  else
    echo -e "${RED}❌ Falha ao iniciar Elements!${NC}"
    echo ""
    echo -e "${YELLOW}Verificando logs:${NC}"
    sudo journalctl -u elementsd -n 20 --no-pager
    return 1
  fi
}

show_elements_status() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        📊 STATUS DO ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check service status
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "   ${GREEN}●${NC} Serviço: ${GREEN}Ativo${NC}"
  else
    echo -e "   ${RED}●${NC} Serviço: ${RED}Inativo${NC}"
    echo ""
    return 1
  fi
  
  # Check if elements-cli is available
  if ! command -v elements-cli &> /dev/null; then
    echo -e "${YELLOW}⚠️  elements-cli não encontrado${NC}"
    echo ""
    return 1
  fi
  
  # Try to connect to RPC
  if timeout 5 elements-cli -datadir=/data/elements getnetworkinfo; then
    echo -e "   ${GREEN}●${NC} RPC: ${GREEN}Conectado${NC}"
    echo ""
    
    # Get network info
    local chain=$(elements-cli -datadir=/data/elements getblockchaininfo | grep '"chain"' | cut -d'"' -f4)
    local blocks=$(elements-cli -datadir=/data/elements getblockcount)
    local connections=$(elements-cli -datadir=/data/elements getconnectioncount)
    local network_info=$(elements-cli -datadir=/data/elements getnetworkinfo)
    local version=$(echo "$network_info" | grep '"version"' | head -n1 | grep -o '[0-9]*')
    
    echo -e "${CYAN}Informações da Rede:${NC}"
    echo -e "   ${BLUE}Chain:${NC}       $chain"
    echo -e "   ${BLUE}Blocos:${NC}      $blocks"
    echo -e "   ${BLUE}Conexões:${NC}    $connections"
    echo -e "   ${BLUE}Versão:${NC}      ${version:-N/A}"
    echo ""
    
    # Check wallet status
    if elements-cli -datadir=/data/elements getwalletinfo; then
      local balance=$(elements-cli -datadir=/data/elements getbalance | head -n1)
      echo -e "${CYAN}Wallet:${NC}"
      echo -e "   ${BLUE}Status:${NC}      ${GREEN}Carregada${NC}"
      echo -e "   ${BLUE}Saldo L-BTC:${NC} ${balance:-0.00000000}"
    else
      echo -e "${CYAN}Wallet:${NC}"
      echo -e "   ${YELLOW}⚠️  Nenhuma wallet carregada${NC}"
    fi
    
  else
    echo -e "   ${YELLOW}●${NC} RPC: ${YELLOW}Aguardando conexão...${NC}"
    echo ""
    echo -e "${YELLOW}O daemon pode estar iniciando. Aguarde alguns segundos.${NC}"
  fi
  
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}
  

create_elements_wallet() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}        👛 CRIANDO WALLET ELEMENTS${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Check if RPC is available
  if ! timeout 5 elements-cli -datadir=/data/elements getnetworkinfo; then
    echo -e "${RED}❌ Elements RPC não está disponível${NC}"
    echo -e "${YELLOW}Certifique-se de que o Elements está em execução${NC}"
    echo ""
    return 1
  fi

  # Check if wallet already exists
  if elements-cli -datadir=/data/elements getwalletinfo; then
    echo -e "${GREEN}✓ Wallet já existe${NC}"
    echo ""
    
    # Show existing address
    echo -e "${BLUE}🏠 Gerando novo endereço L-BTC...${NC}"
    local address=$(elements-cli -datadir=/data/elements getnewaddress)
    if [[ -n "$address" ]]; then
      echo -e "${GREEN}✓ Endereço gerado:${NC}"
      echo ""
      echo -e "   ${YELLOW}$address${NC}"
      echo ""
    fi
  else
    # Create new wallet
    echo -e "${BLUE}💼 Criando wallet padrão...${NC}"
    
    if elements-cli -datadir=/data/elements createwallet "" false false "" false false true; then
      echo -e "${GREEN}✓ Wallet criada com sucesso!${NC}"
      echo ""
      
      # Generate address
      echo -e "${BLUE}🏠 Gerando endereço L-BTC...${NC}"
      local address=$(elements-cli -datadir=/data/elements getnewaddress)
      if [[ -n "$address" ]]; then
        echo -e "${GREEN}✓ Endereço gerado:${NC}"
        echo ""
        echo -e "   ${YELLOW}$address${NC}"
        echo ""
      fi
    else
      echo -e "${RED}❌ Erro ao criar wallet${NC}"
      return 1
    fi
  fi
  
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

stop_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}        ⏹️  PARANDO ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${YELLOW}ℹ️  Elements já está parado${NC}"
    echo ""
    return 0
  fi
  
  echo -e "${BLUE}⏸️  Parando serviço...${NC}"
  sudo systemctl stop elementsd
  
  # Wait for service to stop
  sleep 3
  
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✓ Elements parado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao parar Elements${NC}"
    return 1
  fi
  
  echo ""
}

restart_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}        🔄 REINICIANDO ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  echo -e "${BLUE}🔄 Reiniciando serviço...${NC}"
  sudo systemctl restart elementsd
  
  # Wait for restart
  echo -e "${YELLOW}⏳ Aguardando reinicialização...${NC}"
  sleep 5
  
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✓ Elements reiniciado com sucesso!${NC}"
    echo ""
    show_elements_status
  else
    echo -e "${RED}❌ Erro ao reiniciar Elements${NC}"
    return 1
  fi
}

uninstall_elements() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}        🗑️  DESINSTALAR ELEMENTS CORE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  echo -e "${RED}⚠️  ATENÇÃO: Esta operação removerá o Elements Core${NC}"
  echo ""
  read -p "Tem certeza que deseja continuar? (s/N): " confirm
  
  if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo -e "${BLUE}Operação cancelada.${NC}"
    echo ""
    return 0
  fi

  # Stop service
  echo -e "${BLUE}⏸️  Parando serviço...${NC}"
  sudo systemctl stop elementsd || true
  sudo systemctl disable elementsd || true
  echo -e "${GREEN}✓ Serviço parado${NC}"
  
  # Remove service file
  echo -e "${BLUE}🗑️  Removendo arquivo de serviço...${NC}"
  sudo rm -f /etc/systemd/system/elementsd.service
  sudo systemctl daemon-reload
  echo -e "${GREEN}✓ Arquivo de serviço removido${NC}"
  
  # Remove binaries
  echo -e "${BLUE}🗑️  Removendo binários...${NC}"
  sudo rm -f /usr/local/bin/elementsd
  sudo rm -f /usr/local/bin/elements-cli
  echo -e "${GREEN}✓ Binários removidos${NC}"
  echo ""
  
  # Ask about data removal
  echo -e "${YELLOW}Os dados da blockchain estão em /data/elements${NC}"
  read -p "Deseja remover também os dados da blockchain? (s/N): " remove_data
  
  if [[ "$remove_data" == "s" || "$remove_data" == "S" ]]; then
    echo -e "${BLUE}🗑️  Removendo dados...${NC}"
    sudo rm -rf /data/elements
    sudo userdel -r elements || true
    echo -e "${GREEN}✓ Dados e usuário removidos${NC}"
  else
    echo -e "${YELLOW}Dados preservados em /data/elements${NC}"
  fi

  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Elements Core removido!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

# Menu Elements
elements_menu() {
  while true; do
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}        🔥 ELEMENTS CORE MANAGEMENT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BLUE}1)${NC} Instalar Elements Core"
    echo -e "  ${BLUE}2)${NC} Configurar Elements"
    echo -e "  ${BLUE}3)${NC} Criar Serviço Systemd"
    echo -e "  ${BLUE}4)${NC} Iniciar Elements"
    echo -e "  ${BLUE}5)${NC} Status Elements"
    echo -e "  ${BLUE}6)${NC} Criar Wallet"
    echo -e "  ${BLUE}7)${NC} Parar Elements"
    echo -e "  ${BLUE}8)${NC} Reiniciar Elements"
    echo -e "  ${BLUE}9)${NC} Desinstalar Elements"
    echo ""
    echo -e "  ${BLUE}0)${NC} Voltar"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Escolha uma opção: " option

    case $option in
      1) install_elements ;;
      2) configure_elements ;;
      3) create_elements_service ;;
      4) start_elements ;;
      5) show_elements_status ;;
      6) create_elements_wallet ;;
      7) stop_elements ;;
      8) restart_elements ;;
      9) uninstall_elements ;;
      0) break ;;
      *) echo -e "${RED}❌ Opção inválida!${NC}" ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para continuar..."
  done
}

# Export functions
export -f install_elements
export -f configure_elements
export -f create_elements_service
export -f start_elements
export -f show_elements_status
export -f create_elements_wallet
export -f stop_elements
export -f restart_elements
export -f uninstall_elements
export -f elements_menu