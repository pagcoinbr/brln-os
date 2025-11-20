#!/bin/bash

REPO_DIR="/home/admin/brlnfullauto"
RADIO_DIR="$REPO_DIR/frontend/public/radio"
FLAG_FILE="/tmp/update_available.flag"
TRACK_HASH_FILE="$RADIO_DIR/.last_hash"

cd "$RADIO_DIR" || exit 1

# Gera um hash com base no conteúdo dos arquivos .mp3
HASH_ATUAL=$(find . -type f -name '*.mp3' -exec sha256sum {} + | sha256sum | cut -d ' ' -f1)

HASH_ANTERIOR=""
[ -f "$TRACK_HASH_FILE" ] && HASH_ANTERIOR=$(cat "$TRACK_HASH_FILE")

if [ "$HASH_ANTERIOR" != "$HASH_ATUAL" ]; then
  echo "🔁 Novos arquivos detectados. Atualizando rádio..."
  
  # Create flag file with timestamp
  date +%s > "$FLAG_FILE"
  echo "$HASH_ATUAL" > "$TRACK_HASH_FILE"
  
  echo "✅ Rádio atualizado."
else
  echo "✅ Sem atualizações nos arquivos de áudio."
fi

