#!/bin/bash

# Simple Protocol Buffer Generator for BRLN-OS API
# This script regenerates gRPC protocol buffer files from .proto sources

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_DIR="/root/brln-os/api/v1"
PROTO_DIR="$API_DIR/proto"
LND_PROTO_URL="https://raw.githubusercontent.com/lightningnetwork/lnd/master/lnrpc"

echo -e "${BLUE}🔧 BRLN-OS Protocol Buffer Generator with Download${NC}"
echo -e "${BLUE}=================================================${NC}"

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    local error_details=()
    
    echo -e "${YELLOW}🔍 Verificando dependências...${NC}"
    
    # Check if API directory exists
    if [[ ! -d "$API_DIR" ]]; then
        missing_deps+=("API_DIRECTORY")
        error_details+=("❌ Diretório da API não encontrado: $API_DIR")
        error_details+=("   💡 Solução: Certifique-se de que o BRLN-OS está instalado em /root/brln-os")
        error_details+=("   💡 Ou execute: git clone https://github.com/pagcoinbr/brln-os.git /root/brln-os")
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        missing_deps+=("CURL")
        error_details+=("❌ curl não está instalado")
        error_details+=("   💡 Solução: sudo apt update && sudo apt install -y curl")
    fi
    
    # Check if python3 is installed
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("PYTHON3")
        error_details+=("❌ Python 3 não está instalado")
        error_details+=("   💡 Solução: sudo apt update && sudo apt install -y python3 python3-pip")
    fi
    
    # Check if pip3 is installed
    if ! command -v pip3 &> /dev/null; then
        missing_deps+=("PIP3")
        error_details+=("❌ pip3 não está instalado")
        error_details+=("   💡 Solução: sudo apt update && sudo apt install -y python3-pip")
    fi
    
    # Display errors if any dependencies are missing
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ ERRO: Dependências ausentes detectadas${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        for detail in "${error_details[@]}"; do
            echo -e "${RED}$detail${NC}"
        done
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        echo -e "${YELLOW}📋 Dependências ausentes: ${missing_deps[*]}${NC}\n"
        return 1
    fi
    
    echo -e "${GREEN}✅ Todas as dependências básicas verificadas${NC}"
    return 0
}

# Check if running from correct directory
if ! check_dependencies; then
    exit 1
fi

# Create proto directory if it doesn't exist
if [[ ! -d "$PROTO_DIR" ]]; then
    echo -e "${YELLOW}📁 Creating proto directory: $PROTO_DIR${NC}"
    mkdir -p "$PROTO_DIR"
fi

# Download required proto files
echo -e "${YELLOW}📥 Downloading LND proto files...${NC}"

# Main lightning.proto file
if [[ ! -f "$PROTO_DIR/lightning.proto" ]] || [[ "$1" == "--force-download" ]]; then
    echo -e "${YELLOW}   📄 Downloading lightning.proto...${NC}"
    CURL_OUTPUT=$(curl -s -L -w "\n%{http_code}" "$LND_PROTO_URL/lightning.proto" -o "$PROTO_DIR/lightning.proto" 2>&1)
    HTTP_CODE=$(echo "$CURL_OUTPUT" | tail -n1)
    if [[ $? -eq 0 ]] && [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}   ✅ lightning.proto downloaded${NC}"
    else
        echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ ERRO: Falha ao baixar lightning.proto${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   URL: $LND_PROTO_URL/lightning.proto${NC}"
        echo -e "${YELLOW}   HTTP Code: $HTTP_CODE${NC}"
        echo -e "${YELLOW}   💡 Possíveis causas:${NC}"
        echo -e "${YELLOW}      - Sem conexão com a internet${NC}"
        echo -e "${YELLOW}      - URL do repositório mudou${NC}"
        echo -e "${YELLOW}      - Problemas de DNS${NC}"
        echo -e "${YELLOW}   💡 Solução: Verifique sua conexão e tente novamente${NC}"
        echo -e "${YELLOW}      curl -v $LND_PROTO_URL/lightning.proto${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        exit 1
    fi
else
    echo -e "${GREEN}   ✅ lightning.proto already exists${NC}"
fi

# Download additional proto files for sub-services
ADDITIONAL_PROTO_DOWNLOADS=(
    "signrpc/signer.proto"
    "chainrpc/chainnotifier.proto"
    "invoicesrpc/invoices.proto"
    "walletrpc/walletkit.proto"
    "routerrpc/router.proto"
    "peersrpc/peers.proto"
)

for proto_file in "${ADDITIONAL_PROTO_DOWNLOADS[@]}"; do
    proto_dir_path="$PROTO_DIR/$(dirname "$proto_file")"
    proto_file_path="$PROTO_DIR/$proto_file"
    
    # Create subdirectory if needed
    if [[ ! -d "$proto_dir_path" ]]; then
        mkdir -p "$proto_dir_path"
    fi
    
    if [[ ! -f "$proto_file_path" ]] || [[ "$1" == "--force-download" ]]; then
        echo -e "${YELLOW}   📄 Downloading $proto_file...${NC}"
        curl -s -L "$LND_PROTO_URL/$proto_file" -o "$proto_file_path"
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}   ✅ $proto_file downloaded${NC}"
        else
            echo -e "${YELLOW}   ⚠️ Warning: Failed to download $proto_file${NC}"
        fi
    else
        echo -e "${GREEN}   ✅ $proto_file already exists${NC}"
    fi
done

# Change to API directory
cd "$API_DIR"

# Activate virtual environment if it exists
VENV_PATHS=("/root/envflask" "/home/admin/envflask")
VENV_ACTIVATED=false

for venv_path in "${VENV_PATHS[@]}"; do
    if [[ -f "$venv_path/bin/activate" ]]; then
        echo -e "${YELLOW}⚡ Ativando ambiente virtual: $venv_path${NC}"
        source "$venv_path/bin/activate"
        VENV_ACTIVATED=true
        break
    fi
done

if [[ "$VENV_ACTIVATED" == false ]]; then
    echo -e "${YELLOW}⚠️ Ambiente virtual não encontrado, usando Python do sistema${NC}"
fi

# Check if grpcio-tools is available
echo -e "${YELLOW}🔍 Verificando grpcio-tools...${NC}"
if ! python3 -c "import grpc_tools.protoc" 2>/dev/null; then
    echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERRO: grpcio-tools não encontrado${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   O pacote grpcio-tools é necessário para compilar arquivos .proto${NC}"
    echo -e "${YELLOW}   💡 Solução 1: Instalar com pip3${NC}"
    echo -e "${YELLOW}      pip3 install grpcio-tools${NC}"
    echo -e "${YELLOW}   💡 Solução 2: Se usar ambiente virtual${NC}"
    if [[ "$VENV_ACTIVATED" == true ]]; then
        echo -e "${YELLOW}      pip install grpcio-tools${NC}"
    else
        echo -e "${YELLOW}      source /root/envflask/bin/activate && pip install grpcio-tools${NC}"
    fi
    echo -e "${YELLOW}   💡 Solução 3: Instalar todas as dependências da API${NC}"
    echo -e "${YELLOW}      pip3 install -r $API_DIR/requirements.txt${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    exit 1
fi
echo -e "${GREEN}✅ grpcio-tools disponível${NC}"

echo -e "${YELLOW}🧹 Cleaning old generated files...${NC}"
# Remove old generated files
rm -f *_pb2.py *_pb2_grpc.py || true

echo -e "${YELLOW}🔨 Generating main lightning.proto files...${NC}"

# Generate main lightning protobuf files
echo -e "${YELLOW}   📄 Compiling lightning.proto...${NC}"
COMPILE_ERROR=$(python3 -m grpc_tools.protoc \
    --proto_path="$PROTO_DIR" \
    --python_out=. \
    --grpc_python_out=. \
    "$PROTO_DIR/lightning.proto" 2>&1)
COMPILE_STATUS=$?

if [[ $COMPILE_STATUS -eq 0 ]]; then
    echo -e "${GREEN}   ✅ lightning.proto compiled successfully${NC}"
else
    echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERRO: Falha ao compilar lightning.proto${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   Arquivo: $PROTO_DIR/lightning.proto${NC}"
    echo -e "${YELLOW}   Diretório de trabalho: $PWD${NC}"
    echo -e "${RED}   Detalhes do erro:${NC}"
    echo -e "${RED}$COMPILE_ERROR${NC}"
    echo -e "${YELLOW}   💡 Possíveis causas:${NC}"
    echo -e "${YELLOW}      - Arquivo .proto corrompido ou inválido${NC}"
    echo -e "${YELLOW}      - Sintaxe incorreta no arquivo .proto${NC}"
    echo -e "${YELLOW}      - Dependências ausentes no arquivo .proto${NC}"
    echo -e "${YELLOW}   💡 Solução: Tente baixar novamente os arquivos proto${NC}"
    echo -e "${YELLOW}      $0 --force-download${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    exit 1
fi

# Generate additional proto files if they exist
echo -e "${YELLOW}🔨 Generating additional proto files...${NC}"

ADDITIONAL_PROTOS=(
    "signrpc/signer.proto"
    "chainrpc/chainnotifier.proto"
    "invoicesrpc/invoices.proto"
    "walletrpc/walletkit.proto"
    "routerrpc/router.proto"
    "peersrpc/peers.proto"
)

for proto_file in "${ADDITIONAL_PROTOS[@]}"; do
    if [[ -f "$PROTO_DIR/$proto_file" ]]; then
        echo -e "${YELLOW}   📄 Compiling $proto_file...${NC}"
        python3 -m grpc_tools.protoc \
            --proto_path="$PROTO_DIR" \
            --python_out=. \
            --grpc_python_out=. \
            "$PROTO_DIR/$proto_file"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}   ✅ $proto_file compiled successfully${NC}"
        else
            echo -e "${YELLOW}   ⚠️ Warning: Failed to compile $proto_file${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️ Proto file not found: $proto_file${NC}"
    fi
done

echo -e "${YELLOW}🔧 Fixing import statements...${NC}"
# Fix import statements in generated gRPC files
for grpc_file in *_pb2_grpc.py; do
    if [[ -f "$grpc_file" ]]; then
        # Convert relative imports to absolute imports
        sed -i 's/from \. import \([a-z_]*\)_pb2/import \1_pb2/g' "$grpc_file" || true
        echo -e "${GREEN}   ✅ Fixed imports in $grpc_file${NC}"
    fi
done

# Verify main files were generated
echo -e "${YELLOW}🧪 Verifying generated files...${NC}"
MAIN_FILES=("lightning_pb2.py" "lightning_pb2_grpc.py")
ALL_GENERATED=true

for file in "${MAIN_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}   ✅ $file generated${NC}"
    else
        echo -e "${RED}   ❌ $file missing${NC}"
        ALL_GENERATED=false
    fi
done

# Count all generated files
TOTAL_GENERATED=$(ls -1 *_pb2.py *_pb2_grpc.py | wc -l)

echo -e "${BLUE}📊 Generation Summary:${NC}"
echo -e "${GREEN}   📦 Total generated files: $TOTAL_GENERATED${NC}"

if [[ "$ALL_GENERATED" == true ]]; then
    echo -e "${GREEN}✅ Main protocol buffer files generated successfully!${NC}"
    
    # Test import functionality
    echo -e "${YELLOW}🧪 Testing import functionality...${NC}"
    if python3 -c "
import sys
sys.path.insert(0, '.')
try:
    import lightning_pb2
    import lightning_pb2_grpc
    print('✅ Main imports working correctly')
except ImportError as e:
    print(f'❌ Import error: {e}')
    exit(1)
"; then
        echo -e "${GREEN}✅ Import test passed!${NC}"
    else
        echo -e "${RED}❌ Import test failed${NC}"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 *_pb2.py *_pb2_grpc.py || true
    
    echo ""
    echo -e "${GREEN}🎉 Protocol buffer generation completed successfully!${NC}"
    echo -e "${BLUE}📁 Generated files are located in: $API_DIR${NC}"
    echo -e "${YELLOW}💡 You may need to restart services that use these files:${NC}"
    echo -e "${YELLOW}    sudo systemctl restart messager-monitor${NC}"
    echo -e "${YELLOW}    sudo systemctl restart brln-api${NC}"
    
else
    echo -e "${RED}❌ Protocol buffer generation failed!${NC}"
    exit 1
fi