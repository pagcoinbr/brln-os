#!/bin/bash
source ~/brlnfullauto/shell/.env

lnd_update () {
  cd /tmp
LND_VERSION=$(curl -s https://api.github.com/repos/lightningnetwork/lnd/releases/latest | grep -oP '"tag_name": "\Kv[0-9]+\.[0-9]+\.[0-9]+(?=-beta)')
echo "$LND_VERSION"
{
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/lnd-linux-amd64-$LND_VERSION-beta.tar.gz
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-$LND_VERSION-beta.txt.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-$LND_VERSION-beta.txt
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-roasbeef-$LND_VERSION-beta.sig.ots
    wget -q https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION-beta/manifest-roasbeef-$LND_VERSION-beta.sig
    sha256sum --check manifest-$LND_VERSION-beta.txt --ignore-missing
    curl -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/scripts/keys/roasbeef.asc | gpg --import
    gpg --verify manifest-roasbeef-$LND_VERSION-beta.sig manifest-$LND_VERSION-beta.txt
    tar -xzf lnd-linux-amd64-$LND_VERSION-beta.tar.gz
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd-linux-amd64-$LND_VERSION-beta/lnd lnd-linux-amd64-$LND_VERSION-beta/lncli
    sudo rm -r lnd-linux-amd64-$LND_VERSION-beta lnd-linux-amd64-$LND_VERSION-beta.tar.gz manifest-roasbeef-$LND_VERSION-beta.sig manifest-roasbeef-v$LND_VERSION-beta.sig.ots manifest-v$LND_VERSION-beta.txt manifest-v$LND_VERSION-beta.txt.ots
    sudo systemctl restart lnd
    cd
} &> /dev/null &
  echo "Atualizando LND... Por favor, aguarde."
  wait
  echo "LND atualizado!"
}

bitcoin_update () {
  cd /tmp
VERSION=$(curl -s https://bitcoincore.org/en/download/ | grep -oP 'bitcoin-core-\K[0-9]+\.[0-9]+' | head -n1)
echo "$VERSION"
{
  wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
  wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS
  wget https://bitcoincore.org/bin/bitcoin-core-$VERSION/SHA256SUMS.asc
  sha256sum --ignore-missing --check SHA256SUMS
  curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done
  gpg --verify SHA256SUMS.asc
  tar -xvf bitcoin-$VERSION-x86_64-linux-gnu.tar.gz
  sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin-$VERSION/bin/bitcoin-cli bitcoin-$VERSION/bin/bitcoind
  bitcoind --version
  sudo rm -r bitcoin-$VERSION bitcoin-$VERSION-x86_64-linux-gnu.tar.gz SHA256SUMS SHA256SUMS.asc
    sudo systemctl restart bitcoind
    cd
} &> /dev/null &
  echo "Atualizando Bitcon Core... Por favor, aguarde."
  wait
  echo "Bitcoin Core atualizado!"
}

thunderhub_update () {
  echo "🔍 Buscando a versão mais recente do Thunderhub..."
  LATEST_VERSION=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | grep tag_name | cut -d '"' -f 4)
  if [ -z "$LATEST_VERSION" ]; then
    echo "❌ Não foi possível obter a última versão. Abortando..."
    return 1
  fi
  echo "📦 Última versão encontrada: $LATEST_VERSION"
  read -p "Deseja continuar com a atualização para a versão $LATEST_VERSION? (y/n): " CONFIRMA
  if [[ "$CONFIRMA" != "n" ]]; then
    echo "❌ Atualização cancelada."
    return 1
  fi
  echo "⏳ Atualizando Thunderhub para a versão $LATEST_VERSION..."
  sudo systemctl stop thunderhub
  cd ~/thunderhub || { echo "❌ Diretório ~/thunderhub não encontrado!"; return 1; }
  git fetch --all
  git checkout tags/"$LATEST_VERSION" -b update-"$LATEST_VERSION"
  npm install
  npm run build
  sudo systemctl start thunderhub
  echo "✅ Thunderhub atualizado para a versão $LATEST_VERSION!"
  head -n 3 package.json | grep version
}

lndg_update () {
  echo "🔍 Iniciando atualização do LNDg..."
  cd /home/admin/lndg || { echo "❌ Diretório /home/admin/lndg não encontrado!"; return 1; }
  echo "🛑 Parando serviços do LNDg..."
  sudo systemctl stop lndg.service
  sudo systemctl stop lndg-controller.service
  echo "💾 Salvando alterações locais (git stash)..."
  git stash
  echo "🔄 Atualizando repositório via git pull..."
  git pull origin master
  echo "⚙️ Aplicando migrações..."
  .venv/bin/python manage.py migrate
  echo "🔄 Recarregando systemd e iniciando serviços..."
  sudo systemctl daemon-reload
  sudo systemctl start lndg.service
  sudo systemctl start lndg-controller.service
  echo "✅ LNDg atualizado com sucesso!"
  git log -1 --pretty=format:"📝 Último commit: %h - %s (%cd)" --date=short
}


lnbits_update () {
  echo "🔍 Iniciando atualização do LNbits..."
  cd /home/admin/lnbits || { echo "❌ Diretório /home/admin/lnbits não encontrado!"; return 1; }
  echo "🛑 Parando serviço do LNbits..."
  sudo systemctl stop lnbits
  echo "💾 Salvando alterações locais (git stash)..."
  git stash
  echo "🔄 Atualizando repositório LNbits..."
  git pull origin main
  echo "📦 Atualizando Poetry e dependências..."
  poetry self update
  poetry install --only main
  echo "🔄 Recarregando systemd e iniciando serviço..."
  sudo systemctl daemon-reload
  sudo systemctl start lnbits
  echo "✅ LNbits atualizado com sucesso!"
  git log -1 --pretty=format:"📝 Último commit: %h - %s (%cd)" --date=short
}


thunderhub_uninstall () {
  sudo systemctl stop thunderhub
  sudo systemctl disable thunderhub
  sudo rm -rf /home/admin/thunderhub
  sudo rm -rf /etc/systemd/system/thunderhub.service
  sudo rm -rf /etc/nginx/sites-available/thunderhub-reverse-proxy.conf
  echo "Thunderhub desinstalado!"
}

lndg_unninstall () {
  sudo systemctl stop lndg.service
  sudo systemctl disable lndg.service
  sudo systemctl stop lndg-controller.service
  sudo systemctl disable lndg-controller.service
  sudo rm -rf /home/admin/lndg
  sudo rm -rf /etc/systemd/system/lndg.service
  sudo rm -rf /etc/systemd/system/lndg-controller.service
  sudo rm -rf /etc/nginx/sites-available/lndg-reverse-proxy.conf
  echo "LNDg desinstalado!"
}

lnbits_unninstall () {
  sudo systemctl stop lnbits
  sudo systemctl disable lnbits
  sudo rm -rf /home/admin/lnbits
  sudo rm -rf /etc/systemd/system/lnbits.service
  sudo rm -rf /etc/nginx/sites-available/lnbits-reverse-proxy.conf
  echo "LNbits desinstalado!"
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
      menu_manutencao
      ;;
    2)
      bitcoin_update
      menu_manutencao
      ;;
    3)
      thunderhub_update
      menu_manutencao
      ;;
    4)
      lndg_update
      menu_manutencao
      ;;
    5)
      lnbits_update
      menu_manutencao
      ;;
    6)
      pacotes_do_sistema
      menu_manutencao
      ;;
    7)
      thunderhub_uninstall
      menu_manutencao
      ;;
    8)
      lndg_unninstall
      menu_manutencao
      ;;
    9)
      lnbits_unninstall
      menu_manutencao
      ;;
    0)
      clear
      menu3
      exit 0
      ;;
    *)
      echo "Opção inválida!"
      ;;
  esac
}

manutencao_script () {
  # Executa o script de manutenção
  lnd --version
  bitcoin-cli --version
  menu_manutencao
}	

manutencao_script
