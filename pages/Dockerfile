# Use nginx como base para servir arquivos estáticos
FROM nginx:alpine

# Instalar dependências necessárias
RUN apk add --no-cache curl bash

# Adicionar cloudflared
RUN curl -L --output /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x /usr/local/bin/cloudflared

# Copiar arquivos do site para o diretório do nginx
COPY . /usr/share/nginx/html/

# Copiar configuração customizada do nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copiar script de inicialização
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expor porta 80 (nginx)
EXPOSE 80

# Script de inicialização
ENTRYPOINT ["/entrypoint.sh"]
