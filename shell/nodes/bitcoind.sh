#!/bin/bash
source ~/brlnfullauto/shell/.env

install_bitcoind() {
  local file_path="/home/admin/brlnfullauto/conf_files/bitcoin.conf"
  if [[ $arch == "x86_64" ]]; then
    arch_btc="x86_64"
  else
    arch_btc="aarch64"
  fi
  tar -xzvf ~/brlnfullauto/local_apps/bitcoind/bitcoin-$BTC_VERSION-$arch_btc-linux-gnu.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin ~/brlnfullauto/local_apps/bitcoind/bitcoin-$BTC_VERSION/bin/bitcoin-cli bitcoin-$BTC_VERSION/bin/bitcoind
  sudo mkdir -p /data/bitcoin
  sudo chown admin:admin /data/bitcoin
  ln -s /data/bitcoin /home/admin/.bitcoin
  sudo cp $file_path /data/bitcoin/bitcoin.conf
  sudo chown admin:admin /data/bitcoin/bitcoin.conf
  sudo chmod 640 /data/bitcoin/bitcoin.conf
  cd /home/admin/.bitcoin
  sudo cp ~/brlnfullauto/local_apps/bitcoind/rpcauth.py /home/admin/.bitcoin/rpcauth.py
  sudo sed -i "54s|.*|$(python3 rpcauth.py minibolt $rpcpsswd > /home/admin/.bitcoin/rpc.auth | grep '^rpcauth=')|" /home/admin/brlnfullauto/conf_files/bitcoin.conf
  sudo cp $SERVICES_DIR/bitcoind.service /etc/systemd/system/bitcoind.service
  sudo systemctl enable bitcoind
  sudo systemctl start bitcoind
  sudo ss -tulpn | grep bitcoind
  if [[ $? -ne 0 ]]; then
    echo "Erro ao iniciar o serviço bitcoind. Verifique os logs para mais detalhes."
    exit 1
  else
    echo "Bitcoind instalado com sucesso!"
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

install_bitcoind
bash ~/brlnfullauto/shell/menu.sh