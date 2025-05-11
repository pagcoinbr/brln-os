#!/bin/bash
source ~/brlnfullauto/shell/.env

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