#!/bin/bash
# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/$USER/brln-os"

sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd,docker $USER

# Clone repository if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
  echo -e "${BLUE}Clonando repositório BRLN-OS...${NC}"
  if sudo -u $USER bash git clone https://github.com/pagcoinbr/brln-os.git /home/$USER/brln-os 2>&1; then
    echo -e "${GREEN}Repositório clonado com sucesso.${NC}"
  else
    echo -e "${RED}Erro ao clonar o repositório BRLN-OS.${NC}"
    exit 1
  fi
fi

# Ensure the brunel.sh script exists
if [[ ! -f "$INSTALL_DIR/brunel.sh" ]]; then
  echo -e "${RED}Erro: arquivo brunel.sh não encontrado em $INSTALL_DIR${NC}"
  exit 1
fi

tailscale_vpn() {
  echo -e "${CYAN}🌐 Instalando Tailscale VPN...${NC}"
  curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
  sudo apt install qrencode -y > /dev/null 2>&1

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

  # Executa o git dentro do diretório, sem precisar dar cd
  git -C "$REPO_DIR" stash || true
  git -C "$REPO_DIR" pull origin "$branch"

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
    sudo apt install python3-venv -y >> /dev/null 2>&1 & spinner
  else
    echo "✅ python3-venv já está instalado."
  fi

  # Define o diretório do ambiente virtual
  FLASKVENV_DIR="/home/$USER/envflask"

  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  # Ativa o ambiente virtual
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instala Flask e Flask-CORS
  pip install flask flask-cors >> /dev/null 2>&1 & spinner
  sudo -u $USER bash setup_lnd_client.sh 

  # 🛡️ Caminho seguro para o novo arquivo dentro do sudoers.d
  SUDOERS_TMP="/etc/sudoers.d/$USER-services"

  # 📝 Criação segura do arquivo usando here-document
  sudo tee "$SUDOERS_TMP" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start lnbits.service, /usr/bin/systemctl stop lnbits.service, /usr/bin/systemctl start thunderhub.service, /usr/bin/systemctl stop thunderhub.service, /usr/bin/systemctl start lnd.service, /usr/bin/systemctl stop lnd.service, /usr/bin/systemctl start lndg-controller.service, /usr/bin/systemctl stop lndg-controller.service, /usr/bin/systemctl start lndg.service, /usr/bin/systemctl stop lndg.service, /usr/bin/systemctl start simple-lnwallet.service, /usr/bin/systemctl stop simple-lnwallet.service, /usr/bin/systemctl start bitcoind.service, /usr/bin/systemctl stop bitcoind.service, /usr/bin/systemctl start bos-telegram.service, /usr/bin/systemctl stop bos-telegram.service, /usr/bin/systemctl start tor.service, /usr/bin/systemctl stop tor.service
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
SERVICES=("gotty-fullauto" "gotty-logs-lnd" "gotty-logs-bitcoind" "control-systemd")
PORTS=("3131" "3232" "3434" "3535" "3636" "3333" "5001")
COMMENTS=("allow BRLNfullauto on port 3131 from local network" 
  "allow cli on port 3232 from local network" 
  "allow bitcoinlogs on port 3434 from local network" 
  "allow lndlogs on port 3535 from local network"
  "allow btc-editor on port 3636 from local network"
  "allow lnd-editor on port 3333 from local network"
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
    sudo systemctl enable $service.service >> /dev/null 2>&1
    sudo systemctl restart $service.service >> /dev/null 2>&1 & spinner
  fi
done

# Configure UFW rules for ports
for i in "${!PORTS[@]}"; do
  if ! sudo ufw status | grep -q "${PORTS[i]}/tcp"; then
    sudo ufw allow from $subnet to any port ${PORTS[i]} proto tcp comment "${COMMENTS[i]}" >> /dev/null 2>&1
  fi
done
}

bash "$INSTALL_DIR/brunel.sh"
exit 0
