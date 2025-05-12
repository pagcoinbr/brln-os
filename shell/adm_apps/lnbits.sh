#!/bin/bash
source ~/brlnfullauto/shell/.env

lnbits_install() {
  # Atualiza e instala dependências básicas
  sudo apt install -y pkg-config libsecp256k1-dev libffi-dev build-essential python3-dev git curl

  # Instala Poetry (não precisa ativar venv manual)
  curl -sSL https://install.python-poetry.org | python3 -
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "/home/admin/.bashrc"
  export PATH="$HOME/.local/bin:$PATH"

  # Verifica versão do Poetry
  "$POETRY_BIN" self update || true
  "$POETRY_BIN" --version

  # Clona o repositório LNbits
  git clone https://github.com/lnbits/lnbits.git "/home/admin/lnbits"
  sudo chown -R admin:admin "/home/admin/lnbits"

  # Entra no diretório e instala dependências com Poetry
  cd "/home/admin/lnbits"
  git checkout  v0.12.12
  "$POETRY_BIN" install

  # Copia o arquivo .env e ajusta a variável LNBITS_ADMIN_UI
  cp .env.example .env
  sed -i 's/LNBITS_ADMIN_UI=.*/LNBITS_ADMIN_UI=true/' .env

  # Configurações do lnbits no ufw
  sudo ufw allow from $subnet to any port 5000 proto tcp comment 'allow LNbits from local network'

  # Configura systemd
  sudo cp $SERVICES_DIR/lnbits.service /etc/systemd/system/lnbits.service

  # Ativa e inicia o serviço
  sudo systemctl daemon-reload
  sudo systemctl enable lnbits.service
  sudo systemctl start lnbits.service

  echo "✅ LNbits instalado e rodando como serviço systemd!"
  sudo rm -rf /home/admin/lnd-install
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

lnbits_install
bash ~/brlnfullauto/shell/menu.sh