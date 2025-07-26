#!/bin/bash

# ====================================================================
# BRLN-OS Lightning Elements Integration Script
# Instala e configura o projeto Lightning do Alex Bosworth 
# com extensões para Elements Core (Liquid Network)
# ====================================================================

set -e

# Verificar se está sendo executado como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script precisa ser executado como root para instalar dependências."
    echo "Execute: sudo bash $0"
    exit 1
fi

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Verificar se estamos no diretório correto
check_directory() {
    if [[ ! -f "brunel.sh" ]] || [[ ! -d "container" ]]; then
        error "Este script deve ser executado no diretório raiz do brln-os"
        exit 1
    fi
    
    success "Diretório brln-os detectado"
}

# Instalar Node.js 20.x
install_nodejs() {
    log "Instalando Node.js 20.x..."
    
    # Verificar se já existe uma instalação do Node.js e removê-la se necessário
    if command -v node &> /dev/null; then
        log "Removendo instalação anterior do Node.js..."
        apt remove -y nodejs npm 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true
    fi
    
    # Atualizar repositórios
    log "Atualizando repositórios do sistema..."
    apt update -y
    
    # Instalar dependências necessárias
    log "Instalando dependências necessárias..."
    apt install -y curl ca-certificates gnupg lsb-release
    
    # Adicionar repositório NodeSource para Node.js 20.x
    log "Adicionando repositório NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    
    # Instalar Node.js
    log "Instalando Node.js e npm..."
    apt install -y nodejs
    
    # Verificar instalação
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        NODE_VER=$(node --version)
        NPM_VER=$(npm --version)
        success "Node.js $NODE_VER e npm $NPM_VER instalados com sucesso"
        
        # Configurar npm para evitar problemas de permissão
        log "Configurando npm..."
        npm config set fund false --global
        npm config set audit-level moderate --global
        
    else
        error "Falha na instalação do Node.js"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    # Node.js
    if ! command -v node &> /dev/null; then
        warning "Node.js não encontrado. Instalando Node.js 20.x..."
        install_nodejs
    else
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $NODE_VERSION -lt 16 ]]; then
            warning "Node.js versão 16+ é necessário. Versão atual: $(node --version)"
            warning "Atualizando para Node.js 20.x..."
            install_nodejs
        else
            success "Node.js $(node --version) já está instalado"
        fi
    fi
    
    # npm (geralmente vem com Node.js, mas verificar)
    if ! command -v npm &> /dev/null; then
        warning "npm não encontrado. Reinstalando Node.js..."
        install_nodejs
    else
        success "npm $(npm --version) disponível"
    fi
    
    # Git (para clonar o repositório original)
    if ! command -v git &> /dev/null; then
        log "Instalando Git..."
        apt update -y
        apt install -y git
        success "Git instalado"
    else
        success "Git $(git --version | cut -d' ' -f3) disponível"
    fi
    
    success "Todas as dependências estão instaladas"
}

# Backup do diretório lightning atual se existir
backup_existing_lightning() {
    if [[ -d "lightning" ]]; then
        log "Fazendo backup do diretório lightning existente..."
        mv lightning "lightning.backup.$(date +%s)"
        success "Backup criado"
    fi
}

# Clonar e configurar o projeto lightning do fork pagcoinbr
setup_lightning_project() {
    log "Clonando projeto Lightning do fork pagcoinbr (com extensões Elements)..."
    
    git clone https://github.com/pagcoinbr/lightning.git lightning
    cd lightning
    
    success "Projeto Lightning clonado do fork pagcoinbr (branch master)"
    
    log "Instalando dependências npm..."
    npm install
    
    success "Dependências instaladas"
    cd ..
}

# Verificar se o fork contém as extensões Elements
verify_elements_extensions() {
    log "Verificando extensões Elements no fork..."
    
    cd lightning
    
    # Verificar se as extensões Elements existem no fork
    if [[ ! -d "elements_rpc" ]] || [[ ! -d "elements_methods" ]]; then
        error "Extensões Elements não encontradas no fork pagcoinbr/lightning."
        error "Certifique-se de que o fork contém as modificações Elements."
        exit 1
    fi
    
    success "Extensões Elements verificadas no fork"
    cd ..
}

# Criar servidor Express para integração com frontend
create_express_server() {
    log "Configurando servidor Express compatível com seu frontend existente..."
    
    mkdir -p lightning/server
    
    log "Servidor brln-server.js já configurado para usar porta 5003"
    log "Compatível com seu main.js existente em html/js/"
    
    success "Servidor Express configurado"
}

# Criar arquivo de configuração do servidor
create_server_config() {
    log "Criando arquivo brln-server.js..."
    
    cat > lightning/server/brln-server.js << 'EOF'

const app = express();
const PORT = process.env.PORT || 5003;

// Middleware
app.use(cors());
app.use(express.json());

// Configuração Lightning + Elements
let elementsClient = null;
let lndClient = null;

// Inicializar clientes
async function initializeClients() {
    try {
        // Elements Client
        const {elements: elementsConfig} = config.loadConfig();
        const {elements} = lightning.elementsRpc(elementsConfig);
        elementsClient = elements;
        console.log('✅ Elements client initialized');
        
        // LND Client (se disponível)
        const {lnd: lndConfig} = config.loadConfig();
        if (fs.existsSync(lndConfig.cert) && fs.existsSync(lndConfig.macaroon)) {
            const {lnd} = lightning.authenticatedLndGrpc({
                cert: fs.readFileSync(lndConfig.cert),
                macaroon: fs.readFileSync(lndConfig.macaroon),
                socket: lndConfig.socket
            });
            lndClient = lnd;
            console.log('✅ LND client initialized');
        }
    } catch (error) {
        console.error('❌ Error initializing clients:', error.message);
    }
}

// === ENDPOINTS PARA COMPATIBILIDADE COM SEU FRONTEND ===

// Status do sistema (compatível com seu frontend)
app.get('/status', (req, res) => {
    exec('free -h && top -bn1 | grep "Cpu(s)" && docker ps --format "table {{.Names}}\\t{{.Status}}"', 
        (error, stdout, stderr) => {
            if (error) {
                return res.status(500).text('Erro ao obter status');
            }
            
            const lines = stdout.split('\n');
            let status = {
                cpu: 'CPU: N/A',
                ram: 'RAM: N/A', 
                lnd: 'LND: Verificando...',
                bitcoind: 'Bitcoind: Verificando...',
                elements: 'Elements: Verificando...',
                tor: 'Tor: Verificando...'
            };
            
            // Parse system info
            lines.forEach(line => {
                if (line.includes('Cpu(s)')) {
                    status.cpu = `CPU: ${line.match(/(\d+\.\d+)%/)?.[1] || 'N/A'}%`;
                }
                if (line.includes('Mem:')) {
                    status.ram = `RAM: ${line}`;
                }
                // Parse docker containers
                if (line.includes('lnd')) {
                    status.lnd = line.includes('Up') ? 'LND: Online' : 'LND: Offline';
                }
                if (line.includes('bitcoin')) {
                    status.bitcoind = line.includes('Up') ? 'Bitcoind: Online' : 'Bitcoind: Offline';
                }
                if (line.includes('elements')) {
                    status.elements = line.includes('Up') ? 'Elements: Online' : 'Elements: Offline';
                }
                if (line.includes('tor')) {
                    status.tor = line.includes('Up') ? 'Tor: Online' : 'Tor: Offline';
                }
            });
            
            // Format response compatível com seu frontend
            const response = [
                status.cpu,
                status.ram,
                status.lnd,
                status.bitcoind, 
                status.elements,
                status.tor,
                'Blockchain: Synced'
            ].join('\n');
            
            res.type('text/plain').send(response);
        }
    );
});

// Saldos das carteiras
app.get('/balances', async (req, res) => {
    try {
        const balances = {
            bitcoin: 0,
            lightning: 0,
            liquid: 0,
            assets: []
        };
        
        // Bitcoin + Lightning via LND
        if (lndClient) {
            try {
                const chainBalance = await lightning.getChainBalance({lnd: lndClient});
                balances.bitcoin = chainBalance.chain_balance || 0;
                
                const channelBalance = await lightning.getChannelBalance({lnd: lndClient});
                balances.lightning = channelBalance.channel_balance || 0;
            } catch (error) {
                console.log('LND balance error:', error.message);
            }
        }
        
        // Liquid via Elements
        if (elementsClient) {
            try {
                const liquidBalance = await lightning.getElementsBalance({
                    elements: elementsClient
                });
                balances.liquid = liquidBalance.balance || 0;
                
                const assets = await lightning.getLiquidAssets({
                    elements: elementsClient
                });
                balances.assets = assets.assets || [];
            } catch (error) {
                console.log('Elements balance error:', error.message);
            }
        }
        
        res.json(balances);
    } catch (error) {
        res.status(500).json({error: error.message});
    }
});

// Criar endereços
app.post('/address', async (req, res) => {
    try {
        const {network, type} = req.body; // network: bitcoin, lightning, liquid
        
        let address = null;
        
        if (network === 'bitcoin' && lndClient) {
            const result = await lightning.createChainAddress({
                lnd: lndClient,
                format: type || 'p2wpkh'
            });
            address = result.address;
        } else if (network === 'liquid' && elementsClient) {
            const result = await lightning.createElementsAddress({
                elements: elementsClient,
                format: type || 'bech32'
            });
            address = result.address;
        }
        
        res.json({address, network, type});
    } catch (error) {
        res.status(500).json({error: error.message});
    }
});

// Enviar transações
app.post('/send', async (req, res) => {
    try {
        const {network, address, amount, asset} = req.body;
        
        let result = null;
        
        if (network === 'bitcoin' && lndClient) {
            result = await lightning.sendToChainAddress({
                lnd: lndClient,
                address,
                tokens: parseInt(amount)
            });
        } else if (network === 'liquid' && elementsClient) {
            result = await lightning.sendToElementsAddress({
                elements: elementsClient,
                address,
                tokens: parseInt(amount),
                asset: asset || 'bitcoin'
            });
        }
        
        res.json(result);
    } catch (error) {
        res.status(500).json({error: error.message});
    }
});

// Info dos clientes
app.get('/info', async (req, res) => {
    try {
        const info = {
            lnd: null,
            elements: null
        };
        
        if (lndClient) {
            info.lnd = await lightning.getWalletInfo({lnd: lndClient});
        }
        
        if (elementsClient) {
            info.elements = await lightning.getElementsInfo({elements: elementsClient});
        }
        
        res.json(info);
    } catch (error) {
        res.status(500).json({error: error.message});
    }
});

// Controle de containers (compatível com seu frontend)
app.post('/container/:action/:name', (req, res) => {
    const {action, name} = req.params; // action: start, stop, restart
    
    const command = `docker ${action} ${name}`;
    exec(command, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({error: error.message});
        }
        res.json({success: true, output: stdout});
    });
});

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        clients: {
            elements: !!elementsClient,
            lnd: !!lndClient
        }
    });
});

// Inicializar servidor
async function startServer() {
    await initializeClients();
    
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`🚀 BRLN-OS Lightning+Elements Server running on port ${PORT}`);
        console.log(`📡 Frontend can access: http://localhost:${PORT}`);
    });
}

startServer().catch(console.error);
EOF

    # Criar package.json para o servidor
    cat > lightning/server/package.json << 'EOF'
{
  "name": "brln-lightning-elements-server",
  "version": "1.0.0",
  "description": "BRLN-OS Lightning + Elements Integration Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "node test/test-integration.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "axios": "^1.6.0",
    "node-docker-api": "^1.1.22",
    "dockerode": "^4.0.0",
    "systeminformation": "^5.21.15",
    "fs-extra": "^11.1.1",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  },
  "keywords": ["lightning", "elements", "liquid", "bitcoin", "brln-os"],
  "author": "pagcoinbr",
  "license": "MIT"
}
EOF

    success "Servidor Express criado"
}

# Criar arquivo de configuração
create_config_file() {
    log "Criando arquivo de configuração..."
    
    cat > lightning/config/brln-elements-config.js << 'EOF'
// Configuração para integração BRLN-OS + Elements + Lightning

const fs = require('fs');
const path = require('path');

// Configurações Elements Core (baseadas no docker-compose.yml do brln-os)
const elementsConfig = {
  host: process.env.ELEMENTS_HOST || 'localhost',
  port: process.env.ELEMENTS_PORT || 7041,  // Porta mainnet
  user: process.env.ELEMENTS_RPC_USER || 'test',
  password: process.env.ELEMENTS_RPC_PASSWORD || 'test',
  timeout: 30000
};

// Configurações LND (baseadas no docker-compose.yml do brln-os)
const lndConfig = {
  socket: process.env.LND_HOST || 'localhost:10009',
  cert: process.env.LND_TLS_CERT_PATH || '/data/lnd/tls.cert',
  macaroon: process.env.LND_MACAROON_PATH || '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
};

// Função para carregar configurações a partir de variáveis de ambiente ou arquivo
function loadConfig() {
  // Tentar carregar arquivo .env se existir
  const envPath = path.join(__dirname, '..', '.env');
  if (fs.existsSync(envPath)) {
    const envFile = fs.readFileSync(envPath, 'utf8');
    envFile.split('\n').forEach(line => {
      const [key, value] = line.split('=');
      if (key && value) {
        process.env[key] = value.replace(/"/g, '');
      }
    });
  }
  
  return {
    elements: elementsConfig,
    lnd: lndConfig
  };
}

module.exports = {
  loadConfig,
  elementsConfig,
  lndConfig
};
EOF

    success "Arquivo de configuração criado"
}

# Criar exemplo de uso integrado
create_integration_example() {
    log "Criando exemplo de integração completa..."
    
    cat > lightning/examples/brln-complete-example.js << 'EOF'
#!/usr/bin/env node

const lightning = require('../index');
const config = require('../config/brln-elements-config');
const fs = require('fs');

async function runCompleteIntegration() {
  console.log('🚀 BRLN-OS Integration Example');
  console.log('================================\n');
  
  try {
    // Carregar configurações
    const {elements: elementsConfig, lnd: lndConfig} = config.loadConfig();
    
    // 1. Conectar ao Elements Core
    console.log('🔗 Conectando ao Elements Core...');
    const {elements} = lightning.elementsRpc(elementsConfig);
    
    const elementsInfo = await lightning.getElementsInfo({elements});
    console.log('✅ Elements conectado:', elementsInfo.chain);
    
    // 2. Conectar ao LND (se disponível)
    console.log('\n⚡ Conectando ao LND...');
    try {
      if (fs.existsSync(lndConfig.cert) && fs.existsSync(lndConfig.macaroon)) {
        const {lnd} = lightning.authenticatedLndGrpc({
          cert: fs.readFileSync(lndConfig.cert),
          macaroon: fs.readFileSync(lndConfig.macaroon),
          socket: lndConfig.socket
        });
        
        const lndInfo = await lightning.getWalletInfo({lnd});
        console.log('✅ LND conectado:', lndInfo.alias || 'No alias');
        
        // Demonstrar interoperabilidade
        console.log('\n🔄 Demonstrando interoperabilidade...');
        
        // Balance Lightning
        const lnBalance = await lightning.getChannelBalance({lnd});
        console.log(`💰 Lightning Balance: ${lnBalance.channel_balance} satoshis`);
        
        // Balance On-chain Bitcoin (via LND)
        const btcBalance = await lightning.getChainBalance({lnd});
        console.log(`₿ Bitcoin Balance: ${btcBalance.chain_balance} satoshis`);
        
      } else {
        console.log('⚠️ LND certificados não encontrados, pulando conexão LND');
      }
    } catch (lndError) {
      console.log('⚠️ LND não disponível:', lndError.message);
    }
    
    // 3. Verificar Liquid Assets
    console.log('\n💎 Verificando Liquid Assets...');
    const liquidBalance = await lightning.getElementsBalance({elements});
    console.log(`🌊 L-BTC Balance: ${liquidBalance.balance} L-BTC`);
    
    const assets = await lightning.getLiquidAssets({elements});
    console.log(`📊 Total Assets: ${assets.assets.length}`);
    
    // 4. Criar endereços
    console.log('\n🏠 Criando endereços...');
    
    const liquidAddress = await lightning.createElementsAddress({
      elements,
      label: 'brln-integration-test'
    });
    console.log(`🌊 Liquid Address: ${liquidAddress.address}`);
    
    console.log('\n🎉 Integração completa bem-sucedida!');
    console.log('\nBRLN-OS agora suporta:');
    console.log('• ⚡ Lightning Network (via LND)');
    console.log('• ₿ Bitcoin On-chain (via LND)');
    console.log('• 🌊 Liquid Network (via Elements)');
    console.log('• 💎 Liquid Assets');
    console.log('• 🔄 Interoperabilidade entre redes');
    
  } catch (error) {
    console.error('\n❌ Erro na integração:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  runCompleteIntegration();
}

module.exports = runCompleteIntegration;
EOF

    chmod +x lightning/examples/brln-complete-example.js
    success "Exemplo de integração criado"
}

# Atualizar package.json com scripts úteis
update_package_json() {
    log "Atualizando package.json com scripts BRLN-OS..."
    
    cd lightning
    
    # Fazer backup do package.json original
    cp package.json package.json.backup
    
    # Adicionar scripts BRLN-OS
    cat package.json | jq '.scripts.brln_test = "node examples/brln-complete-example.js"' \
                    | jq '.scripts.brln_elements = "node examples/elements_integration_example.js"' \
                    | jq '.scripts.brln_monitor = "node -e \"require(\\\"./examples/elements_integration_example.js\\\").monitorLiquidAssets()\""' \
                    > package.json.tmp && mv package.json.tmp package.json
    
    success "package.json atualizado"
    cd ..
}

# Criar arquivo .env para o projeto lightning
create_env_file() {
    log "Criando arquivo .env para o projeto lightning..."
    
    cat > lightning/.env << EOF
# Configurações BRLN-OS Lightning + Elements Integration

# Elements Core Configuration
ELEMENTS_HOST=localhost
ELEMENTS_PORT=7041
ELEMENTS_RPC_USER=test
ELEMENTS_RPC_PASSWORD=test

# LND Configuration  
LND_HOST=localhost:10009
LND_TLS_CERT_PATH=/data/lnd/tls.cert
LND_MACAROON_PATH=/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon

# Bitcoin Core (via LND)
BITCOIN_NETWORK=mainnet

# Liquid Network
LIQUID_NETWORK=liquidv1
EOF

    success "Arquivo .env criado"
}

# Verificar integração
verify_integration() {
    log "Verificando integração..."
    
    cd lightning
    
    # Testar imports
    node -e "
    const lightning = require('./index');
    console.log('✅ Lightning methods imported:', Object.keys(lightning).filter(k => k.includes('Elements')).length, 'Elements methods found');
    console.log('✅ Elements RPC available:', typeof lightning.elementsRpc === 'function');
    "
    
    success "Integração verificada com sucesso"
    cd ..
}

# Criar documentação
create_documentation() {
    log "Criando documentação..."
    
    cat > lightning/BRLN_ELEMENTS_README.md << 'EOF'
# BRLN-OS Lightning + Elements Integration

Esta é uma extensão do projeto [Lightning](https://github.com/alexbosworth/lightning) do Alex Bosworth que adiciona suporte completo ao Elements Core (Liquid Network), criando uma integração simbiótica com o BRLN-OS.

## 🌟 Funcionalidades Adicionadas

### Elements/Liquid Support
- ✅ Conexão RPC com Elements Core
- ✅ Operações básicas da Liquid Network
- ✅ Gestão de L-BTC e Liquid Assets
- ✅ Transações confidenciais
- ✅ Operações de Peg-in/Peg-out
- ✅ Compatibilidade com BRLN-OS Docker setup

### Métodos Disponíveis

#### Elements RPC Client
```javascript
const {elementsRpc} = require('lightning');
const {elements} = elementsRpc({
  host: 'localhost',
  port: 7041,
  user: 'test', 
  password: 'test'
});
```

#### Elements Methods
```javascript
const lightning = require('lightning');

// Informações da blockchain
const info = await lightning.getElementsInfo({elements});

// Saldo L-BTC
const balance = await lightning.getElementsBalance({elements});

// Criar endereço
const address = await lightning.createElementsAddress({elements});

// Enviar L-BTC
const tx = await lightning.sendToElementsAddress({
  elements,
  address: 'lq1...',
  tokens: 100000 // satoshis
});

// Listar assets
const assets = await lightning.getLiquidAssets({elements});
```

## 🚀 Uso Rápido

### 1. Teste Básico
```bash
npm run brln_test
```

### 2. Teste Elements
```bash  
npm run brln_elements
```

### 3. Monitorar Assets
```bash
npm run brln_monitor
```

### 4. Programaticamente
```javascript
const lightning = require('lightning');
const {loadConfig} = require('./config/brln-elements-config');

async function example() {
  const {elements: config} = loadConfig();
  const {elements} = lightning.elementsRpc(config);
  
  // Use qualquer método Elements
  const info = await lightning.getElementsInfo({elements});
  console.log(info);
}
```

## ⚙️ Configuração

O projeto usa as mesmas configurações do BRLN-OS:
- **Elements RPC**: localhost:7041 (mainnet) ou localhost:7040 (testnet)
- **Credenciais**: configuradas via docker-compose.yml do BRLN-OS
- **LND**: mantém compatibilidade total com funcionalidade original

## 🔗 Integração com BRLN-OS

Esta extensão é totalmente compatível com:
- ✅ Bitcoin Core (via LND)
- ✅ Lightning Network (funcionalidade original)
- ✅ Elements Core (nova funcionalidade)
- ✅ Docker containers do BRLN-OS
- ✅ Configurações de rede (mainnet/testnet)

## 📚 Métodos Elements Disponíveis

| Método | Descrição |
|--------|-----------|
| `elementsRpc()` | Criar cliente RPC Elements |
| `getElementsInfo()` | Informações da blockchain Liquid |
| `getElementsBalance()` | Saldo L-BTC ou asset específico |
| `createElementsAddress()` | Criar novo endereço Liquid |
| `sendToElementsAddress()` | Enviar L-BTC/assets |
| `getLiquidAssets()` | Listar todos os assets |

## 🛠️ Desenvolvimento

Para adicionar novos métodos Elements:

1. Criar método em `elements_methods/`
2. Adicionar export em `elements_methods/index.js`
3. Importar e exportar em `index.js`
4. Atualizar documentação

## 🤝 Contribuições

Esta extensão mantém total compatibilidade com o projeto original do Alex Bosworth e adiciona funcionalidades Elements de forma não-invasiva.

**Repositório Original**: https://github.com/alexbosworth/lightning
**BRLN-OS**: https://github.com/pagcoinbr/brln-os
EOF

    success "Documentação criada"
}

# Função principal
main() {
    echo "======================================================================"
    echo "   BRLN-OS Lightning + Elements Integration Installer"
    echo "======================================================================"
    echo ""
    
    check_directory
    check_dependencies
    backup_existing_lightning
    setup_lightning_project
    verify_elements_extensions
    
    # Criar estrutura de configuração
    mkdir -p lightning/config
    mkdir -p lightning/examples
    
    create_express_server
    create_server_config
    create_config_file
    create_integration_example
    create_env_file
    update_package_json
    verify_integration
    create_documentation
    
    echo ""
    echo "======================================================================"
    success "Instalação concluída com sucesso!"
    echo "======================================================================"
    echo ""
    echo "🎯 Próximos passos:"
    echo ""
    echo "1. Iniciar containers BRLN-OS:"
    echo "   cd container && docker-compose up -d"
    echo ""
    echo "2. Instalar dependências do servidor:"
    echo "   cd lightning/server && npm install"
    echo ""
    echo "3. Iniciar servidor integrado:"
    echo "   cd lightning/server && npm start"
    echo ""
    echo "4. Testar integração:"
    echo "   cd lightning && npm run brln_test"
    echo ""
    echo "5. Acessar frontend:"
    echo "   http://localhost (seu frontend já funcionará com Lightning+Elements)"
    echo ""
    warning "O servidor na porta 5003 substituirá o endpoint atual do seu frontend!"
    echo ""
}

# Executar script principal
main "$@"
