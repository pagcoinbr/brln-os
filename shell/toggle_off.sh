#!/bin/bash
source ~/brlnfullauto/shell/.env

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