#!/bin/bash

# Generate Protocol Buffer Files Script for BRLN-OS API
# This script regenerates all gRPC protocol buffer files from .proto sources

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

set -o pipefail  # Exit on pipe failures but allow individual commands to fail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configure dynamic paths
configure_brln_paths
# Now we have: API_DIR, PROTO_DIR, etc. set dynamically
VENV_DIR="/home/admin/envflask"

echo -e "${BLUE}🔧 BRLN-OS Protocol Buffer Generator${NC}"
echo -e "${BLUE}====================================${NC}"

# Check if running from correct directory
if [[ ! -d "$API_DIR" ]]; then
    echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERRO: Diretório da API não encontrado${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   Procurando: $API_DIR${NC}"
    echo -e "${YELLOW}   Diretório atual: $PWD${NC}"
    echo -e "${YELLOW}   💡 Possíveis causas:${NC}"
    echo -e "${YELLOW}      - BRLN-OS não está instalado${NC}"
    echo -e "${YELLOW}      - BRLN-OS instalado em local diferente${NC}"
    echo -e "${YELLOW}   💡 Solução 1: Instalar BRLN-OS${NC}"
    echo -e "${YELLOW}      git clone https://github.com/pagcoinbr/brln-os.git /root/brln-os${NC}"
    echo -e "${YELLOW}   💡 Solução 2: Ajustar variável API_DIR no script${NC}"
    echo -e "${YELLOW}      Se BRLN-OS está em outro local, edite o script e ajuste API_DIR${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    exit 1
fi

if [[ ! -d "$PROTO_DIR" ]]; then
    echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERRO: Diretório proto não encontrado${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}   Procurando: $PROTO_DIR${NC}"
    echo -e "${YELLOW}   💡 Solução: Os arquivos .proto precisam ser baixados primeiro${NC}"
    echo -e "${YELLOW}      Execute: /root/brln-os/scripts/gen-proto.sh${NC}"
    echo -e "${YELLOW}   Este script irá:${NC}"
    echo -e "${YELLOW}      1. Criar o diretório proto${NC}"
    echo -e "${YELLOW}      2. Baixar todos os arquivos .proto necessários${NC}"
    echo -e "${YELLOW}      3. Compilar os arquivos automaticamente${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    exit 1
fi

# Change to API directory
cd "$API_DIR"

# Check if virtual environment exists
if [[ -d "$VENV_DIR" ]]; then
    echo -e "${YELLOW}🐍 Using virtual environment: $VENV_DIR${NC}"
    source "$VENV_DIR/bin/activate"
else
    echo -e "${YELLOW}⚠️ Virtual environment not found, using system Python${NC}"
fi

# Check if grpcio-tools is installed
echo -e "${YELLOW}🔍 Verificando grpcio-tools...${NC}"
if ! python3 -c "import grpc_tools.protoc" 2>/dev/null; then
    echo -e "${YELLOW}📦 grpcio-tools não encontrado, tentando instalar...${NC}"
    if pip3 install grpcio-tools 2>&1; then
        echo -e "${GREEN}✅ grpcio-tools instalado com sucesso${NC}"
    else
        echo -e "${RED}\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}❌ ERRO: Falha ao instalar grpcio-tools${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}   💡 Possíveis causas:${NC}"
        echo -e "${YELLOW}      - Sem permissões de root${NC}"
        echo -e "${YELLOW}      - Sem conexão com a internet${NC}"
        echo -e "${YELLOW}      - Problemas com pip${NC}"
        echo -e "${YELLOW}   💡 Soluções:${NC}"
        echo -e "${YELLOW}      sudo pip3 install grpcio-tools${NC}"
        echo -e "${YELLOW}      ou${NC}"
        echo -e "${YELLOW}      python3 -m pip install --user grpcio-tools${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        exit 1
    fi
else
    echo -e "${GREEN}✅ grpcio-tools disponível${NC}"
fi

# Check if protoc is available
if ! command -v protoc &> /dev/null; then
    echo -e "${YELLOW}📦 Installing protobuf-compiler...${NC}"
    sudo apt update
    sudo apt install -y protobuf-compiler
fi

echo -e "${YELLOW}🧹 Cleaning old generated files...${NC}"
# Remove old generated files
rm -f *_pb2.py *_pb2_grpc.py || true

echo -e "${YELLOW}🔨 Generating protocol buffer files...${NC}"

# Define compilation order (main files first, then sub-modules)
COMPILE_ORDER=(
    "lightning.proto"
    "signrpc/signer.proto" 
    "chainrpc/chainnotifier.proto"
    "invoicesrpc/invoices.proto"
    "walletrpc/walletkit.proto"
    "routerrpc/router.proto"
    "peersrpc/peers.proto"
)

# Track generation statistics
GENERATED_COUNT=0
FAILED_COUNT=0

for proto_file in "${COMPILE_ORDER[@]}"; do
    if [[ -f "$PROTO_DIR/$proto_file" ]]; then
        echo -e "${YELLOW}   📄 Compiling $proto_file...${NC}"
        
        if python3 -m grpc_tools.protoc \
            --proto_path="$PROTO_DIR" \
            --python_out=. \
            --grpc_python_out=. \
            "$PROTO_DIR/$proto_file"; then
            ((GENERATED_COUNT++))
            echo -e "${GREEN}   ✅ $proto_file compiled successfully${NC}"
        else
            ((FAILED_COUNT++))
            echo -e "${RED}   ❌ Failed to compile $proto_file${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️ Proto file not found: $proto_file${NC}"
    fi
done

# Additional proto files (compile any remaining .proto files)
echo -e "${YELLOW}🔍 Checking for additional proto files...${NC}"
ADDITIONAL_PROTOS=$(find "$PROTO_DIR" -name "*.proto" ! -path "*/signrpc/*" ! -path "*/chainrpc/*" ! -path "*/invoicesrpc/*" ! -path "*/walletrpc/*" ! -path "*/routerrpc/*" ! -path "*/peersrpc/*" ! -name "lightning.proto" || true)

for proto_file in $ADDITIONAL_PROTOS; do
    if [[ -f "$proto_file" ]]; then
        relative_path=$(realpath --relative-to="$PROTO_DIR" "$proto_file")
        echo -e "${YELLOW}   📄 Compiling additional: $relative_path...${NC}"
        
        if python3 -m grpc_tools.protoc \
            --proto_path="$PROTO_DIR" \
            --python_out=. \
            --grpc_python_out=. \
            "$proto_file"; then
            ((GENERATED_COUNT++))
            echo -e "${GREEN}   ✅ $relative_path compiled successfully${NC}"
        else
            ((FAILED_COUNT++))
            echo -e "${RED}   ❌ Failed to compile $relative_path${NC}"
        fi
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
MISSING_MAIN=()

for file in "${MAIN_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        MISSING_MAIN+=("$file")
    else
        echo -e "${GREEN}   ✅ $file generated${NC}"
    fi
done

# Count all generated files
TOTAL_GENERATED=$(ls -1 *_pb2.py *_pb2_grpc.py | wc -l)

echo -e "${BLUE}📊 Generation Summary:${NC}"
echo -e "${GREEN}   ✅ Successfully compiled: $GENERATED_COUNT proto files${NC}"
echo -e "${GREEN}   📦 Total generated files: $TOTAL_GENERATED${NC}"

if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "${RED}   ❌ Failed compilations: $FAILED_COUNT${NC}"
fi

if [[ ${#MISSING_MAIN[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ All main protocol buffer files generated successfully!${NC}"
    
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
    fi
    
    # Set proper permissions
    echo -e "${YELLOW}🔑 Setting file permissions...${NC}"
    chmod 644 *_pb2.py *_pb2_grpc.py || true
    
    echo ""
    echo -e "${GREEN}🎉 Protocol buffer generation completed successfully!${NC}"
    echo -e "${BLUE}📁 Generated files are located in: $API_DIR${NC}"
    echo -e "${YELLOW}💡 You may need to restart services that use these files${NC}"
    
else
    echo -e "${RED}❌ Missing main files: ${MISSING_MAIN[*]}${NC}"
    echo -e "${RED}❌ Protocol buffer generation failed!${NC}"
    exit 1
fi