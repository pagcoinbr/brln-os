#!/bin/bash

# 🧠 Configurações iniciais
branch="teste_v0.9"
git_user="pagcoinbr"
INSTALL_DIR="/home/admin/brlnfullauto"
ADMIN_PASS="admin"  # Senha temporária (pode substituir por outra ou gerar aleatória)

# 🎨 Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# 🚫 Silencia a saída padrão e de erro
QUIET=">> /dev/null 2>&1"

echo -e "${BLUE}🔐 Criando usuário 'admin' se necessário...${NC}"
sleep 1

create_admin_user() {
  # Cria grupo 'admin' se não existir
  getent group admin $QUIET || sudo groupadd admin $QUIET

  # Cria usuário admin se necessário
  if ! id "admin" &>/dev/null; then
    sudo useradd -m -s /bin/bash -g admin -G sudo,adm,cdrom,dip,plugdev,lxd admin $QUIET
    echo "admin:$ADMIN_PASS" | sudo chpasswd
    sudo chage -d 0 admin  # Força troca de senha no primeiro login
  fi

  # Ajusta permissões da home
  sudo mkdir -p /home/admin $QUIET
  sudo chown -R admin:admin /home/admin
  sudo chmod 755 /home/admin
}

clone_repo_if_needed() {
  if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${BLUE}📦 Clonando repositório do BRLN FullAuto...${NC}"
    sudo -u admin git clone -q "https://github.com/$git_user/brlnfullauto.git" "$INSTALL_DIR"
    sudo -u admin git -C "$INSTALL_DIR" switch "$branch" $QUIET
    sudo chmod +x "$INSTALL_DIR/brlnfullauto.sh"
  fi
}

launch_main_script() {
  echo -e "${GREEN}🚀 Iniciando o BRLN FullAuto como usuário admin...${NC}"
  exec sudo -u admin bash "$INSTALL_DIR/brlnfullauto.sh"
}

# 🔁 Execução principal
main_call() {
  atual_user=$(whoami)
  if [[ "$atual_user" == "admin" ]]; then
    clone_repo_if_needed
    launch_main_script
  else
    create_admin_user
    clone_repo_if_needed
    launch_main_script
  fi
}

main_call
