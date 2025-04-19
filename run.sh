#!/bin/bash
SCRIPT_VERSION=v0.8.9.1-beta
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
LND_VERSION=0.18.5
BTC_VERSION=28.1
VERSION_THUB=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | jq -r '.tag_name' | sed 's/^v//')
HTML_SRC=/home/admin/brlnfullauto/html
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
SERVICES="/home/admin/brlnfullauto/services"
POETRY_BIN="/home/admin/.local/bin/poetry"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

INSTALL_DIR="/home/admin/brlnfullauto"

echo -e "${BLUE}Iniciando instalação do BRLN FullAuto...${NC}"
sleep 1

brln_check () {
  if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${YELLOW}Digite a senha do usuário admin para continuar...${NC}"
  else
    echo -e "${RED}Diretório brlnfullauto não encontrado, baixando como admin...${NC}"
    sudo -u admin git clone https://github.com/pagcoinbr/brlnfullauto.git "$INSTALL_DIR"
    sudo chown -R admin:admin "$INSTALL_DIR"
    sleep 2
    sudo -u admin git -C "$INSTALL_DIR" switch teste_v0.9
  fi

  sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
  sudo chmod +x "$INSTALL_DIR/brlnfullauto.sh"
  terminal_web
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
    echo 
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
read -p "Você deseja criar o usuário admin? (yes/no): " create_user
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

terminal_web () {
  sudo apt install apache2 -y
  sudo a2enmod cgid dir
  sudo systemctl restart apache2

  # Criar diretórios e mover arquivos
  sudo mkdir -p "$CGI_DST"
  sudo rm -f "$WWW_HTML/"*.html
  sudo rm -f "$WWW_HTML"/*.png
  sudo rm -f "$CGI_DST/"*.sh
  sudo cp "$HTML_SRC/"*.html "$WWW_HTML/"
  sudo cp "$HTML_SRC"/*.png "$WWW_HTML/"
  sudo cp "$HTML_SRC/cgi-bin/"*.sh "$CGI_DST/"

  # Corrigir permissões de execução
  sudo chmod +x "$CGI_DST"/*.sh
  for script in "$CGI_DST"/*.sh; do
    sudo chmod +x "$script"
  done

  # Configurar o Apache para permitir CGI no diretório correto
  if ! grep -q 'Directory "/usr/lib/cgi-bin"' "/etc/apache2/sites-enabled/000-default.conf"; then
    echo "Adicionando bloco de configuração CGI ao Apache..."
    sudo sed -i '/<\/VirtualHost>/i \
<Directory "/usr/lib/cgi-bin">\n\
  AllowOverride None\n\
  Options +ExecCGI -MultiViews +SymLinksIfOwnerMatch\n\
  Require all granted\n\
  AddHandler cgi-script .sh\n\
</Directory>\n' "/etc/apache2/sites-enabled/000-default.conf"
  else
    echo "Bloco de configuração CGI já existe no Apache."
  fi

  # Gerar sudoers dinâmico com todos os scripts .sh do cgi-bin
  echo "Atualizando permissões sudo para www-data nos scripts do CGI..."

  SCRIPT_LIST=$(find /usr/lib/cgi-bin/ -maxdepth 1 -type f -name "*.sh" | sort | paste -sd ", " -)

  if [ -n "$SCRIPT_LIST" ]; then
    sudo tee /etc/sudoers.d/www-data-scripts > /dev/null <<EOF
www-data ALL=(ALL) NOPASSWD: $SCRIPT_LIST
EOF
    echo "Permissões atualizadas com sucesso!"
  else
    echo "Nenhum script encontrado no diretório /usr/lib/cgi-bin/. Verifique se os scripts estão no local correto."
  fi

  # Abre a porta 80 no UFW
  if ! sudo ufw status | grep -q "80/tcp"; then
    echo "Abrindo a porta 80 no UFW..."
    sudo ufw allow from 192.168.0.0/23 to any port 80 proto tcp comment 'allow Apache from local network'
  else
    echo "A porta 80 já está aberta no UFW."
  fi

  sudo usermod -aG admin www-data
  sudo systemctl restart apache2
  echo "✅ Interface web do node Lightning instalada com sucesso!"

  if [[ ! -f /usr/local/bin/gotty ]]; then
    echo -e "${GREEN} Instalando Terminal Web... ${NC}"
    wget https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz >> /dev/null 2>&1
    tar -xvzf gotty_linux_amd64.tar.gz
    sudo mv gotty /usr/local/bin
    sudo cp /home/admin/brlnfullauto/services/gotty.service /etc/systemd/system/gotty.service
    sudo systemctl enable gotty.service
    sudo systemctl start gotty.service
    echo -e "${GREEN} gotty instalado com sucesso! ${NC}"
    echo -e "${GREEN} Acesse o terminal web em: http://$(hostname -I | awk '{print $1}') ${NC}"
    exit 0
  else
    echo -e "${GREEN} gotty já está instalado! ${NC}"
  fi
}

main_call