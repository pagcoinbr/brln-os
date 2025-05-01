#!/bin/bash

REPO_DIR="/home/admin/brlnfullauto"
RADIO_DIR="/var/www/html/radio"
FLAG_FILE="$RADIO_DIR/update_available.flag"

cd "$REPO_DIR" || exit 1

HASH_ANTERIOR=$(git rev-parse HEAD)
git pull origin v1.0-beta
HASH_ATUAL=$(git rev-parse HEAD)

if [ "$HASH_ANTERIOR" != "$HASH_ATUAL" ]; then
  echo "🔁 Atualizações detectadas. Atualizando rádio..."
  find "$RADIO_DIR" -type f -name "*.mp3" ! -name "intro.mp3" -exec rm -f {} +
  cp -r "$REPO_DIR/html/radio/"* "$RADIO_DIR"

  # Escreve o timestamp atual no arquivo de sinalização
  date +%s > "$FLAG_FILE"
else
  echo "✅ Sem atualizações."
fi
