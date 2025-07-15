#!/bin/bash
SCRIPT_VERSION=v1.0-beta
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
LND_VERSION=0.18.5
BTC_VERSION=28.1
VERSION_THUB=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | jq -r '.tag_name' | sed 's/^v//')
REPO_DIR="/home/$USER/brlnfullauto"
HTML_SRC="$REPO_DIR/html"
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
SERVICES_DIR="/home/$USER/brlnfullauto/services"
POETRY_BIN="/home/$USER/.local/bin/poetry"
FLASKVENV_DIR="/home/$USER/envflask"
atual_user=$(whoami)
branch=main
git_user=pagcoinbr

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

update_and_upgrade() {
  app="Interface Gráfica"
  echo "Instalando Apache..."
  sudo -v
  sudo apt install apache2 -y >> /dev/null 2>&1 & spinner
  echo "Habilitando módulos do Apache..."
  sudo a2enmod cgid dir >> /dev/null 2>&1 & spinner
  echo "Reiniciando o serviço Apache..."
  sudo systemctl restart apache2 >> /dev/null 2>&1 & spinner

  # Executa o git dentro do diretório, sem precisar dar cd
  git -C "$REPO_DIR" stash || true
  git -C "$REPO_DIR" pull origin "$branch"

  sudo rm -rf "$WWW_HTML"/*.html
  sudo rm -rf "$WWW_HTML/css"
  sudo rm -rf "$WWW_HTML/js"
  sudo rm -rf "$WWW_HTML/imagens"
  sudo rm -rf "$WWW_HTML/radio"
  sudo rm -rf "$CGI_DST"/*.sh

  echo "📥 Copiando novos arquivos da interface web..."

  # Copia os HTMLs principais
  sudo cp "$HTML_SRC"/*.html "$WWW_HTML/"

  # Copia pastas CSS, JS, Imagens
  sudo cp -r "$HTML_SRC/css" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/js" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/imagens" "$WWW_HTML/"
  sudo cp -r "$HTML_SRC/radio" "$WWW_HTML/"

  # Copia scripts CGI para /usr/lib/cgi-bin
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
  SCRIPT_LIST=$(sudo find "$CGI_DST" -maxdepth 1 -type f -name "*.sh" | sort | tr '\n' ',' | sed 's/,$//')

  if [ -n "$SCRIPT_LIST" ]; then
    sudo tee /etc/sudoers.d/www-data-scripts > /dev/null <<EOF
www-data ALL=(ALL) NOPASSWD: $SCRIPT_LIST
EOF
  fi
  # Abre a posta 80 no UFW
  if ! sudo ufw status | grep -q "80/tcp"; then
    sudo ufw allow from $subnet to any port 80 proto tcp comment 'allow Apache from local network'
  fi
  sudo usermod -aG $USER www-data
  # Garante que o pacote python3-venv esteja instalado
  if ! dpkg -l | grep -q python3-venv; then
    sudo apt install python3-venv -y >> /dev/null 2>&1 & spinner
  else
    echo "✅ python3-venv já está instalado."
  fi

  # Define o diretório do ambiente virtual
  FLASKVENV_DIR="/home/$USER/envflask"

  # Cria o ambiente virtual apenas se ainda não existir
  if [ ! -d "$FLASKVENV_DIR" ]; then
    python3 -m venv "$FLASKVENV_DIR" >> /dev/null 2>&1 & spinner
  else
    echo "✅ Ambiente virtual já existe em $FLASKVENV_DIR."
  fi

  # Ativa o ambiente virtual
  echo "⚡ Ativando ambiente virtual..."
  source "$FLASKVENV_DIR/bin/activate"

  # Instala Flask e Flask-CORS
  pip install flask flask-cors >> /dev/null 2>&1 & spinner

  # 🛡️ Caminho seguro para o novo arquivo dentro do sudoers.d
  SUDOERS_TMP="/etc/sudoers.d/$USER-services"

  # 📝 Criação segura do arquivo usando here-document
  sudo tee "$SUDOERS_TMP" > /dev/null <<EOF
$USER ALL=(ALL) NOPASSWD: /usr/bin/systemctl start lnbits.service, /usr/bin/systemctl stop lnbits.service, /usr/bin/systemctl start thunderhub.service, /usr/bin/systemctl stop thunderhub.service, /usr/bin/systemctl start lnd.service, /usr/bin/systemctl stop lnd.service, /usr/bin/systemctl start lndg-controller.service, /usr/bin/systemctl stop lndg-controller.service, /usr/bin/systemctl start lndg.service, /usr/bin/systemctl stop lndg.service, /usr/bin/systemctl start simple-lnwallet.service, /usr/bin/systemctl stop simple-lnwallet.service, /usr/bin/systemctl start bitcoind.service, /usr/bin/systemctl stop bitcoind.service, /usr/bin/systemctl start bos-telegram.service, /usr/bin/systemctl stop bos-telegram.service, /usr/bin/systemctl start tor.service, /usr/bin/systemctl stop tor.service
EOF

  # ✅ Valida se o novo arquivo sudoers é válido
  if sudo visudo -c -f "$SUDOERS_TMP"; then
    sleep 1
  else
    echo "⛔ Erro na validação! Arquivo inválido, removendo."
    sudo rm -f "$SUDOERS_TMP"
    exit 1
  fi
  sudo systemctl restart apache2
  sudo apt install -y python3-flask >> /dev/null 2>&1 & spinner
}

gotty_do () {
  echo -e "${GREEN} Instalando Interface gráfica... ${NC}"
  LOCAL_APPS="/home/$USER/brlnfullauto/local_apps"
  if [[ $arch == "x86_64" ]]; then
    sudo tar -xvzf "$LOCAL_APPS/gotty/gotty_2.0.0-alpha.3_linux_amd64.tar.gz" -C /home/$USER >> /dev/null 2>&1
  else
    sudo tar -xvzf "$LOCAL_APPS/gotty/gotty_2.0.0-alpha.3_linux_arm.tar.gz" -C /home/$USER >> /dev/null 2>&1
  fi
  # Move e torna executável
  sudo mv /home/$USER/gotty /usr/local/bin/gotty
  sudo chmod +x /usr/local/bin/gotty
}

gotty_install () {
if [[ ! -f /usr/local/bin/gotty ]]; then
  gotty_do
else
  echo -e "${GREEN} Gotty já instalado, atualizando... ${NC}"
  sudo rm -f /usr/local/bin/gotty
  gotty_do
fi

# Define arrays for services and ports
SERVICES=("gotty" "gotty-fullauto" "gotty-logs-lnd" "gotty-logs-bitcoind" "gotty-btc-editor" "gotty-lnd-editor" "control-systemd")
PORTS=("3131" "3232" "3434" "3535" "3636" "3333" "5001")
COMMENTS=("allow BRLNfullauto on port 3131 from local network" 
  "allow cli on port 3232 from local network" 
  "allow bitcoinlogs on port 3434 from local network" 
  "allow lndlogs on port 3535 from local network"
  "allow btc-editor on port 3636 from local network"
  "allow lnd-editor on port 3333 from local network"
  "allow control-systemd on port 5001 from local network")

# Remove and copy service files
for service in "${SERVICES[@]}"; do
  sudo rm -f /etc/systemd/system/$service.service
  sudo cp /home/$USER/brlnfullauto/services/$service.service /etc/systemd/system/$service.service
done

# Reload systemd and enable/start services
sudo systemctl daemon-reload
for service in "${SERVICES[@]}"; do
  if ! sudo systemctl is-enabled --quiet $service.service; then
    sudo systemctl enable $service.service >> /dev/null 2>&1
    sudo systemctl restart $service.service >> /dev/null 2>&1 & spinner
  fi
done

# Configure UFW rules for ports
for i in "${!PORTS[@]}"; do
  if ! sudo ufw status | grep -q "${PORTS[i]}/tcp"; then
    sudo ufw allow from $subnet to any port ${PORTS[i]} proto tcp comment "${COMMENTS[i]}" >> /dev/null 2>&1
  fi
done
}

gui_update() {
  update_and_upgrade
  gotty_install
  sudo chown -R $USER:$USER /var/www/html/radio
  sudo chmod +x /var/www/html/radio/radio-update.sh
  sudo chmod +x /home/$USER/brlnfullauto/html/radio/radio-update.sh
  menu
}

terminal_web() {
  echo -e "${GREEN} Iniciando... ${NC}"
  if [[ ! -f /usr/local/bin/gotty ]]; then
    # Baixa o binário como admin
    update_and_upgrade
    radio_update
    gotty_install
    sudo chown -R $USER:$USER /var/www/html/radio
    sudo chmod +x /var/www/html/radio/radio-update.sh
    sudo chmod +x /home/$USER/brlnfullauto/html/radio/radio-update.sh
    tailscale_vpn
    opening
    exit 0
  else
    if [[ $atual_user == "$USER" ]]; then
      menu
      exit 0
    else
      echo -e "${RED} Você não está logado como $USER! ${NC}"
      echo -e "${RED} Logando como $USER e executando o script... ${NC}"
      if [[ ! -f /usr/local/bin/gotty ]]; then
        update_and_upgrade
        gotty_install
      fi
      sudo -u $USER bash "$INSTALL_DIR/brunel.sh"
      exit 0
    fi
  fi
}

create_main_dir() {
  sudo mkdir /data
  sudo chown $USER:$USER /data
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow from $subnet to any port 22 proto tcp comment 'allow SSH from local network'
  sudo ufw --force enable
}

install_tor() {
  sudo apt install -y apt-transport-https
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main
  deb-src [arch=amd64 signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] $TOR_LINIK jammy main" | sudo tee /etc/apt/sources.list.d/tor.list
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

postgres_db () {
  cd "$(dirname "$0")" || cd ~

  echo -e "${GREEN}⏳ Iniciando instalação do PostgreSQL...${NC}"

  # Importa a chave do repositório oficial
  sudo install -d /usr/share/postgresql-common/pgdg
  sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

  # Adiciona o repositório
  sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

  # Atualiza os pacotes e instala o PostgreSQL
  sudo apt update && sudo apt install -y postgresql postgresql-contrib

  echo -e "${GREEN}✅ PostgreSQL instalado com sucesso!${NC}"
  sleep 2

  # Cria o diretório de dados customizado
  sudo mkdir -p /data/postgresdb/17
  sudo chown -R postgres:postgres /data/postgresdb
  sudo chmod -R 700 /data/postgresdb

  echo -e "${GREEN}📁 Diretório /data/postgresdb/17 preparado.${NC}"
  sleep 1

  # Inicializa o cluster no novo local
  sudo -u postgres /usr/lib/postgresql/17/bin/initdb -D /data/postgresdb/17

  # Redireciona o PostgreSQL para o novo diretório
  sudo sed -i "42s|.*|data_directory = '/data/postgresdb/17'|" /etc/postgresql/17/main/postgresql.conf

  echo -e "${YELLOW}🔁 Redirecionando data_directory para /data/postgresdb/17${NC}"

  # Reinicia serviços e recarrega systemd
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl restart postgresql

  # Mostra clusters ativos
  pg_lsclusters

  # Cria a role com o nome do usuário atual e senha padrão (admin)
  sudo -u postgres psql -c "CREATE ROLE $USER WITH LOGIN CREATEDB PASSWORD 'admin';" || true

  # Cria banco de dados lndb com owner sendo o usuário atual
  sudo -u postgres createdb -O $USER lndb

  echo -e "${GREEN}🎉 PostgreSQL está pronto para uso com o banco 'lndb' e o usuário '$USER'.${NC}"
}



download_lnd() {
  set -e
  mkdir -p ~/lnd-install
  cd ~/lnd-install
  if [[ $arch == "x86_64" ]]; then
    arch_lnd="amd64"
  else
    arch_lnd="arm64"
  fi
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/lnd-linux-$arch_lnd-v$LND_VERSION-beta.tar.gz
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-v$LND_VERSION-beta.txt
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig.ots
  wget https://github.com/lightningnetwork/lnd/releases/download/v$LND_VERSION-beta/manifest-roasbeef-v$LND_VERSION-beta.sig
  sha256sum --check manifest-v$LND_VERSION-beta.txt --ignore-missing
  curl https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
  gpg --verify manifest-roasbeef-v$LND_VERSION-beta.sig manifest-v$LND_VERSION-beta.txt
  tar -xzf lnd-linux-$arch_lnd-v$LND_VERSION-beta.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-$arch_lnd-v$LND_VERSION-beta/lnd lnd-linux-$arch_lnd-v$LND_VERSION-beta/lncli
  sudo rm -r lnd-linux-$arch_lnd-v$LND_VERSION-beta lnd-linux-$arch_lnd-v$LND_VERSION-beta.tar.gz manifest-roasbeef-v$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots
}

configure_lnd() {
  local file_path="/home/$USER/brlnfullauto/conf_files/lnd.conf"
  echo -e "${GREEN}################################################################${NC}"
  echo -e "${GREEN} A seguir você será solicitado a adicionar suas credenciais do ${NC}"
  echo -e "${GREEN} bitcoind.rpcuser e bitcoind.rpcpass, caso você seja membro da BRLN.${NC}"
  echo -e "${YELLOW} Caso você não seja membro, escolha a opção ${RED}não${NC} ${YELLOW}e prossiga.${NC}"
  echo -e "${GREEN}################################################################${NC}"  
  echo
  read -p "Você deseja utilizar o bitcoind da BRLN? (y/n): " use_brlnd
  if [[ $use_brlnd == "y" ]]; then
    echo -e "${GREEN} Você escolheu usar o bitcoind remoto da BRLN! ${NC}"
    read -p "Digite o bitcoind.rpcuser(BRLN): " bitcoind_rpcuser
    read -p "Digite o bitcoind.rpcpass(BRLN): " bitcoind_rpcpass
    sed -i "s|^bitcoind\.rpcuser=.*|bitcoind.rpcuser=${bitcoind_rpcuser}|" "$file_path"
    sed -i "s|^bitcoind\.rpcpass=.*|bitcoind.rpcpass=${bitcoind_rpcpass}|" "$file_path"
  elif [[ $use_brlnd == "n" ]]; then
    echo -e "${RED} Você escolheu não usar o bitcoind remoto da BRLN! ${NC}"
    toggle_on
  else
    echo -e "${RED} Opção inválida. Por favor, escolha 'y' ou 'n'. ${NC}"
    exit 1
  fi
  # Coloca o alias lá na linha 8 (essa parte pode manter igual)
  local alias_line="alias=$alias BR⚡️LN"
  sudo sed -i "s|^alias=.*|$alias_line|" "$file_path"
  read -p "Qual Database você deseja usar? (postgres/bbolt): " db_choice
  if [[ $db_choice == "postgres" ]]; then
    echo -e "${GREEN}Você escolheu usar o Postgres!${NC}"
    read -p "Você deseja exibir os logs da instalação? (y/n): " show_logs
    if [[ $show_logs == "y" ]]; then
      echo -e "${GREEN}Exibindo logs da instalação do Postgres...${NC}"
      postgres_db
    elif [[ $show_logs == "n" ]]; then
      echo -e "${RED}Você escolheu não exibir os logs da instalação do Postgres!${NC}"
      postgres_db >> /dev/null 2>&1 & spinner
    else
      echo -e "${RED}Opção inválida. Por favor, escolha 'y' ou 'n'.${NC}"
      exit 1
    fi
    psql -V
    lnd_db=$(cat <<EOF
[db]
## Database selection
db.backend=postgres

[postgres]
db.postgres.dsn=postgresql://$USER:admin@127.0.0.1:5432/lndb?sslmode=disable
db.postgres.timeout=0
EOF
)
  elif [[ $db_choice == "bbolt" ]]; then
    echo -e "${RED}Você escolheu usar o Bbolt!${NC}"
    lnd_db=$(cat <<EOF
[bolt]
## Database
# Set the next value to false to disable auto-compact DB
# and fast boot and comment the next line
db.bolt.auto-compact=true
# Uncomment to do DB compact at every LND reboot (default: 168h)
#db.bolt.auto-compact-min-age=0h
EOF
)
  else
    echo -e "${RED}Opção inválida. Por favor, escolha 'sqlite' ou 'bbolt'.${NC}"
    exit 1
  fi
  # Inserir a configuração no arquivo lnd.conf na linha 100
  sed -i "/^routing\.strictgraphpruning=true/r /dev/stdin" "$file_path" <<< "

$lnd_db"

  sudo usermod -aG debian-tor $USER
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo usermod -a -G debian-tor $USER
  sudo mkdir -p /data/lnd
  sudo chown -R $USER:$USER /data/lnd
  if [[ ! -L /home/$USER/.lnd ]]; then
    ln -s /data/lnd /home/$USER/.lnd
  fi
    sudo chmod -R g+X /data/lnd
    sudo chmod 640 /run/tor/control.authcookie
    sudo chmod 750 /run/tor
    sudo cp $SERVICES_DIR/lnd.service /etc/systemd/system/lnd.service
    sudo cp $file_path /data/lnd/lnd.conf
    sudo chown $USER:$USER /data/lnd/lnd.conf
    sudo chmod 640 /data/lnd/lnd.conf
  if [[ $use_brlnd == "y" ]]; then
    create_wallet
  else
    echo -e "${RED}Você escolheu não usar o bitcoind remoto da BRLN!${NC}"
    echo -e "${YELLOW}Agora Você irá criar sua ${RED}FRASE DE 24 PALAVRAS.${YELLOW} Para isso você precisa aguardar seu bitcoin core sincronizar para prosseguir com a instalação, este processo pode demorar de 3 a 7 dias, dependendo do seu hardware.${NC}"
    echo -e "${YELLOW}Para acompanhar a sincronização do bitcoin core, use o comando ${RED} journalctl -fu bitcoind ${YELLOW}. Ao atingir 100%, você deve iniciar este programa novamente e escolher a opção ${RED}2 ${YELLOW}mais uma vez. ${NC}"
    echo -e "${YELLOW}Apenas após o termino deste processo, você pode prosseguir com a instalação do lnd, caso contrário você receberá um erro na criação da carteira.${NC}"
    read -p "Seu bitcoin core já está completamente sincronizado? (y/n): " sync_choice
      if [[ $sync_choice == "y" ]]; then
        echo -e "${GREEN} Você escolheu que o bitcoin core já está sincronizado! ${NC}"
        toggle_on >> /dev/null 2>&1
        sleep 5
        create_wallet
      fi
  fi
}

24_word_confirmation () {
  echo -e "${YELLOW} Você confirma que anotou a sua frase de 24 palavras corretamente? Ela não poderá ser recuperada no futuro, se não anotada agora!!! ${NC}"
  echo -e "${RED}Se voce não guardar esta informação de forma segura, você pode perder seus fundos depositados neste node, permanentemente!!!${NC}"
  read -p "Você confirma que anotou a sua frase de 24 palavras corretamente? (y/n): " confirm_phrase
  if [[ $confirm_phrase == "y" ]]; then
    echo -e "${GREEN} Você confirmou que anotou a frase de 24 palavras! ${NC}"
  else
    echo -e "${RED} Opção inválida. Por favor, confirme se anotou a frase de segurança. ${NC}"
    24_word_confirmation
  fi
  unset password  # limpa da memória, por segurança
  menu
} 

create_wallet () {
  if [[ ! -L /home/$USER/.lnd ]]; then
    ln -s /data/lnd /home/$USER/.lnd
  fi
  sudo chmod -R g+X /data/lnd
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  echo -e "${YELLOW}############################################################################################### ${NC}"
  echo -e "${YELLOW}Agora Você irá criar sua ${RED}FRASE DE 24 PALAVRAS${YELLOW}, digite a senha de desbloqueio do lnd, depois repita mais 2x para registra-la no lnd e pressione 'n' para criar uma nova carteira. ${NC}" 
  echo -e "${YELLOW}apenas pressione ${RED}ENTER${YELLOW} quando questionado se quer adicionar uma senha a sua frase de 24 palavras.${NC}" 
  echo -e "${YELLOW}AVISO!: Anote sua frase de 24 palavras com ATENÇÃO, AGORA! ${RED}Esta frase não pode ser recuperada no futuro se não for anotada agora. ${NC}" 
  echo -e "${RED}Se voce não guardar esta informação de forma segura, você pode perder seus fundos depositados neste node, permanentemente!!!${NC}"
  echo -e "${YELLOW}############################################################################################### ${NC}"
  read -p "Digite a senha da sua carteira lighting: " password
  read -p "Confirme a senha da sua carteira lighting: " password2
  if [[ $password != $password2 ]]; then
    echo -e "${RED}As senhas não coincidem. Por favor, tente novamente.${NC}"
    create_wallet
  fi
  echo "$password" | sudo tee /data/lnd/password.txt > /dev/null
  sudo chown $USER:$USER /data/lnd/password.txt
  sudo chmod 600 /data/lnd/password.txt
  sudo chown $USER:$USER /data/lnd
  sudo chmod 740 /data/lnd/lnd.conf
  sudo systemctl daemon-reload
  sudo systemctl enable lnd >> /dev/null 2>&1
  sudo systemctl start lnd
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
  24_word_confirmation
}

install_bitcoind() {
  local file_path="/home/$USER/brlnfullauto/conf_files/bitcoin.conf"
  set -e
  if [[ $arch == "x86_64" ]]; then
    arch_btc="x86_64"
  else
    arch_btc="aarch64"
  fi

  cd /tmp
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/bitcoin-$BTC_VERSION-$arch_btc-linux-gnu.tar.gz
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS
  wget https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS.asc
  sha256sum --ignore-missing --check SHA256SUMS
  curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do
    curl -s "$url" | gpg --import
  done
  gpg --verify SHA256SUMS.asc
  tar -xzvf bitcoin-$BTC_VERSION-$arch_btc-linux-gnu.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$BTC_VERSION/bin/bitcoin-cli bitcoin-$BTC_VERSION/bin/bitcoind
  sudo mkdir -p /data/bitcoin
  sudo chown $USER:$USER /data/bitcoin
  ln -s /data/bitcoin /home/$USER/.bitcoin
  sudo cp $file_path /data/bitcoin/bitcoin.conf
  sudo chown $USER:$USER /data/bitcoin/bitcoin.conf
  sudo chmod 640 /data/bitcoin/bitcoin.conf
  cd /home/$USER/.bitcoin
  wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py
  sudo sed -i "54s|.*|$(python3 rpcauth.py minibolt $rpcpsswd > /home/$USER/.bitcoin/rpc.auth | grep '^rpcauth=')|" /home/$USER/brlnfullauto/conf_files/bitcoin.conf
  sudo cp $SERVICES_DIR/bitcoind.service /etc/systemd/system/bitcoind.service
  sudo systemctl enable bitcoind
  sudo systemctl start bitcoind
  sudo ss -tulpn | grep bitcoind
  echo "Bitcoind instalado com sucesso!"
}

install_nodejs() {
  if [[ -d ~/.npm-global ]]; then
    echo "Node.js já está instalado."
  else
    curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
    sudo apt-get install nodejs -y
  fi
}

install_bos() {
  if [[ -d ~/.npm-global ]]; then
    echo "Balance of Satoshis já está instalado."
  else
    mkdir -p ~/.npm-global
    npm config set prefix ~/.npm-global
    if ! grep -q 'PATH="$HOME/.npm-global/bin:$PATH"' ~/.profile; then
      echo 'PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.profile
    fi
  cd ~
  npm i -g balanceofsatoshis
  sudo bash -c 'echo "127.0.0.1" >> /etc/hosts'
  sudo chown -R $USER:$USER /data/lnd
  sudo chmod -R 755 /data/lnd
  export BOS_DEFAULT_LND_PATH=/data/lnd
  mkdir -p ~/.bos/$alias
  base64 -w0 /data/lnd/tls.cert > /data/lnd/tls.cert.base64
  base64 -w0 /data/lnd/data/chain/bitcoin/mainnet/$USER.macaroon > /data/lnd/data/chain/bitcoin/mainnet/$USER.macaroon.base64
  cert_base64=$(cat /data/lnd/tls.cert.base64)
  macaroon_base64=$(cat /data/lnd/data/chain/bitcoin/mainnet/$USER.macaroon.base64)
  bash -c "cat <<EOF > ~/.bos/$alias/credentials.json
{
  "cert": "$cert_base64",
  "macaroon": "$macaroon_base64",
  "socket": "lnd:10009"
}
EOF"
  sudo cp $SERVICES_DIR/bos-telegram.service /etc/systemd/system/bos-telegram.service
  sudo systemctl daemon-reload
  fi
}

tailscale_vpn() {
  echo -e "${CYAN}🌐 Instalando Tailscale VPN...${NC}"
  curl -fsSL https://tailscale.com/install.sh | sh > /dev/null 2>&1
  sudo apt install qrencode -y > /dev/null 2>&1

  LOGFILE="/tmp/tailscale_up.log"
  QRFILE="/tmp/tailscale_qr.log"

  sudo rm -f "$LOGFILE" "$QRFILE"
  sudo touch "$LOGFILE"
  sudo chmod 666 "$LOGFILE"

  echo -e "${BLUE}▶️ Executando 'tailscale up'...${NC}"
  (sudo tailscale up > "$LOGFILE" 2>&1) &

  echo -e "${YELLOW}⏳ Aguardando link de autenticação do Tailscale (sem timeout)...${NC}"
  echo -e "${YELLOW} Caso esta etapa não progrida em 5 minutos, pressione Ctrl+C e faça ${RED}"tailscale up"${NC}"

  while true; do
    url=$(grep -Eo 'https://login\.tailscale\.com/[a-zA-Z0-9/]+' "$LOGFILE" | head -n1)
    if [[ -n "$url" ]]; then
      echo -e "${GREEN}✅ Link encontrado: $url${NC}"
      echo "$url" | qrencode -t ANSIUTF8 | tee "$QRFILE"
      echo -e "${GREEN}🔗 QR Code salvo em: $QRFILE${NC}"
      break
    fi
    sleep 1
  done
  opening
}

opening () {
  clear
  echo
  echo -e "${GREEN}✅ Interface gráfica instalada com sucesso! 🎉${NC}"
  echo -e "${GREEN}⚡️ Pronto! Seu node está no ar, seguro e soberano... ou quase. 😏${NC}"
  echo -e "${GREEN}🤨 Mas me diz... ainda vai confiar seus sats na mão dos outros?${NC}"
  echo -e "${GREEN}🚀 Rodar o próprio node é só o primeiro passo rumo à liberdade financeira.${NC}"
  echo -e "${GREEN}🌐 Junte-se aos que realmente entendem soberania: 👉${BLUE} https://br-ln.com${NC}"
  echo -e "${GREEN}🔥 Na BR⚡LN a gente não confia... a gente verifica, roda, automatiza e ensina!${NC}"
  echo -e "${GREEN} Acesse seu ${YELLOW}Node Lightning${NC}${GREEN} pelo navegador em:${NC}"
  echo
  echo -e "${RED} http://$(hostname -I | awk '{print $1}') ${NC}"
  echo
  echo -e "${RED} Ou escaneie o QR Code abaixo para conectar sua tailnet: ${NC}"
  echo
  echo -e "${GREEN}✅ Link encontrado: ${RED} $url${NC}"
  echo "$url" | qrencode -t ANSIUTF8
  echo
  echo -e "${GREEN} Em seguida escolha ${YELLOW}\"Configurações\"${NC}${GREEN} e depois ${YELLOW}\"Iniciar BrlnFullAuto\" ${NC}"
  echo
  echo
}

toggle_bitcoin () {
    # Exibir o menu para o usuário
    while true; do
        echo "Escolha uma opção:"
        echo "1) Trocar para o Bitcoin Core local"
        echo "2) Trocar para o node Bitcoin remoto"
        echo "3) Sair"
        read -p "Digite sua escolha: " choice

        case $choice in
            1)
                echo "Trocando para o Bitcoin Core local..."
                toggle_on
                wait
                echo "Trocado para o Bitcoin Core local."
                ;;
            2)
                echo "Trocando para o node Bitcoin remoto..."
                toggle_off
                wait 
                echo "Trocado para o node Bitcoin remoto."
                ;;
            3)
                echo "Saindo."
                menu
                ;;
            *)
                echo "Escolha inválida. Por favor, tente novamente."
                ;;
        esac
        echo ""
    done
}

toggle_on () {
  local FILES_TO_DELETE=(
    "/home/admin/.lnd/tls.cert"
    "/home/admin/.lnd/tls.key"
    "/home/admin/.lnd/v3_onion_private_key"
  )

  # Função interna para comentar linhas
  sed -i 's|^[[:space:]]*\(\[Bitcoind\]\)|#\1|' /data/lnd/lnd.conf
  sed -i 's|^[[:space:]]*\(bitcoind\.[^=]*=.*\)|#\1|' /data/lnd/lnd.conf
  # Função interna para apagar os arquivos
    for file in "${FILES_TO_DELETE[@]}"; do
      if [ -f "$file" ]; then
        rm -f "$file" >> /dev/null 2>&1
        echo "Deleted: $file"
      else
        echo "File not found: $file" >> /dev/null 2>&1
      fi
    done
  # Função interna para reiniciar o serviço LND
    sudo systemctl restart lnd
    if [ $? -eq 0 ]; then
      echo "LND service restarted successfully."
    else
      echo "Failed to restart LND service."
    fi
}

toggle_off () {
  local FILES_TO_DELETE=(
    "/home/admin/.lnd/tls.cert"
    "/home/admin/.lnd/tls.key"
    "/home/admin/.lnd/v3_onion_private_key"
  )

  # Função interna para descomentar linhas
  sed -i 's|^[[:space:]]*#\([[:space:]]*\[Bitcoind\]\)|\1|' /data/lnd/lnd.conf
  sed -i 's|^[[:space:]]*#\([[:space:]]*bitcoind\.[^=]*=.*\)|\1|' /data/lnd/lnd.conf
  # Função interna para apagar os arquivos
    for file in "${FILES_TO_DELETE[@]}"; do
      if [ -f "$file" ]; then
        rm -f "$file"
        echo "Deleted: $file"
      else
        echo "File not found: $file"
      fi
    done

  # Função interna para reiniciar o serviço LND
    sudo systemctl restart lnd
    if [ $? -eq 0 ]; then
      echo "LND service restarted successfully."
    else
      echo "Failed to restart LND service."
    fi
}

pacotes_do_sistema () {
  sudo apt update && sudo apt upgrade -y
  sudo systemctl reload tor
  echo "Os pacotes do sistema foram atualizados! Ex: Tor + i2pd + PostgreSQL"
}

menu_manutencao() {
  echo "Escolha uma opção:"
  echo "1) Atualizar o LND"
  echo "2) Atualizar o Bitcoind ATENÇÃO"
  echo "Antes de atualizar o Bitcoind, leia as notas de atualização"
  echo "3) Atualizar o Thunderhub"
  echo "4) Atualizar o LNDg"
  echo "5) Atualizar o LNbits"
  echo "6) Atualizar os pacotes do sistema"
  echo "7) Desinstalar Thunderhub"
  echo "8) Desinstalar LNDg"
  echo "9) Desinstalar LNbits"
  echo "0) Sair"
  read -p "Opção: " option

  case $option in
    1)
      lnd_update
      ;;
    2)
      bitcoin_update
      ;;
    3)
      thunderhub_update
      ;;
    4)
      lndg_update
      ;;
    5)
      lnbits_update
      ;;
    6)
      pacotes_do_sistema
      ;;
    7)
      thunderhub_uninstall
      ;;
    8)
      lndg_unninstall
      ;;
    9)
      lnbits_unninstall
      ;;
    0)
      echo "Saindo..."
      exit 0
      ;;
    *)
      echo "Opção inválida!"
      ;;
  esac
}

config_bos_telegram () {
  # ⚡ Script para configurar o BOS Telegram no systemd
  # 🔐 Substitui o placeholder pelo Connection Code fornecido
  # 🛠️ Reinicia o serviço após modificação

  SERVICE_FILE="/etc/systemd/system/bos-telegram.service"
  BOT_LINK="https://t.me/BotFather"

  echo "🔗 Gerando QR Code para acessar o bot do Telegram..."
  qrencode -t ansiutf8 "$BOT_LINK"

  echo ""
  echo "📱 Aponte sua câmera para o QR Code acima para abrir: $BOT_LINK"
  echo ""

  echo "⚡️ Crie um bot no Telegram usando o BotFather e obtenha a API Key."
  echo "🌐 Agora acesse a interface web, vá em \"Configurações\" e clique em \" Autenticar Bos Telegram\"."

  # Aguarda o usuário confirmar que recebeu a conexão
  read -p "Pressione ENTER aqui após a conexão ser concluída no Telegram..."

  echo "✍️ Digite o Connection Code do seu bot Telegram:"
  read -r connection_code

  # 🧠 Validação simples
  if [[ -z "$connection_code" ]]; then
    echo "❌ Connection Code não pode estar vazio."
    exit 1
  fi

  # 📝 Adiciona ou substitui ExecStart com o Connection Code
  if grep -q '^ExecStart=' "$SERVICE_FILE"; then
    sudo sed -i "s|^ExecStart=.*|ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect $connection_code|g" "$SERVICE_FILE"
  else
    sudo sed -i "/^\[Service\]/a ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect $connection_code" "$SERVICE_FILE"
  fi

  echo "✅ Connection Code inserido com sucesso no serviço bos-telegram."

  # 🔄 Recarrega o systemd e reinicia o serviço
  echo "🔄 Recarregando daemon do systemd..."
  sudo systemctl daemon-reload

  echo "🚀 Ativando e iniciando o serviço bos-telegram..."
  sudo systemctl enable bos-telegram
  sudo systemctl start bos-telegram

  echo "✅ Serviço bos-telegram configurado e iniciado com sucesso!"
  echo "💬 Verifique se recebeu a mensagem: 🤖 Connected to <nome do seu node>"
}

tor_acess () {
  TORRC_FILE="/etc/tor/torrc"
  HIDDEN_SERVICE_DIR="/var/lib/tor/hidden_service_lnd_rest"
  SERVICE_BLOCK=$(cat <<EOF
# Hidden Service LND REST
HiddenServiceDir $HIDDEN_SERVICE_DIR
HiddenServiceVersion 3
HiddenServicePoWDefensesEnabled 1
HiddenServicePort 8080 127.0.0.1:8080
EOF
  )

  echo "🚀 Iniciando configuração do serviço oculto do LND REST via Tor..."

  if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Por favor, execute como root (sudo)."
    exit 1
  fi

  # Verifica se já existe uma configuração para o hidden_service_lnd_rest
  if grep -q "$HIDDEN_SERVICE_DIR" "$TORRC_FILE"; then
    echo "♻️ Configuração existente detectada. Atualizando..."
    awk -v block="$SERVICE_BLOCK" '
      BEGIN { updated = 0 }
      $0 ~ /HiddenServiceDir .*hidden_service_lnd_rest/ {
        print block
        skip = 1
        updated = 1
        next
      }
      skip && /^HiddenServicePort/ { skip = 0; next }
      skip { next }
      { print }
      END {
        if (!updated) {
          print block
        }
      }
    ' "$TORRC_FILE" > /tmp/torrc.tmp && mv /tmp/torrc.tmp "$TORRC_FILE"
  else
    echo "➕ Adicionando nova entrada após o marcador de hidden services..."
    awk -v block="$SERVICE_BLOCK" '
      /## This section is just for location-hidden services ##/ {
        print
        print block
        next
      }
      { print }
    ' "$TORRC_FILE" > /tmp/torrc.tmp && mv /tmp/torrc.tmp "$TORRC_FILE"
  fi

  echo "🔄 Recarregando o Tor..."
  systemctl reload tor

  echo "⏳ Aguardando geração do endereço onion..."
  for i in {1..10}; do
    [[ -f "$HIDDEN_SERVICE_DIR/hostname" ]] && break
    sleep 1
  done

  if [[ -f "$HIDDEN_SERVICE_DIR/hostname" ]]; then
    echo "✅ Endereço onion encontrado:"
    cat "$HIDDEN_SERVICE_DIR/hostname"
  else
    echo "❌ Falha ao localizar o hostname. Verifique se o Tor está rodando corretamente."
    exit 1
  fi
}

submenu_opcoes() {
  echo -e "${CYAN}🔧 Mais opções disponíveis:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- 🏠 Trocar para o bitcoin local."
  echo -e "   ${GREEN}2${NC}- ☁️ Trocar para o bitcoin remoto."
  echo -e "   ${GREEN}3${NC}- 🔴 Atualizar e desinstalar programas."
  echo -e "   ${GREEN}4${NC}- 🔧 Ativar o Bos Telegram no boot do sistema."
  echo -e "   ${GREEN}5${NC}- 🔄 Atualizar interface gráfica."
  echo -e "   ${RED}0${NC}- Voltar ao menu principal"
  echo

  read -p "👉  Digite sua escolha:     " suboption

  case $suboption in
    1)
      echo -e "${YELLOW}🏠 🔁 Trocar para o bitcoin local...${NC}"
      toggle_on
      echo -e "${GREEN}✅ Serviços reiniciados!${NC}"
      submenu_opcoes
      ;;
    2)
      echo -e "${YELLOW}🔁 ☁️ Trocar para o bitcoin remoto...${NC}"
      toggle_off
      echo -e "${GREEN}✅ Atualização concluída!${NC}"
      submenu_opcoes
      ;;
    3)
      manutencao_script
      submenu_opcoes
      ;;
    4)
      echo -e "${YELLOW}🔧 Configurando o Bos Telegram...${NC}"
      config_bos_telegram
      submenu_opcoes
      ;;
    5)
      echo -e "${YELLOW} Atualizando interface gráfica...${NC}"
            app="Gui"
      sudo -v
      echo -e "${CYAN}🚀 Atualizando interface gráfica...${NC}"
      gui_update
      echo -e "\033[43m\033[30m ✅ Interface atualizada com sucesso! \033[0m"
      exit 0
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

radio_update () {
  # Caminho do script que deve rodar a cada hora
  SCRIPT="/home/admin/brlnfullauto/html/radio/radio-update.sh"

  # Linha que será adicionada ao crontab
  CRON_LINE="0 * * * * $SCRIPT >> /var/log/update_radio.log 2>&1"

  # Verifica se já existe no crontab
  crontab -l 2>/dev/null | grep -F "$SCRIPT" > /dev/null

  if [ $? -eq 0 ]; then
    echo "✅ A entrada do crontab já existe. Nenhuma alteração feita."
  else
    echo "➕ Adicionando entrada ao crontab..."
    (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
    echo "✅ Entrada adicionada com sucesso!"
  fi
  sudo chmod +x $SCRIPT
}

ip_finder () {
  ip_local=$(hostname -I | awk '{print $1}')
}  

get_network_cidr() {
  interface=$(ip route | grep default | awk '{print $5}')
  if [[ -z "$interface" ]]; then
    echo "Error: No default route found. Please check your network configuration." >&2
    exit 1
  fi

  ip_info=$(ip -o -f inet addr show "$interface" | awk '{print $4}')
  ip_address=$(echo "$ip_info" | cut -d'/' -f1)
  prefix=$(echo "$ip_info" | cut -d'/' -f2)

  IFS='.' read -r o1 o2 o3 o4 <<< "$ip_address"

  mask=$(( 0xFFFFFFFF << (32 - $prefix) & 0xFFFFFFFF ))

  ip_as_int=$(( (o1 << 24) + (o2 << 16) + (o3 << 8) + o4 ))
  network_as_int=$(( ip_as_int & mask ))

  n1=$(( (network_as_int >> 24) & 0xFF ))
  n2=$(( (network_as_int >> 16) & 0xFF ))
  n3=$(( (network_as_int >> 8) & 0xFF ))
  n4=$(( network_as_int & 0xFF ))

  subnet="${n1}.${n2}.${n3}.${n4}/${prefix}"
}

system_detector () {
  arch=$(uname -m)
}

system_preparations () {
  create_main_dir
  configure_ufw
  echo -e "${YELLOW}🕒 Isso pode demorar um pouco...${NC}"
  echo -e "${YELLOW}Na pior das hipóteses, até 30 minutos...${NC}"
  install_tor
  install_nodejs
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

        printf "\r\033[KInstalando $app no seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
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

menu() {
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
  echo -e "   ${GREEN}1${NC}- Instalar Interface de Rede"
  echo -e "   ${GREEN}2${NC}- Instalar Bitcoin Core"
  echo -e "   ${GREEN}3${NC}- Instalar LND & Criar Carteira"
  echo 
  echo -e "${YELLOW} Estas São as Opções de Instalação de Aplicativos de Administração:${NC}"
  echo
  echo -e "   ${GREEN}4${NC}- Instalar Simple LNWallet - By JVX (Exige LND)"
  echo -e "   ${GREEN}5${NC}- Instalar Thunderhub & Balance of Satoshis (Exige LND)"
  echo -e "   ${GREEN}6${NC}- Instalar Lndg (Exige LND)"
  echo -e "   ${GREEN}7${NC}- Instalar LNbits"
  echo -e "   ${GREEN}8${NC}- Mais opções"
  echo -e "   ${RED}0${NC}- Sair"
  echo 
  echo -e "${GREEN} $SCRIPT_VERSION ${NC}"
  echo
  read -p "👉   Digite sua escolha:   " option
  echo

  case $option in
    1)
      app="Rede Privada"
      sudo -v
      echo -e "${CYAN}🚀 Instalando preparações do sistema...${NC}"
      echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
      read -p "Deseja exibir logs? (y/n): " verbose_mode
    # Força pedido de password antes do background
      sudo -v
      sudo apt autoremove -y
      if [[ "$verbose_mode" == "y" ]]; then
        system_preparations
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW}Aguarde p.f. A instalação está sendo executada em segundo plano...${NC}"
        echo -e "${YELLOW}🕒 ATENÇÃO: Esta etapa pode demorar 10 - 30min. Seja paciente.${NC}"
        system_preparations >> /dev/null 2>&1 &
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
      echo -e "\033[43m\033[30m ✅ Instalação da interface de rede concluída! \033[0m"
      menu      
      ;;

    2)
      app="Bitcoin"
      sudo -v
      echo -e "${YELLOW} instalando o bitcoind...${NC}"
      read -p "Escolha sua senha do Bitcoin Core: " "rpcpsswd"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        install_bitcoind
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        install_bitcoind >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ Sua instalação do bitcoin core foi bem sucedida! \033[0m"
      menu
      ;;
    3)
      app="Lnd"
      sudo -v
      echo -e "${CYAN}🚀 Iniciando a instalação do LND...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      echo -e "${YELLOW} instalando o lnd...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        download_lnd
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        download_lnd >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      configure_lnd
      echo -e "\033[43m\033[30m ✅ Sua instalação do LND foi bem sucedida! \033[0m"
      menu
      ;;
    4)
      app="Simple Wallet"
      sudo -v
      echo -e "${CYAN}🚀 Instalando Simple LNWallet...${NC}"
      simple_lnwallet
      echo -e "\033[43m\033[30m ✅ Simple LNWallet instalado com sucesso! \033[0m"
      menu
      ;;
    5)
      app="Balance of Satoshis"
      sudo -v
      echo -e "${CYAN}🚀 Instalando Balance of Satoshis...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        install_bos
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco...${NC}  "
        install_bos >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ Balance of Satoshis instalado com sucesso! \033[0m"
      echo
      echo -e "${YELLOW}🕒 Iniciando a instalação do Thunderhub...${NC}"
      read -p "Digite a senha para ThunderHub: " thub_senha
      echo -e "${CYAN}🚀 Instalando ThunderHub...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      app="Thunderhub"
      if [[ "$verbose_mode" == "y" ]]; then
        install_thunderhub
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso poderá demorar 10min ou mais. Seja paciente...${NC}"
        install_thunderhub >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ ThunderHub instalado com sucesso! \033[0m"
      menu
      ;;
    6)
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
        menu
      fi
      echo -e "${YELLOW}📝 Para acessar o LNDG, use a seguinte senha:${NC}"
      echo
      cat ~/lndg/data/lndg-admin.txt
      echo
      echo
      echo -e "${YELLOW}📝 Você deve mudar essa senha ao final da instalação."
      echo -e "\033[43m\033[30m ✅ LNDG instalado com sucesso! \033[0m"
      menu
      ;;
    7)
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
      menu
      ;;
    8)
      submenu_opcoes
      ;;
    0)
      echo -e "${MAGENTA}👋 Saindo... Até a próxima!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Opção inválida! Tente novamente.${NC}"
      ;;
    esac
  }

system_detector
get_network_cidr
ip_finder
terminal_web
