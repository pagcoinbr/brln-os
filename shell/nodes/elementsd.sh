#!/bin/bash
source ~/brlnfullauto/shell/.env

elementsd_install() {
  if [[ ! -f /usr/local/bin/elementsd ]]; then
      if [[ $arch == "x86_64" ]]; then
          echo "${GREEN}Instalando Elementd para x86_64...${NC}"
          elements_arch="elements-$ELEMENTD_VERSION-x86_64-linux-gnu.tar.gz"
      else
          echo "${GREEN}Instalando Elementd para arm64...${NC}"
          elements_arch="elements-$ELEMENTD_VERSION-aarch64-linux-gnu.tar.gz"
      fi
      tar -xvzf "$LOCAL_APPS/elementsd/$elements_arch"
      sudo cp "/home/admin/brlnfullauto/elements-$ELEMENTD_VERSION/bin/elementsd" "$LOCAL_BIN"
      sudo cp "/home/admin/brlnfullauto/elements-$ELEMENTD_VERSION/bin/elements-cli" "$LOCAL_BIN"
      sudo mkdir -p "$ELEMENTS_DIR"
      sudo chown -R admin:admin "$ELEMENTS_DIR"
      sudo chmod -R 755 "$ELEMENTS_DIR"
      sudo rm -f "$ELEMENTS_CONF"
      sudo cp ~/brlnfullauto/conf_files/elements.conf $ELEMENTS_CONF
      sudo chown admin:admin $ELEMENTS_CONF
      sudo chmod 640 $ELEMENTS_CONF
      ln -s $ELEMENTS_DIR /home/admin/.elements
      sudo rm -rf "/etc/systemd/system/elementsd.service"
      sudo cp "$SERVICES_DIR/elementsd.service" "/etc/systemd/system/"
      sudo systemctl daemon-reload
      if [[ $? -eq 0 ]]; then
          echo -e "${GREEN}Elementd instalado com sucesso!${NC}"
          echo -e "${GREEN}Para criar um novo endereço de recebimento Liquid:${NC}"
          echo -e "${GREEN}elements-cli -rpcwallet=peerswap getnewaddress${NC}"
          echo -e "${GREEN}Para enviar L-BTC para um endereço Liquid:${NC}"
          echo -e "${GREEN}elements-cli -rpcwallet=peerswap sendtoaddress [endereço] [quantidade em formato decimal, ex.: 0.1 para 0.10000000 L-BTC]${NC}"
      else
          echo -e "${RED}Erro ao instalar Elementd.${NC}"
      fi
  else
    echo -e "${GREEN}Elementd já está instalado.${NC}"
    elements-cli loadwallet peerswap
    echo -e "${GREEN}Para criar um novo endereço de recebimento Liquid:${NC}"
    echo -e "${GREEN}elements-cli -rpcwallet=peerswap getnewaddress${NC}"
    echo -e "${GREEN}Para enviar L-BTC para um endereço Liquid:${NC}"
    echo -e "${GREEN}elements-cli -rpcwallet=peerswap sendtoaddress [endereço] [quantidade em formato decimal, ex.: 0.1 para 0.10000000 L-BTC]${NC}"
  fi
  sudo systemctl daemon-reload
  sudo systemctl enable elementsd.service
  sudo systemctl start elementsd.service
  if [[ $? -eq 0 ]]; then
      echo -e "${GREEN}Elementd iniciado com sucesso!${NC}"
  else
      echo -e "${RED}Erro ao iniciar Elementd.${NC}"
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

elementsd_install