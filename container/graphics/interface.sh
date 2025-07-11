#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Define default paths and variables
REPO_DIR="/home/$USER/brlnfullauto"
WWW_HTML="/var/www/html"
HTML_SRC="/home/$USER/brlnfullauto/container/graphics/html"
CGI_DST="/usr/lib/cgi-bin"
LOCAL_APPS="/home/$USER/brlnfullauto/container/graphics"
FLASKVENV_DIR="/home/$USER/brlnfullauto/container/graphics"
SUDOERS_TMP="/etc/sudoers.d/brln-$USER"
subnet="192.168.0.0/16"

# Detect system architecture
arch=$(uname -m)

# Define service arrays - using the actual service files that exist
SERVICES=("gotty-btc-editor" "gotty-fullauto" "gotty-lnd-editor" "gotty-logs-bitcoind" "gotty-logs-lnd" "gotty")
PORTS=("8080" "8081" "8082" "8083" "8084" "3232")
COMMENTS=("GoTTY BTC Editor" "GoTTY Full Auto" "GoTTY LND Editor" "GoTTY Logs Bitcoind" "GoTTY Logs LND" "GoTTY Terminal")

# Function to find missing files in user home directory
find_missing_file() {
    local target_file="$1"
    local search_filename="$(basename "$target_file")"
    
    if [[ -f "$target_file" ]]; then
        echo "$target_file"
        return 0
    fi
    
    echo "⚠️  Arquivo não encontrado: $target_file" >&2
    echo "🔍 Procurando $search_filename na home do usuário..." >&2
    
    # Search in current user's home and common locations
    local found_file=""
    
    # Try to find in user homes
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            found_file=$(find "$user_home" -name "$search_filename" -type f 2>/dev/null | head -n1)
            if [[ -n "$found_file" ]]; then
                echo "✅ Encontrado: $found_file" >&2
                echo "$found_file"
                return 0
            fi
        fi
    done
    
    # Try common system locations
    found_file=$(find /opt /usr/local /var -name "$search_filename" -type f 2>/dev/null | head -n1)
    if [[ -n "$found_file" ]]; then
        echo "✅ Encontrado: $found_file" >&2
        echo "$found_file"
        return 0
    fi
    
    echo "❌ Arquivo $search_filename não foi encontrado no sistema" >&2
    return 1
}

# Function to resolve and update paths dynamically
resolve_paths() {
    echo "🔍 Verificando e resolvendo caminhos de arquivos..."
    
    # Update REPO_DIR if current path doesn't exist
    if [[ ! -d "$REPO_DIR" ]]; then
        local found_repo=$(find /home -name "brlnfullauto" -type d 2>/dev/null | head -n1)
        if [[ -n "$found_repo" ]]; then
            REPO_DIR="$found_repo"
            echo "✅ REPO_DIR atualizado para: $REPO_DIR"
        fi
    fi
    
    # Update HTML_SRC based on REPO_DIR
    HTML_SRC="$REPO_DIR/container/graphics/html"
    
    # Update LOCAL_APPS based on REPO_DIR
    LOCAL_APPS="$REPO_DIR/container/graphics"
    
    # Update FLASKVENV_DIR based on REPO_DIR
    FLASKVENV_DIR="$REPO_DIR/container/graphics"
    
    echo "📁 Caminhos resolvidos:"
    echo "   REPO_DIR: $REPO_DIR"
    echo "   HTML_SRC: $HTML_SRC"
    echo "   LOCAL_APPS: $LOCAL_APPS"
    echo "   FLASKVENV_DIR: $FLASKVENV_DIR"
}

# Function to validate all required files before starting
validate_required_files() {
    echo "🔍 Validando arquivos necessários..."
    local missing_files=()
    local warnings=()
    
    # Critical files that are required
    local critical_files=(
        "$REPO_DIR/container/graphics/control-systemd.py"
        "$HTML_SRC/index.html"
        "$HTML_SRC/main.html"
    )
    
    # Optional files that will show warnings if missing
    local optional_files=(
        "$LOCAL_APPS/requirements.txt"
        "$LOCAL_APPS/gotty_2.0.0-alpha.3_linux_amd64.tar.gz"
        "$LOCAL_APPS/gotty_2.0.0-alpha.3_linux_arm.tar.gz"
        "$REPO_DIR/html/radio/radio-update.sh"
    )
    
    # Add service files to optional list
    for service in "${SERVICES[@]}"; do
        optional_files+=("$REPO_DIR/container/graphics/$service.service")
    done
    
    # Check critical files
    for file in "${critical_files[@]}"; do
        if ! find_missing_file "$file" >/dev/null 2>&1; then
            missing_files+=("$file")
        fi
    done
    
    # Check optional files
    for file in "${optional_files[@]}"; do
        if ! find_missing_file "$file" >/dev/null 2>&1; then
            warnings+=("$file")
        fi
    done
    
    # Report results
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo "❌ Arquivos críticos não encontrados:"
        for file in "${missing_files[@]}"; do
            echo "   • $file"
        done
        echo "⚠️  O script pode falhar devido a arquivos ausentes!"
        read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Operação cancelada pelo usuário"
            exit 1
        fi
    else
        echo "✅ Todos os arquivos críticos foram encontrados"
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "⚠️  Arquivos opcionais não encontrados (funcionalidade pode ser limitada):"
        for file in "${warnings[@]}"; do
            echo "   • $(basename "$file")"
        done
    fi
    
    echo "🚀 Prosseguindo com a instalação..."
    echo
}

terminal_web() {
    resolve_paths
    validate_required_files
    apache_install
    radio_update
    sudo chown -R $USER:$USER /var/www/html/radio
    
    # Use find_missing_file for radio-update.sh paths
    local default_radio_web="/var/www/html/radio/radio-update.sh"
    local radio_web=$(find_missing_file "$default_radio_web" 2>/dev/null)
    if [[ -n "$radio_web" && -f "$radio_web" ]]; then
        sudo chmod +x "$radio_web"
    fi
    
    local default_radio_html="$REPO_DIR/html/radio/radio-update.sh"
    local radio_html=$(find_missing_file "$default_radio_html" 2>/dev/null)
    if [[ -n "$radio_html" && -f "$radio_html" ]]; then
        sudo chmod +x "$radio_html"
    fi
    
    gotty_install
    tailscale_vpn
    opening
    exit 0
}

radio_update () {
  # Caminho do script que deve rodar a cada hora
  local default_script_radio="/home/$USER/brlnfullauto/html/radio/radio-update.sh"
  script_radio=$(find_missing_file "$default_script_radio" 2>/dev/null)
  
  if [[ -z "$script_radio" || ! -f "$script_radio" ]]; then
    echo "⚠️  Script radio-update.sh não encontrado, pulando configuração do cron"
    return 1
  fi

  # Linha que será adicionada ao crontab
  CRON_LINE="0 * * * * $script_radio >> /var/log/update_radio.log 2>&1"

  # Verifica se já existe no crontab
  if [ ! -f /var/log/update_radio.log ]; then
    sudo touch /var/log/update_radio.log
    sudo chown $USER:$USER /var/log/update_radio.log
    sudo chmod 666 /var/log/update_radio.log
  fi
  crontab -l 2>/dev/null | grep -F "$script_radio" > /dev/null
  if [ $? -eq 0 ]; then
    echo "✅ A entrada do crontab já existe. Nenhuma alteração feita."
  else
    echo "➕ Adicionando entrada ao crontab..."
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "✅ Entrada adicionada com sucesso!"
  fi
  sudo chmod +x "$script_radio"
}

apache_install() {
  app="Interface Gráfica"
  echo "Instalando Apache..."
  sudo -v
  sudo apt install apache2 -y >> /dev/null 2>&1 & spinner
  echo "Habilitando módulos do Apache..."
  sudo a2enmod cgid dir >> /dev/null 2>&1 & spinner
  echo "Reiniciando o serviço Apache..."
  sudo systemctl restart apache2

  echo -e "🗑️ Limpando arquivos antigos da interface web..."
  sudo rm -rf "$WWW_HTML"/*.html
  sudo rm -rf "$WWW_HTML/css"
  sudo rm -rf "$WWW_HTML/js"
  sudo rm -rf "$WWW_HTML/imagens"
  sudo rm -rf "$WWW_HTML/radio"
  sudo rm -rf "$CGI_DST"/*.sh

  echo "📥 Copiando novos arquivos da interface web..."
  sudo cp "$HTML_SRC"/*.html "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/css" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/js" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/imagens" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/radio" "$WWW_HTML/"
  sudo cp "$HTML_SRC/cgi-bin/"*.sh "$CGI_DST/"

  # Copia o sistema de controle Flask atualizado
  echo "🐍 Copiando sistema de controle Flask..."
  local default_control_py="$REPO_DIR/container/graphics/control-systemd.py"
  local control_py=$(find_missing_file "$default_control_py" 2>/dev/null)
  
  if [[ -n "$control_py" && -f "$control_py" ]]; then
    sudo cp "$control_py" "$WWW_HTML/"
    sudo chown www-data:www-data "$WWW_HTML/control-systemd.py"
    sudo chmod +x "$WWW_HTML/control-systemd.py"
  else
    echo "⚠️  control-systemd.py não encontrado, continuando sem ele"
  fi

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
  # Abre a porta 80 no UFW
  if ! sudo ufw status | grep -q "80/tcp"; then
    sudo ufw allow from $subnet to any port 80 proto tcp comment 'allow Apache from local network'
  fi
  sudo usermod -aG $USER www-data
  # Garante que o pacote python3-venv esteja instalado
  if ! dpkg -l | grep -q python3-venv; then
    sudo apt install python3-venv -y >> /dev/null 2>&1 & spinner
  else
    echo "✅ python3-venv já está instalado."
  fi
  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  # Ativa o ambiente virtual
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instala Flask, Flask-CORS e Flask-SocketIO para WebSockets
  echo "📦 Instalando dependências Python..."
  
  # Try to use requirements.txt if available
  local default_requirements="$LOCAL_APPS/requirements.txt"
  local requirements_file=$(find_missing_file "$default_requirements")
  
  if [[ $? -eq 0 ]]; then
    echo "📋 Usando requirements.txt encontrado: $requirements_file"
    pip install -r "$requirements_file" >> /dev/null 2>&1 & spinner
  else
    echo "📦 Instalando dependências padrão do Flask..."
    pip install flask flask-cors flask-socketio >> /dev/null 2>&1 & spinner
  fi

  # 📝 Criação segura do arquivo usando here-document
  sudo tee "$SUDOERS_TMP" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start lnbits.service, /usr/bin/systemctl stop lnbits.service, /usr/bin/systemctl start thunderhub.service, /usr/bin/systemctl stop thunderhub.service, /usr/bin/systemctl start lnd.service, /usr/bin/systemctl stop lnd.service, /usr/bin/systemctl start lndg-controller.service, /usr/bin/systemctl stop lndg-controller.service, /usr/bin/systemctl start lndg.service, /usr/bin/systemctl stop lndg.service, /usr/bin/systemctl start simple-lnwallet.service, /usr/bin/systemctl stop simple-lnwallet.service, /usr/bin/systemctl start bitcoind.service, /usr/bin/systemctl stop bitcoind.service, /usr/bin/systemctl start bos-telegram.service, /usr/bin/systemctl stop bos-telegram.service, /usr/bin/systemctl start tor.service, /usr/bin/systemctl stop tor.service, /usr/bin/docker, /usr/bin/docker-compose
$USER ALL=(ALL) NOPASSWD: /usr/bin/python3 /var/www/html/control-systemd.py
www-data ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/docker-compose
www-data ALL=(ALL) NOPASSWD: /usr/bin/python3 /var/www/html/control-systemd.py
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
  sudo apt install -y python3-flask >> /dev/null 2>&1 & spinner
  
  # Configurar e iniciar o serviço Flask
  echo "🚀 Configurando serviço Flask..."
  setup_flask_service
}

setup_flask_service() {
  # Criar arquivo de serviço systemd para o Flask
  sudo tee /etc/systemd/system/brln-flask.service > /dev/null <<EOF
[Unit]
Description=BRLN Flask Control Service
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=/var/www/html
Environment="PATH=$FLASKVENV_DIR/bin"
ExecStart=$FLASKVENV_DIR/bin/python3 /var/www/html/control-systemd.py
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  # Habilitar e iniciar o serviço
  sudo systemctl daemon-reload
  sudo systemctl enable brln-flask.service
  sudo systemctl start brln-flask.service
  
  # Abrir porta 5001 para o Flask
  if ! sudo ufw status | grep -q "5001/tcp"; then
    sudo ufw allow from $subnet to any port 5001 proto tcp comment 'BRLN Flask Control API'
  fi
  
  echo "✅ Serviço Flask configurado e iniciado na porta 5001"
}

gotty_install () {
if [[ ! -f /usr/local/bin/gotty ]]; then
  gotty_do
fi

# Remove and copy service files
for service in "${SERVICES[@]}"; do
  sudo rm -f /etc/systemd/system/$service.service
  # First try the graphics directory where the services actually are
  local default_service="$REPO_DIR/container/graphics/$service.service"
  local service_file=$(find_missing_file "$default_service" 2>/dev/null)
  
  if [[ -n "$service_file" && -f "$service_file" ]]; then
    sudo cp "$service_file" /etc/systemd/system/$service.service
  else
    echo "⚠️  Arquivo de serviço $service.service não encontrado, pulando"
    continue
  fi
done

# Reload systemd and enable/start services
sudo systemctl daemon-reload
for service in "${SERVICES[@]}"; do
  if sudo systemctl list-unit-files | grep -q "$service.service"; then
    if ! sudo systemctl is-enabled --quiet $service.service; then
      sudo systemctl enable $service.service >> /dev/null 2>&1
      sudo systemctl restart $service.service >> /dev/null 2>&1 & spinner
    fi
  else
    echo "⚠️  Serviço $service.service não encontrado, pulando"
  fi
done

# Configure UFW rules for ports
for i in "${!PORTS[@]}"; do
  if ! sudo ufw status | grep -q "${PORTS[i]}/tcp"; then
    sudo ufw allow from $subnet to any port ${PORTS[i]} proto tcp comment "${COMMENTS[i]}" >> /dev/null 2>&1
  fi
done
}

gotty_do () {
  echo -e "${GREEN} Instalando Interface gráfica... ${NC}"
  
  local gotty_archive=""
  if [[ $arch == "x86_64" ]]; then
    local default_gotty="$LOCAL_APPS/gotty_2.0.0-alpha.3_linux_amd64.tar.gz"
    gotty_archive=$(find_missing_file "$default_gotty")
  else
    local default_gotty="$LOCAL_APPS/gotty_2.0.0-alpha.3_linux_arm.tar.gz"
    gotty_archive=$(find_missing_file "$default_gotty")
  fi
  
  if [[ $? -ne 0 ]]; then
    echo "❌ Arquivo gotty não encontrado, não é possível instalar a interface gráfica"
    return 1
  fi
  
  sudo tar -xvzf "$gotty_archive" -C /home/$USER >> /dev/null 2>&1
  sudo rm -f /usr/local/bin/gotty
  sudo cp /home/$USER/gotty /usr/local/bin/gotty
  sudo chmod +x /usr/local/bin/gotty
}

tailscale_vpn() {
  if tailscale status &>/dev/null; then
    echo -e "${GREEN}✅ Tailscale já está conectado. Pulando instalação.${NC}"
    exit 0
  else
    echo -e "${GREEN}⚡ Instalando Tailscale...${NC}"  
  fi
  echo -e "${CYAN}🌐 Instalando Tailscale VPN...${NC}"
  curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1 & spinner
  sudo apt install qrencode -y > /dev/null 2>&1 & spinner

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

spinner() {
    local pid=$!
    local delay=0.2
    local max=${SPINNER_MAX:-20}
    local count=0
    local spinstr='|/-\\'
    local j=0

    tput civis

    # Monitorar processo
    while kill -0 "$pid" 2>/dev/null; do
        local emoji=""
        for ((i=0; i<=count; i++)); do
            emoji+="⚡"
        done

        local spin_char="${spinstr:j:1}"
        j=$(( (j + 1) % 4 ))
        count=$(( (count + 1) % (max + 1) ))

        printf "\r\033[KInstalando seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
        sleep "$delay"
    done

    wait "$pid"
    exit_code=$?

    tput cnorm
    if [[ $exit_code -eq 0 ]]; then
        printf "\r\033[K${GREEN}✔️ Processo finalizado com sucesso!${NC}\n"
    else
        printf "\r\033[K${RED}❌ Processo finalizado com erro (código: $exit_code)${NC}\n"
    fi

    return $exit_code
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
  echo
  echo -e "${GREEN}📊 Acesse seu ${YELLOW}Node Lightning${NC}${GREEN} pelo navegador em:${NC}"
  echo -e "${RED} 🌐 Interface Web: http://$(hostname -I | awk '{print $1}') ${NC}"
  echo -e "${RED} 🐍 API Flask: http://$(hostname -I | awk '{print $1}'):5001 ${NC}"
  echo
  echo -e "${CYAN}🔧 Serviços disponíveis:${NC}"
  echo -e "${GREEN} • Interface Web Principal (Apache)${NC}"
  echo -e "${GREEN} • API de Controle Flask com WebSockets${NC}"
  echo -e "${GREEN} • Gerenciamento de Containers Docker${NC}"
  echo -e "${GREEN} • Monitoramento em Tempo Real${NC}"
  echo -e "${GREEN} • Ferramentas Lightning Network${NC}"
  echo
  echo -e "${RED} Ou escaneie o QR Code abaixo para conectar sua tailnet: ${NC}"
  echo
  echo -e "${GREEN}✅ Link encontrado: ${RED} $url${NC}"
  echo "$url" | qrencode -t ANSIUTF8
  echo
  echo -e "${GREEN} Em seguida escolha ${YELLOW}\"Configurações\"${NC}${GREEN} e depois ${YELLOW}\"Iniciar BrlnFullAuto\" ${NC}"
  echo
  echo -e "${YELLOW}💡 Dica: Use Ctrl+C para parar este script e 'sudo systemctl status brln-flask' para verificar o status do Flask${NC}"
  echo
}

# Validate required files before starting
validate_required_files

terminal_web