#!/bin/bash
# Script de instalação da API BRLN-OS Comando Central

set -e

echo "🚀 Instalando API BRLN-OS Comando Central..."

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretórios
API_DIR="/root/brln-os/api/v1/comandcentral"
VENV_DIR="/home/admin/envflask"
SERVICE_FILE="/root/brln-os/services/brln-api.service"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Por favor, execute como root (sudo)"
    exit 1
fi

# Criar e ativar ambiente virtual se não existir
echo -e "${YELLOW}📦 Configurando ambiente virtual...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✅ Ambiente virtual criado${NC}"
else
    echo -e "${GREEN}✅ Ambiente virtual já existe${NC}"
fi

# Instalar dependências
echo -e "${YELLOW}📦 Instalando dependências Python...${NC}"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip > /dev/null 2>&1
pip install -r "$API_DIR/requirements.txt" > /dev/null 2>&1
echo -e "${GREEN}✅ Dependências instaladas${NC}"

# Tornar o app.py executável
chmod +x "$API_DIR/app.py"

# Copiar e habilitar o serviço systemd
echo -e "${YELLOW}⚙️  Configurando serviço systemd...${NC}"
cp "$SERVICE_FILE" /etc/systemd/system/
systemctl daemon-reload
systemctl enable brln-api
echo -e "${GREEN}✅ Serviço configurado${NC}"

# Iniciar o serviço
echo -e "${YELLOW}🚀 Iniciando serviço...${NC}"
systemctl restart brln-api
sleep 2

# Verificar status
if systemctl is-active --quiet brln-api; then
    echo -e "${GREEN}✅ API iniciada com sucesso!${NC}"
    echo ""
    echo "📊 Status: systemctl status brln-api"
    echo "📋 Logs: journalctl -u brln-api -f"
    echo "🌐 Health Check: curl http://localhost:5001/api/v1/comandcentral/health"
    echo ""
    echo "⚠️  Não esqueça de reiniciar o Nginx para aplicar as mudanças:"
    echo "   sudo systemctl restart nginx"
else
    echo -e "${YELLOW}⚠️  Serviço iniciado mas pode haver problemas${NC}"
    echo "Verifique os logs: journalctl -u brln-api -n 50"
fi
