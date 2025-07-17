#!/bin/bash

# Source das funções básicas
source "$(dirname "$0")/scripts/basic.sh"
basics

INSTALL_DIR="/home/$USER/brln-os"

# Função para aguardar liberação do lock do apt
wait_for_apt_lock() {
    local max_wait=300  # 5 minutos máximo
    local waited=0
    
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            error "Timeout aguardando liberação do lock do apt (${max_wait}s)"
            error "Forçando limpeza dos locks..."
            
            # Terminar processos apt/dpkg travados
            sudo pkill -f "apt|dpkg" 2>/dev/null || true
            sleep 2
            
            # Remover locks
            sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock
            
            # Reconfigurar dpkg
            sudo dpkg --configure -a
            break
        fi
        
        log "Aguardando liberação do lock do apt... (${waited}s/${max_wait}s)"
        sleep 5
        waited=$((waited + 5))
    done
}

# Função para executar comandos apt com retry
safe_apt() {
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        wait_for_apt_lock
        
        if sudo "$@"; then
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                warning "Comando falhou, tentando novamente... (tentativa $retry/$max_retries)"
                sleep 10
            fi
        fi
    done
    
    error "Comando falhou após $max_retries tentativas: $*"
    return 1
}

log "Iniciando a Instalação do BRLN-OS..."
log "Atualizando repositórios e instalando dependências..."

safe_apt apt update
safe_apt apt upgrade -y
safe_apt apt install -y docker-compose

# Verificar e adicionar usuário ao grupo docker no início para evitar problemas de permissão
if command -v docker &> /dev/null; then
    if ! groups $USER | grep -q docker; then
        log "Adicionando usuário $USER ao grupo docker..."
        sudo usermod -aG docker $USER
        log "Usuário adicionado ao grupo docker. Aplicando as mudanças de grupo..."
        exec sg docker "$0 $*"
    fi
fi

# Verificar se estamos no diretório correto
if [[ ! -d "container" ]]; then
    error "Diretório 'container' não encontrado!"
    error "Execute este script no diretório raiz do projeto brlnfullauto"
    echo ""
    echo "Exemplo:"
    echo "  git clone https://github.com/pagcoinbr/brln-os.git"
    echo "  cd brlnfullauto"
    echo "  ./setup.sh"
    exit 1
fi

# Verificar se o script principal existe
if [[ ! -f "container/setup-docker-smartsystem.sh" ]]; then
    error "Script setup-docker-smartsystem.sh não encontrado em container/"
    exit 1
fi

# Verificar pré-requisitos
log "Verificando pré-requisitos do sistema..."

# Verificar se é Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    warning "Este script foi otimizado para Linux. Pode não funcionar corretamente em outros sistemas."
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    warning "Docker não encontrado!"
    echo ""
    echo "Para instalar o Docker, execute:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo ""
    read -p "Deseja que eu instale o Docker automaticamente? y/N: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker..."
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
        log "Docker instalado! Você pode precisar fazer logout/login para usar sem sudo"
    else
        error "Docker é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    log "Docker encontrado: v$DOCKER_VERSION ✓"
fi

# Verificar Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    warning "Docker Compose não encontrado!"
    echo ""
    echo "Para instalar o Docker Compose, execute:"
    echo "  sudo apt-get update && sudo apt-get install docker-compose-plugin"
    echo ""
    read -p "Deseja que eu instale o Docker Compose automaticamente? y/N: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Instalando Docker Compose..."
        sudo apt-get update && sudo apt-get install -y docker-compose-plugin
        log "Docker Compose instalado! ✓"
    else
        error "Docker Compose é obrigatório. Instale-o antes de continuar."
        exit 1
    fi
else
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        log "Docker Compose encontrado: v$COMPOSE_VERSION ✓"
    else
        COMPOSE_VERSION=$(docker compose version --short)
    log "Docker Compose plugin encontrado: v$COMPOSE_VERSION ✓"
    fi
fi

# Verificar espaço em disco
log "Verificando espaço em disco..."
AVAILABLE_SPACE=$(df . | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [[ $AVAILABLE_GB -lt 100 ]]; then
    warning "Espaço em disco baixo: ${AVAILABLE_GB}GB disponível"
    warning "Recomendado: pelo menos 1000GB para blockchain completa"
    echo ""
    read -p "Deseja continuar mesmo assim? y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Operação cancelada pelo usuário"
        exit 1
    fi
else
    log "Espaço em disco suficiente: ${AVAILABLE_GB}GB ✓"
fi

# Verificar permissões nos scripts
log "Configurando permissões dos scripts..."
chmod +x container/setup-docker-smartsystem.sh
if [[ -f "container/build.sh" ]]; then
    chmod +x container/build.sh
fi

# Verificar se há containers ativos e parar se necessário
if [[ $(docker ps -q | wc -l) -gt 0 ]]; then
    warning "Existem containers Docker ativos. Parando todos os containers..."
    echo "Este processo pode apagar os volumes de projetos em execução, tenha cuidado ao prosseguir."
    read -p "Deseja continuar e parar todos os containers? y/N: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operação cancelada pelo usuário.${NC}"
        exit 1
    else
        log "Parando todos os containers e removendo volumes..."
        cd container || exit 1
        docker-compose down -v
        cd - || exit 1
        log "Todos os containers foram parados e volumes removidos."
    fi
fi

sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd,docker $USER

# Clone repository if it doesn't exist
if [[ ! -d "/root/brln-os" ]]; then
  echo -e "${BLUE}Clonando repositório BRLN-OS...${NC}"
  if sudo git clone https://github.com/pagcoinbr/brln-os.git /$USER/brln-os 2>&1; then
    echo -e "${GREEN}Repositório clonado com sucesso.${NC}"
  else
    echo -e "${RED}Erro ao clonar o repositório BRLN-OS.${NC}"
    exit 1
  fi
fi

tailscale_vpn() {
  echo -e "${CYAN}🌐 Instalando Tailscale VPN...${NC}"
  curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
  safe_apt apt install -y qrencode

  LOGFILE="/tmp/tailscale_up.log"
  QRFILE="/tmp/tailscale_qr.log"

  sudo rm -f "$LOGFILE" "$QRFILE"
  sudo touch "$LOGFILE"
  sudo chmod 666 "$LOGFILE"

  echo -e "${BLUE}▶️ Executando 'tailscale up'...${NC}"
  (sudo tailscale up > "$LOGFILE" 2>&1) &

  echo -e "${YELLOW}⏳ Aguardando link de autenticação do Tailscale (sem timeout)...${NC}"
  echo -e "${YELLOW} Caso esta etapa não progrida em 5 minutos, pressione Ctrl+C e faça ${RED}"tailscale up"${NC}"

  while true; do
    url=$(grep -Eo 'https://login\.tailscale\.com/[a-zA-Z0-9/]+' "$LOGFILE" | head -n1)
    if [[ -n "$url" ]]; then
      echo -e "${GREEN}✅ Link encontrado: $url${NC}"
      echo "$url" | qrencode -t ANSIUTF8 | tee "$QRFILE"
      echo -e "${GREEN}🔗 QR Code salvo em: $QRFILE${NC}"
      break
    fi
    sleep 1
  done
  opening
}

opening () {
  clear
  
  echo
  echo -e "${GREEN}✅ Interface gráfica instalada com sucesso! 🎉${NC}"
  echo -e "${GREEN}⚡️ Pronto! Seu node está no ar, seguro e soberano... ou quase. 😏${NC}"
  echo -e "${GREEN}🤨 Mas me diz... ainda vai confiar seus sats na mão dos outros?${NC}"
  echo -e "${GREEN}🚀 Rodar o próprio node é só o primeiro passo rumo à liberdade financeira.${NC}"
  echo -e "${GREEN}🌐 Junte-se aos que realmente entendem soberania: 👉${BLUE} https://br-ln.com${NC}"
  echo -e "${GREEN}🔥 Na BR⚡LN a gente não confia... a gente verifica, roda, automatiza e ensina!${NC}"
  echo -e "${GREEN} Acesse seu ${YELLOW}Node Lightning${NC}${GREEN} pelo navegador em:${NC}"
  echo
  clear
  echo -e "${CYAN}"
  echo "$BRLN_ASCII_FULL"
  echo -e "${GREEN}"
  echo "$BRLN_OS_ASCII"
  echo -e "${YELLOW}"
  echo "$LIGHTNING_BOLT"
  echo -e "${NC}"
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  log "🎯 Instalação Completa!"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  log "🎉 Configuração concluída!"
  echo ""
  info "📱 Interfaces web disponíveis:"
  echo "  • LNDG Dashboard: http://localhost:8889"
  echo "  • Thunderhub: http://localhost:3000"
  echo "  • LNbits: http://localhost:5000"
  echo "  • PeerSwap Web: http://localhost:1984"
  echo ""
  info "📋 Comandos úteis:"
  echo "  Estes comandos precisam ser executados no diretório 'container':"
  echo "  • Ver logs: docker logs [serviço] -f"
  echo "  • Reiniciar: docker restart [serviço]"
  echo "  • Status: docker ps"
  echo ""
  warning "🔒 Altere as senhas padrão antes de usar em produção!"
  echo ""
  info "🔑 Senhas configuradas:"
  echo "  • LNbits: Acesse http://localhost:5000 e crie o super usuário agora"
  echo "  • Thunderhub: Configurada durante o setup (verifique container/thunderhub/thubConfig.yaml)"
  echo "  • RPC Bitcoin: Gerada no container/bitcoin/bitcoin.conf pelo rpcauth.py"
  echo "  • RPC Elements: Definida no container/elements/elements.conf"
  echo ""
  echo -e "${RED} http://$(hostname -I | awk '{print $1}') ${NC}"
  echo
  echo -e "${RED} Ou escaneie o QR Code abaixo para conectar sua tailnet: ${NC}"
  echo
  echo -e "${GREEN}✅ Link encontrado: ${RED} $url${NC}"
  echo "$url" | qrencode -t ANSIUTF8
  echo
  echo -e "${GREEN} Em seguida escolha ${YELLOW}\"Configurações\"${NC}${GREEN} e depois ${YELLOW}\"Iniciar BrlnFullAuto\" ${NC}"
  echo
  echo
}

terminal_web() {
  echo -e "${GREEN} Iniciando... ${NC}"
  if [[ ! -f /usr/local/bin/gotty ]]; then
    update_and_upgrade
    radio_update
    gotty_install
    sudo chown -R $USER:$USER /var/www/html/radio
    sudo chmod +x /var/www/html/radio/radio-update.sh
    sudo chmod +x /home/$USER/brln-os/html/radio/radio-update.sh
    tailscale_vpn
    opening
    exit 0
  else
    echo -e "${GREEN} Interface gráfica já instalada, acesse seu navegador utilizando o ip da sua maquina e pressione em BRLN Node Manager. ${NC}"
    exit 0
  fi
}

update_and_upgrade() {
  app="Interface Gráfica"
  echo "Instalando Apache..."
  sudo -v
  sudo apt install apache2 -y >> /dev/null 2>&1 & spinner
  echo "Habilitando módulos do Apache..."
  sudo a2enmod cgid dir >> /dev/null 2>&1 & spinner
  echo "Reiniciando o serviço Apache..."
  sudo systemctl restart apache2 >> /dev/null 2>&1 & spinner

  sudo rm -rf "$WWW_HTML"/*.html
  sudo rm -rf "$WWW_HTML/css"
  sudo rm -rf "$WWW_HTML/js"
  sudo rm -rf "$WWW_HTML/imagens"
  sudo rm -rf "$WWW_HTML/radio"
  sudo rm -rf "$CGI_DST"/*.sh

  echo "📥 Copiando novos arquivos da interface web..."

  # Copia os HTMLs principais
  sudo cp "$HTML_SRC"/*.html "$WWW_HTML/"

  # Copia pastas CSS, JS, Imagens
  sudo cp -r "$HTML_SRC/css" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/js" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/imagens" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/radio" "$WWW_HTML/"

  # Copia scripts CGI para /usr/lib/cgi-bin
  sudo cp "$HTML_SRC/cgi-bin/"*.sh "$CGI_DST/"

  # Corrigir permissões de execução
  sudo chmod +x "$CGI_DST"/*.sh
  for script in "$CGI_DST"/*.sh; do
    sudo chmod +x "$script"
  done

  # Configurar o Apache para permitir CGI no diretório correto
  if ! grep -q 'Directory "/usr/lib/cgi-bin"' "/etc/apache2/sites-enabled/000-default.conf"; then
    echo "Adicionando bloco de configuração CGI ao Apache..."
    sudo sed -i '/<\/VirtualHost>/i \
    <Directory "/usr/lib/cgi-bin">\n\
      AllowOverride None\n\
      Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch\n\
      Require all granted\n\
      AddHandler cgi-script .sh\n\
    </Directory>\n' "/etc/apache2/sites-enabled/000-default.conf"
  else
    echo "Bloco de configuração CGI já existe no Apache."
  fi

  # Gerar sudoers dinâmico com todos os scripts .sh do cgi-bin
  SCRIPT_LIST=$(sudo find "$CGI_DST" -maxdepth 1 -type f -name "*.sh" | sort | tr '\n' ',' | sed 's/,$//')

  if [ -n "$SCRIPT_LIST" ]; then
    sudo tee /etc/sudoers.d/www-data-scripts > /dev/null <<EOF
www-data ALL=(ALL) NOPASSWD: $SCRIPT_LIST
EOF
  fi
  # Abre a posta 80 no UFW
  if ! sudo ufw status | grep -q "80/tcp"; then
    sudo ufw allow from $subnet to any port 80 proto tcp comment 'allow Apache from local network'
  fi
  sudo usermod -aG $USER www-data
  # Garante que o pacote python3-venv esteja instalado
  if ! dpkg -l | grep -q python3-venv; then
    sudo apt install python3-venv -y # >> /dev/null 2>&1 & spinner
  else
    echo "✅ python3-venv já está instalado."
  fi

  # Define o diretório do ambiente virtual
  FLASKVENV_DIR="/home/$USER/envflask"

  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" # >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  # Ativa o ambiente virtual
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instala Flask e Flask-CORS
  pip install flask flask-cors # >> /dev/null 2>&1 & spinner
  sudo -u $USER bash setup_lnd_client.sh 

  # 🛡️ Caminho seguro para o novo arquivo dentro do sudoers.d
  SUDOERS_TMP="/etc/sudoers.d/$USER-services"

  # 📝 Criação segura do arquivo usando here-document
  sudo tee "$SUDOERS_TMP" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start control-systemd.service, /usr/bin/systemctl stop control-systemd.service, /usr/bin/systemctl start command-center.service, /usr/bin/systemctl stop command-center.service, /usr/bin/systemctl start gotty-fullauto.service, /usr/bin/systemctl stop gotty-fullauto.service
EOF

  # ✅ Valida se o novo arquivo sudoers é válido
  if sudo visudo -c -f "$SUDOERS_TMP"; then
    sleep 1
  else
    echo "⛔ Erro na validação! Arquivo inválido, removendo."
    sudo rm -f "$SUDOERS_TMP"
    exit 1
  fi
  sudo systemctl restart apache2
  sudo apt install -y python3-flask # >> /dev/null 2>&1 & spinner
}

gotty_do () {
  echo -e "${GREEN} Instalando Interface gráfica... ${NC}"
  LOCAL_APPS="/home/$USER/brln-os/local_apps"
  if [[ $arch == "x86_64" ]]; then
    sudo tar -xvzf "$LOCAL_APPS/gotty/gotty_2.0.0-alpha.3_linux_amd64.tar.gz" -C /home/$USER >> /dev/null 2>&1
  else
    sudo tar -xvzf "$LOCAL_APPS/gotty/gotty_2.0.0-alpha.3_linux_arm.tar.gz" -C /home/$USER >> /dev/null 2>&1
  fi
  # Move e torna executável
  sudo mv /home/$USER/gotty /usr/local/bin/gotty
  sudo chmod +x /usr/local/bin/gotty
}

gotty_install () {
if [[ ! -f /usr/local/bin/gotty ]]; then
  gotty_do
else
  echo -e "${GREEN} Gotty já instalado, atualizando... ${NC}"
  sudo rm -f /usr/local/bin/gotty
  gotty_do
fi

# Define arrays for services and ports
SERVICES=("gotty-fullauto" "gotty-logs-lnd" "gotty-logs-elements" "gotty-logs-bitcoind" "control-systemd")
PORTS=("3131" "3232" "5001")
COMMENTS=("allow BRLNfullauto on port 3131 from local network" 
  "allow cli on port 3232 from local network" 
  "allow control-systemd on port 5001 from local network")

# Remove and copy service files
for service in "${SERVICES[@]}"; do
  sudo rm -f /etc/systemd/system/$service.service
  sudo cp /home/$USER/brln-os/services/$service.service /etc/systemd/system/$service.service
done

# Reload systemd and enable/start services
sudo systemctl daemon-reload
for service in "${SERVICES[@]}"; do
  if ! sudo systemctl is-enabled --quiet $service.service; then
    sudo systemctl enable $service.service # >> /dev/null 2>&1
    sudo systemctl restart $service.service # >> /dev/null 2>&1 & spinner
  fi
done
sudo bash "$INSTALL_DIR/scripts/generate-services.sh"
}
terminal_web

bash "$INSTALL_DIR/brunel.sh"
exit 0
