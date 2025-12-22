#!/bin/bash

# Gotty installation and management functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

gotty_do() {
  echo -e "${GREEN} Instalando Interface gráfica... ${NC}"
  LOCAL_APPS="$LOCAL_APPS_DIR"
  
  # Check if gotty archives are directly in LOCAL_APPS or in gotty subdirectory
  if [[ -f "$LOCAL_APPS/gotty_2.0.0-alpha.3_linux_amd64.tar.gz" ]]; then
    GOTTY_PATH="$LOCAL_APPS"
  elif [[ -f "$LOCAL_APPS/gotty/gotty_2.0.0-alpha.3_linux_amd64.tar.gz" ]]; then
    GOTTY_PATH="$LOCAL_APPS/gotty"
  else
    echo -e "${RED}❌ Arquivos do gotty não encontrados em $LOCAL_APPS ou $LOCAL_APPS/gotty${NC}"
    echo -e "${YELLOW}Defina LOCAL_APPS_DIR para um caminho válido antes de continuar.${NC}"
    return 1
  fi
  
  if [[ $arch == "x86_64" ]]; then
    sudo tar -xvzf "$GOTTY_PATH/gotty_2.0.0-alpha.3_linux_amd64.tar.gz" -C "$HOME" >> /dev/null 2>&1
  else
    sudo tar -xvzf "$GOTTY_PATH/gotty_2.0.0-alpha.3_linux_arm.tar.gz" -C "$HOME" >> /dev/null 2>&1
  fi
  
  # Move e torna executável
  sudo mv "$HOME/gotty" /usr/local/bin/gotty
  sudo chmod +x /usr/local/bin/gotty
}

gotty_install() {
  if [[ ! -f /usr/local/bin/gotty ]]; then
    gotty_do
  else
    echo -e "${GREEN} Gotty já instalado, atualizando... ${NC}"
    sudo rm -f /usr/local/bin/gotty
    gotty_do
  fi
}

install_gotty_services() {
  echo -e "${GREEN}📋 Instalando serviços Gotty...${NC}"
  
  SERVICES=("gotty" "gotty-fullauto" "gotty-logs-lnd" "gotty-logs-bitcoind" "gotty-btc-editor" "gotty-lnd-editor")
  
  for service in "${SERVICES[@]}"; do
    service_file="$SERVICES_DIR/${service}.service"
    if [[ -f "$service_file" ]]; then
      echo "📋 Instalando ${service}.service..."
      safe_cp "$service_file" "/etc/systemd/system/${service}.service"
      if [[ $? -eq 0 ]]; then
        sudo systemctl daemon-reload
        sudo systemctl enable ${service} >> /dev/null 2>&1 || echo -e "${YELLOW}⚠️ Não foi possível habilitar ${service}${NC}"
      fi
    else
      echo -e "${RED}❌ Arquivo ${service}.service não encontrado em $SERVICES_DIR${NC}"
    fi
  done
  
  sudo systemctl daemon-reload
  echo -e "${GREEN}✅ Serviços Gotty instalados${NC}"
}

terminal_web() {
  echo -e "${GREEN}💻 Configurando interface web do terminal...${NC}"
  
  # Instalar Gotty
  gotty_install
  
  # Instalar serviços
  install_gotty_services
  
  # Verificar se os serviços foram instalados
  if [[ ! -f /usr/local/bin/gotty ]]; then
    echo -e "${RED}❌ Gotty não foi instalado corretamente${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✅ Interface web do terminal configurada com sucesso!${NC}"
  echo -e "${BLUE}💡 Use os serviços systemd para gerenciar as interfaces web do terminal${NC}"
}

gui_update() {
  echo -e "${GREEN}🔄 Atualizando interface gráfica...${NC}"
  terminal_web
}