#!/bin/bash
# Atualiza os pacotes do sistema e recarrega o serviço Tor  
  sudo apt update && sudo apt upgrade -y
  sudo systemctl reload tor
  echo "Os pacotes do sistema foram atualizados!"