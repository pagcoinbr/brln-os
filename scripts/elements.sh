#!/bin/bash
# Elements Core Installation Script
# BRLN-OS Elements Configuration and Management
# Based on: https://brlnbtc.substack.com/p/elements-peerswap-e-psweb-guia-pratico

# Source required configurations
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Elements version
ELEMENTS_VERSION="23.2.1"

install_elements() {
  echo -e "${GREEN}🔥 Instalando Elements Core...${NC}"
  
  # Verificar se já está instalado
  if command -v elementsd &> /dev/null; then
    echo -e "${YELLOW}⚠️ Elements já está instalado. Versão:${NC}"
    elementsd --version | head -n1
    read -p "Deseja reinstalar? (y/n): " reinstall
    if [[ "$reinstall" != "y" ]]; then
      return 0
    fi
  fi

  app="Elements Core"
  
  # Criar usuário elements se não existir
  if ! id "elements" &>/dev/null; then
    echo "👤 Criando usuário elements..."
    sudo adduser --disabled-password --gecos "" elements
  fi

  # Criar diretórios de dados
  echo "📁 Criando diretórios de dados..."
  sudo mkdir -p /data/elements
  sudo chown elements:elements /data/elements

  # Instalar dependências
  echo "📦 Instalando dependências..."
  sudo apt update >> /dev/null 2>&1 & spinner
  sudo apt install -y build-essential libtool autotools-dev automake \
    pkg-config bsdmainutils python3 libssl-dev libevent-dev \
    libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
    libboost-program-options-dev libboost-test-dev libboost-thread-dev \
    libdb-dev libdb++-dev libminiupnpc-dev libzmq3-dev \
    git wget curl >> /dev/null 2>&1 & spinner

  # Download Elements Core
  echo "⬇️ Baixando Elements Core v$ELEMENTS_VERSION..."
  cd /tmp
  
  # Verificar arquitetura
  ARCH=$(uname -m)
  if [[ "$ARCH" == "x86_64" ]]; then
    ELEMENTS_ARCH="x86_64-linux-gnu"
  elif [[ "$ARCH" == "aarch64" ]]; then
    ELEMENTS_ARCH="aarch64-linux-gnu"
  else
    echo -e "${RED}❌ Arquitetura não suportada: $ARCH${NC}"
    return 1
  fi

  # Baixar e verificar
  wget -q "https://github.com/ElementsProject/elements/releases/download/elements-$ELEMENTS_VERSION/elements-$ELEMENTS_VERSION-$ELEMENTS_ARCH.tar.gz" \
    || { echo -e "${RED}❌ Erro ao baixar Elements${NC}"; return 1; }
  
  wget -q "https://github.com/ElementsProject/elements/releases/download/elements-$ELEMENTS_VERSION/SHA256SUMS.asc" \
    || { echo -e "${RED}❌ Erro ao baixar checksums${NC}"; return 1; }

  # Verificar checksum
  echo "🔍 Verificando integridade do arquivo..."
  if ! sha256sum --ignore-missing --check SHA256SUMS.asc 2>/dev/null | grep -q "elements-$ELEMENTS_VERSION-$ELEMENTS_ARCH.tar.gz: OK"; then
    echo -e "${RED}❌ Verificação de integridade falhou!${NC}"
    return 1
  fi

  # Extrair e instalar
  echo "📦 Extraindo e instalando Elements..."
  tar -xzf "elements-$ELEMENTS_VERSION-$ELEMENTS_ARCH.tar.gz"
  
  # Instalar binários
  sudo install -m 0755 -o root -g root -t /usr/local/bin \
    "elements-$ELEMENTS_VERSION/bin/elementsd" \
    "elements-$ELEMENTS_VERSION/bin/elements-cli" \
    "elements-$ELEMENTS_VERSION/bin/elements-tx"

  # Cleanup
  rm -rf elements-$ELEMENTS_VERSION* SHA256SUMS.asc

  echo -e "${GREEN}✅ Elements Core instalado com sucesso!${NC}"
  elementsd --version | head -n1
}

configure_elements() {
  echo -e "${GREEN}⚙️ Configurando Elements Core...${NC}"

  # Criar arquivo de configuração
  echo "📝 Criando arquivo de configuração..."
  sudo mkdir -p /data/elements
  
  # Configuração baseada no tutorial BRLN
  sudo tee /data/elements/elements.conf > /dev/null << EOF
# Elements Configuration
# Network
chain=liquidv1
daemon=1
server=1
listen=1
listenonion=0

# RPC Configuration
rpcuser=elements
rpcpassword=$(openssl rand -base64 32)
rpcbind=127.0.0.1
rpcport=7041
rpcallowip=127.0.0.1

# Data Directory
datadir=/data/elements

# Wallet Configuration  
fallbackfee=0.00001000
mintxfee=0.00000100

# P2P Network
port=7042
connect=0
addnode=node1.liquid.network:7042
addnode=node2.liquid.network:7042

# Logging
debug=0
logtimestamps=1

# Performance
dbcache=512
maxmempool=512

# Security
disablewallet=0
walletnotify=
blocknotify=

# Elements Specific
validatepegin=1
initialfreecoins=0
signblockscript=
fedpegscript=
pak=
EOF

  # Ajustar permissões
  sudo chown elements:elements /data/elements/elements.conf
  sudo chmod 600 /data/elements/elements.conf

  echo -e "${GREEN}✅ Configuração criada!${NC}"
}

create_elements_service() {
  echo -e "${GREEN}🔧 Criando serviço systemd...${NC}"
  
  # Criar arquivo de serviço
  sudo tee /etc/systemd/system/elementsd.service > /dev/null << EOF
[Unit]
Description=Elements Core daemon
Documentation=https://github.com/ElementsProject/elements
After=network.target
Wants=network.target

[Service]
Type=notify
ExecStart=/usr/local/bin/elementsd -conf=/data/elements/elements.conf -datadir=/data/elements -daemon=0
ExecReload=/bin/kill -HUP \$MAINPID
TimeoutStopSec=60
TimeoutStartSec=15
Restart=always
RestartSec=30
User=elements
Group=elements

# Process management
KillMode=mixed
KillSignal=SIGTERM

# Security measures
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

# Directory creation and permissions
RuntimeDirectory=elementsd
RuntimeDirectoryMode=0710

[Install]
WantedBy=multi-user.target
EOF

  # Habilitar e iniciar serviço
  sudo systemctl daemon-reload
  sudo systemctl enable elementsd
  
  echo -e "${GREEN}✅ Serviço criado e habilitado!${NC}"
}

start_elements() {
  echo -e "${GREEN}🚀 Iniciando Elements Core...${NC}"
  
  # Verificar se já está rodando
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${YELLOW}ℹ️ Elements já está rodando${NC}"
    return 0
  fi

  sudo systemctl start elementsd
  
  # Aguardar inicialização
  echo -e "${YELLOW}⏳ Aguardando sincronização inicial...${NC}"
  sleep 10
  
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✅ Elements iniciado com sucesso!${NC}"
    
    # Mostrar status
    show_elements_status
  else
    echo -e "${RED}❌ Falha ao iniciar Elements!${NC}"
    echo "Verifique os logs: journalctl -u elementsd -f"
    return 1
  fi
}

show_elements_status() {
  echo -e "${BLUE}📊 Status do Elements Core:${NC}"
  
  # Informações básicas
  if command -v elements-cli &> /dev/null; then
    echo "📡 Conectividade:"
    if timeout 5 elements-cli -conf=/data/elements/elements.conf getnetworkinfo >/dev/null 2>&1; then
      echo -e "   ${GREEN}✅ RPC conectado${NC}"
      
      # Info da blockchain
      local blocks=$(elements-cli -conf=/data/elements/elements.conf getblockcount 2>/dev/null || echo "N/A")
      local connections=$(elements-cli -conf=/data/elements/elements.conf getconnectioncount 2>/dev/null || echo "N/A")
      
      echo "🔗 Conexões: $connections"
      echo "📦 Blocos: $blocks"
      
      # Status da wallet
      if elements-cli -conf=/data/elements/elements.conf getwalletinfo >/dev/null 2>&1; then
        local balance=$(elements-cli -conf=/data/elements/elements.conf getbalance 2>/dev/null || echo "0.00")
        echo "💰 Saldo L-BTC: $balance"
      else
        echo -e "   ${YELLOW}⚠️ Wallet não carregada${NC}"
      fi
      
    else
      echo -e "   ${RED}❌ RPC não responde${NC}"
    fi
  fi
  
  # Status do serviço
  echo "🔧 Serviço:"
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "   ${GREEN}✅ Ativo${NC}"
  else
    echo -e "   ${RED}❌ Inativo${NC}"
  fi
}

create_elements_wallet() {
  echo -e "${GREEN}👛 Criando wallet Elements...${NC}"
  
  # Verificar se RPC está disponível
  if ! timeout 5 elements-cli -conf=/data/elements/elements.conf getnetworkinfo >/dev/null 2>&1; then
    echo -e "${RED}❌ Elements RPC não está disponível${NC}"
    return 1
  fi

  # Criar wallet padrão se não existir
  if ! elements-cli -conf=/data/elements/elements.conf getwalletinfo >/dev/null 2>&1; then
    echo "💼 Criando wallet padrão..."
    
    if elements-cli -conf=/data/elements/elements.conf createwallet "" false false "" false false true >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Wallet criada com sucesso!${NC}"
    else
      echo -e "${RED}❌ Erro ao criar wallet${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✅ Wallet já existe${NC}"
  fi

  # Gerar novo endereço
  echo "🏠 Gerando endereço L-BTC..."
  local address=$(elements-cli -conf=/data/elements/elements.conf getnewaddress 2>/dev/null)
  if [[ -n "$address" ]]; then
    echo -e "${BLUE}📬 Endereço L-BTC: ${YELLOW}$address${NC}"
  fi
}

stop_elements() {
  echo -e "${YELLOW}⏹️ Parando Elements Core...${NC}"
  sudo systemctl stop elementsd
  
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✅ Elements parado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao parar Elements${NC}"
    return 1
  fi
}

restart_elements() {
  echo -e "${YELLOW}🔄 Reiniciando Elements Core...${NC}"
  sudo systemctl restart elementsd
  sleep 5
  
  if sudo systemctl is-active --quiet elementsd; then
    echo -e "${GREEN}✅ Elements reiniciado com sucesso!${NC}"
    show_elements_status
  else
    echo -e "${RED}❌ Erro ao reiniciar Elements${NC}"
    return 1
  fi
}

uninstall_elements() {
  echo -e "${YELLOW}🗑️ Removendo Elements Core...${NC}"
  
  read -p "Tem certeza que deseja remover o Elements Core? (y/N): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Operação cancelada."
    return 0
  fi

  # Parar serviço
  sudo systemctl stop elementsd 2>/dev/null || true
  sudo systemctl disable elementsd 2>/dev/null || true
  
  # Remover arquivos de serviço
  sudo rm -f /etc/systemd/system/elementsd.service
  sudo systemctl daemon-reload
  
  # Remover binários
  sudo rm -f /usr/local/bin/elementsd
  sudo rm -f /usr/local/bin/elements-cli  
  sudo rm -f /usr/local/bin/elements-tx
  
  # Remover dados (opcional)
  read -p "Remover também os dados da blockchain? (y/N): " remove_data
  if [[ "$remove_data" == "y" ]]; then
    sudo rm -rf /data/elements
    sudo userdel elements 2>/dev/null || true
  fi

  echo -e "${GREEN}✅ Elements removido!${NC}"
}

# Menu Elements
elements_menu() {
  while true; do
    echo
    echo -e "${CYAN}🔥 Elements Core Management${NC}"
    echo "=========================="
    echo "1) Instalar Elements"
    echo "2) Configurar Elements" 
    echo "3) Criar Serviço"
    echo "4) Iniciar Elements"
    echo "5) Status Elements"
    echo "6) Criar Wallet"
    echo "7) Parar Elements"
    echo "8) Reiniciar Elements"
    echo "9) Desinstalar Elements"
    echo "0) Voltar"
    echo
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