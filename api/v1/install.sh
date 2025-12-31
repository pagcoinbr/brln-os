#!/bin/bash
# ⚠️  ATENÇÃO: Este script foi integrado ao brunel.sh principal
# 🔄 Use: bash brunel.sh e escolha a opção "9 - Instalar API BRLN gRPC"
# 📁 Localização: /root/brln-os/brunel.sh (função install_brln_api)

echo ""
echo -e "\033[1;33m⚠️  ATENÇÃO: Este script foi migrado para o brunel.sh principal\033[0m"
echo ""
echo -e "\033[1;32m🔄 Para instalar a API BRLN gRPC:\033[0m"
echo -e "\033[1;36m   1. Execute: cd /root/brln-os && bash brunel.sh\033[0m"
echo -e "\033[1;36m   2. Escolha a opção '9 - Instalar API BRLN gRPC'\033[0m"
echo ""
echo -e "\033[1;35m📋 A instalação agora é integrada e sincronizada com todo o sistema!\033[0m"
echo -e "\033[1;32m✅ Funcionalidades adicionais: firewall automático, logs melhorados, integração com ambiente virtual\033[0m"
echo ""
exit 0

# Diretórios
API_DIR="/root/brln-os/api/v1"
API_TARGET="/home/admin/brln-api"
VENV_DIR="/home/admin/envflask"
SERVICE_FILE="/root/brln-os/services/brln-api.service"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Por favor, execute como root (sudo)${NC}"
    exit 1
fi

# Verificar e instalar dependências do sistema
echo -e "${YELLOW}🔧 Verificando dependências do sistema...${NC}"

# Atualizar repositórios
apt update > /dev/null 2>&1

# Instalar protoc se necessário
if ! command -v protoc &> /dev/null; then
    echo -e "${YELLOW}📦 Instalando protobuf-compiler...${NC}"
    apt install -y protobuf-compiler python3-full > /dev/null 2>&1
    echo -e "${GREEN}✅ protobuf-compiler instalado${NC}"
else
    echo -e "${GREEN}✅ protobuf-compiler já está instalado${NC}"
fi

# Criar e ativar ambiente virtual se não existir
echo -e "${YELLOW}📦 Configurando ambiente virtual...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✅ Ambiente virtual criado${NC}"
else
    echo -e "${GREEN}✅ Ambiente virtual já existe${NC}"
fi

# Ativar ambiente virtual
source "$VENV_DIR/bin/activate"

# Instalar dependências Python
echo -e "${YELLOW}📦 Instalando dependências Python no venv...${NC}"
pip install --upgrade pip > /dev/null 2>&1
pip install -r "$API_DIR/requirements.txt" > /dev/null 2>&1
echo -e "${GREEN}✅ Dependências Python instaladas${NC}"

# Compilar proto files do LND
echo -e "${YELLOW}⚡ Compilando proto files do LND...${NC}"
cd "$API_DIR"

# Criar diretórios para proto files se não existirem  
mkdir -p proto
mkdir -p proto/signrpc
mkdir -p proto/invoicesrpc
mkdir -p proto/walletrpc
mkdir -p proto/routerrpc
mkdir -p proto/chainrpc
mkdir -p proto/peersrpc

# Lista dos proto files principais do LND com seus diretórios
declare -A PROTO_FILES=(
    ["lightning.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/lightning.proto"
    ["signrpc/signer.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/signrpc/signer.proto"
    ["invoicesrpc/invoices.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/invoicesrpc/invoices.proto"
    ["walletrpc/walletkit.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/walletrpc/walletkit.proto"
    ["routerrpc/router.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/routerrpc/router.proto"
    ["chainrpc/chainnotifier.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/chainrpc/chainnotifier.proto"
    ["peersrpc/peers.proto"]="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc/peersrpc/peers.proto"
)

# Baixar proto files se não existirem
for proto_file in "${!PROTO_FILES[@]}"; do
    if [ ! -f "proto/$proto_file" ]; then
        echo -e "${YELLOW}📥 Baixando $proto_file...${NC}"
        curl -s -o "proto/$proto_file" "${PROTO_FILES[$proto_file]}"
        echo -e "${GREEN}✅ $proto_file baixado${NC}"
    else
        echo -e "${GREEN}✅ $proto_file já existe${NC}"
    fi
done

# Compilar proto files usando o venv (ordem importa devido às dependências)
echo -e "${YELLOW}🔨 Compilando protobuf files...${NC}"
COMPILE_ORDER=(
    "lightning.proto"
    "signrpc/signer.proto" 
    "chainrpc/chainnotifier.proto"
    "invoicesrpc/invoices.proto"
    "walletrpc/walletkit.proto"
    "routerrpc/router.proto"
    "peersrpc/peers.proto"
)

for proto_file in "${COMPILE_ORDER[@]}"; do
    echo -e "${YELLOW}   Compilando $proto_file...${NC}"
    python3 -m grpc_tools.protoc \
        --proto_path=proto \
        --python_out=. \
        --grpc_python_out=. \
        "proto/$proto_file" 2>/dev/null || echo -e "${YELLOW}   ⚠️  Warning compilando $proto_file${NC}"
done

# Verificar se os arquivos principais foram gerados
MAIN_FILES=("lightning_pb2.py" "lightning_pb2_grpc.py")
MISSING_FILES=()

for file in "${MAIN_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Proto files principais compilados com sucesso!${NC}"
    
    # Contar arquivos gerados
    GENERATED_COUNT=$(ls -1 *_pb2.py *_pb2_grpc.py 2>/dev/null | wc -l)
    echo -e "${GREEN}📦 $GENERATED_COUNT arquivos proto gerados${NC}"
    
    # Ajustar imports para funcionarem corretamente
    echo -e "${YELLOW}🔧 Ajustando imports...${NC}"
    for grpc_file in *_pb2_grpc.py; do
        if [ -f "$grpc_file" ]; then
            # Converter imports relativos para absolutos para evitar erros de importação
            sed -i 's/from \. import \([a-z_]*\)_pb2/import \1_pb2/g' "$grpc_file" 2>/dev/null || true
        fi
    done
    
    # Verificar se os imports estão funcionando
    echo -e "${YELLOW}🧪 Testando importação...${NC}"
    if /home/admin/envflask/bin/python3 -c "
import sys
sys.path.insert(0, '.')
try:
    import lightning_pb2 as lnrpc
    import lightning_pb2_grpc as lnrpcstub
    print('✅ gRPC proto files podem ser importados!')
except ImportError as e:
    print(f'❌ Erro de importação: {e}')
    exit(1)
" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Imports testados e funcionando${NC}"
    else
        echo -e "${RED}❌ Erro nos imports. Tentando correção adicional...${NC}"
        # Correção adicional se necessário
        for grpc_file in *_pb2_grpc.py; do
            if [ -f "$grpc_file" ]; then
                sed -i 's/from \. import/import/g' "$grpc_file" 2>/dev/null || true
            fi
        done
    fi
    
else
    echo -e "${RED}❌ Erro na compilação dos proto files!${NC}"
    echo -e "${RED}   Arquivos faltando: ${MISSING_FILES[*]}${NC}"
    exit 1
fi

# Tornar o app.py executável
chmod +x "$API_DIR/app.py"

# Copiar API para diretório acessível
echo -e "${YELLOW}📁 Copiando API para diretório acessível...${NC}"
cp -r "$API_DIR" "$API_TARGET"
chown -R admin:admin "$API_TARGET"
echo -e "${GREEN}✅ API copiada para $API_TARGET${NC}"

# Copiar e habilitar o serviço systemd
echo -e "${YELLOW}⚙️  Configurando serviço systemd...${NC}"
cp "$SERVICE_FILE" /etc/systemd/system/
systemctl daemon-reload
systemctl enable brln-api
echo -e "${GREEN}✅ Serviço configurado${NC}"

# Iniciar o serviço
echo -e "${YELLOW}🚀 Iniciando serviço...${NC}"
systemctl restart brln-api
sleep 3

# Verificar status
if systemctl is-active --quiet brln-api; then
    echo -e "${GREEN}✅ API gRPC iniciada com sucesso!${NC}"
    echo ""
    echo "📊 Status: systemctl status brln-api"
    echo "📋 Logs: journalctl -u brln-api -f"
    echo "🌐 Health Check: curl http://localhost:2121/api/v1/system/health"
    echo "🌐 API Direta: http://localhost:2121"
    echo ""
    echo "🎯 API usa APENAS gRPC (sem proxy reverso)"
    echo "⚡ Performance melhorada com protocolo binário"
    echo "📦 Proto files compilados: lightning, invoices, walletkit, router, signer, chainnotifier, peers"
    echo ""
    echo "📝 Endpoints disponíveis:"
    echo "   • Health: http://localhost:2121/api/v1/system/health"
    echo "   • Status LND: http://localhost:2121/api/v1/config/lnd_status"
    echo "   • Wallet Balance: http://localhost:2121/api/v1/config/wallet_balance"
else
    echo -e "${RED}⚠️  Serviço com problemas!${NC}"
    echo "Verifique os logs: journalctl -u brln-api -n 50"
    echo ""
    echo -e "${YELLOW}💡 Dicas de troubleshooting:${NC}"
    echo "1. Verifique se o LND está rodando: systemctl status lnd"
    echo "2. Verifique os certificados: ls -la /data/lnd/tls.cert"
    echo "3. Verifique o macaroon: ls -la /data/lnd/data/chain/bitcoin/\${BITCOIN_NETWORK:-mainnet}/admin.macaroon"
    echo "4. Teste conectividade: netstat -tlnp | grep :2121"
fi

echo ""
echo -e "${GREEN}🎉 Instalação gRPC completa!${NC}"
