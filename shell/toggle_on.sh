#!/bin/bash
source ~/brlnfullauto/shell/.env

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