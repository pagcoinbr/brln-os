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
  
  # Detect BRLN-OS directory
  configure_brln_paths quiet
  SCRIPT_DIR="$BRLN_OS_DIR"
  
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
    BOS_VERSION=$(bos --version | head -n1)
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
  
  # Note: /data/lnd ownership remains as lnd:lnd for security
  # BOS will access LND files through proper group permissions
  
  # Export BOS_DEFAULT_LND_PATH
  if ! grep -q 'export BOS_DEFAULT_LND_PATH=' ~/.profile; then
    echo 'export BOS_DEFAULT_LND_PATH=/data/lnd' >> ~/.profile
  fi
  export BOS_DEFAULT_LND_PATH=/data/lnd
  
  # Create bos directory
  echo -e "${BLUE}Criando diretório para node: $NODE_NAME${NC}"
  mkdir -p ~/.bos/$NODE_NAME
  
  # Check if LND files exist before proceeding
  if [[ -f "/data/lnd/tls.cert" ]] && [[ -f "/data/lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon" ]]; then
    # Generate base64 files
    echo -e "${BLUE}Gerando arquivos base64...${NC}"
    base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
    base64 -w0 /data/lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon > /data/lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon.base64
    
    # Create credentials.json
    echo -e "${BLUE}Criando credentials.json...${NC}"
    cert_base64=$(cat /data/lnd/tls.cert.base64)
    macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon.base64)
    
    cat > ~/.bos/$NODE_NAME/credentials.json <<EOFCRED
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOFCRED
    
    echo -e "${GREEN}✓ Credenciais BOS configuradas${NC}"
  else
    echo -e "${YELLOW}⚠️  LND ainda não gerou os arquivos necessários (tls.cert e admin.macaroon)${NC}"
    echo -e "${YELLOW}   As credenciais serão criadas automaticamente quando o LND iniciar${NC}"
  fi
  
  # Setup daily credentials update cron job
  echo -e "${BLUE}Configurando atualização automática de credenciais...${NC}"
  
  # Install jq if not available (needed for credential updater)
  if ! command -v jq &> /dev/null; then
    sudo apt-get install -y jq > /dev/null 2>&1
  fi
  
  # Add cron job to update credentials daily at 3 AM
  CRON_CMD="/usr/local/bin/update-bos-credentials"
  CRON_ENTRY="0 3 * * * $CRON_CMD >> /tmp/bos-update.log 2>&1"
  
  if ! crontab -l 2>/dev/null | grep -Fq "$CRON_CMD"; then
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    echo -e "${GREEN}✓ Cron job configurado para atualização diária às 3 AM${NC}"
  else
    echo -e "${GREEN}✓ Cron job já configurado${NC}"
  fi
  
  # Run the updater script immediately if files exist
  if [[ -f "/data/lnd/tls.cert" ]] && [[ -f "/data/lnd/data/chain/bitcoin/${BITCOIN_NETWORK}/admin.macaroon" ]]; then
    /usr/local/bin/update-bos-credentials
  fi
  
  # Test bos functionality
  if bos utxos 2>/dev/null | grep -q "utxos|channel"; then
    echo -e "${GREEN}✓ bos funcionando corretamente${NC}"
  else
    echo -e "${YELLOW}⚠ Aguarde o LND sincronizar completamente para usar bos${NC}"
  fi
  
  echo ""
  echo -e "${GREEN}✅ Balance of Satoshis instalado com sucesso!${NC}"
  echo -e "${CYAN}💡 Comandos úteis:${NC}"
  echo -e "${CYAN}   bos --help           - Ver todos os comandos${NC}"
  echo -e "${CYAN}   bos balance          - Ver saldo${NC}"
  echo -e "${CYAN}   bos forwards         - Ver forwards${NC}"
  echo ""
  echo -e "${YELLOW}💡 Para configurar o Telegram Bot, use o menu de configurações${NC}"
}

configure_bos_telegram() {
  echo -e "${GREEN}⚡ Configurando Balance of Satoshis - Telegram Bot...${NC}"
  
  # Detect BRLN-OS directory
  configure_brln_paths quiet
  SCRIPT_DIR="$BRLN_OS_DIR"
  
  # Check if bos is installed
  if ! command -v bos &> /dev/null; then
    echo -e "${RED}❌ Balance of Satoshis não está instalado.${NC}"
    echo -e "${YELLOW}Por favor, instale primeiro usando o menu de instalação.${NC}"
    return 1
  fi
  
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
    echo -e "${YELLOW}Tente novamente ou configure manualmente com: bos telegram${NC}"
    return 1
  fi
  
  # Store in password manager
  echo -e "${BLUE}Salvando credenciais...${NC}"
  ensure_pm_session  # Unlock password manager session
  source "$SCRIPT_DIR/brln-tools/secure_password_manager.sh"
  secure_store_password_full "bos_telegram_id" "$telegram_id" "Balance of Satoshis - Telegram User ID" "$atual_user" 0 "https://t.me/${bot_username}"
  secure_store_password_full "bos_telegram_bot" "$bot_api_key" "Balance of Satoshis - Bot API Key (@${bot_username})" "$atual_user" 0 "https://t.me/BotFather"
  echo -e "${GREEN}✓ Credenciais armazenadas no gerenciador de senhas${NC}"
  
  # Create systemd service
  echo -e "${BLUE}Criando serviço systemd...${NC}"
  source "$SCRIPT_DIR/scripts/services.sh"
  create_bos_telegram_service
  
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
  echo ""
  echo -e "${CYAN}💡 Status: sudo systemctl status bos-telegram${NC}"
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
  
  # Create and enable messager-monitor service for keysend notifications
  echo -e "${BLUE}💬 Configurando Lightning Messager Monitor (Keysend)...${NC}"
  source "$SCRIPT_DIR/scripts/services.sh"
  create_messager_monitor_service
  
  # Reload systemd and enable service
  sudo systemctl daemon-reload
  sudo systemctl enable messager-monitor.service
  
  # Start messager-monitor service
  echo -e "${BLUE}▶️  Iniciando serviço de notificações...${NC}"
  sudo systemctl start messager-monitor.service
  
  # Wait a moment and check status
  sleep 2
  
  if systemctl is-active --quiet messager-monitor.service; then
    echo -e "${GREEN}✓ Serviço messager-monitor iniciado${NC}"
    echo -e "${GREEN}✓ Notificações de mensagens Lightning ativas${NC}"
  else
    echo -e "${YELLOW}⚠ Verificar status: sudo systemctl status messager-monitor${NC}"
  fi
  
  echo -e "${GREEN}✅ Lightning Monitor configurado!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}💬 Monitor de Mensagens Lightning${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}📊 Endpoint API: POST /api/v1/lightning/chat/keysends/check${NC}"
  echo -e "${CYAN}🔍 Status: sudo systemctl status messager-monitor${NC}"
  echo -e "${CYAN}📋 Logs: sudo journalctl -fu messager-monitor${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
  
  # Detect BRLN-OS directory
  configure_brln_paths quiet
  SCRIPT_DIR="$BRLN_OS_DIR"
  
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
  cd ~
  
  if [[ -d "lndg" ]]; then
    echo -e "${YELLOW}⚠ Diretório lndg já existe. Atualizando...${NC}"
    cd lndg
    # git pull  # Disabled to avoid conflicts with local changes
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
  .venv/bin/pip3 install -r requirements.txt
  
  # Install whitenoise
  echo -e "${BLUE}Instalando Whitenoise...${NC}"
  .venv/bin/pip3 install whitenoise
  
  # Initialize Django settings
  echo -e "${BLUE}Inicializando configurações Django...${NC}"
  .venv/bin/python3 initialize.py --whitenoise
  
  # Check if admin password was created
  if [[ -f "data/lndg-admin.txt" ]]; then
    LNDG_PASSWORD=$(cat data/lndg-admin.txt)
    echo -e "${GREEN}✓ Senha do admin gerada e salva em data/lndg-admin.txt${NC}"
    
    # Store password securely in password manager
    source "$SCRIPT_DIR/brln-tools/secure_password_manager.sh"
    secure_store_password_full "lndg_admin" "$LNDG_PASSWORD" "LNDg Dashboard Admin" "lndg-admin" 8889 "http://127.0.0.1:8889"
    echo -e "${GREEN}✓ Credenciais LNDg salvas no gerenciador de senhas${NC}"
  fi
  
  # Create systemd service for LNDg
  echo -e "${BLUE}Criando serviço systemd para LNDg...${NC}"
  source "$SCRIPT_DIR/scripts/services.sh"
  create_lndg_service
  
  # Create systemd service for LNDg Controller
  echo -e "${BLUE}Criando serviço systemd para LNDg Controller...${NC}"
  create_lndg_controller_service
  
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

# ============================================================================
# RESUMO DAS FUNÇÕES DO SCRIPT LIGHTNING.SH
# ============================================================================
#
# Este script contém funções para instalação e configuração de aplicações
# Lightning Network no sistema BRLN-OS. Todas as funções são projetadas para
# trabalhar em conjunto com a configuração do sistema e usar o gerenciador
# de senhas integrado.
#
# DEPENDÊNCIAS:
# - config.sh: Configurações globais do sistema
# - utils.sh: Utilitários e funções auxiliares
# - services.sh: Criação de serviços systemd
# - secure_password_manager.sh: Gerenciamento seguro de senhas
#
# ============================================================================
# LISTA DE FUNÇÕES DISPONÍVEIS:
# ============================================================================
#
# 1. install_nodejs()
#    DESCRIÇÃO: Instala Node.js LTS no sistema
#    FUNCIONALIDADE:
#    - Verifica se Node.js já está instalado
#    - Adiciona repositório NodeSource oficial
#    - Instala a versão LTS do Node.js com npm
#    - Confirma instalação com verificação de comando
#    REQUERIMENTOS: Conexão com internet, permissões sudo
#    STATUS: Função auxiliar para outras instalações
#
# 2. install_bos()
#    DESCRIÇÃO: Instala Balance of Satoshis (BOS) - ferramenta avançada para LND
#    FUNCIONALIDADE:
#    - Verifica se LND está instalado (pré-requisito obrigatório)
#    - Instala Node.js 21.x se necessário
#    - Configura npm para instalação global sem sudo
#    - Instala Balance of Satoshis via npm global
#    - Configura variáveis de ambiente (BOS_DEFAULT_LND_PATH)
#    - Cria diretório de configuração BOS
#    - Gera credenciais base64 para LND (cert e macaroon)
#    - Cria arquivo credentials.json para autenticação
#    - Configura cron job para atualização automática de credenciais (3h AM)
#    - Instala jq como dependência
#    - Testa funcionalidade básica do BOS
#    REQUERIMENTOS: LND instalado, Node.js, permissões sudo
#    INTEGRAÇÃO: Gerenciador de senhas, cron jobs, systemd
#
# 3. configure_bos_telegram()
#    DESCRIÇÃO: Configura bot Telegram para Balance of Satoshis
#    FUNCIONALIDADE:
#    - Verifica se BOS está instalado (pré-requisito)
#    - Instala qrencode para geração de QR codes
#    - Interface guiada para criação de bot via @BotFather
#    - Validação automática de API Key do Telegram
#    - Geração de QR codes para facilitar acesso mobile
#    - Captura automática do Telegram ID do usuário
#    - Armazenamento seguro de credenciais no gerenciador de senhas
#    - Criação e configuração de serviço systemd (bos-telegram)
#    - Envio automático de mensagem de boas-vindas
#    - Interface visual completa com cores e formatação
#    REQUERIMENTOS: BOS instalado, conexão internet, Telegram
#    INTEGRAÇÃO: Password manager, systemd services, Telegram API
#
# 4. setup_lightning_monitor()
#    DESCRIÇÃO: Configura monitor Lightning Network com Flask
#    FUNCIONALIDADE:
#    - Cria ambiente virtual Python para Flask API
#    - Ativa ambiente virtual automaticamente
#    - Instala dependências Flask do requirements.txt
#    - Configura serviço systemd lightning-monitor
#    - Habilita serviço para inicialização automática
#    REQUERIMENTOS: Python3, pip, venv
#    INTEGRAÇÃO: Flask API, systemd
#
# 5. install_brln_api()
#    DESCRIÇÃO: Instala API BRLN completa com gRPC
#    FUNCIONALIDADE:
#    - Executa setup_lightning_monitor() para base Flask
#    - Instala dependências gRPC (grpcio, grpcio-tools)
#    - Gera arquivos Python gRPC a partir de arquivos .proto
#    - Configura serviço systemd brln-api
#    - Habilita API para inicialização automática
#    REQUERIMENTOS: Flask environment, proto files
#    INTEGRAÇÃO: gRPC, protobuf, systemd, Flask
#
# 6. install_lndg()
#    DESCRIÇÃO: Instala LNDg - Dashboard web completo para Lightning Node
#    FUNCIONALIDADE:
#    - Verifica se LND está instalado (pré-requisito obrigatório)
#    - Instala dependências sistema (python3, pip, virtualenv, git)
#    - Clona repositório oficial LNDg do GitHub
#    - Cria ambiente virtual Python isolado
#    - Instala todas as dependências Python do requirements.txt
#    - Instala whitenoise para servir arquivos estáticos
#    - Inicializa configurações Django com whitenoise
#    - Gera senha de admin automaticamente
#    - Armazena credenciais no gerenciador de senhas seguro
#    - Cria dois serviços systemd (lndg e lndg-controller)
#    - Configura arquivos de log com permissões corretas
#    - Inicia serviços e verifica funcionamento
#    - Fornece informações completas de acesso (URL, usuário, senha)
#    - Interface visual detalhada com todas as informações necessárias
#    REQUERIMENTOS: LND instalado, Python3, Git, permissões sudo
#    INTEGRAÇÃO: Django, systemd, password manager, GitHub
#    PORTAS: 8889 (interface web)
#    USUÁRIO: lndg-admin
#
# ============================================================================
# FLUXO DE INSTALAÇÃO RECOMENDADO:
# ============================================================================
# 1. Instalar LND (pré-requisito para BOS e LNDg)
# 2. install_nodejs() - se necessário
# 3. install_bos() - ferramentas avançadas LND
# 4. configure_bos_telegram() - notificações mobile
# 5. install_lndg() - dashboard web completo
# 6. setup_lightning_monitor() - monitoramento API
# 7. install_brln_api() - API completa com gRPC
#
# ============================================================================
# INTEGRAÇÃO COM SISTEMA BRLN-OS:
# ============================================================================
# - Todas as funções utilizam configurações globais (config.sh)
# - Senhas e credenciais armazenadas no gerenciador seguro
# - Serviços systemd para execução automática
# - Logs centralizados e padronizados
# - Interface visual consistente com cores e emojis
# - Verificações de pré-requisitos em todas as instalações
# - Suporte a diferentes redes Bitcoin (mainnet/testnet)
# - Integração com sistema de permissões e usuários
#
# ============================================================================
# PORTAS E SERVIÇOS:
# ============================================================================
# - LNDg Dashboard: 8889 (HTTP)
# - Flask API: Configurável via environment
# - gRPC API: Configurável via proto files
# - Telegram Bot: Sem porta (usa Telegram API)
# - BOS: Command line + cron jobs
#
# ============================================================================