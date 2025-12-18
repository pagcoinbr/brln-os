#!/bin/bash

# Inicia o nginx em background
nginx -g "daemon off;" &

# Aguarda o nginx iniciar
sleep 2

# Inicia o cloudflared tunnel
echo "Iniciando túnel Cloudflare..."

if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    echo "✅ Usando túnel com TOKEN fixo (URL permanente)"
    cloudflared tunnel run --token "$CLOUDFLARE_TUNNEL_TOKEN"
else
    echo "⚠️  Usando túnel temporário (URL aleatória)"
    cloudflared tunnel --url http://localhost:80 --no-autoupdate
fi

# Mantém o container rodando
wait
