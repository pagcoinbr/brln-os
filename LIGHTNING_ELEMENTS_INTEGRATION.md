# 🌊 Lightning + Elements Integration for BRLN-OS

Uma extensão do projeto [Lightning](https://github.com/alexbosworth/lightning) do Alex Bosworth que adiciona suporte completo ao **Elements Core (Liquid Network)**, criando uma integração simbiótica com o projeto **BRLN-OS**.

## 🎯 Objetivo

Estender o projeto Lightning original para permitir conexões e operações com **Elements Core** da mesma forma que ele já faz com **LND**, criando uma API unificada para:

- ⚡ **Lightning Network** (via LND) 
- ₿ **Bitcoin On-chain** (via LND)
- 🌊 **Liquid Network** (via Elements Core)
- 💎 **Liquid Assets**

## 🛠️ Estrutura das Modificações

### Novos Diretórios Criados

```
lightning/
├── elements_rpc/           # Cliente RPC para Elements Core
│   └── index.js           # Conexão e métodos RPC básicos
├── elements_methods/       # Métodos Elements siguindo padrão Lightning
│   ├── index.js
│   ├── create_chain_address.js
│   ├── get_chain_balance.js
│   ├── get_chain_info.js
│   ├── get_liquid_assets.js
│   └── send_to_chain_address.js
├── config/                # Configurações BRLN-OS
│   └── brln-elements-config.js
└── examples/              # Exemplos de uso
    ├── elements_integration_example.js
    └── brln-complete-example.js
```

### Modificações nos Arquivos Existentes

- **`index.js`**: Adicionados imports e exports dos métodos Elements
- **`package.json`**: Adicionados scripts BRLN-OS
- **`.env`**: Configurações para integração com containers

## 🚀 Instalação

### Opção 1: Script Automatizado

```bash
# No diretório raiz do brln-os
./scripts/install-lightning-elements.sh
```

### Opção 2: Manual

```bash
# Clonar projeto original
git clone https://github.com/alexbosworth/lightning.git
cd lightning

# Instalar dependências
npm install
npm install axios  # Para Elements RPC

# Aplicar modificações (copiar arquivos criados)
# ... 
```

## 📋 Métodos Elements Disponíveis

### Cliente RPC

```javascript
const {elementsRpc} = require('lightning');

const {elements} = elementsRpc({
  host: 'localhost',        // ou 'elements' no Docker
  port: 7041,              // mainnet port  
  user: 'test',            // RPC user
  password: 'test'         // RPC password
});
```

### Métodos Principais

```javascript
const lightning = require('lightning');

// 1. Informações da blockchain Liquid
const chainInfo = await lightning.getElementsInfo({elements});

// 2. Saldo L-BTC (ou qualquer asset)
const balance = await lightning.getElementsBalance({
  elements,
  asset: 'bitcoin' // L-BTC (padrão)
});

// 3. Criar endereço Liquid
const address = await lightning.createElementsAddress({
  elements,
  format: 'bech32',
  label: 'my-address'
});

// 4. Enviar L-BTC
const transaction = await lightning.sendToElementsAddress({
  elements,
  address: 'lq1qw5w...',
  tokens: 100000,  // satoshis
  description: 'Payment description'
});

// 5. Listar todos os Liquid Assets  
const assets = await lightning.getLiquidAssets({elements});
```

## 🔄 Integração com BRLN-OS

### Configuração Docker

O projeto usa as mesmas configurações do `docker-compose.yml` do BRLN-OS:

```yaml
# Elements Core configuração
elements:
  ports:
    - 7041:7041   # RPC mainnet
  environment:
    - ELEMENTS_DATA=/home/elements/.elements

# LND (funcionalidade original mantida)
lnd:
  ports:
    - 10009:10009  # gRPC port
```

### Variáveis de Ambiente

```bash
# Elements
ELEMENTS_HOST=localhost
ELEMENTS_PORT=7041
ELEMENTS_RPC_USER=test
ELEMENTS_RPC_PASSWORD=test

# LND (original)
LND_HOST=localhost:10009
LND_TLS_CERT_PATH=/data/lnd/tls.cert
LND_MACAROON_PATH=/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon
```

## 💡 Exemplos de Uso

### Exemplo Básico

```javascript
const lightning = require('lightning');

async function basicExample() {
  // Conectar Elements
  const {elements} = lightning.elementsRpc({
    host: 'localhost',
    port: 7041,
    user: 'test',
    password: 'test'
  });

  // Verificar conexão
  const info = await lightning.getElementsInfo({elements});
  console.log('Connected to:', info.chain);

  // Verificar saldo
  const balance = await lightning.getElementsBalance({elements});
  console.log('L-BTC Balance:', balance.balance);
}
```

### Exemplo com LND + Elements

```javascript
async function completeIntegration() {
  // Elements
  const {elements} = lightning.elementsRpc({...});
  
  // LND (funcionalidade original)
  const {lnd} = lightning.authenticatedLndGrpc({
    cert: fs.readFileSync('/data/lnd/tls.cert'),
    macaroon: fs.readFileSync('/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'),
    socket: 'localhost:10009'
  });

  // Comparar saldos
  const liquidBalance = await lightning.getElementsBalance({elements});
  const bitcoinBalance = await lightning.getChainBalance({lnd});
  const lightningBalance = await lightning.getChannelBalance({lnd});

  console.log('L-BTC:', liquidBalance.balance);
  console.log('BTC:', bitcoinBalance.chain_balance);
  console.log('Lightning:', lightningBalance.channel_balance);
}
```

## 🧪 Testes

```bash
# Teste integração completa
npm run brln_test

# Teste apenas Elements
npm run brln_elements  

# Monitor de assets
npm run brln_monitor
```

## 📚 API Reference

| Método Original (LND) | Método Elements | Descrição |
|----------------------|-----------------|-----------|
| `getChainBalance` | `getElementsBalance` | Saldo da carteira |
| `createChainAddress` | `createElementsAddress` | Criar endereço |
| `sendToChainAddress` | `sendToElementsAddress` | Enviar transação |
| `getWalletInfo` | `getElementsInfo` | Informações gerais |
| - | `getLiquidAssets` | Listar assets (Liquid específico) |

## 🤝 Compatibilidade

- ✅ **100% compatível** com projeto Lightning original
- ✅ **Não-invasivo**: métodos LND originais inalterados
- ✅ **Modular**: Elements methods são opcionais
- ✅ **Docker-ready**: funciona com containers BRLN-OS
- ✅ **Multi-network**: mainnet/testnet support

## 🔮 Próximos Passos

1. **Implementar métodos avançados**: Confidential transactions, Peg operations
2. **Websockets**: Streaming de eventos Elements
3. **Asset management**: Issuing e reissuing de assets
4. **Integration tests**: Testes automatizados com containers
5. **TypeScript definitions**: Tipos para métodos Elements

## 📄 Fork Information

- **Projeto Original**: https://github.com/alexbosworth/lightning
- **Autor Original**: Alex Bosworth  
- **Fork Maintainer**: pagcoinbr
- **BRLN-OS Project**: https://github.com/pagcoinbr/brln-os

## 📞 Suporte

Para questões sobre:
- **Funcionalidade Lightning original**: Ver documentação do Alex Bosworth
- **Extensões Elements**: Abrir issue no repositório BRLN-OS
- **Integração BRLN-OS**: Consultar documentação do projeto principal

---

**⚡ Lightning + 🌊 Liquid = 🚀 BRLN-OS Integration**
