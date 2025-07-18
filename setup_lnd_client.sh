#!/bin/bash
# Setup script para cliente Python gRPC do LND
# Baseado no tutorial oficial do LND

# Source das funções básicas
source "$(dirname "$0")/scripts/.env"
basics

set -e

log "🔧 Configurando ambiente Python para cliente LND gRPC..."

# Criar diretório para o ambiente virtual se não existir
VENV_DIR="./lnd_client_env"

# Verificar se o Python 3 está instalado
if ! command -v python3 &> /dev/null; then
    error "❌ Python 3 não está instalado. Instale o Python 3 primeiro."
    exit 1
fi

# Verificar se o pip está instalado
if ! command -v pip3 &> /dev/null; then
    error "❌ pip3 não está instalado. Instale o pip primeiro."
    exit 1
fi

# 1. Criar ambiente virtual
log "📦 Criando ambiente virtual..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
    log "✅ Ambiente virtual criado em $VENV_DIR"
else
    info "ℹ️  Ambiente virtual já existe em $VENV_DIR"
fi

# 2. Ativar ambiente virtual
log "🔌 Ativando ambiente virtual..."
source $VENV_DIR/bin/activate

# 3. Atualizar pip
log "⬆️  Atualizando pip..."
pip install --upgrade pip

# 4. Instalar dependências
log "📥 Instalando dependências Python..."
pip install grpcio-tools requests

# 5. Baixar arquivo proto do LND
log "📡 Baixando lightning.proto do repositório oficial do LND..."
if [ ! -f "lightning.proto" ]; then
    curl -o lightning.proto -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/lightning.proto
    log "✅ lightning.proto baixado"
else
    info "ℹ️  lightning.proto já existe"
fi

# 6. Compilar arquivo proto
log "🔨 Compilando arquivo proto..."
python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. lightning.proto

# Verificar se os arquivos foram gerados
if [ -f "lightning_pb2.py" ] && [ -f "lightning_pb2_grpc.py" ]; then
    log "✅ Arquivos proto compilados com sucesso:"
    info "   - lightning_pb2.py"
    info "   - lightning_pb2_grpc.py"
    info "   - lightning_pb2.pyi"
else
    error "❌ Erro ao compilar arquivos proto"
    exit 1
fi

# 7. Baixar e compilar subservers opcionais (router, invoices, etc.)
echo "📡 Baixando protos de subserviços..."

# Router subserver (para pagamentos avançados)
if [ ! -f "router.proto" ]; then
    curl -o router.proto -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/routerrpc/router.proto
    python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. router.proto
    echo "✅ Router proto compilado"
fi

# Invoices subserver 
if [ ! -f "invoices.proto" ]; then
    curl -o invoices.proto -s https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/invoicesrpc/invoices.proto
    python -m grpc_tools.protoc --proto_path=. --python_out=. --grpc_python_out=. invoices.proto
    echo "✅ Invoices proto compilado"
fi

# Criar arquivo requirements.txt
echo "📝 Criando requirements.txt..."
cat > requirements.txt << EOF
grpcio-tools>=1.50.0
grpcio>=1.50.0
requests>=2.28.0
protobuf>=4.21.0
EOF

# Criar script de ativação do ambiente
echo "📝 Criando script de ativação..."
cat > activate_env.sh << 'EOF'
#!/bin/bash
# Script para ativar o ambiente virtual do cliente LND
source ./lnd_client_env/bin/activate
echo "🔌 Ambiente virtual ativado!"
echo "Para executar o cliente: python lnd_balance_client.py"
echo "Para desativar: deactivate"
EOF
chmod +x activate_env.sh

# 8. Instruções finais
echo ""
echo "🎉 Setup concluído com sucesso!"
echo ""
echo "📋 Para usar o cliente:"
echo "   1. Ative o ambiente virtual: source ./activate_env.sh"
echo "   2. Execute o cliente: python lnd_balance_client.py"
echo ""
echo "📁 Arquivos gerados:"
echo "   - lightning_pb2.py (módulo proto compilado)"
echo "   - lightning_pb2_grpc.py (stub gRPC)"
echo "   - router_pb2.py (router subserver)"
echo "   - invoices_pb2.py (invoices subserver)"
echo "   - requirements.txt (dependências)"
echo "   - activate_env.sh (script de ativação)"
echo ""
echo "⚠️  Certifique-se de que:"
echo "   - Os contêineres LND e Elements estão rodando"
echo "   - Os certificados TLS estão em /data/lnd/tls.cert"
echo "   - O macaroon está em /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon"
echo ""
