#!/bin/bash
# PeerSwap & PeerSwap Web Installation Script
# BRLN-OS PeerSwap Configuration and Management

# Source required configurations
source "$(dirname "$0")/config.sh"
source "$(dirname "$0")/utils.sh"

# PeerSwap versions
PEERSWAP_VERSION="4.0"
PSWEB_VERSION="1.7.8"

install_peerswap() {
  echo -e "${GREEN}🔄 Instalando PeerSwap...${NC}"
  
  # Verificar se já está instalado
  if command -v peerswapd &> /dev/null; then
    echo -e "${YELLOW}⚠️ PeerSwap já está instalado. Versão:${NC}"
    peerswapd --version 2>/dev/null || echo "Versão não disponível"
    read -p "Deseja reinstalar? (y/n): " reinstall
    if [[ "$reinstall" != "y" ]]; then
      return 0
    fi
  fi

  app="PeerSwap"
  
  # Criar usuário peerswap se não existir
  if ! id "peerswap" &>/dev/null; then
    echo "👤 Criando usuário peerswap..."
    sudo adduser --disabled-password --gecos "" peerswap
  fi

  # Instalar dependências
  echo "📦 Instalando dependências..."
  sudo apt update >> /dev/null 2>&1 & spinner
  sudo apt install -y git build-essential golang-go >> /dev/null 2>&1 & spinner

  # Verificar versão do Go
  GO_VERSION=$(go version 2>/dev/null | grep -o 'go[0-9]\+\.[0-9]\+' | head -n1)
  if [[ -z "$GO_VERSION" ]] || [[ "${GO_VERSION#go}" < "1.19" ]]; then
    echo "📦 Instalando Go mais recente..."
    install_go
  fi

  # Criar diretórios
  echo "📁 Criando diretórios..."
  sudo mkdir -p /data/peerswap
  sudo chown peerswap:peerswap /data/peerswap

  # Compilar PeerSwap do código fonte
  echo "🔨 Compilando PeerSwap do código fonte..."
  cd /tmp
  
  # Clonar repositório
  git clone https://github.com/ElementsProject/peerswap.git
  cd peerswap
  
  # Checkout versão específica
  git checkout v$PEERSWAP_VERSION 2>/dev/null || git checkout main
  
  # Compilar
  echo "⚙️ Compilando binários..."
  make lnd-release >> /dev/null 2>&1 & spinner
  
  # Instalar binários
  sudo install -m 0755 -o root -g root -t /usr/local/bin \
    build/peerswapd-lnd \
    build/pscli-lnd
    
  # Criar links simbólicos
  sudo ln -sf /usr/local/bin/peerswapd-lnd /usr/local/bin/peerswapd
  sudo ln -sf /usr/local/bin/pscli-lnd /usr/local/bin/pscli

  # Cleanup
  cd /
  rm -rf /tmp/peerswap

  echo -e "${GREEN}✅ PeerSwap compilado e instalado com sucesso!${NC}"
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
  wget -q "https://golang.org/dl/go$GO_VERSION.linux-$GO_ARCH.tar.gz"
  
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
  echo -e "${GREEN}⚙️ Configurando PeerSwap...${NC}"

  # Criar arquivo de configuração
  echo "📝 Criando arquivo de configuração..."
  sudo mkdir -p /data/peerswap
  
  # Configuração PeerSwap
  sudo tee /data/peerswap/peerswap.conf > /dev/null << EOF
# PeerSwap Configuration

# LND Connection
lnd.host=localhost:10009
lnd.tlscertpath=/data/lnd/tls.cert
lnd.macaroonpath=/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon

# Elements Connection (if available)
elementsd.rpchost=localhost
elementsd.rpcport=7041
elementsd.rpcuser=elements
elementsd.rpcpassword=$(grep rpcpassword /data/elements/elements.conf 2>/dev/null | cut -d'=' -f2 || echo "changeme")
elementsd.rpcwallet=peerswap

# PeerSwap Settings
datadir=/data/peerswap
network=mainnet
resthost=localhost
restport=42069

# Policy Settings
policy.reserve_onchain_msat=100000000
policy.reserve_channel_msat=100000000
policy.min_swap_amount_msat=10000000
policy.max_swap_amount_msat=1000000000

# Logging
loglevel=info
logfile=/data/peerswap/peerswap.log
EOF

  # Ajustar permissões
  sudo chown peerswap:peerswap /data/peerswap/peerswap.conf
  sudo chmod 600 /data/peerswap/peerswap.conf

  echo -e "${GREEN}✅ Configuração criada!${NC}"
}

create_peerswap_service() {
  echo -e "${GREEN}🔧 Criando serviço systemd para PeerSwap...${NC}"
  
  # Criar arquivo de serviço
  sudo tee /etc/systemd/system/peerswap.service > /dev/null << EOF
[Unit]
Description=PeerSwap Daemon
Documentation=https://github.com/ElementsProject/peerswap
After=network.target lnd.service
Wants=network.target
Requires=lnd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/peerswapd --config=/data/peerswap/peerswap.conf
ExecReload=/bin/kill -HUP \$MAINPID
TimeoutStopSec=60
TimeoutStartSec=30
Restart=always
RestartSec=30
User=peerswap
Group=peerswap

# Process management
KillMode=process
KillSignal=SIGTERM

# Security measures  
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

# Directory creation and permissions
RuntimeDirectory=peerswap
RuntimeDirectoryMode=0710

[Install]
WantedBy=multi-user.target
EOF

  # Habilitar serviço
  sudo systemctl daemon-reload
  sudo systemctl enable peerswap
  
  echo -e "${GREEN}✅ Serviço PeerSwap criado e habilitado!${NC}"
}

install_psweb() {
  echo -e "${GREEN}🌐 Instalando PeerSwap Web Interface...${NC}"

  app="PeerSwap Web"
  
  # Verificar se Node.js está instalado
  if ! command -v npm &> /dev/null; then
    echo "📦 Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install nodejs -y >> /dev/null 2>&1 & spinner
  fi

  # Criar usuário psweb se não existir
  if ! id "psweb" &>/dev/null; then
    echo "👤 Criando usuário psweb..."
    sudo adduser --disabled-password --gecos "" psweb
  fi

  # Criar diretórios
  echo "📁 Criando diretórios..."
  sudo mkdir -p /data/psweb /opt/psweb
  sudo chown psweb:psweb /data/psweb

  # Baixar e instalar PeerSwap Web
  echo "⬇️ Baixando PeerSwap Web v$PSWEB_VERSION..."
  cd /tmp
  
  # Clonar repositório
  git clone https://github.com/Impa10r/peerswap-web.git
  cd peerswap-web
  
  # Checkout versão específica se disponível
  git checkout v$PSWEB_VERSION 2>/dev/null || echo "Usando branch main"
  
  # Copiar para diretório final
  sudo cp -r . /opt/psweb/
  sudo chown -R psweb:psweb /opt/psweb

  # Instalar dependências
  echo "📦 Instalando dependências Node.js..."
  cd /opt/psweb
  sudo -u psweb npm install >> /dev/null 2>&1 & spinner

  # Cleanup
  rm -rf /tmp/peerswap-web

  echo -e "${GREEN}✅ PeerSwap Web instalado!${NC}"
}

configure_psweb() {
  echo -e "${GREEN}⚙️ Configurando PeerSwap Web...${NC}"

  # Criar arquivo de configuração
  echo "📝 Criando arquivo de configuração..."
  sudo tee /data/psweb/config.json > /dev/null << EOF
{
  "peerswap": {
    "host": "localhost",
    "port": 42069,
    "protocol": "http"
  },
  "lnd": {
    "host": "localhost",
    "port": 10009,
    "tlsCertPath": "/data/lnd/tls.cert",
    "macaroonPath": "/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon"
  },
  "elements": {
    "host": "localhost", 
    "port": 7041,
    "user": "elements",
    "password": "$(grep rpcpassword /data/elements/elements.conf 2>/dev/null | cut -d'=' -f2 || echo "changeme")"
  },
  "server": {
    "port": 1984,
    "host": "0.0.0.0"
  },
  "theme": "dark",
  "autoRefresh": 30,
  "currency": "BRL"
}
EOF

  # Ajustar permissões
  sudo chown psweb:psweb /data/psweb/config.json
  sudo chmod 600 /data/psweb/config.json

  echo -e "${GREEN}✅ Configuração PeerSwap Web criada!${NC}"
}

create_psweb_service() {
  echo -e "${GREEN}🔧 Criando serviço systemd para PeerSwap Web...${NC}"
  
  # Criar arquivo de serviço
  sudo tee /etc/systemd/system/psweb.service > /dev/null << EOF
[Unit]
Description=PeerSwap Web Interface
Documentation=https://github.com/Impa10r/peerswap-web
After=network.target peerswap.service
Wants=network.target
Requires=peerswap.service

[Service]
Type=simple
WorkingDirectory=/opt/psweb
ExecStart=/usr/bin/node server.js --config=/data/psweb/config.json
ExecReload=/bin/kill -HUP \$MAINPID
TimeoutStopSec=60
TimeoutStartSec=15
Restart=always
RestartSec=30
User=psweb
Group=psweb

# Environment
Environment=NODE_ENV=production
Environment=CONFIG_PATH=/data/psweb/config.json

# Process management
KillMode=process
KillSignal=SIGTERM

# Security measures
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

  # Habilitar serviço
  sudo systemctl daemon-reload
  sudo systemctl enable psweb
  
  echo -e "${GREEN}✅ Serviço PeerSwap Web criado e habilitado!${NC}"
}

start_peerswap() {
  echo -e "${GREEN}🚀 Iniciando PeerSwap...${NC}"
  
  # Verificar dependências
  if ! sudo systemctl is-active --quiet lnd; then
    echo -e "${RED}❌ LND não está rodando! Inicie o LND primeiro.${NC}"
    return 1
  fi

  sudo systemctl start peerswap
  sleep 5
  
  if sudo systemctl is-active --quiet peerswap; then
    echo -e "${GREEN}✅ PeerSwap iniciado com sucesso!${NC}"
    
    # Configurar UFW
    if ! sudo ufw status | grep -q "42069/tcp"; then
      sudo ufw allow from $subnet to any port 42069 proto tcp comment 'allow PeerSwap from local network'
    fi
    
    show_peerswap_status
  else
    echo -e "${RED}❌ Falha ao iniciar PeerSwap!${NC}"
    echo "Verifique os logs: journalctl -u peerswap -f"
    return 1
  fi
}

start_psweb() {
  echo -e "${GREEN}🌐 Iniciando PeerSwap Web...${NC}"
  
  # Verificar dependências
  if ! sudo systemctl is-active --quiet peerswap; then
    echo -e "${RED}❌ PeerSwap não está rodando! Inicie o PeerSwap primeiro.${NC}"
    return 1
  fi

  sudo systemctl start psweb
  sleep 3
  
  if sudo systemctl is-active --quiet psweb; then
    echo -e "${GREEN}✅ PeerSwap Web iniciado com sucesso!${NC}"
    
    # Configurar UFW
    if ! sudo ufw status | grep -q "1984/tcp"; then
      sudo ufw allow from $subnet to any port 1984 proto tcp comment 'allow PeerSwap Web from local network'
    fi
    
    echo -e "${YELLOW}🌐 Interface disponível em: http://$ip_local:1984${NC}"
  else
    echo -e "${RED}❌ Falha ao iniciar PeerSwap Web!${NC}"
    echo "Verifique os logs: journalctl -u psweb -f"
    return 1
  fi
}

show_peerswap_status() {
  echo -e "${BLUE}📊 Status do PeerSwap:${NC}"
  
  # Status do serviço
  echo "🔧 Serviço PeerSwap:"
  if sudo systemctl is-active --quiet peerswap; then
    echo -e "   ${GREEN}✅ Ativo${NC}"
    
    # Tentar conectar via CLI
    if command -v pscli &> /dev/null; then
      echo "📡 Conectividade:"
      if timeout 5 pscli --config=/data/peerswap/peerswap.conf getinfo >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ CLI conectado${NC}"
        
        # Informações básicas
        local peers=$(pscli --config=/data/peerswap/peerswap.conf listpeers 2>/dev/null | wc -l || echo "0")
        echo "👥 Peers: $peers"
        
      else
        echo -e "   ${RED}❌ CLI não responde${NC}"
      fi
    fi
  else
    echo -e "   ${RED}❌ Inativo${NC}"
  fi
  
  # Status PeerSwap Web
  echo "🌐 PeerSwap Web:"
  if sudo systemctl is-active --quiet psweb; then
    echo -e "   ${GREEN}✅ Ativo (http://$ip_local:1984)${NC}"
  else
    echo -e "   ${RED}❌ Inativo${NC}"
  fi
}

create_elements_wallet_for_peerswap() {
  echo -e "${GREEN}👛 Configurando wallet Elements para PeerSwap...${NC}"
  
  # Verificar se Elements está rodando
  if ! sudo systemctl is-active --quiet elementsd; then
    echo -e "${RED}❌ Elements não está rodando!${NC}"
    return 1
  fi

  # Criar wallet específica para PeerSwap
  if ! elements-cli -conf=/data/elements/elements.conf listwallets | grep -q "peerswap"; then
    echo "💼 Criando wallet 'peerswap'..."
    
    if elements-cli -conf=/data/elements/elements.conf createwallet "peerswap" false false "" false false true >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Wallet 'peerswap' criada!${NC}"
    else
      echo -e "${RED}❌ Erro ao criar wallet${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}✅ Wallet 'peerswap' já existe${NC}"
  fi

  # Gerar endereço para a wallet
  local address=$(elements-cli -conf=/data/elements/elements.conf -rpcwallet=peerswap getnewaddress 2>/dev/null)
  if [[ -n "$address" ]]; then
    echo -e "${BLUE}📬 Endereço PeerSwap L-BTC: ${YELLOW}$address${NC}"
  fi
}

stop_peerswap() {
  echo -e "${YELLOW}⏹️ Parando PeerSwap...${NC}"
  sudo systemctl stop peerswap psweb
  
  if ! sudo systemctl is-active --quiet peerswap; then
    echo -e "${GREEN}✅ PeerSwap parado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Erro ao parar PeerSwap${NC}"
    return 1
  fi
}

# Menu PeerSwap
peerswap_menu() {
  while true; do
    echo
    echo -e "${CYAN}🔄 PeerSwap Management${NC}"
    echo "======================"
    echo "1) Instalar PeerSwap"
    echo "2) Configurar PeerSwap"
    echo "3) Criar Serviço PeerSwap"
    echo "4) Instalar PeerSwap Web"
    echo "5) Configurar PeerSwap Web"
    echo "6) Criar Serviço PeerSwap Web"
    echo "7) Iniciar PeerSwap"
    echo "8) Iniciar PeerSwap Web"
    echo "9) Status PeerSwap"
    echo "10) Configurar Wallet Elements"
    echo "11) Parar Serviços"
    echo "0) Voltar"
    echo
    read -p "Escolha uma opção: " option

    case $option in
      1) install_peerswap ;;
      2) configure_peerswap ;;
      3) create_peerswap_service ;;
      4) install_psweb ;;
      5) configure_psweb ;;
      6) create_psweb_service ;;
      7) start_peerswap ;;
      8) start_psweb ;;
      9) show_peerswap_status ;;
      10) create_elements_wallet_for_peerswap ;;
      11) stop_peerswap ;;
      0) break ;;
      *) echo -e "${RED}❌ Opção inválida!${NC}" ;;
    esac
    
    read -p "Pressione ENTER para continuar..."
  done
}

# Export functions
export -f install_peerswap
export -f install_go
export -f configure_peerswap
export -f create_peerswap_service
export -f install_psweb
export -f configure_psweb
export -f create_psweb_service
export -f start_peerswap
export -f start_psweb
export -f show_peerswap_status
export -f create_elements_wallet_for_peerswap
export -f stop_peerswap
export -f peerswap_menu