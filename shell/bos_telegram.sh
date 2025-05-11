#!/bin/bash
source ~/brlnfullauto/shell/.env

config_bos_telegram () {
  # ⚡ Script para configurar o BOS Telegram no systemd
  # 🔐 Substitui o placeholder pelo Connection Code fornecido
  # 🛠️ Reinicia o serviço após modificação

  SERVICE_FILE="/etc/systemd/system/bos-telegram.service"
  BOT_LINK="https://t.me/BotFather"

  echo "🔗 Gerando QR Code para acessar o bot do Telegram..."
  qrencode -t ansiutf8 "$BOT_LINK"

  echo ""
  echo "📱 Aponte sua câmera para o QR Code acima para abrir: $BOT_LINK"
  echo ""

  echo "⚡️ Crie um bot no Telegram usando o BotFather e obtenha a API Key."
  echo "🌐 Agora acesse a interface web, vá em \"Configurações\" e clique em \" Autenticar Bos Telegram\"."

  # Aguarda o usuário confirmar que recebeu a conexão
  read -p "Pressione ENTER aqui após a conexão ser concluída no Telegram..."

  echo "✍️ Digite o Connection Code do seu bot Telegram:"
  read -r connection_code

  # 🧠 Validação simples
  if [[ -z "$connection_code" ]]; then
    echo "❌ Connection Code não pode estar vazio."
    exit 1
  fi

  # 📝 Adiciona ou substitui ExecStart com o Connection Code
  if grep -q '^ExecStart=' "$SERVICE_FILE"; then
    sudo sed -i "s|^ExecStart=.*|ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect $connection_code|g" "$SERVICE_FILE"
  else
    sudo sed -i "/^\[Service\]/a ExecStart=/home/admin/.npm-global/bin/bos telegram --use-small-units --connect $connection_code" "$SERVICE_FILE"
  fi

  echo "✅ Connection Code inserido com sucesso no serviço bos-telegram."

  # 🔄 Recarrega o systemd e reinicia o serviço
  echo "🔄 Recarregando daemon do systemd..."
  sudo systemctl daemon-reload

  echo "🚀 Ativando e iniciando o serviço bos-telegram..."
  sudo systemctl enable bos-telegram
  sudo systemctl start bos-telegram

  echo "✅ Serviço bos-telegram configurado e iniciado com sucesso!"
  echo "💬 Verifique se recebeu a mensagem: 🤖 Connected to <nome do seu node>"
}