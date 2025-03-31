#!/bin/bash

# Obter a última versão lançada do Thunderhub
THUB_VERSION=$(curl -s https://api.github.com/repos/apotdevin/thunderhub/releases/latest | grep '"tag_name":' | cut -d '"' -f4 | sed 's/^v//')

echo "Última versão do Thunderhub detectada: $THUB_VERSION"

# Parar o serviço
sudo systemctl stop thunderhub

# Acessar o diretório do Thunderhub
cd ~/thunderhub

# Atualizar o repositório para a versão específica
git fetch --tags
git checkout v$THUB_VERSION
git pull origin v$THUB_VERSION

# Instalar dependências e buildar o projeto
npm install
npm run build

# Iniciar novamente o serviço
sudo systemctl restart thunderhub

# Exibir versão instalada
echo "✅ Thunderhub atualizado para a versão $THUB_VERSION!"
head -n 3 ~/thunderhub/package.json | grep version
