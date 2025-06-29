#!/bin/bash
#variáveis do sistema e script
ip_local=$(hostname -I | awk '{print $1}')
subnet=$(echo "$ip_local" | awk -F. '{print $1"."$2"."$3".0/23"}')
arch=$(uname -m)
atual_user=$(whoami)
branch="liquid"
git_user="REDACTED_USERbr"

# Variáveis específicas
SCRIPT_VERSION="v1.0-beta"
LND_VERSION="0.18.5"
BTC_VERSION="28.1"
REPO_DIR="/home/admin/brlnfullauto"
INSTALL_DIR="/home/admin/brlnfullauto"
SERVICES_DIR="/home/admin/brlnfullauto/services"
POETRY_BIN="/home/admin/.local/bin/poetry"
FLASKVENV_DIR="/home/admin/envflask"
ELEMENTD_VERSION="23.2.7"
LOCAL_APPS="/home/admin/brlnfullauto/local_apps"
SHELL_DIR="/home/admin/brlnfullauto/shell"
NODES_DIR="/home/admin/brlnfullauto/shell/nodes"
ADMAPPS_DIR="/home/admin/brlnfullauto/shell/adm_apps"
SUDOERS_TMP="/etc/sudoers.d/admin-services"
LOG_FILE="/home/admin/brlnfullauto/logs/install.log"
HTML_SRC="/home/admin/brlnfullauto/html"
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"

# Inserir novo serciço para copiadora de serviços
SERVICES=("gotty" "gotty-fullauto" "gotty-logs-lnd" "gotty-logs-bitcoind" "gotty-btc-editor" "gotty-lnd-editor" "control-systemd")
PORTS=("3131" "3232" "3434" "3535" "3636" "3333" "5001")
COMMENTS=("allow BRLNfullauto on port 3131 from local network" 
  "allow cli on port 3232 from local network" 
  "allow bitcoinlogs on port 3434 from local network" 
  "allow lndlogs on port 3535 from local network"
  "allow btc-editor on port 3636 from local network"
  "allow lnd-editor on port 3333 from local network"
  "allow control-systemd on port 5001 from local network")

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

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
  echo -e "${GREEN} Iniciando... ${NC}"
  if [[ ! -f "$WWW_HTML/main.html" ]]; then
    for i in {4..1}; do
      for ms in {0..9}; do
        echo -ne "\rIniciando: $i.$ms segundos"
        sleep 0.1
      done
    done
  fi
  clear
  sudo -u admin bash "$SHELL_DIR/interface.sh"
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
    fi
  done
}

autorizar_scripts
main_call
exit 0
