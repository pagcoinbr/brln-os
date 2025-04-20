#!/bin/bash

# ⚡ Script para configurar o BOS Telegram no systemd
# 🔐 Substitui o placeholder pelo Connection Code fornecido
# 🛠️ Reinicia o serviço após modificação

SERVICE_FILE="/etc/systemd/system/bos-telegram.service"
PLACEHOLDER="<seu_connect_code_aqui>"
BOT_LINK="https://t.me/BotFather"

echo "🔗 Gerando QR Code para acessar o bot do Telegram..."
qrencode -t ansiutf8 "$BOT_LINK"

echo ""
echo "📱 Aponte sua câmera para o QR Code acima para abrir: $BOT_LINK"
echo ""

bos telegram

echo "✍️ Digite o Connection Code do seu bot Telegram:"
read -r connection_code

# 🧠 Validação simples
if [[ -z "$connection_code" ]]; then
  echo "❌ Connection Code não pode estar vazio."
  exit 1
fi

# 📝 Substituir placeholder
if grep -q "$PLACEHOLDER" "$SERVICE_FILE"; then
  sudo sed -i "s|$PLACEHOLDER|$connection_code|g" "$SERVICE_FILE"
  echo "✅ Connection Code inserido com sucesso no serviço."
else
  echo "⚠️ Placeholder não encontrado. Verifique se o arquivo está correto."
  exit 1
fi

# 🔄 Recarrega o systemd e reinicia o serviço
echo "🔄 Recarregando daemon do systemd..."
sudo systemctl daemon-reload

echo "🚀 Ativando e iniciando o serviço bos-telegram..."
sudo systemctl enable bos-telegram
sudo systemctl start bos-telegram

echo "✅ Serviço bos-telegram configurado e iniciado com sucesso!"
echo "💬 Verifique se recebeu a mensagem: 🤖 Connected to <nome do seu node>"
