#!/bin/bash
source ~/brlnfullauto/shell/.env

install_bos() {
  if [[ -d ~/.npm-global ]]; then
    echo "Balance of Satoshis já está instalado."
  else
    mkdir -p ~/.npm-global
    npm config set prefix ~/.npm-global
    if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
      echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
    fi
  cd ~
  npm i -g balanceofsatoshis
  sudo bash -c 'echo "127.0.0.1" >> /etc/hosts'
  sudo chown -R admin:admin /data/lnd
  sudo chmod -R 755 /data/lnd
  export BOS_DEFAULT_LND_PATH=/data/lnd
  mkdir -p ~/.bos/$alias
  base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
  base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon > /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64
  cert_base64=$(cat /data/lnd/tls.cert.base64)
  macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon.base64)
  bash -c "cat <<EOF > ~/.bos/$alias/credentials.json
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "localhost:10009"
}
EOF"
  sudo cp $SERVICES_DIR/bos-telegram.service /etc/systemd/system/bos-telegram.service
  sudo systemctl daemon-reload
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

install_bos
bash ~/brlnfullauto/shell/menu.sh