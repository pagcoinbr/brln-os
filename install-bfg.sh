#!/bin/bash
# Script para instalar BFG Repo-Cleaner (ferramenta mais segura para limpeza)

echo "📦 Instalando BFG Repo-Cleaner..."

# Verificar se Java está instalado
if ! command -v java &> /dev/null; then
    echo "☕ Instalando Java (necessário para BFG)..."
    sudo apt update
    sudo apt install -y openjdk-11-jre-headless
fi

# Baixar BFG
echo "⬇️  Baixando BFG..."
wget -O /tmp/bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar

# Instalar BFG globalmente
echo "📍 Instalando BFG em /usr/local/bin..."
sudo cp /tmp/bfg.jar /usr/local/bin/
sudo chmod +x /usr/local/bin/bfg.jar

# Criar script wrapper
sudo tee /usr/local/bin/bfg > /dev/null << 'EOF'
#!/bin/bash
java -jar /usr/local/bin/bfg.jar "$@"
EOF

sudo chmod +x /usr/local/bin/bfg

echo "✅ BFG instalado com sucesso!"
echo "Agora você pode executar: ./cleanup-credentials.sh"
