#!/bin/bash

# Utility functions
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

safe_cp() {
  local src="$1"
  local dest="$2"

  if [[ -e "$src" ]]; then
    sudo cp "$src" "$dest"
  else
    echo -e "${RED}❌ Arquivo não encontrado para cópia: $src${NC}"
    return 1
  fi
}

spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
  wait $pid
  local exit_status=$?
  
  if [ $exit_status -eq 0 ]; then
    echo -e "${GREEN}✔️ Processo finalizado com sucesso!${NC}"
  else
    echo -e "${RED}❌ Processo finalizado com erro (código: $exit_status)${NC}"
  fi
  
  return $exit_status
}

create_main_dir() {
  sudo mkdir -p $HOME
}

configure_ufw() {
  sudo ufw --force enable
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
}

close_ports_except_ssh() {
  echo -e "${YELLOW}🔒 Fechando todas as portas exceto SSH...${NC}"
  
  # Get current SSH port (default 22)
  ssh_port=$(sudo ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -n1)
  ssh_port=${ssh_port:-22}
  
  echo -e "${BLUE}Mantendo porta SSH: $ssh_port${NC}"
  
  # Reset UFW to default settings
  sudo ufw --force reset
  
  # Set default policies
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  
  # Allow SSH
  sudo ufw allow $ssh_port/tcp comment 'SSH access'
  
  # Enable UFW
  sudo ufw --force enable
  
  echo -e "${GREEN}✅ Firewall configurado - apenas SSH ($ssh_port) permitido${NC}"
  
  # Show current status
  sudo ufw status numbered
}