#!/bin/bash
source ~/brlnfullauto/shell/.env

cabecalho() {
  echo
  echo -e "${CYAN}🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟${NC}"
  echo
  echo -e "${YELLOW}⚡ Este Sript Instalará um Node Lightning Standalone${NC}"
  echo -e "  ${GREEN}🛠️ Bem Vindo ao Seu Novo Banco, Ele é BRASILEIRO. ${NC}"
  echo
  echo -e "${YELLOW} Acesse seu nó usando o IP no navegador:${RED} $ip_local${NC}"
  echo -e "${YELLOW} Sua arquitetura é:${RED} $arch${NC}"
  echo
  echo -e "${YELLOW}📝 Escolha uma opção:${NC}"
  echo
}

menu1 () {
  cabecalho
  echo -e "   ${GREEN}1${NC}- Instalação inicial"
  echo
  echo -e "   ${GREEN}2${NC}- Instalação de aplicativos administrativos"
  echo
  echo -e "   ${GREEN}3${NC}- Mais opções"
  echo
  echo -e "   ${RED}0${NC}- Voltar"
  echo
  read -p "👉  Digite sua escolha:     " option
  case $option in
    1)
      clear
      menu2
      ;;
    2)
      clear
      menu3
      ;;
    3)
      clear
      submenu_opcoes
      ;;
    0)
      echo -e "${MAGENTA}👋 Saindo... Até a próxima!${NC}"
      exit 0
      ;;
    *)
      clear
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      cabecalho
      menu1
      exit 0
      ;;
  esac
  exit 0
}

menu2 () {
  cabecalho
  echo -e "   ${GREEN}1${NC}- Instalar Interface de Rede"
  echo -e "   ${GREEN}2${NC}- Instalar Bitcoin Core"
  echo -e "   ${GREEN}3${NC}- Instalar LND & Criar Carteira"
  echo -e "   ${GREEN}4${NC}- Instalar Elements"
  echo -e "   ${RED}0${NC}- Voltar"
  echo
  read -p "👉  Digite sua escolha:     " option
  case $option in
    1)
      clear
      app="Rede Privada"
      sudo -v
      echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
      echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      sudo -v
      sudo apt autoremove -y
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$NODES_DIR/network.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW}Aguarde p.f. A instalação está sendo executada em segundo plano...${NC}"
        echo -e "${YELLOW}🕒 ATENÇÃO: Esta etapa pode demorar 10 - 30min. Seja paciente.${NC}"
        bash "$NODES_DIR/network.sh" >> /dev/null 2>&1 &
        pid=$!
        if declare -f spinner > /dev/null; then
          spinner $pid
        else
          echo -e "${RED}Erro: Função 'spinner' não encontrada.${NC}"
          wait $pid
        fi
        clear
      else
        echo "Opção inválida."
      fi
      wait
      if [[ $? -ne 0 ]]; then
        echo -e "${RED}Erro na instalação do sistema. Verifique os logs para mais detalhes.${NC}"
        exit 1
      fi
      echo -e "\033[43m\033[30m ✅ Instalação da interface de rede concluída! \033[0m"
      menu2      
      ;;
    2)
      clear
      app="Bitcoin"
      sudo -v
      echo -e "${YELLOW} instalando o bitcoind...${NC}"
      read -p "Escolha sua senha do Bitcoin Core: " "rpcpsswd"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$NODES_DIR/bitcoind.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        bash "$NODES_DIR/bitcoind.sh" >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu2
      fi
      echo -e "\033[43m\033[30m ✅ Sua instalação do bitcoin core foi bem sucedida! \033[0m"
      menu2
      ;;
    3)
      app="Lnd"
      sudo -v
      echo -e "${CYAN}🚀 Iniciando a instalação do LND...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      echo -e "${YELLOW} instalando o lnd...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$NODES_DIR/lnd.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        bash "$NODES_DIR/lnd.sh" >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu2
      fi
      echo -e "\033[43m\033[30m ✅ Sua instalação do LND foi bem sucedida! \033[0m"
      menu2
      ;;
    4)
      clear
      app="Elements"
      sudo -v
      echo -e "${CYAN}🚀 Iniciando a instalação do Elements...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      echo -e "${YELLOW} instalando o elements...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$NODES_DIR/elementsd.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        bash "$NODES_DIR/elementsd.sh" >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu2
      fi
      echo -e "\033[43m\033[30m ✅ Sua instalação do Elements foi bem sucedida! \033[0m"
      menu2
      ;;
    0)
      clear
      menu1
      ;;
    *)
      clear
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      menu2
      ;;
  esac
}

menu3 () {
  cabecalho
  echo -e "   ${GREEN}1${NC}- Instalar Simple LNWallet - By JVX (Exige LND)"
  echo -e "   ${GREEN}2${NC}- Balance of Satoshis (Exige LND)"
  echo -e "   ${GREEN}3${NC}- Instalar Thunderhub(Exige LND)"
  echo -e "   ${GREEN}4${NC}- Instalar Lndg (Exige LND)"
  echo -e "   ${GREEN}5${NC}- Instalar LNbits"
  echo -e "   ${GREEN}6${NC}- Instalar PeerSwapWeb"
  echo -e "   ${RED}0${NC}- Voltar"
  echo
  read -p "👉  Digite sua escolha:     " option
  echo
  case $option in
    1)
      clear
      app="Simple Wallet"
      sudo -v
      echo -e "${CYAN}🚀 Instalando Simple LNWallet...${NC}"
      bash "$ADMAPPS_DIR/simple_wallet.sh"
      echo -e "\033[43m\033[30m ✅ Simple LNWallet instalado com sucesso! \033[0m"
      menu
      ;;
    2)
      clear
      app="Balance of Satoshis"
      sudo -v
      echo -e "${CYAN}🚀 Instalando Balance of Satoshis...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$ADMAPPS_DIR/balance_of_satoshis.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco...${NC}  "
        bash "$ADMAPPS_DIR/balanceofsatoshis.sh" >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ Balance of Satoshis instalado com sucesso! \033[0m"
      menu3
      ;;
    3)
      echo -e "${YELLOW}🕒 Iniciando a instalação do Thunderhub...${NC}"
      read -p "Digite a senha para ThunderHub: " thub_senha
      echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      app="Thunderhub"
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$ADMAPPS_DIR/thunderhub.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso poderá demorar 10min ou mais. Seja paciente...${NC}"
        install_thunderhub >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu3
      fi
      echo -e "\033[43m\033[30m ✅ ThunderHub instalado com sucesso! \033[0m"
      menu3
      ;;
    4)
      clear
      app="Lndg"
      sudo -v
      echo -e "${CYAN}🚀 Instalando LNDG...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        install_lndg
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco...${NC}"
        install_lndg >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida. Usando o modo padrão."
        menu3
      fi
      echo -e "${YELLOW}📝 Para acessar o LNDG, use a seguinte senha:${NC}"
      echo
      cat ~/lndg/data/lndg-admin.txt
      echo
      echo
      echo -e "${YELLOW}📝 Você deve mudar essa senha ao final da instalação."
      echo -e "\033[43m\033[30m ✅ LNDG instalado com sucesso! \033[0m"
      menu3
      ;;
    5)
      clear
      app="Lnbits"
      sudo -v
      echo -e "${CYAN}🚀 Instalando LNbits...${NC}"
      read -p "Deseja exigir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        lnbits_install
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco... Seja paciente.${NC}"
        lnbits_install >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ LNbits instalado com sucesso! \033[0m"
      menu3
      ;;
    6)
      clear
      app="PeerSwapWeb"
      sudo -v
      echo -e "${CYAN}🚀 Instalando PeerSwapWeb...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$ADMAPPS_DIR/peerswapweb.sh"
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco... Seja paciente.${NC}"
        bash "$ADMAPPS_DIR/peerswapweb.sh" >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu3
      fi
      echo -e "\033[43m\033[30m ✅ PeerSwapWeb instalado com sucesso! \033[0m"
      ;;
    0)
      echo -e "${MAGENTA}👋 Saindo... Até a próxima!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      menu3
      ;;
  esac
}


submenu_opcoes() {
  cabecalho
  echo -e "${CYAN}🔧 Mais opções disponíveis:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- 🏠 Trocar para o bitcoin local."
  echo -e "   ${GREEN}2${NC}- ☁️ Trocar para o bitcoin remoto."
  echo -e "   ${GREEN}3${NC}- 🔴 Atualizar e desinstalar programas."
  echo -e "   ${GREEN}4${NC}- 🔧 Ativar o Bos Telegram no boot do sistema."
  echo -e "   ${GREEN}5${NC}- 🔄 Atualizar interface gráfica."
  echo -e "   ${GREEN}6${NC}- 🧅 Tor Adress (acesso remoto)"
  echo -e "   ${RED}0${NC}- Voltar ao menu principal"
  echo

  read -p "👉  Digite sua escolha:     " suboption

  case $suboption in
    1)
      echo -e "${YELLOW}🏠 🔁 Trocar para o bitcoin local...${NC}"
      bash "$SHELL_DIR/toggle_on.sh"
      echo -e "${GREEN}✅ Serviços reiniciados!${NC}"
      submenu_opcoes
      ;;
    2)
      echo -e "${YELLOW}🔁 ☁️ Trocar para o bitcoin remoto...${NC}"
      bash "$SHELL_DIR/toggle_off.sh"
      echo -e "${GREEN}✅ Atualização concluída!${NC}"
      submenu_opcoes
      ;;
    3)
      manutencao_script
      submenu_opcoes
      ;;
    4)
      echo -e "${YELLOW}🔧 Configurando o Bos Telegram...${NC}"
      bash "$SHELL_DIR/bos_telegram.sh"
      submenu_opcoes
      ;;
    5)
      echo -e "${YELLOW} Atualizando interface gráfica...${NC}"
      app="Gui"
      sudo -v
      echo -e "${CYAN}🚀 Atualizando interface gráfica...${NC}"
      bash "$SHELL_DIR/interface.sh"
      echo -e "\033[43m\033[30m ✅ Interface atualizada com sucesso! \033[0m"
      exit 0
      ;;
    6)
      echo -e "${YELLOW}🔄 Criando endereço Tor...${NC}"
      bash "$SHELL_DIR/tor_hs.sh"
      echo -e "${GREEN}✅ Endereço onion encontrado!${NC}"
      submenu_opcoes
      ;;
    0)
      menu
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      submenu_opcoes
      ;;
  esac
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

menu1
exit 0

