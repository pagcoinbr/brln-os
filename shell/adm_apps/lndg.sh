#!/bin/bash
source ~/brlnfullauto/shell/.env

install_lndg () {
  if [[ -d /home/admin/lndg ]]; then
    echo "LNDG já está instalado."
  else
  sudo apt install -y python3-pip python3-venv
  sudo ufw allow from $subnet to any port 8889 proto tcp comment 'allow lndg from local network'
  cd
  git clone https://github.com/cryptosharks131/lndg.git
  cd lndg
  sudo apt install -y virtualenv
  virtualenv -p python3 .venv
  .venv/bin/pip install -r requirements.txt
  .venv/bin/pip install whitenoise
  .venv/bin/python3 initialize.py --whitenoise
  sudo cp $SERVICES_DIR/lndg.service /etc/systemd/system/lndg.service
  sudo cp $SERVICES_DIR/lndg-controller.service /etc/systemd/system/lndg-controller.service
  sudo systemctl daemon-reload
  sudo systemctl enable lndg-controller.service
  sudo systemctl start lndg-controller.service
  sudo systemctl enable lndg.service
  sudo systemctl start lndg.service
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

install_lndg
bash ~/brlnfullauto/shell/menu.sh