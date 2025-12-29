#!/bin/bash

# Script de configuração Apache Proxy Reverso para BRLN-OS
# Resolve problema de SameSite cookies em iframes cross-origin

echo "🔧 Configurando Apache Proxy Reverso para BRLN-OS..."

# Verificar se o Apache está instalado
if ! command -v apache2 &> /dev/null; then
    echo "📦 Instalando Apache2..."
    sudo apt update
    sudo apt install apache2 -y
fi

# Habilitar módulos necessários
echo "🔌 Habilitando módulos Apache necessários..."
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_wstunnel
sudo a2enmod headers
sudo a2enmod rewrite
sudo a2enmod ssl

# Parar serviços que podem conflitar na porta 80
echo "⏹️  Parando serviços conflitantes..."
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl disable nginx 2>/dev/null || true

# Backup da configuração atual do Apache
if [ -f /etc/apache2/sites-available/000-default.conf ]; then
    echo "💾 Fazendo backup da configuração atual..."
    sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.backup.$(date +%Y%m%d_%H%M%S)
fi

# Copiar configurações do BRLN
echo "📁 Copiando configurações BRLN..."
sudo cp /root/brln-os/conf_files/brln-apache.conf /etc/apache2/sites-available/
sudo cp /root/brln-os/conf_files/brln-ssl-api.conf /etc/apache2/sites-available/

# Desabilitar site padrão e habilitar BRLN
echo "🔄 Configurando sites Apache..."
sudo a2dissite 000-default 2>/dev/null || true
sudo a2ensite brln-apache
sudo a2ensite brln-ssl-api

# Verificar configuração
echo "✅ Verificando configuração Apache..."
sudo apache2ctl configtest

if [ $? -eq 0 ]; then
    echo "✅ Configuração Apache válida!"
    
    # Reiniciar Apache
    echo "🔄 Reiniciando Apache..."
    sudo systemctl restart apache2
    sudo systemctl enable apache2
    
    # Configurar firewall
    echo "🔥 Configurando firewall..."
    sudo ufw allow from $(ip route get 1 | grep -oP 'src \K\S+' | cut -d. -f1-3).0/24 to any port 80 proto tcp comment 'allow Apache HTTP from local network'
    sudo ufw allow from $(ip route get 1 | grep -oP 'src \K\S+' | cut -d. -f1-3).0/24 to any port 443 proto tcp comment 'allow Apache HTTPS from local network'
    
    echo ""
    echo "🎉 Configuração Apache concluída com sucesso!"
    echo ""
    echo "📍 Agora você pode acessar:"
    echo "   • Interface principal: http://$(hostname -I | awk '{print $1}')/main.html"
    echo "   • Simple LNWallet: http://$(hostname -I | awk '{print $1}')/simple-lnwallet/"
    echo "   • LNDg: http://$(hostname -I | awk '{print $1}')/lndg/"
    echo "   • ThunderHub: http://$(hostname -I | awk '{print $1}')/thunderhub/"
    echo "   • LNBits: http://$(hostname -I | awk '{print $1}')/lnbits/"
    echo ""
    echo "🔧 Os cookies SameSite foram configurados para funcionar em iframes!"
    echo ""
    
else
    echo "❌ Erro na configuração Apache. Verifique os logs:"
    echo "   sudo tail -f /var/log/apache2/error.log"
    exit 1
fi