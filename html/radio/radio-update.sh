#!/bin/bash

REPO_DIR="/home/admin/brlnfullauto"
RADIO_DIR="$REPO_DIR/html/radio"
FLAG_FILE="$RADIO_DIR/update_available.flag"

cd "$REPO_DIR" || exit 1

HASH_ANTERIOR=$(git rev-parse HEAD)
git pull origin v1.0-beta > /dev/null 2>&1
HASH_ATUAL=$(git rev-parse HEAD)

if [ "$HASH_ANTERIOR" != "$HASH_ATUAL" ]; then
  echo "🔁 Atualizações detectadas. Atualizando rádio..."
  cp -r "$REPO_DIR/html/radio/"* "$RADIO_DIR"

  # Escreve o timestamp atual no arquivo de sinalização
  date +%s > "$FLAG_FILE"
else
  echo "✅ Sem atualizações."
fi
