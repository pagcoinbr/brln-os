#!/bin/bash
source ~/brlnfullauto/shell/.env

get_simple_wallet () {
  cd ~
  arch=$(uname -m)
  if [[ $arch == "x86_64" ]]; then
    echo "Arquitetura x86_64 detectada."
    simple_arch="simple-lnwallet"
  else
    echo "Arquitetura ARM64 detectada."
    simple_arch="simple-lnwallet-rpi"
  fi
  if [[ -f /home/admin/$simple_arch ]]; then
    rm -rf /home/admin/$simple_arch
  fi
  cp /home/admin/brlnfullauto/local_apps/simple-lnwallet/$simple_arch /home/admin/
  if [[ -f /home/admin/simple-lnwallet-rpi ]]; then
  mv /home/admin/$simple_arch /home/admin/simple-lnwallet
  fi
  chmod +x /home/admin/$simple_arch
  sudo apt install xxd -y
}

simple_lnwallet () {
  get_simple_wallet
  sudo rm -f /etc/systemd/system/simple-lnwallet.service
  sudo cp ~/brlnfullauto/services/simple-lnwallet.service /etc/systemd/system/simple-lnwallet.service
  sleep 1
  sudo systemctl daemon-reload
  sleep 1
  sudo systemctl enable simple-lnwallet
  sudo systemctl start simple-lnwallet
  sudo ufw allow from $subnet to any port 35671 proto tcp comment 'allow Simple LNWallet from local network'
  echo
  echo -e "${YELLOW}📝 Copie o conteúdo do arquivo macaroon.hex e cole no campo macaroon:${NC}"
  xxd -p ~/.lnd/data/chain/bitcoin/mainnet/admin.macaroon | tr -d '\n' > ~/brlnfullauto/macaroon.hex
  cat ~/brlnfullauto/macaroon.hex
  echo
  echo
  echo
  echo -e "${YELLOW}📝 Copie o conteúdo do arquivo tls.hex e cole no campo tls:${NC}" 
  xxd -p ~/.lnd/tls.cert | tr -d '\n' | tee ~/brlnfullauto/tls.hex
  cat ~/brlnfullauto/tls.hex
  echo
  echo
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

get_simple_wallet
simple_lnwallet
bash ~/brlnfullauto/shell/menu.sh