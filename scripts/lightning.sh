#!/bin/bash

# Lightning Network applications installation functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

install_nodejs() {
  echo -e "${GREEN}📦 Instalando Node.js...${NC}"
  if ! command -v npm &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    echo -e "${BLUE}📦 Instalando Node.js...${NC}"
    sudo apt install nodejs -y
  else
    echo "✅ Node.js já está instalado."
  fi
}

install_bos() {
  echo -e "${GREEN}⚡ Instalando Balance of Satoshis (bos)...${NC}"
  
  # Check if LND is installed
  if ! command -v lnd &> /dev/null; then
    echo -e "${RED}❌ LND não está instalado. Instale o LND primeiro.${NC}"
    return 1
  fi
  
  # Install Node.js if needed
  echo -e "${BLUE}Verificando Node.js...${NC}"
  if ! command -v node &> /dev/null; then
    echo -e "${BLUE}Instalando Node.js 21.x...${NC}"
    curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
    echo -e "${BLUE}📦 Instalando pacote Node.js...${NC}"
    sudo apt-get install nodejs -y
  fi
  
  NODE_VERSION=$(node -v)
  echo -e "${GREEN}✓ Node.js: $NODE_VERSION${NC}"
  
  # Configure npm for global installation without sudo
  echo -e "${BLUE}Configurando npm global...${NC}"
  mkdir -p ~/.npm-global
  npm config set prefix '~/.npm-global'
  
  # Add to PATH if not already there
  if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
    echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
  fi
  source ~/.profile
  
  # Install Balance of Satoshis
  echo -e "${BLUE}Instalando Balance of Satoshis...${NC}"
  echo -e "${BLUE}📦 Instalando Balance of Satoshis...${NC}"
  npm i -g balanceofsatoshis
  
  # Verify installation
  if command -v bos &> /dev/null; then
    BOS_VERSION=$(bos --version 2>/dev/null | head -n1)
    echo -e "${GREEN}✓ bos instalado: $BOS_VERSION${NC}"
  else
    echo -e "${RED}❌ Erro ao instalar bos${NC}"
    return 1
  fi
  
  # Update /etc/hosts if needed
  if ! grep -q "127.0.0.1 localhost" /etc/hosts; then
    echo -e "${BLUE}Atualizando /etc/hosts...${NC}"
    sudo bash -c 'echo "127.0.0.1 localhost" >> /etc/hosts'
  fi
  
  # Adjust LND directory permissions
  echo -e "${BLUE}Ajustando permissões do diretório LND...${NC}"
  sudo chown -R $atual_user:$atual_user /data/lnd
  sudo chmod -R 755 /data/lnd
  
  # Export BOS_DEFAULT_LND_PATH
  if ! grep -q 'export BOS_DEFAULT_LND_PATH=' ~/.profile; then
    echo 'export BOS_DEFAULT_LND_PATH=/data/lnd' >> ~/.profile
  fi
  export BOS_DEFAULT_LND_PATH=/data/lnd
  
  # Create bos directory
  NODE_NAME="${HOSTNAME:-brlnbolt}"
  echo -e "${BLUE}Criando diretório para node: $NODE_NAME${NC}"
  mkdir -p ~/.bos/$NODE_NAME
  
  # Generate base64 files
  echo -e "${BLUE}Gerando arquivos base64...${NC}"
  base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
  base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64
  
  # Create credentials.json
  echo -e "${BLUE}Criando credentials.json...${NC}"
  cert_base64=$(cat /data/lnd/tls.cert.base64)
  macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)
  
  cat > ~/.bos/$NODE_NAME/credentials.json <<EOF
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOF
  
  # Test installation
  echo -e "${BLUE}Testando instalação bos...${NC}"
  if bos utxos 2>/dev/null | grep -q "utxos\|channel"; then
    echo -e "${GREEN}✓ bos funcionando corretamente${NC}"
  else
    echo -e "${YELLOW}⚠ Aguarde o LND sincronizar completamente para usar bos${NC}"
  fi
  
  # Interactive Telegram setup
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}         📱 CONFIGURAÇÃO DO TELEGRAM BOT${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Install qrencode if not available
  if ! command -v qrencode &> /dev/null; then
    echo -e "${BLUE}Instalando gerador de QR Code...${NC}"
    echo -e "${BLUE}📦 Instalando qrencode...${NC}"
    sudo apt install -y qrencode
  fi
  
  read -p "Deseja configurar o Telegram Bot agora? (s/n): " setup_telegram
  
  if [[ "$setup_telegram" == "s" || "$setup_telegram" == "S" ]]; then
    
    # Step 1: Get Bot API Key
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   PASSO 1: Criar seu Bot no Telegram${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}1. Abra o Telegram e acesse @BotFather${NC}"
    echo ""
    echo -e "${CYAN}   Escaneie este QR Code com seu celular:${NC}"
    echo ""
    qrencode -t ANSIUTF8 "https://t.me/BotFather"
    echo ""
    echo -e "${CYAN}2. Envie o comando: ${GREEN}/newbot${NC}"
    echo -e "${CYAN}3. Escolha um nome para seu bot${NC}"
    echo -e "${CYAN}4. Escolha um username (deve terminar com 'bot')${NC}"
    echo -e "${CYAN}5. Copie a API Key fornecida${NC}"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get Bot API Key with validation
    while true; do
      read -p "Cole aqui a API Key do seu Bot: " bot_api_key
      
      if [[ -z "$bot_api_key" ]]; then
        echo -e "${RED}❌ API Key não pode estar vazia!${NC}"
        continue
      fi
      
      if [[ ! "$bot_api_key" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}❌ Formato inválido! Exemplo: 123456789:ABCdefGHI...${NC}"
        continue
      fi
      
      # Test API Key with Telegram
      echo -e "${BLUE}Validando API Key...${NC}"
      bot_check=$(curl -s "https://api.telegram.org/bot${bot_api_key}/getMe")
      
      if echo "$bot_check" | grep -q '"ok":true'; then
        bot_username=$(echo "$bot_check" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        bot_name=$(echo "$bot_check" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}✓ Bot validado: @${bot_username} (${bot_name})${NC}"
        break
      else
        echo -e "${RED}❌ API Key inválida! Verifique e tente novamente.${NC}"
      fi
    done
    
    # Step 2: Get Telegram ID automatically
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   PASSO 2: Conectar seu Telegram ao Bot${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}1. Abra o Telegram e acesse: @${bot_username}${NC}"
    echo ""
    echo -e "${CYAN}   Escaneie este QR Code com seu celular:${NC}"
    echo ""
    qrencode -t ANSIUTF8 "https://t.me/${bot_username}"
    echo ""
    echo -e "${CYAN}2. Clique em ${GREEN}START${CYAN} ou envie qualquer mensagem${NC}"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Aguardando sua mensagem no bot...${NC}"
    
    # Clear any old updates
    curl -s "https://api.telegram.org/bot${bot_api_key}/getUpdates?offset=-1" > /dev/null
    
    # Wait for user message and capture Telegram ID
    telegram_id=""
    max_attempts=60  # 60 attempts = 5 minutes (5 seconds each)
    attempt=0
    
    while [[ -z "$telegram_id" && $attempt -lt $max_attempts ]]; do
      # Show progress indicator
      printf "\r${BLUE}⏳ Aguardando... [%d/%d]${NC}" $((attempt + 1)) $max_attempts
      
      # Get updates from Telegram
      updates=$(curl -s "https://api.telegram.org/bot${bot_api_key}/getUpdates")
      
      # Extract telegram ID from the first message
      telegram_id=$(echo "$updates" | grep -o '"id":[0-9]*' | head -n1 | cut -d':' -f2)
      
      if [[ -n "$telegram_id" ]]; then
        # Get user info
        user_name=$(echo "$updates" | grep -o '"first_name":"[^"]*"' | head -n1 | cut -d'"' -f4)
        echo ""
        echo -e "${GREEN}✓ Conectado! Telegram ID: $telegram_id${NC}"
        if [[ -n "$user_name" ]]; then
          echo -e "${GREEN}✓ Usuário: $user_name${NC}"
        fi
        break
      fi
      
      sleep 5
      ((attempt++))
    done
    
    echo ""
    
    if [[ -z "$telegram_id" ]]; then
      echo -e "${RED}❌ Timeout! Não recebemos sua mensagem.${NC}"
      echo -e "${YELLOW}Configure manualmente depois com: bos telegram${NC}"
      return 1
    fi
    
    # Store in password manager
    echo -e "${BLUE}Salvando credenciais...${NC}"
    source "$SCRIPT_DIR/brln-tools/password_manager.sh"
    store_password_full "bos_telegram_id" "$telegram_id" "Balance of Satoshis - Telegram User ID" "$atual_user" 0 "https://t.me/${bot_username}"
    store_password_full "bos_telegram_bot" "$bot_api_key" "Balance of Satoshis - Bot API Key (@${bot_username})" "$atual_user" 0 "https://t.me/BotFather"
    echo -e "${GREEN}✓ Credenciais armazenadas no gerenciador de senhas${NC}"
    
    # Create systemd service
    echo -e "${BLUE}Criando serviço systemd...${NC}"
    sudo bash -c "cat > /etc/systemd/system/bos-telegram.service << 'EOFSERVICE'
# Systemd unit for Bos-Telegram Bot
# /etc/systemd/system/bos-telegram.service

[Unit]
Description=bos-telegram
Wants=lnd.service
After=lnd.service

[Service]
ExecStart=/home/${atual_user}/.npm-global/bin/bos telegram --use-small-units --connect ${telegram_id}
User=${atual_user}
Restart=always
TimeoutSec=120
RestartSec=30
StandardOutput=null
StandardError=journal
Environment=BOS_DEFAULT_LND_PATH=/data/lnd

[Install]
WantedBy=multi-user.target
EOFSERVICE"
    
    # Enable and start service
    sudo systemctl daemon-reload
    sudo systemctl enable bos-telegram.service
    sudo systemctl start bos-telegram.service
    
    sleep 2
    
    if systemctl is-active --quiet bos-telegram.service; then
      echo -e "${GREEN}✓ Serviço bos-telegram iniciado${NC}"
    else
      echo -e "${YELLOW}⚠ Verificar status: sudo systemctl status bos-telegram${NC}"
    fi
    
    # Send welcome message
    curl -s -X POST "https://api.telegram.org/bot${bot_api_key}/sendMessage" \
      -d chat_id="$telegram_id" \
      -d text="✅ *BRLNBolt conectado com sucesso!*%0A%0ABot Balance of Satoshis ativo.%0A%0ATeste com: \`/balance\`" \
      -d parse_mode="Markdown" > /dev/null
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Configuração do Telegram concluída!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🤖 Bot: @${bot_username}${NC}"
    echo -e "${CYAN}👤 Telegram ID: ${telegram_id}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Comandos disponíveis no Telegram:${NC}"
    echo -e "${CYAN}  /balance     - Ver saldo${NC}"
    echo -e "${CYAN}  /forwards    - Ver forwards recentes${NC}"
    echo -e "${CYAN}  /earnings    - Ver ganhos${NC}"
    echo -e "${CYAN}  /connect     - Conectar outro bot${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
  else
    echo -e "${YELLOW}Configuração do Telegram pulada.${NC}"
    echo -e "${CYAN}💡 Configure mais tarde com: bos telegram${NC}"
  fi
  
  echo ""
  echo -e "${GREEN}✅ Balance of Satoshis instalado com sucesso!${NC}"
  echo -e "${CYAN}💡 Comandos úteis:${NC}"
  echo -e "${CYAN}   bos --help           - Ver todos os comandos${NC}"
  echo -e "${CYAN}   bos balance          - Ver saldo${NC}"
  echo -e "${CYAN}   bos forwards         - Ver forwards${NC}"
  echo -e "${CYAN}   bos telegram         - Configurar Telegram${NC}"
  echo -e "${CYAN}💡 Status: sudo systemctl status bos-telegram${NC}"
}

install_thunderhub() {
  echo -e "${GREEN}⚡ Instalando ThunderHub...${NC}"
  
  # Check if LND is installed
  if ! command -v lnd &> /dev/null; then
    echo -e "${RED}❌ LND não está instalado. Instale o LND primeiro.${NC}"
    return 1
  fi
  
  # Check Node.js and NPM
  echo -e "${BLUE}Verificando Node.js e NPM...${NC}"
  if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo -e "${BLUE}Instalando Node.js...${NC}"
    install_nodejs
  fi
  
  NODE_VERSION=$(node -v)
  NPM_VERSION=$(npm -v)
  echo -e "${GREEN}✓ Node.js: $NODE_VERSION${NC}"
  echo -e "${GREEN}✓ NPM: $NPM_VERSION${NC}"
  
  # Get ThunderHub version from config
  VERSION=$VERSION_THUB
  
  # Import developer's GPG key
  echo -e "${BLUE}Importando chave GPG do desenvolvedor...${NC}"
  curl -s https://github.com/apotdevin.gpg | gpg --import 2>/dev/null || true
  
  # Clone repository
  echo -e "${BLUE}Clonando ThunderHub v${VERSION}...${NC}"
  cd /home/$atual_user
  
  if [[ -d "thunderhub" ]]; then
    echo -e "${YELLOW}⚠ Diretório thunderhub já existe. Removendo...${NC}"
    rm -rf thunderhub
  fi
  
  git clone --branch v${VERSION} https://github.com/apotdevin/thunderhub.git
  cd thunderhub
  
  # Verify commit signature
  echo -e "${BLUE}Verificando assinatura do commit...${NC}"
  if git verify-commit v${VERSION} 2>&1 | grep -q "Good signature"; then
    echo -e "${GREEN}✓ Assinatura GPG verificada${NC}"
  else
    echo -e "${YELLOW}⚠ Aviso: Não foi possível verificar a assinatura GPG${NC}"
  fi
  
  # Install dependencies
  echo -e "${BLUE}Instalando dependências NPM (isso pode demorar)...${NC}"
  npm install > /dev/null 2>&1
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Dependências instaladas${NC}"
  else
    echo -e "${RED}❌ Erro ao instalar dependências${NC}"
    return 1
  fi
  
  # Disable telemetry (optional)
  echo -e "${BLUE}Desativando telemetria do Next.js...${NC}"
  npx next telemetry disable 2>/dev/null
  
  # Build
  echo -e "${BLUE}Compilando ThunderHub (isso pode demorar vários minutos)...${NC}"
  npm run build > /tmp/thunderhub-build.log 2>&1
  
  if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ ThunderHub compilado com sucesso${NC}"
  else
    echo -e "${RED}❌ Erro ao compilar ThunderHub${NC}"
    echo -e "${YELLOW}Veja os logs em: /tmp/thunderhub-build.log${NC}"
    return 1
  fi
  
  # Verify version
  INSTALLED_VERSION=$(head -n 3 /home/$atual_user/thunderhub/package.json | grep version | cut -d'"' -f4)
  echo -e "${GREEN}✓ ThunderHub v${INSTALLED_VERSION} instalado${NC}"
  
  # Configure
  echo -e "${BLUE}Configurando ThunderHub...${NC}"
  
  # Copy environment file
  cp .env .env.local
  
  # Update config path
  sed -i "s|ACCOUNT_CONFIG_PATH=.*|ACCOUNT_CONFIG_PATH='/home/$atual_user/thunderhub/thubConfig.yaml'|" .env.local
  
  # Generate master password for ThunderHub
  THUB_MASTER_PASSWORD=$(openssl rand -base64 24)
  THUB_ACCOUNT_PASSWORD=$(openssl rand -base64 16)
  
  # Create thubConfig.yaml
  cat > thubConfig.yaml << EOF
masterPassword: '${THUB_MASTER_PASSWORD}'
accounts:
  - name: 'BRLNBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '${THUB_ACCOUNT_PASSWORD}'
backupsEnabled: true
healthCheckPingEnabled: true
EOF
  
  chmod 600 thubConfig.yaml
  echo -e "${GREEN}✓ Arquivo de configuração criado${NC}"
  
  # Store passwords in password manager
  source "$SCRIPT_DIR/brln-tools/password_manager.sh"
  store_password_full "thunderhub_master" "$THUB_MASTER_PASSWORD" "ThunderHub Master Password" "admin" 3000 "http://127.0.0.1:3000"
  store_password_full "thunderhub_account" "$THUB_ACCOUNT_PASSWORD" "ThunderHub Account Password" "admin" 3000 "http://127.0.0.1:3000"
  echo -e "${GREEN}✓ Senhas salvas no gerenciador de senhas${NC}"
  
  # Create systemd service
  echo -e "${BLUE}Criando serviço systemd...${NC}"
  sudo bash -c "cat > /etc/systemd/system/thunderhub.service << 'EOF'
# BRLN Bolt: unidade systemd para Thunderhub
# /etc/systemd/system/thunderhub.service

[Unit]
Description=ThunderHub
Requires=lnd.service
After=lnd.service

[Service]
WorkingDirectory=/home/${atual_user}/thunderhub
ExecStart=/usr/bin/npm run start

User=${atual_user}
Group=${atual_user}

# Process management
####################
TimeoutSec=300

# Hardening Measures
####################
PrivateTmp=true
ProtectSystem=full
NoNewPrivileges=true
PrivateDevices=true

[Install]
WantedBy=multi-user.target
EOF"
  
  # Enable and start service
  echo -e "${BLUE}Habilitando e iniciando serviço...${NC}"
  sudo systemctl daemon-reload
  sudo systemctl enable thunderhub.service
  sudo systemctl start thunderhub.service
  
  # Wait a moment and check status
  sleep 3
  
  if systemctl is-active --quiet thunderhub.service; then
    echo -e "${GREEN}✓ Serviço thunderhub iniciado${NC}"
  else
    echo -e "${YELLOW}⚠ Verificar status: sudo systemctl status thunderhub.service${NC}"
  fi
  
  echo -e "${GREEN}✅ ThunderHub instalado com sucesso!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}⚡ ThunderHub Dashboard${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}🌐 URL: http://$(hostname -I | awk '{print $1}'):3000${NC}"
  echo -e "${CYAN}🔑 Master Password: ${THUB_MASTER_PASSWORD}${NC}"
  echo -e "${CYAN}🔑 Account Password: ${THUB_ACCOUNT_PASSWORD}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✓ Senhas armazenadas no gerenciador de senhas${NC}"
  echo -e "${CYAN}💡 Consultar senhas: Menu > Configurações > Gerenciador de Senhas${NC}"
  echo -e "${CYAN}💡 Logs: journalctl -fu thunderhub${NC}"
  echo -e "${CYAN}💡 Config: /home/$atual_user/thunderhub/thubConfig.yaml${NC}"
  echo -e "${CYAN}💡 Status: sudo systemctl status thunderhub${NC}"
}

lnbits_install() {
  echo -e "${GREEN}⚡ Instalando LNbits...${NC}"
  
  # Create lnbits user
  if ! id "lnbits" &>/dev/null; then
    echo -e "${BLUE}👤 Criando usuário lnbits...${NC}"
    sudo useradd -r -m -s /bin/bash lnbits
    echo -e "${GREEN}✓ Usuário lnbits criado${NC}"
  else
    echo -e "${YELLOW}⚠ Usuário lnbits já existe${NC}"
  fi
  
  # Install Python dependencies
  echo -e "${BLUE}📦 Instalando dependências Python...${NC}"
  sudo apt install python3-pip python3-venv -y
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao instalar dependências Python${NC}"
    return 1
  fi
  
  # Clone LNbits
  echo -e "${BLUE}📥 Clonando repositório LNbits...${NC}"
  cd /home/lnbits
  
  if [ -d "lnbits" ]; then
    echo -e "${YELLOW}⚠ Diretório lnbits já existe, removendo...${NC}"
    sudo rm -rf lnbits
  fi
  
  sudo -u lnbits git clone https://github.com/lnbits/lnbits.git
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao clonar repositório LNbits${NC}"
    return 1
  fi
  
  cd lnbits
  
  # Setup virtual environment
  echo -e "${BLUE}🐍 Criando ambiente virtual...${NC}"
  sudo -u lnbits python3 -m venv venv
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao criar ambiente virtual${NC}"
    return 1
  fi
  
  echo -e "${BLUE}📦 Instalando dependências LNbits...${NC}"
  echo -e "${YELLOW}⏳ Isto pode demorar alguns minutos...${NC}"
  sudo -u lnbits ./venv/bin/pip install --upgrade pip
  sudo -u lnbits ./venv/bin/pip install -r requirements.txt
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Erro ao instalar dependências do LNbits${NC}"
    echo -e "${BLUE}💡 Tentando com --no-cache-dir...${NC}"
    sudo -u lnbits ./venv/bin/pip install --no-cache-dir -r requirements.txt
    
    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Falha na instalação das dependências. Verifique os logs acima.${NC}"
      return 1
    fi
  fi
  
  # Install systemd service
  echo -e "${BLUE}🔧 Configurando serviço systemd...${NC}"
  if [[ -f "$SERVICES_DIR/lnbits.service" ]]; then
    safe_cp "$SERVICES_DIR/lnbits.service" /etc/systemd/system/lnbits.service
    sudo systemctl daemon-reload
    sudo systemctl enable lnbits
    echo -e "${GREEN}✓ Serviço systemd configurado${NC}"
  else
    echo -e "${YELLOW}⚠ Arquivo de serviço não encontrado: $SERVICES_DIR/lnbits.service${NC}"
  fi
  
  echo -e "${GREEN}✅ LNbits instalado com sucesso!${NC}"
  echo -e "${CYAN}💡 Iniciar com: sudo systemctl start lnbits${NC}"
  echo -e "${CYAN}💡 Status: sudo systemctl status lnbits${NC}"
  echo -e "${CYAN}💡 Logs: journalctl -fu lnbits${NC}"
}

setup_lightning_monitor() {
  echo -e "${GREEN}📊 Configurando Lightning Monitor...${NC}"
  
  # Setup virtual environment for Flask API
  if [ ! -d "$FLASKVENV_DIR" ]; then
    echo -e "${BLUE}🐍 Criando ambiente virtual Flask...${NC}"
    python3 -m venv "$FLASKVENV_DIR"
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi
  
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"
  
  # Install Flask dependencies
  if [[ -f "$SCRIPT_DIR/api/v1/requirements.txt" ]]; then
    echo -e "${BLUE}📦 Instalando dependências Flask...${NC}"
    pip install -r "$SCRIPT_DIR/api/v1/requirements.txt"
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
  echo -e "${BLUE}📦 Instalando gRPC...${NC}"
  pip install grpcio grpcio-tools
  
  # Generate gRPC files if proto files exist
  if [[ -d "$SCRIPT_DIR/api/v1/proto" ]]; then
    echo "🔧 Gerando arquivos gRPC..."
    cd "$SCRIPT_DIR/api/v1"
    python -m grpc_tools.protoc \
      --python_out=. \
      --grpc_python_out=. \
      --proto_path=proto \
      proto/*.proto
  fi
  
  # Install API service
  if [[ -f "$SERVICES_DIR/brln-api.service" ]]; then
    safe_cp "$SERVICES_DIR/brln-api.service" /etc/systemd/system/brln-api.service
    sudo systemctl daemon-reload
    sudo systemctl enable brln-api
  fi
  
  echo -e "${GREEN}✅ BRLN API instalada!${NC}"
}

install_lndg() {
  echo -e "${GREEN}📊 Instalando LNDg (Lightning Node Dashboard)...${NC}"
  
  # Check if LND is installed
  if ! command -v lnd &> /dev/null; then
    echo -e "${RED}❌ LND não está instalado. Instale o LND primeiro.${NC}"
    return 1
  fi
  
  # Install dependencies
  echo -e "${BLUE}Instalando dependências...${NC}"
  sudo apt update
  sudo apt install -y python3 python3-pip virtualenv git
  
  # Clone repository
  echo -e "${BLUE}Clonando repositório LNDg...${NC}"
  cd /home/$atual_user
  
  if [[ -d "lndg" ]]; then
    echo -e "${YELLOW}⚠ Diretório lndg já existe. Atualizando...${NC}"
    cd lndg
    git pull
  else
    git clone https://github.com/cryptosharks131/lndg.git
    cd lndg
  fi
  
  # Setup Python virtual environment
  echo -e "${BLUE}Configurando ambiente virtual Python...${NC}"
  if [[ ! -d ".venv" ]]; then
    virtualenv -p python3 .venv
  fi
  
  # Install requirements
  echo -e "${BLUE}Instalando dependências Python...${NC}"
  .venv/bin/pip3 install -r requirements.txt > /dev/null 2>&1
  
  # Install whitenoise
  echo -e "${BLUE}Instalando Whitenoise...${NC}"
  .venv/bin/pip3 install whitenoise > /dev/null 2>&1
  
  # Initialize Django settings
  echo -e "${BLUE}Inicializando configurações Django...${NC}"
  .venv/bin/python3 initialize.py --whitenoise
  
  # Check if admin password was created
  if [[ -f "data/lndg-admin.txt" ]]; then
    LNDG_PASSWORD=$(cat data/lndg-admin.txt)
    echo -e "${GREEN}✓ Senha do admin gerada e salva em data/lndg-admin.txt${NC}"
    
    # Store password securely in password manager
    source "$SCRIPT_DIR/brln-tools/password_manager.sh"
    store_password_full "lndg_admin" "$LNDG_PASSWORD" "LNDg Dashboard Admin" "lndg-admin" 8889 "http://127.0.0.1:8889"
    echo -e "${GREEN}✓ Credenciais LNDg salvas no gerenciador de senhas${NC}"
  fi
  
  # Create systemd service for LNDg
  echo -e "${BLUE}Criando serviço systemd para LNDg...${NC}"
  sudo bash -c "cat > /etc/systemd/system/lndg.service << 'EOF'
[Unit]
Description=LNDG Service
After=lnd.service
Requires=lnd.service

[Service]
WorkingDirectory=/home/${atual_user}/lndg
ExecStart=/home/${atual_user}/lndg/.venv/bin/python3 /home/${atual_user}/lndg/manage.py runserver 0.0.0.0:8889
User=${atual_user}
Group=${atual_user}
Restart=on-failure
Type=simple
StandardError=syslog
NotifyAccess=none

[Install]
WantedBy=multi-user.target
EOF"
  
  # Create systemd service for LNDg Controller
  echo -e "${BLUE}Criando serviço systemd para LNDg Controller...${NC}"
  sudo bash -c "cat > /etc/systemd/system/lndg-controller.service << 'EOF'
[Unit]
Description=Controlador de backend para Lndg
After=lnd.service
Requires=lnd.service

[Service]
Environment=PYTHONUNBUFFERED=1
User=${atual_user}
Group=${atual_user}
ExecStart=/home/${atual_user}/lndg/.venv/bin/python3 /home/${atual_user}/lndg/controller.py
StandardOutput=append:/var/log/lndg-controller.log
StandardError=append:/var/log/lndg-controller.log
Restart=always
RestartSec=60s

[Install]
WantedBy=multi-user.target
EOF"
  
  # Create log files with proper permissions
  sudo touch /var/log/lndg-controller.log
  sudo chown $atual_user:$atual_user /var/log/lndg-controller.log
  
  # Reload systemd and enable services
  echo -e "${BLUE}Habilitando serviços...${NC}"
  sudo systemctl daemon-reload
  sudo systemctl enable lndg.service
  sudo systemctl enable lndg-controller.service
  
  # Start services
  echo -e "${BLUE}Iniciando serviços...${NC}"
  sudo systemctl start lndg.service
  sudo systemctl start lndg-controller.service
  
  # Wait a moment and check status
  sleep 2
  
  if systemctl is-active --quiet lndg.service; then
    echo -e "${GREEN}✓ Serviço lndg iniciado${NC}"
  else
    echo -e "${YELLOW}⚠ Verificar status: sudo systemctl status lndg.service${NC}"
  fi
  
  if systemctl is-active --quiet lndg-controller.service; then
    echo -e "${GREEN}✓ Serviço lndg-controller iniciado${NC}"
  else
    echo -e "${YELLOW}⚠ Verificar status: sudo systemctl status lndg-controller.service${NC}"
  fi
  
  echo -e "${GREEN}✅ LNDg instalado com sucesso!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}📊 LNDg Dashboard${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}🌐 URL: http://$(hostname -I | awk '{print $1}'):8889${NC}"
  echo -e "${CYAN}👤 Usuário: lndg-admin${NC}"
  echo -e "${CYAN}🔑 Senha: ${LNDG_PASSWORD:-'Ver arquivo data/lndg-admin.txt'}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"  echo -e "${GREEN}✓ Credenciais armazenadas no gerenciador de senhas${NC}"
  echo -e "${CYAN}💡 Consultar senhas: Menu > Configurações > Gerenciador de Senhas${NC}"  echo -e "${CYAN}💡 Logs LNDg: journalctl -fu lndg${NC}"
  echo -e "${CYAN}💡 Logs Controller: sudo tail -f /var/log/lndg-controller.log${NC}"
  echo -e "${CYAN}💡 Status: sudo systemctl status lndg lndg-controller${NC}"
}