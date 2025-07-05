#!/bin/bash
source ~/brlnfullauto/shell/.env

install_thunderhub() {
  if [[ -d ~/thunderhub ]]; then
    echo "ThunderHub já está instalado."
  else
  node -v
  npm -v
  sudo apt update && sudo apt full-upgrade -y
  cd
  curl https://github.com/apotdevin.gpg | gpg --import
  git clone --branch v$VERSION_THUB https://github.com/apotdevin/thunderhub.git && cd thunderhub
  git verify-commit v$VERSION_THUB
  npm install
  npm run build
  sudo ufw allow from $subnet to any port 3000 proto tcp comment 'allow ThunderHub SSL from local network'
  cp /home/admin/thunderhub/.env /home/admin/thunderhub/.env.local
  sed -i '51s|.*|ACCOUNT_CONFIG_PATH="/home/admin/thunderhub/thubConfig.yaml"|' /home/admin/thunderhub/.env.local
  bash -c "cat <<EOF > thubConfig.yaml
masterPassword: '$thub_senha'
accounts:
  - name: 'BRLNBolt'
    serverUrl: '127.0.0.1:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: '$thub_senha'
EOF"
  sudo cp $SERVICES_DIR/thunderhub.service /etc/systemd/system/thunderhub.service
  sudo systemctl start thunderhub.service
  sudo systemctl enable thunderhub.service
  fi
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

install_thunderhub
bash ~/brlnfullauto/shell/menu.sh