#!/bin/bash

# Detecta o IP local (excluindo 127.0.0.1 e interfaces docker)
ip_local=$(hostname -I | awk '{print $1}')

# Alternativa mais robusta se quiser filtrar apenas IPv4 e ignorar loopback:
# ip_local=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^127|^172\.17' | head -n1)

# Salva em um arquivo na raiz do projeto (ou onde seu HTML possa acessar)
echo "$ip_local" > /var/www/html/ip.txt

# Exibe mensagem para depuração
echo "IP local detectado: $ip_local (salvo em /var/www/html/ip.txt)"
