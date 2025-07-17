      echo -e "${CYAN}🚀 Instalando LNbits...${NC}"
      read -p "Deseja exigir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco... Seja paciente.${NC}"
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi