#!/bin/bash

REPO_DIR="/home/admin/brlnfullauto"
RADIO_DIR="/var/www/html/radio"
FLAG_FILE="$RADIO_DIR/update_available.flag"
TRACK_HASH_FILE="$RADIO_DIR/.last_hash"

cd "$REPO_DIR/html/radio" || exit 1
git stash
git pull
chmod +x /home/admin/brlnfullauto/html/radio/*.sh
# Gera um hash com base no conteúdo dos arquivos .mp3
HASH_ATUAL=$(find . -type f -name '*.mp3' -exec sha256sum {} + | sha256sum | cut -d ' ' -f1)

HASH_ANTERIOR=""
[ -f "$TRACK_HASH_FILE" ] && HASH_ANTERIOR=$(cat "$TRACK_HASH_FILE")

if [ "$HASH_ANTERIOR" != "$HASH_ATUAL" ]; then
  echo "🔁 Novos arquivos detectados. Atualizando rádio..."
  find "$RADIO_DIR" -type f -name "*.mp3" ! -name "intro.mp3" -exec rm -f {} +
  cp -r "$REPO_DIR/html/radio/"* "$RADIO_DIR"

  find "$REPO_DIR/html/radio" -name '*.mp3' -exec stat -c "%Y %n" {} + | sort -nr | head -n1 | cut -d ' ' -f1 > "$FLAG_FILE"
  echo "$HASH_ATUAL" > "$TRACK_HASH_FILE"
else
  echo "✅ Sem atualizações nos arquivos de áudio."
fi

