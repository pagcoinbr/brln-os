#!/bin/bash
SCRIPT_VERSION=v2.0-alfa
TOR_LINIK=https://deb.torproject.org/torproject.org
TOR_GPGLINK=https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc
LND_VERSION=0.18.5
BTC_VERSION=28.1
VERSION_THUB=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | jq -r '.tag_name' | sed 's/^v//')
REPO_DIR="/home/$USER/brln-os"
HTML_SRC="$REPO_DIR/html"
CGI_DST="/usr/lib/cgi-bin"
WWW_HTML="/var/www/html"
SERVICES_DIR="/home/$USER/brln-os/services"
POETRY_BIN="/home/$USER/.local/bin/poetry"
FLASKVENV_DIR="/home/$USER/envflask"
atual_user=$(whoami)
branch="main"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor

gui_update() {
  update_and_upgrade
  gotty_install
  sudo chown -R $USER:$USER /var/www/html/radio
  sudo chmod +x /var/www/html/radio/radio-update.sh
  sudo chmod +x /home/$USER/brln-os/html/radio/radio-update.sh
  menu
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



configure_lnd() {
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
  SCRIPT="/home/$USER/brln-os/html/radio/radio-update.sh"

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
  echo -e "   ${GREEN}1${NC}- Instalação completa do BRLN-OS"
  echo
  echo -e "${YELLOW} Instalação Avançada:${NC}"
  echo
  echo -e "   ${GREEN}2${NC}- Instalar Bitcoin Core"
  echo -e "   ${GREEN}3${NC}- Instalar LND & Criar Carteira"
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
      app="BRLN-OS"
      sudo -v
      echo -e "${CYAN}🚀 Instalando BRLN-OS...${NC}"
      echo -e "${YELLOW}Digite a senha do usuário admin caso solicitado.${NC}" 
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      sudo apt autoremove -y
      if [[ "$verbose_mode" == "y" ]]; then
        bash "$REPO_DIR/setup.sh" 
        cd "$REPO_DIR/container"
        docker-compose build
        docker-compose up -d
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW}Aguarde p.f. A instalação está sendo executada em segundo plano...${NC}"
        echo -e "${YELLOW}🕒 ATENÇÃO: Esta etapa pode demorar 10 - 30min. Seja paciente.${NC}"
        bash "$REPO_DIR/setup.sh"
        cd "$REPO_DIR/container"
        docker-compose build >> /dev/null 2>&1 & spinner
        docker-compose up -d >> /dev/null 2>&1 & spinner
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
      echo -e "\033[43m\033[30m ✅ Instalação do BRLN-OS de rede concluída! \033[0m"
      menu      
      ;;

    2)
      app="bitcoin"
      sudo -v
      echo -e "${YELLOW} instalando o bitcoind...${NC}"
      read -p "Escolha sua senha do Bitcoin Core: " "rpcpsswd"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      echo -e "\033[43m\033[30m ✅ Sua instalação do bitcoin core foi bem sucedida! \033[0m"
      menu
      ;;
    3)
      app="lnd"
      sudo -v
      echo -e "${CYAN}🚀 Iniciando a instalação do LND...${NC}"
      read -p "Digite o nome do seu Nó (NÃO USE ESPAÇO!): " "alias"
      echo -e "${YELLOW} instalando o lnd...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde p.f.${NC}"
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
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
      app="thunderhub"
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
    5)
      app="Balance of Satoshis"
      sudo -v
      echo -e "${CYAN}🚀 Instalando Balance of Satoshis...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app >> /dev/null
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco...${NC}  "
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
        clear
      else
        echo "Opção inválida."
        menu
      fi
      menu
      ;;
    6)
      app="lndg"
      sudo -v
      echo -e "${CYAN}🚀 Instalando LNDG...${NC}"
      read -p "Deseja exibir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco...${NC}"
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
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
      app="lnbits"
      sudo -v
      echo -e "${CYAN}🚀 Instalando LNbits...${NC}"
      read -p "Deseja exigir logs? (y/n): " verbose_mode
      if [[ "$verbose_mode" == "y" ]]; then
        cd "$REPO_DIR/container"
        docker-compose build $app
        docker-compose up -d $app
      elif [[ "$verbose_mode" == "n" ]]; then
        echo -e "${YELLOW} 🕒 Aguarde, isso pode demorar um pouco... Seja paciente.${NC}"
        cd "$REPO_DIR/container"
        docker-compose build $app >> /dev/null 2>&1 & spinner
        docker-compose up -d $app >> /dev/null 2>&1 & spinner
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
ip_finder
menu
