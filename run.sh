#!/bin/bash

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

echo -e "${GREEN}Iniciando instalação do BRLN FullAuto...${NC}"
sleep 1

brln_check () {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${GREEN}Diretório brlnfullauto já presente.${NC}"
  else
    echo -e "${RED}Diretório brlnfullauto não encontrado, baixando como admin...${NC}"

    sudo -u admin git clone https://github.com/pagcoinbr/brlnfullauto.git "$INSTALL_DIR"
    sudo chown -R admin:admin "$INSTALL_DIR"
    sleep 2
    #sudo -u admin git -C "$INSTALL_DIR" checkout v0.8-beta
  fi

  sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
  sudo chmod +x "$INSTALL_DIR/brlnfullauto.sh"

  echo -e "${GREEN}Executando brlnfullauto.sh como admin...${NC}"
  sudo -u admin bash "$INSTALL_DIR/brlnfullauto.sh"
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

    echo "✅ Diretório /home/admin corrigido com sucesso."
  else
    echo "✅ Diretório /home/admin já pertence ao usuário admin."
  fi
else
  echo "➕ Criando diretório /home/admin..."
  sudo mkdir -p /home/admin
  sudo chown admin:admin /home/admin
  sudo chmod 755 /home/admin
  echo "✅ Diretório /home/admin criado com sucesso."
fi
}

main_call () {
# Identifica e cria o usuário/grupo admin
atual_user=$(whoami)
if [[ $atual_user = "admin" ]]; then
  echo -e "${GREEN} Você já está logado como admin! ${NC}"
  dir_check
  brln_check
else
  echo -e "${RED} Você não está logado como admin! ${NC}"
  echo -e "${YELLOW} Você precisa estar logado como admin para prosseguir com a instalação do lnd! ${NC}"
fi
read -p "Você deseja criar um usuário admin? (yes/no): " create_user
if [[ $create_user == "yes" ]]; then
# Garante que o grupo 'admin' existe
if getent group admin > /dev/null; then
    echo "✅ Grupo 'admin' já existe."
else
    echo "➕ Criando grupo 'admin'..."
    sudo groupadd admin
fi

# Garante que o usuário 'admin' existe
if id "admin" &>/dev/null; then
  echo "✅ Usuário 'admin' já existe."
  sudo passwd admin
  dir_check
  brln_check
else
  echo "➕ Criando usuário 'admin' e adicionando ao grupo 'admin'..."
  sudo adduser --gecos "" --ingroup admin admin
  dir_check
  brln_check
fi
elif [[ $create_user == "no" ]]; then
  echo -e "${RED} Você escolheu não criar um usuário admin! ${NC}"
  echo -e "${YELLOW} Você precisa estar logado como admin para prosseguir com a instalação do lnd! ${NC}"
  exit 1
fi
}

main_call
