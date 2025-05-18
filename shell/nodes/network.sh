#!/bin/bash
source ~/brlnfullauto/shell/.env
TOR_LINK="https://deb.torproject.org/torproject.org"

create_main_dir() {
  sudo mkdir /data
  sudo chown admin:admin /data
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow from $subnet to any port 22 proto tcp comment 'allow SSH from local network'
  sudo ufw --force enable
}

install_tor() {
  TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
  sudo apt install -y apt-transport-https
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINK jammy main
  deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINK jammy main" | sudo tee /etc/apt/sources.list.d/tor.list
  sudo su -c "wget -qO- $TOR_GPGLINK | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg"
  sudo apt update && sudo apt install -y tor deb.torproject.org-keyring
  sudo sed -i 's/^#ControlPort 9051/ControlPort 9051/' /etc/tor/torrc
  sudo systemctl reload tor
  if sudo ss -tulpn | grep -q "127.0.0.1:9050" && sudo ss -tulpn | grep -q "127.0.0.1:9051"; then
    echo "Tor está configurado corretamente e ouvindo nas portas 9050 e 9051."
    wget -q -O - https://repo.i2pd.xyz/.help/add_repo | sudo bash -s -
    sudo apt update && sudo apt install -y i2pd
    echo "i2pd instalado com sucesso."
  else
    echo "Erro: Tor não está ouvindo nas portas corretas."
  fi
}

install_nodejs() {
  if [[ -d ~/.npm-global ]]; then
    echo "Node.js já está instalado."
  else
    curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
    sudo apt-get install nodejs -y
  fi
}

Install_go (){
  sudo snap install go --classic
  sudo apt install -y make
}

create_main_dir
configure_ufw
echo -e "${YELLOW}🕒 Isso pode demorar um pouco...${NC}"
echo -e "${YELLOW}Na pior das hipóteses, até 30 minutos...${NC}"
install_tor
install_go
install_nodejs