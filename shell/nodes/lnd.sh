#!/bin/bash
source ~/brlnfullauto/shell/.env

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

  # Cria a role admin com senha padrão (admin)
  sudo -u postgres psql -c "CREATE ROLE admin WITH LOGIN CREATEDB PASSWORD 'admin';" || true

  # Cria banco de dados lndb com owner admin
  sudo -u postgres createdb -O admin lndb

  echo -e "${GREEN}🎉 PostgreSQL está pronto para uso com o banco 'lndb' e o usuário 'admin'.${NC}"
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
  local file_path="/home/admin/brlnfullauto/conf_files/lnd.conf"
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
db.postgres.dsn=postgresql://admin:admin@127.0.0.1:5432/lndb?sslmode=disable
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

  sudo usermod -aG debian-tor admin
  sudo chmod 640 /run/tor/control.authcookie
  sudo chmod 750 /run/tor
  sudo usermod -a -G debian-tor admin
  sudo mkdir -p /data/lnd
  sudo chown -R admin:admin /data/lnd
  if [[ ! -L /home/admin/.lnd ]]; then
    ln -s /data/lnd /home/admin/.lnd
  fi
    sudo chmod -R g+X /data/lnd
    sudo chmod 640 /run/tor/control.authcookie
    sudo chmod 750 /run/tor
    sudo cp $SERVICES_DIR/lnd.service /etc/systemd/system/lnd.service
    sudo cp $file_path /data/lnd/lnd.conf
    sudo chown admin:admin /data/lnd/lnd.conf
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
  if [[ ! -L /home/admin/.lnd ]]; then
    ln -s /data/lnd /home/admin/.lnd
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
  sudo chown admin:admin /data/lnd/password.txt
  sudo chmod 600 /data/lnd/password.txt
  sudo chown admin:admin /data/lnd
  sudo chmod 740 /data/lnd/lnd.conf
  sudo systemctl daemon-reload
  sudo systemctl enable lnd >> /dev/null 2>&1
  sudo systemctl start lnd
  lncli --tlscertpath /data/lnd/tls.cert.tmp create
  24_word_confirmation
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

        printf "\r\033[KInstalando seu BRLN bolt...${YELLOW}%s${NC} ${CYAN}[%s]${NC}" "$emoji" "$spin_char"
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