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

echo -e "${BLUE}🔧 BRLN-OS Protocol Buffer Generator (Simple)${NC}"
echo -e "${BLUE}=============================================${NC}"

# Check if running from correct directory
if [[ ! -d "$API_DIR" ]]; then
    echo -e "${RED}❌ API directory not found: $API_DIR${NC}"
    exit 1
fi

if [[ ! -d "$PROTO_DIR" ]]; then
    echo -e "${RED}❌ Proto directory not found: $PROTO_DIR${NC}"
    exit 1
fi

# Change to API directory
cd "$API_DIR"

# Check if grpcio-tools is available
if ! python3 -c "import grpc_tools.protoc" >/dev/null 2>&1; then
    echo -e "${YELLOW}📦 grpcio-tools not found in current environment${NC}"
    echo -e "${YELLOW}💡 Install with: pip3 install grpcio-tools${NC}"
    exit 1
fi

echo -e "${YELLOW}🧹 Cleaning old generated files...${NC}"
# Remove old generated files
rm -f *_pb2.py *_pb2_grpc.py 2>/dev/null || true

echo -e "${YELLOW}🔨 Generating main lightning.proto files...${NC}"

# Generate main lightning protobuf files
echo -e "${YELLOW}   📄 Compiling lightning.proto...${NC}"
python3 -m grpc_tools.protoc \
    --proto_path="$PROTO_DIR" \
    --python_out=. \
    --grpc_python_out=. \
    "$PROTO_DIR/lightning.proto"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}   ✅ lightning.proto compiled successfully${NC}"
else
    echo -e "${RED}   ❌ Failed to compile lightning.proto${NC}"
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
            "$PROTO_DIR/$proto_file" >/dev/null 2>&1
        
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
        sed -i 's/from \. import \([a-z_]*\)_pb2/import \1_pb2/g' "$grpc_file" 2>/dev/null || true
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
TOTAL_GENERATED=$(ls -1 *_pb2.py *_pb2_grpc.py 2>/dev/null | wc -l)

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
" 2>/dev/null; then
        echo -e "${GREEN}✅ Import test passed!${NC}"
    else
        echo -e "${RED}❌ Import test failed${NC}"
        exit 1
    fi
    
    # Set proper permissions
    chmod 644 *_pb2.py *_pb2_grpc.py 2>/dev/null || true
    
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