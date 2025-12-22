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
  if sudo systemctl is-active --quiet brln-frontend 2>/dev/null; then
    echo "⏹️ Parando serviço Next.js frontend..."
    sudo systemctl stop brln-frontend 2>/dev/null || true
    sudo systemctl disable brln-frontend 2>/dev/null || true
  fi

  # Configurar Apache Web Server
  setup_apache_web

  # Install/Update systemd service
  echo "Configurando serviço systemd..."
  # Skip brln-frontend.service since we're using Apache
  # safe_cp "$SERVICES_DIR/brln-frontend.service" /etc/systemd/system/brln-frontend.service
  # sudo systemctl daemon-reload

  # Garante que o pacote python3-venv esteja instalado (still needed for control scripts)
  if ! dpkg -l | grep -q python3-venv; then
    sudo apt install python3-venv -y >> /dev/null 2>&1 & spinner
  else
    echo "✅ python3-venv já está instalado."
  fi

  # Define o diretório do ambiente virtual
  FLASKVENV_DIR="$HOME/envflask"

  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instalar dependências Python se requirements.txt existir
  if [[ -f "$REPO_DIR/api/v1/requirements.txt" ]]; then
    pip install -r "$REPO_DIR/api/v1/requirements.txt" >> /dev/null 2>&1 & spinner
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
  if ! crontab -l 2>/dev/null | grep -Fq "$crontab_entry"; then
    (crontab -l 2>/dev/null; echo "$crontab_entry") | crontab -
    echo "📅 Crontab configurado para atualizações automáticas"
  else
    echo "✅ A entrada do crontab já existe. Nenhuma alteração feita."
  fi
  
  echo -e "${GREEN}✅ Sistema atualizado e configurado!${NC}"
}

install_tor() {
  echo -e "${GREEN}🧅 Instalando Tor...${NC}"
  
  # Add Tor repository
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates
  
  # Add GPG key
  wget -qO- $TOR_GPGLINK | gpg --dearmor | sudo tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
  
  # Add repository
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tor.list
  
  # Install Tor
  sudo apt update
  sudo apt install -y tor deb.torproject.org-keyring
  
  # Enable and start Tor
  sudo systemctl enable tor
  sudo systemctl start tor
  
  echo -e "${GREEN}✅ Tor instalado e iniciado!${NC}"
}

tailscale_vpn() {
  echo -e "${GREEN}🔒 Instalando Tailscale VPN...${NC}"
  
  # Download and install Tailscale
  curl -fsSL https://tailscale.com/install.sh | sh
  
  echo -e "${GREEN}✅ Tailscale instalado!${NC}"
  echo -e "${BLUE}💡 Execute 'sudo tailscale up' para conectar à sua rede Tailscale${NC}"
}