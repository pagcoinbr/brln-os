#!/bin/bash
source ~/brlnfullauto/shell/.env

install_bitcoind() {
  local file_path="/home/admin/brlnfullauto/conf_files/bitcoin.conf"
  set -e
  if [[ $arch == "x86_64" ]]; then
    arch_btc="x86_64"
  else
    arch_btc="aarch64"
  fi

  cd /tmp
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/bitcoin-$BTC_VERSION-$arch_btc-linux-gnu.tar.gz
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS.asc
  sha256sum --ignore-missing --check SHA256SUMS
  # Importação das chaves PGP oficiais do Bitcoin Core
  curl https://bitcoincore.org/keys/keys.txt | gpg --import
  # Verificação da assinatura PGP
  gpg --verify SHA256SUMS.asc
  tar -xzvf bitcoin-$BTC_VERSION-$arch_btc-linux-gnu.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$BTC_VERSION/bin/bitcoin-cli bitcoin-$BTC_VERSION/bin/bitcoind
  sudo mkdir -p /data/bitcoin
  sudo chown admin:admin /data/bitcoin
  ln -s /data/bitcoin /home/admin/.bitcoin
  sudo cp $file_path /data/bitcoin/bitcoin.conf
  sudo chown admin:admin /data/bitcoin/bitcoin.conf
  sudo chmod 640 /data/bitcoin/bitcoin.conf
  cd /home/admin/.bitcoin
  wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
  sudo sed -i "54s|.*|$(python3 rpcauth.py minibolt $rpcpsswd > /home/admin/.bitcoin/rpc.auth | grep '^rpcauth=')|" /home/admin/brlnfullauto/conf_files/bitcoin.conf
  sudo cp $SERVICES_DIR/bitcoind.service /etc/systemd/system/bitcoind.service
  sudo systemctl enable bitcoind
  sudo systemctl start bitcoind
  sudo ss -tulpn | grep bitcoind
  echo "Bitcoind instalado com sucesso!"
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