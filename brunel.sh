#!/bin/bash

# Source das funções básicas
source "$(dirname "$0")/scripts/.env"
basics

SCRIPT_VERSION=v2.0-alfa
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
LND_VERSION=0.18.5
BTC_VERSION=28.1
VERSION_THUB=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | jq -r '.tag_name' | sed 's/^v//')
# Set REPO_DIR based on whether we're running as root or not
if [[ "$EUID" -eq 0 ]]; then
    REPO_DIR="/root/brln-os"
else
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
HTML_SRC="$REPO_DIR/html"
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
SERVICES_DIR="$REPO_DIR/services"
POETRY_BIN="/home/$USER/.local/bin/poetry"
FLASKVENV_DIR="/home/$USER/envflask"
atual_user=$(whoami)
branch="main"

log "Iniciando configuração do BRLN-OS Container Stack..."

gui_update() {
  update_and_upgrade
  gotty_install
  sudo chown -R $USER:$USER /var/www/html/radio
  sudo chmod +x /var/www/html/radio/radio-update.sh
  sudo chmod +x $REPO_DIR/html/radio/radio-update.sh
  menu
}

create_main_dir() {
  sudo mkdir -p /data
  sudo chown $USER:$USER /data
  cp -r "/root/brln-os/scripts/.env.example" "/root/brln-os/scripts/.env"
}

# Função para preparar o sistema Docker adequadamente
prepare_docker_system() {
  log "🔧 Preparando sistema Docker..."
  
  # Criar diretórios de dados necessários
  log "📁 Criando diretórios de dados..."
  sudo mkdir -p /data/{lnd,bitcoin,elements,lndg,thunderhub,lnbits}
  sudo chown -R $USER:$USER /data
  
  # Copiar arquivos necessários para os volumes
  log "📋 Copiando arquivos de configuração necessários..."
  
  # Copiar arquivo de senha do LND se não existir
  if [[ ! -f "/data/lnd/password.txt" ]]; then
    if [[ -f "$REPO_DIR/container/lnd/password.txt" ]]; then
      sudo cp "$REPO_DIR/container/lnd/password.txt" "/data/lnd/"
      log "✅ Arquivo password.txt copiado para /data/lnd/"
    else
      warning "⚠️ Arquivo password.txt não encontrado em container/lnd/"
    fi
  fi
  
  # Verificar se o setup-docker-smartsystem.sh existe e executá-lo
  if [[ -f "$REPO_DIR/container/setup-docker-smartsystem.sh" ]]; then
    log "🚀 Executando setup-docker-smartsystem.sh..."
    cd "$REPO_DIR/container"
    chmod +x setup-docker-smartsystem.sh
    
    # Executar o setup inteligente
    if sudo ./setup-docker-smartsystem.sh; then
      log "✅ Sistema Docker preparado com sucesso!"
      # Criar arquivo de controle para indicar que o sistema foi preparado
      touch "/data/.docker_system_prepared"
    else
      error "❌ Falha na preparação do sistema Docker"
      return 1
    fi
  else
    warning "⚠️ setup-docker-smartsystem.sh não encontrado"
  fi
  
  log "🎯 Preparação do sistema concluída!"
}

# Função para verificar se o sistema Docker precisa ser preparado
check_docker_system_ready() {
  local ready=true
  
  # Verificar se os diretórios principais existem
  if [[ ! -d "/data/lnd" ]] || [[ ! -d "/data/bitcoin" ]]; then
    ready=false
  fi
  
  # Verificar se o arquivo de senha do LND existe
  if [[ ! -f "/data/lnd/password.txt" ]]; then
    ready=false
  fi
  
  echo $ready
}

# Função para garantir que o sistema Docker esteja preparado antes de instalar serviços
ensure_docker_system_ready() {
  local service_name="$1"
  
  # Verificar se já foi preparado
  if [[ -f "/data/.docker_system_prepared" ]] && [[ $(check_docker_system_ready) == "true" ]]; then
    log "✅ Sistema Docker já está preparado"
    return 0
  fi
  
  log "🔧 Sistema Docker precisa ser preparado antes de instalar $service_name"
  log "🚀 Executando preparação automática do sistema..."
  
  if prepare_docker_system; then
    log "✅ Sistema Docker preparado com sucesso para $service_name!"
    return 0
  else
    error "❌ Falha na preparação do sistema Docker para $service_name"
    return 1
  fi
}

configure_ufw() {
  sudo sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw
  sudo ufw logging off
  sudo ufw allow from $subnet to any port 22 proto tcp comment 'allow SSH from local network'
  sudo ufw --force enable
}

postgres_db () {
  cd "$(dirname "$0")" || cd ~

  log "⏳ Iniciando instalação do PostgreSQL..."

  # Importa a chave do repositório oficial
  sudo install -d /usr/share/postgresql-common/pgdg
  sudo curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

  # Adiciona o repositório
  sudo sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

  # Atualiza os pacotes e instala o PostgreSQL
  sudo apt update && sudo apt install -y postgresql postgresql-contrib

  log "✅ PostgreSQL instalado com sucesso!"
  sleep 2

  # Cria o diretório de dados customizado
  sudo mkdir -p /data/postgresdb/17
  sudo chown -R postgres:postgres /data/postgresdb
  sudo chmod -R 700 /data/postgresdb

  log "📁 Diretório /data/postgresdb/17 preparado."
  sleep 1

  # Inicializa o cluster no novo local
  sudo -u postgres /usr/lib/postgresql/17/bin/initdb -D /data/postgresdb/17

  # Redireciona o PostgreSQL para o novo diretório
  sudo sed -i "42s|.*|data_directory = '/data/postgresdb/17'|" /etc/postgresql/17/main/postgresql.conf

  warning "🔁 Redirecionando data_directory para /data/postgresdb/17"

  # Reinicia serviços e recarrega systemd
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl restart postgresql

  # Mostra clusters ativos
  pg_lsclusters

  # Cria a role com o nome do usuário atual e senha padrão
  sudo -u postgres psql -c "CREATE ROLE $USER WITH LOGIN CREATEDB PASSWORD '$USER';" || true

  # Cria banco de dados lndb com owner sendo o usuário atual
  sudo -u postgres createdb -O $USER lndb

  log "🎉 PostgreSQL está pronto para uso com o banco 'lndb' e o usuário '$USER'."
}



configure_lnd() {
# Coloca o alias lá na linha 8 (essa parte pode manter igual)
local alias_line="alias=$alias BR⚡️LN"
sudo sed -i "s|^alias=.*|$alias_line|" "$file_path"
read -p "Qual Database você deseja usar? (postgres/bbolt): " db_choice
  if [[ $db_choice == "postgres" ]]; then
    log "Você escolheu usar o Postgres!"
    read -p "Você deseja exibir os logs da instalação? (y/n): " show_logs
    if [[ $show_logs == "y" ]]; then
      log "Exibindo logs da instalação do Postgres..."
      postgres_db
    elif [[ $show_logs == "n" ]]; then
      warning "Você escolheu não exibir os logs da instalação do Postgres!"
      postgres_db >> /dev/null 2>&1 & spinner
    else
      error "Opção inválida. Por favor, escolha 'y' ou 'n'."
      exit 1
    fi
    psql -V
    lnd_db=$(cat <<EOF
[db]
## Database selection
db.backend=postgres

[postgres]
db.postgres.dsn=postgresql://$USER:$USER@127.0.0.1:5432/lndb?sslmode=disable
db.postgres.timeout=0
EOF
)
  elif [[ $db_choice == "bbolt" ]]; then
    warning "Você escolheu usar o Bbolt!"
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
    error "Opção inválida. Por favor, escolha 'sqlite' ou 'bbolt'."
    exit 1
  fi
  # Inserir a configuração no arquivo lnd.conf na linha 100
  sed -i "/^routing\.strictgraphpruning=true/r /dev/stdin" "$file_path" <<< "

$lnd_db"
}

install_nodejs() {
  if [[ -d ~/.npm-global ]]; then
    info "Node.js já está instalado."
  else
    curl -sL https://deb.nodesource.com/setup_21.x | sudo -E bash -
    sudo apt-get install nodejs -y
  fi
}

install_bos() {
  if [[ -d ~/.npm-global ]]; then
    info "Balance of Satoshis já está instalado."
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
  "socket": "127.0.0.1:10009"
}
EOF"
  sudo cp $SERVICES_DIR/bos-telegram.service /etc/systemd/system/bos-telegram.service
  sudo systemctl daemon-reload
  fi
}

toggle_bitcoin () {
    # Exibir o menu para o usuário
    while true; do
        info "Escolha uma opção:"
        info "1) Trocar para o Bitcoin Core local"
        info "2) Trocar para o node Bitcoin remoto"
        info "3) Sair"
        read -p "Digite sua escolha: " choice

        case $choice in
            1)
                log "Trocando para o Bitcoin Core local..."
                toggle_on
                wait
                log "Trocado para o Bitcoin Core local."
                ;;
            2)
                log "Trocando para o node Bitcoin remoto..."
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
    "/data/lnd/tls.cert"
    "/data/lnd/tls.key"
    "/data/lnd/v3_onion_private_key"
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
    "/data/lnd/tls.cert"
    "/data/lnd/tls.key"
    "/data/lnd/v3_onion_private_key"
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
    sudo sed -i "s|^ExecStart=.*|ExecStart=/home/$USER/.npm-global/bin/bos telegram --use-small-units --connect $connection_code|g" "$SERVICE_FILE"
  else
    sudo sed -i "/^\[Service\]/a ExecStart=/home/$USER/.npm-global/bin/bos telegram --use-small-units --connect $connection_code" "$SERVICE_FILE"
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

submenu_opcoes() {
  echo -e "${CYAN}🔧 Mais opções disponíveis:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- 🏠 Trocar para o bitcoin local."
  echo -e "   ${GREEN}2${NC}- ☁️ Trocar para o bitcoin remoto."
  echo -e "   ${GREEN}3${NC}- 🔧 Ativar o Bos Telegram no boot do sistema."
  echo -e "   ${GREEN}4${NC}- 🔄 Atualizar interface gráfica."
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
      echo -e "${YELLOW}🔧 Configurando o Bos Telegram...${NC}"
      config_bos_telegram
      submenu_opcoes
      ;;
    4)
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
  SCRIPT="$REPO_DIR/html/radio/radio-update.sh"

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
  cd "$REPO_DIR/container"
  sudo -v
  echo
  echo -e "${CYAN}🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟${NC}"
  echo
  echo -e "${CYAN}"
  echo "$BRLN_ASCII_FULL"
  echo -e "${GREEN}"
  echo "$BRLN_OS_ASCII"
  echo -e "${YELLOW}"
  echo "$LIGHTNING_BOLT"
  echo -e "${NC}"
  echo
  echo -e "${YELLOW} Acesse seu nó usando o IP no navegador:${RED} $ip_local${NC}"
  echo -e "${YELLOW} Sua arquitetura é:${RED} $arch${NC}"
  echo
  echo -e "${YELLOW}📝 Escolha uma opção:${NC}"
  echo
  echo -e "   ${GREEN}1${NC}- Instalar Bitcoin + LND & Criar Carteira"
  echo -e "   ${GREEN}2${NC}- Instalar Elements (Liquid Network Node)"
  echo -e "   ${GREEN}3${NC}- Thunderhub (Exige LND)"
  echo -e "   ${GREEN}4${NC}- Instalar Balance of Satoshis (Exige LND)"
  echo -e "   ${GREEN}5${NC}- Instalar Lndg (Exige LND)"
  echo -e "   ${GREEN}6${NC}- Instalar LNbits"
  echo -e "   ${GREEN}7${NC}- Mais opções"
  echo -e "   ${GREEN}8${NC}- 🔧 Preparar Sistema Docker"
  echo -e "   ${RED}0${NC}- Sair"
  echo 
  echo -e "${GREEN} $SCRIPT_VERSION ${NC}"
  echo
  read -p "👉   Digite sua escolha:   " option
  echo

  case $option in
    1)
      app="lnd"
      echo -e "${CYAN}🚀 Iniciando a instalação do $app...${NC}"
      
      # Garantir que o sistema Docker esteja preparado
      if ! ensure_docker_system_ready "$app"; then
        error "❌ Falha na preparação do sistema Docker para $app"
        menu
        return 1
      fi
      
      sudo bash "$REPO_DIR/scripts/install-$app.sh"
      echo -e "\033[43m\033[30m ✅ Sua instalação do $app foi bem sucedida! \033[0m"
      menu
      ;;
    2)
      app="elements"
      echo -e "${CYAN}🚀 Iniciando a instalação do $app...${NC}"
      
      # Garantir que o sistema Docker esteja preparado
      if ! ensure_docker_system_ready "$app"; then
        error "❌ Falha na preparação do sistema Docker para $app"
        menu
        return 1
      fi
      
      sudo bash "$REPO_DIR/scripts/install-$app.sh"
      echo -e "\033[43m\033[30m ✅ $app instalado com sucesso \033[0m"
      menu
      ;;
    3)
      app="thunderhub"
      echo -e "${CYAN}🚀 Iniciando a instalação do $app...${NC}"
      
      # Garantir que o sistema Docker esteja preparado
      if ! ensure_docker_system_ready "$app"; then
        error "❌ Falha na preparação do sistema Docker para $app"
        menu
        return 1
      fi
      
      sudo bash "$REPO_DIR/scripts/install-$app.sh"
      echo -e "\033[43m\033[30m ✅ $app instalado com sucesso! \033[0m"
      menu
      ;;
    4)
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
      menu
      ;;
    5)
      app="lndg"
      echo -e "${CYAN}🚀 Iniciando a instalação do $app...${NC}"
      
      # Garantir que o sistema Docker esteja preparado
      if ! ensure_docker_system_ready "$app"; then
        error "❌ Falha na preparação do sistema Docker para $app"
        menu
        return 1
      fi
      
      sudo bash "$REPO_DIR/scripts/install-$app.sh"
      echo -e "\033[43m\033[30m ✅ $app instalado com sucesso! \033[0m"
      menu
      ;;
    6)
      app="lnbits"
      echo -e "${CYAN}🚀 Iniciando a instalação do $app...${NC}"
      
      # Garantir que o sistema Docker esteja preparado
      if ! ensure_docker_system_ready "$app"; then
        error "❌ Falha na preparação do sistema Docker para $app"
        menu
        return 1
      fi
      
      sudo bash "$REPO_DIR/scripts/install-$app.sh"
      echo -e "\033[43m\033[30m ✅ $app instalado com sucesso! \033[0m"
      menu
      ;;
    7)
      submenu_opcoes
      ;;
    8)
      echo -e "${CYAN}🔧 Preparando Sistema Docker...${NC}"
      if prepare_docker_system; then
        echo -e "\033[43m\033[30m ✅ Sistema Docker preparado com sucesso! \033[0m"
      else
        echo -e "\033[41m\033[37m ❌ Falha na preparação do Sistema Docker! \033[0m"
      fi
      menu
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
ip_finder
menu
