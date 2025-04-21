#!/bin/bash
echo "⚡ Iniciando BOS Telegram via Gotty..."
echo "Use o navegador para inserir a API Key e o código de conexão."

while true; do
  /home/admin/.npm-global/bin/bos telegram
  echo "❌ O processo foi encerrado. Reiniciando em 5 segundos..."
  sleep 5
done
