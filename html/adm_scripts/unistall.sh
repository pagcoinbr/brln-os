#!/bin/bash
## Este script serve apra manutenção do BRLNFullauto

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
  echo "Os pacotes do sistema foram atualizados!"
}

menu() {
  echo "Escolha uma opção:"
  echo "1) Atualizar os pacotes do sistema"
  echo "2) Desinstalar Thunderhub"
  echo "3) Desinstalar LNDg"
  echo "4) Desinstalar LNbits"
  echo "0) Sair"
  read -p "Opção: " option

  case $option in
    1)
      pacotes_do_sistema
      ;;
    2)
      thunderhub_uninstall
      ;;
    3)
      lndg_unninstall
      ;;
    4)
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

menu
