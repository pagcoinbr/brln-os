#!/bin/bash
source ~/brlnfullauto/shell/.env

echo -e "${BLUE}Criando usuário administrador/admin.${NC}"
sleep 1

brln_check () {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Digite a senha do usuário admin para continuar...${NC}"
  else
    sudo -u admin git clone -q https://github.com/$git_user/brlnfullauto.git "$INSTALL_DIR"
    sudo chown -R admin:admin "$INSTALL_DIR"
    sudo -u admin git -C "$INSTALL_DIR" switch $branch > /dev/null
  fi
  sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
  for i in {5..1}; do
    for ms in {0..9}; do
      echo -ne "\rCarregando: $i.$ms segundos"
      sleep 0.1
    done
  done
  echo -e "\rContagem regressiva: 0.0 segundos"
  sudo -u admin bash "$SHELL_DIR/interface.sh"
  sudo -u admin bash "$SHELL_DIR/menu.sh"
  exit 0
}

dir_check () {
  # Verifica se o diretório /home/admin existe
if [[ -d "/home/admin" ]]; then
  # Verifica se o dono do diretório é o usuário 'admin'
  owner=$(stat -c '%U' /home/admin)

  if [[ "$owner" != "admin" ]]; then
    echo "⚠️ O diretório /home/admin existe, mas pertence a $owner. Corrigindo..."
    
    # Encerra todos os processos do usuário admin (precaução, caso haja)
    pkill -u admin 2>/dev/null

    # Remove com segurança
    sudo rm -rf /home/admin

    # Recria o diretório
    sudo mkdir -p /home/admin
    sudo chown admin:admin /home/admin
    sudo chmod 755 /home/admin
  fi
else
  echo
  sudo mkdir -p /home/admin
  sudo chown admin:admin /home/admin
  sudo chmod 755 /home/admin
  echo
fi
}

main_call () {
if [[ $atual_user = "admin" ]]; then
  dir_check
  brln_check
  exit 0
else
  if id "admin" &>/dev/null; then
  dir_check
  brln_check
  exit 0
  fi
fi
if ! getent group admin > /dev/null; then
  sudo groupadd admin
fi
if id "admin" &>/dev/null; then
  sudo passwd admin
  dir_check
  brln_check
  exit 0
else
  sudo adduser --gecos "" --ingroup admin admin
  dir_check
  brln_check
  exit 0
fi
}

autorizar_scripts() {
  for script in "$NODES_DIR"/*.sh "$ADMAPPS_DIR"/*.sh "$SHELL_DIR"/*.sh; do
    if [ -f "$script" ]; then
      chmod +x "$script"
      echo "Permissão de execução adicionada: $script"
    fi
  done
}

autorizar_scripts
main_call
exit 0
