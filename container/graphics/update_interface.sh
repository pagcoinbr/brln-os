#!/bin/bash
source ~/brlnfullauto/shell/.env

apache_install() {
  app="Interface Gráfica"
  echo "Instalando Apache..."
  sudo -v
  sudo apt install apache2 -y >> /dev/null 2>&1 & spinner
  echo "Habilitando módulos do Apache..."
  sudo a2enmod cgid dir >> /dev/null 2>&1 & spinner
  echo "Reiniciando o serviço Apache..."
  sudo systemctl restart apache2

  # Executa o git dentro do diretório, sem precisar dar cd
  git -C "$REPO_DIR" stash || true
  git -C "$REPO_DIR" pull origin "$branch"

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
  sudo usermod -aG admin www-data
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

  # Instala Flask e Flask-CORS
  pip install flask flask-cors >> /dev/null 2>&1 & spinner

  # 📝 Criação segura do arquivo usando here-document
  sudo tee "$SUDOERS_TMP" > /dev/null <<EOF
admin ALL=(ALL) NOPASSWD: /usr/bin/systemctl start lnbits.service, /usr/bin/systemctl stop lnbits.service, /usr/bin/systemctl start thunderhub.service, /usr/bin/systemctl stop thunderhub.service, /usr/bin/systemctl start lnd.service, /usr/bin/systemctl stop lnd.service, /usr/bin/systemctl start lndg-controller.service, /usr/bin/systemctl stop lndg-controller.service, /usr/bin/systemctl start lndg.service, /usr/bin/systemctl stop lndg.service, /usr/bin/systemctl start simple-lnwallet.service, /usr/bin/systemctl stop simple-lnwallet.service, /usr/bin/systemctl start bitcoind.service, /usr/bin/systemctl stop bitcoind.service, /usr/bin/systemctl start bos-telegram.service, /usr/bin/systemctl stop bos-telegram.service, /usr/bin/systemctl start tor.service, /usr/bin/systemctl stop tor.service
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

gotty_install () {
# Remove and copy service files
for service in "${SERVICES[@]}"; do
  sudo rm -f /etc/systemd/system/$service.service
  sudo cp /home/admin/brlnfullauto/services/$service.service /etc/systemd/system/$service.service
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

apache_install
gotty_install

if [[ $? -ne 0 ]]; then
  echo "⛔ Erro ao atualizar a interface gráfica!"
  exit 1
else
  echo "✅ Interface gráfica atualizada com sucesso!"
fi