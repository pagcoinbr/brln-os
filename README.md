# ⚡ BRLN-OS

<div align="center">

![BRLN-OS Logo](https://img.shields.io/badge/BRLN--OS-Lightning%20Node-orange?style=for-the-badge&logo=bitcoin&logoColor=white)

**Sistema operacional containerizado completo para Bitcoin, Lightning Network e Liquid Network**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![Lightning](https://img.shields.io/badge/lightning-network-yellow.svg)](https://lightning.network)
[![Bitcoin](https://img.shields.io/badge/bitcoin-core-orange.svg)](https://bitcoincore.org)
[![Python](https://img.shields.io/badge/python-gRPC%20client-blue.svg)](https://python.org)
[![Elements](https://img.shields.io/badge/elements-liquid%20network-green.svg)](https://elementsproject.org)

*Uma plataforma completa de nó Bitcoin e Lightning Network com interface web integrada, cliente Python gRPC e suporte avançado para PeerSwap*

</div>

---

## 🚀 Instalação Rápida

Execute este comando simples para instalar o BRLN-OS em seu sistema:

```bash
# Instalação direta via script automatizado
curl -fsSL https://pagcoin.org/start.sh | sudo bash

# OU clone e execute manualmente
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os
sudo ./run.sh
```

**É isso!** O BRLN-OS será instalado automaticamente com todos os componentes necessários.

---

## 📖 Sobre o Projeto

O **BRLN-OS** é uma distribuição containerizada avançada que transforma qualquer sistema Linux em um poderoso nó Bitcoin e Lightning Network profissional. Baseado em Docker Compose, oferece uma solução completa e automatizada para executar um stack completo de serviços Bitcoin, incluindo interface web moderna, cliente Python gRPC para automação e monitoramento avançado.

### 🏗️ Arquitetura de Serviços

#### ⚡ **Núcleo Lightning Network**
- **LND v0.18.5**: Daemon Lightning Network com suporte completo a gRPC
- **LNbits**: Sistema bancário Lightning web-based com múltiplas extensões
- **Thunderhub**: Interface web moderna para gerenciamento avançado do LND
- **LNDG**: Dashboard profissional com estatísticas detalhadas e análise de canais
- **Cliente Python gRPC**: Automação e integração programática com LND e Elements

#### ₿ **Stack Bitcoin & Liquid**
- **Bitcoin Core v28.1**: Nó completo Bitcoin com ZMQ, I2P e suporte Tor
- **Elements v23.2.7**: Suporte completo ao Liquid Network (sidechain do Bitcoin)
- **PeerSwap v4.0**: Ferramenta avançada para swaps automáticos BTC ↔ Liquid
- **PeerSwap Web**: Interface web moderna para gestão de swaps e liquidez

#### � **Ferramentas e Automação**
- **Interface Web Integrada**: Dashboard unificado com rádio player e controle de serviços
- **Sistema de Controle**: Scripts Python Flask para gerenciamento systemd via API
- **Monitor de Saldos**: Cliente Python para monitoramento automático de saldos
- **Scripts de Automação**: Ferramentas para instalação, configuração e manutenção

#### 🛡️ **Segurança e Privacidade**
- **Tor Integration**: Proxy Tor completo para todos os serviços
- **Container Isolation**: Cada serviço isolado em container próprio
- **Network Security**: Rede Docker privada para comunicação entre serviços
- **Backup Automation**: Scripts automatizados para backup de seeds e canais

### ✨ **Principais Características**

- **🎯 Instalação Zero-Config**: Um comando instala e configura tudo automaticamente
- **🐳 Arquitetura Containerizada**: Isolamento completo com Docker Compose
- **🔒 Segurança Máxima**: Integração Tor, isolamento de rede e criptografia end-to-end
- **📊 Monitoramento Profissional**: Grafana, métricas em tempo real e logs centralizados
- **�️ Interface Web Moderna**: Dashboard responsivo com controle total dos serviços
- **🐍 Cliente Python gRPC**: API programática para LND e Elements
- **🔄 Auto-Updates**: Sistema de atualizações automáticas dos componentes
- **📱 Mobile Friendly**: Interfaces otimizadas para dispositivos móveis
- **⚡ PeerSwap Ready**: Liquidez automática entre Bitcoin e Liquid Network

---

## 🛠️ Instalação Manual

Se preferir instalar manualmente ou quiser mais controle sobre o processo:

### Pré-requisitos

- **Sistema**: Linux (Ubuntu 20.04+ recomendado)
- **RAM**: Mínimo 4GB (8GB+ recomendado para uso profissional)
- **Armazenamento**: 1TB+ (SSD NVMe recomendado para Bitcoin Core)
- **Docker**: Será instalado automaticamente se não presente
- **Python 3.8+**: Para cliente gRPC e scripts de automação
- **Conexão**: Internet banda larga para sincronização inicial

### Processo Manual

```bash
# 1. Clone o repositório
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os

# 2. Execute o script de instalação principal
sudo ./run.sh

# 3. (Opcional) Configure o cliente Python gRPC
./setup_lnd_client.sh

# 4. (Opcional) Execute setup adicional via brunel.sh
sudo ./brunel.sh
```

### Configuração Avançada

```bash
# Configurar variáveis de ambiente
cp scripts/.env.example scripts/.env
nano scripts/.env

# Personalizar configurações Bitcoin
nano container/bitcoin/bitcoin.conf

# Personalizar configurações LND
nano container/lnd/lnd.conf

# Configurar Elements/Liquid
nano container/elements/elements.conf
```

---

## 🏗️ Arquitetura do Sistema

```
brln-os/
├── 📄 run.sh                     # Script principal de instalação
├── 📄 brunel.sh                  # Setup avançado e configuração GUI
├── 📄 setup_lnd_client.sh        # Setup do cliente Python gRPC
├── 🐍 lnd_balance_client_v2.py   # Cliente avançado Python gRPC
├── 🐍 control-systemd.py         # API Flask para controle de serviços
│
├── 📁 container/                 # Stack de containers Docker
│   ├── 🐳 docker-compose.yml    # Orquestração principal dos serviços
│   │
│   ├── ₿ bitcoin/               # Bitcoin Core v28.1
│   │   ├── Dockerfile.bitcoin   # Container Bitcoin personalizado
│   │   ├── bitcoin.conf         # Configuração otimizada
│   │   └── bitcoin.sh           # Script de inicialização
│   │
│   ├── ⚡ lnd/                  # Lightning Network Daemon v0.18.5
│   │   ├── Dockerfile.lnd       # Container LND personalizado
│   │   ├── lnd.conf             # Configuração Lightning
│   │   └── entrypoint.sh        # Script de entrada
│   │
│   ├── 🔷 elements/             # Liquid Network v23.2.7
│   │   ├── Dockerfile.elements  # Container Elements
│   │   ├── elements.conf        # Configuração Liquid
│   │   └── elements.sh          # Script Liquid
│   │
│   ├── 💰 lnbits/               # Sistema bancário Lightning
│   │   ├── Dockerfile.lnbits    # Container LNbits personalizado
│   │   └── entrypoint.sh        # Configuração automática
│   │
│   ├── 🌩️ thunderhub/           # Interface web LND
│   │   └── Dockerfile.thunderhub # Container ThunderHub
│   │
│   ├── 📊 lndg/                 # Dashboard Lightning Network
│   │   ├── Dockerfile.lndg      # Container LNDG
│   │   └── entrypoint.sh        # Setup LNDG
│   │
│   ├── 🔄 peerswap/             # Swaps BTC/Liquid automáticos
│   │   ├── Dockerfile.peerswap  # Container PeerSwap
│   │   └── peerswap.conf.example # Configuração exemplo
│   │
│   ├── 🌐 psweb/                # Interface PeerSwap
│   │   └── Dockerfile.psweb     # Container PeerSwap Web
│   │
│   ├── 🧅 tor/                  # Proxy Tor para privacidade
│   │   └── Dockerfile.tor       # Container Tor customizado
│   │
│   └── 📈 monitoring/           # Stack de monitoramento
│       ├── grafana/             # Dashboards Grafana
│       ├── prometheus.yml       # Métricas Prometheus
│       └── loki-config.yml      # Logs centralizados
│
├── 📁 html/                     # Interface web integrada
│   ├── index.html               # Página principal
│   ├── main.html                # Dashboard de controle
│   ├── radio.html               # Player de rádio integrado
│   ├── css/                     # Estilos responsivos
│   ├── js/                      # Scripts JavaScript
│   └── cgi-bin/                 # Scripts CGI Python
│
├── 📁 scripts/                  # Scripts de automação
│   ├── .env.example             # Variáveis de ambiente
│   ├── install-*.sh             # Scripts de instalação individuais
│   ├── command-central.sh       # Centro de comandos
│   └── generate-services.sh     # Gerador de serviços systemd
│
├── 📁 services/                 # Serviços systemd
│   ├── control-systemd.service  # Serviço de controle
│   └── command-center.service   # Centro de comandos
│
└── 📁 local_apps/               # Aplicações locais
    └── gotty/                   # Terminal web (GoTTY)
```  
## 🌐 Painel de Controle Web

O BRLN-OS inclui uma interface web moderna e responsiva para controle completo do sistema:

### 🎨 Interface Principal
- **Dashboard Unificado**: Controle de todos os serviços em uma única tela
- **Player de Rádio**: Rádio BRL Lightning Club integrado
- **Tema Claro/Escuro**: Alternância automática de temas
- **Design Responsivo**: Otimizado para desktop e mobile

### 🔗 Acesso aos Serviços

Após a instalação, os serviços estarão disponíveis através das seguintes URLs:

| Serviço | URL | Porta | Descrição |
|---------|-----|-------|-----------|
| 🎨 **Interface Principal** | `http://localhost/` | 80 | Dashboard principal BRLN-OS |
| ⚡ **Thunderhub** | `http://localhost:3000` | 3000 | Gerenciamento avançado LND |
| 💰 **LNbits** | `http://localhost:5000` | 5000 | Sistema bancário Lightning |
| 📊 **LNDG** | `http://localhost:8889` | 8889 | Dashboard e estatísticas LND |
| 🔄 **PeerSwap Web** | `http://localhost:1984` | 1984 | Interface PeerSwap |
| 📈 **Grafana** | `http://localhost:3010` | 3010 | Monitoramento e métricas |
| 🖥️ **Terminal Web** | `http://localhost:8080` | 8080 | GoTTY - Terminal via browser |

### 🔧 APIs e Conectividade

| Protocolo | Endpoint | Porta | Finalidade |
|-----------|----------|-------|-----------|
| � **LND gRPC** | `localhost:10009` | 10009 | API gRPC Lightning Network |
| 🌐 **LND REST** | `http://localhost:8080` | 8080 | API REST Lightning Network |
| ₿ **Bitcoin RPC** | `localhost:8332` | 8332 | RPC Bitcoin Core |
| 🔷 **Elements RPC** | `localhost:18884` | 18884 | RPC Liquid Network |
| 🔄 **PeerSwap** | `localhost:42069` | 42069 | API PeerSwap |
| 🧅 **Tor SOCKS** | `localhost:9050` | 9050 | Proxy Tor |
| ⚙️ **Control API** | `localhost:5001` | 5001 | API Flask controle sistema |

---

## 🔧 Configuração e Personalização

### Configuração Automática

O BRLN-OS configura automaticamente:
- ✅ Certificados TLS e autenticação macaroon para LND
- ✅ Endereços Tor hidden services para todos os serviços
- ✅ Conexões seguras entre componentes Docker
- ✅ Configurações otimizadas do Bitcoin Core com ZMQ
- ✅ Integração completa Bitcoin ↔ Lightning ↔ Liquid
- ✅ Setup automático do PeerSwap para liquidez
- ✅ Cliente Python gRPC configurado e pronto
- ✅ Interface web com controle de serviços

### Personalização Avançada

Para personalizar configurações específicas:

#### Bitcoin Core
```bash
# Editar configuração Bitcoin
nano container/bitcoin/bitcoin.conf

# Exemplo de configurações avançadas:
# prune=550           # Modo pruned para economizar espaço
# maxconnections=40   # Limite de conexões
# dbcache=2048       # Cache de banco de dados
```

#### Lightning Network (LND)
```bash
# Editar configuração LND
nano container/lnd/lnd.conf

# Configurações importantes:
# bitcoin.feerate=1              # Taxa mínima de fee
# routing.assumechanvalid=true   # Otimização de roteamento
# wtclient.active=true          # Watchtower client ativo
```

#### Liquid Network (Elements)
```bash
# Editar configuração Elements
nano container/elements/elements.conf

# Configurações Liquid:
# fallbackfee=0.00001000        # Fee padrão Liquid
# chain=liquidv1                # Rede Liquid mainnet
```

#### Cliente Python gRPC
```bash
# Configurar cliente Python
nano lnd_client_config.ini

# Personalizar endpoints e credenciais
[LND]
host = localhost
port = 10009
tls_cert_path = /data/lnd/tls.cert
macaroon_path = /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon

[ELEMENTS]
host = localhost
port = 18884
rpc_user = elementsuser
rpc_password = elementspassword123
```

### Variáveis de Ambiente

```bash
# Configurar ambiente
cp scripts/.env.example scripts/.env
nano scripts/.env

# Principais variáveis:
BITCOIN_NETWORK=mainnet        # mainnet, testnet, regtest
LND_ALIAS="Meu Nó BRLN"       # Nome do seu nó Lightning
GRAFANA_PASSWORD=suasenha      # Senha Grafana
TOR_ENABLED=true              # Habilitar Tor
```

## 🐍 Cliente Python gRPC

O BRLN-OS inclui um cliente Python avançado para automação e integração:

### Características do Cliente

- **🔌 Conectividade gRPC**: Conexão direta com LND via gRPC
- **🔷 Suporte Elements**: Integração com RPC Elements/Liquid
- **📋 Configuração INI**: Arquivo de configuração flexível
- **📊 Monitoramento**: Consulta de saldos e status dos nós
- **🔒 Autenticação**: Suporte completo a macaroons e TLS
- **📝 Logging**: Sistema de logs configurável

### Setup e Uso

```bash
# 1. Configurar ambiente Python
./setup_lnd_client.sh

# 2. Ativar ambiente virtual
source lnd_client_env/bin/activate

# 3. Executar cliente
python3 lnd_balance_client_v2.py

# Exemplo de saída:
# ⚡ Lightning Network Daemon (LND) Status
# 🔗 Conectado ao LND: localhost:10009
# 💰 Saldo Lightning: 1,500,000 sats
# ₿  Saldo On-chain: 0.05000000 BTC
# 🔷 Saldo Liquid: 0.02000000 L-BTC
```

### API de Exemplo

```python
from lnd_balance_client_v2 import LNDClient, ConfigManager

# Inicializar cliente
config = ConfigManager()
client = LNDClient(config)

# Conectar e obter informações
client.connect()
info = client.get_node_info()
balance = client.get_wallet_balance()

print(f"Nó: {info.alias}")
print(f"Saldo: {balance.total_balance} sats")
```

### Integração com Systemd

```bash
# Instalar como serviço systemd
cp services/control-systemd.service /etc/systemd/system/
systemctl enable control-systemd
systemctl start control-systemd

# API de controle disponível em localhost:5001
curl http://localhost:5001/service-status?app=lnd
```

## 🎯 Comandos Essenciais

### � Gerenciamento de Containers

```bash
# Navegar para diretório do projeto
cd /root/brln-os/container

# Ver status de todos os serviços
docker-compose ps

# Iniciar todos os serviços
docker-compose up -d

# Parar todos os serviços
docker-compose down

# Reiniciar serviço específico
docker-compose restart <serviço>

# Ver logs em tempo real
docker-compose logs -f <serviço>

# Exemplo: Monitorar logs do Bitcoin
docker-compose logs -f bitcoin

# Exemplo: Reiniciar LND
docker-compose restart lnd
```

### ⚡ Lightning Network (LND) CLI

```bash
# Informações gerais do nó
docker exec lnd lncli getinfo

# Verificar saldo on-chain
docker exec lnd lncli walletbalance

# Verificar saldo em canais Lightning
docker exec lnd lncli channelbalance

# Listar canais ativos
docker exec lnd lncli listchannels

# Backup de canais (IMPORTANTE!)
docker exec lnd lncli exportchanbackup --all

# Gerar novo endereço Bitcoin
docker exec lnd lncli newaddress p2tr

# Pagar invoice Lightning
docker exec lnd lncli payinvoice <invoice>

# Criar invoice
docker exec lnd lncli addinvoice --amt=<sats> --memo="<descrição>"
```

### ₿ Bitcoin Core CLI

```bash
# Informações da blockchain
docker exec bitcoin bitcoin-cli getblockchaininfo

# Verificar saldo da carteira
docker exec bitcoin bitcoin-cli getbalance

# Gerar novo endereço
docker exec bitcoin bitcoin-cli getnewaddress

# Enviar bitcoin
docker exec bitcoin bitcoin-cli sendtoaddress <endereço> <valor>

# Listar transações
docker exec bitcoin bitcoin-cli listtransactions
```

### 🔷 Elements/Liquid CLI

```bash
# Informações do nó Liquid
docker exec elements elements-cli getblockchaininfo

# Verificar saldo L-BTC
docker exec elements elements-cli getbalance

# Enviar L-BTC
docker exec elements elements-cli sendtoaddress <endereço> <valor>

# Listar assets Liquid
docker exec elements elements-cli listissuances
```

### 🔄 PeerSwap CLI

```bash
# Listar peers para swap
docker exec peerswap pscli listpeers

# Swap out (Bitcoin -> Liquid)
docker exec peerswap pscli swapout --peer_id=<peer> --amt=<sats> --asset=lbtc

# Swap in (Liquid -> Bitcoin)  
docker exec peerswap pscli swapin --peer_id=<peer> --amt=<sats> --asset=lbtc

# Listar swaps ativos
docker exec peerswap pscli listswaps
```

### 🐍 Cliente Python

```bash
# Ativar ambiente virtual
source lnd_client_env/bin/activate

# Executar cliente de saldos
python3 lnd_balance_client_v2.py

# Verificar configuração
python3 -c "from lnd_balance_client_v2 import ConfigManager; print(ConfigManager().config)"
```

---

## � Recursos Mobile e Interface

### 🎨 Interface Web Responsiva

O BRLN-OS inclui uma interface web moderna otimizada para todos os dispositivos:

- **📱 Design Responsivo**: Interface adaptável para desktop, tablet e mobile
- **🎵 Player de Rádio Integrado**: BRL Lightning Club Radio diretamente no dashboard
- **🌗 Tema Claro/Escuro**: Alternância automática baseada na preferência do usuário
- **⚡ Controle de Serviços**: Botões diretos para acesso a todas as aplicações
- **🔗 Links Externos**: Acesso rápido a ferramentas essenciais do ecossistema Bitcoin

### 📱 Aplicações Mobile-Ready

| App | Mobile Support | Características |
|-----|----------------|-----------------|
| 💰 **LNbits** | ✅ PWA Completo | App web progressivo, funciona offline |
| ⚡ **Thunderhub** | ✅ Responsivo | Interface otimizada para mobile |
| 📊 **LNDG** | ✅ Adaptável | Dashboards redimensionáveis |
| 🔄 **PeerSwap Web** | ✅ Mobile-First | Interface simplificada para mobile |
| 📈 **Grafana** | ✅ Responsivo | Dashboards adaptativos |

### 🌐 Acesso Remoto via Tor

- **🧅 Hidden Services**: Todos os serviços disponíveis via endereços .onion
- **🔒 Conexão Segura**: Acesso criptografado de qualquer lugar do mundo
- **📱 Mobile Tor**: Use navegadores com suporte Tor (Tor Browser, Orbot)
- **🔐 Sem Exposição de IP**: Mantenha privacidade total

---

## 🏆 Casos de Uso e Exemplos

### 🏢 Para Empresas

```bash
# Setup empresarial com alta disponibilidade
# Configurar múltiplos canais para redundância
docker exec lnd lncli openchannel --node_key=<routing_node> --local_amt=5000000

# Monitor automático de liquidez
python3 lnd_balance_client_v2.py --monitor --alert-threshold=1000000

# Backup automático para múltiplos destinos
./backup-completo.sh && rsync -av /backup/ remote-server:/backup/
```

### 🏠 Para Uso Pessoal

```bash
# Setup básico para HODLers
# Abrir canal com nó de roteamento confiável
docker exec lnd lncli openchannel --node_key=<trusted_node> --local_amt=1000000

# Configurar recebimento Lightning
docker exec lnd lncli addinvoice --amt=50000 --memo="Recebimento teste"

# Monitoramento simples via interface web
# Acesse: http://localhost:8889 (LNDG)
```

### 🔄 Para Trading/Arbitragem

```bash
# Setup para arbitragem Bitcoin/Liquid
# Configurar PeerSwap para swaps automáticos
docker exec peerswap pscli swapout --peer_id=<peer> --amt=100000 --asset=lbtc

# Monitor de preços e oportunidades
python3 -c "
import requests
btc_price = requests.get('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd').json()
print(f'BTC: \${btc_price[\"bitcoin\"][\"usd\"]}')
"
```

### 🏪 Para Merchants

```bash
# Setup para aceitar pagamentos Lightning
# Configurar LNbits com extensões de e-commerce
# Acesse: http://localhost:5000

# Criar carteira para loja
# Via interface LNbits ou API:
curl -X POST http://localhost:5000/api/v1/wallet \
  -H "X-Api-Key: <admin_key>" \
  -d '{"name": "Loja Virtual", "user": "merchant"}'

# Gerar QR code para pagamento
docker exec lnd lncli addinvoice --amt=25000 --memo="Produto XYZ"
```

---

## �🔒 Segurança e Backup

### 🛡️ Medidas de Segurança Implementadas

- **🧅 Tor Integration**: Hidden services para todos os componentes
- **🐳 Container Isolation**: Cada serviço isolado com usuários específicos
- **🔐 TLS/SSL**: Comunicação criptografada entre serviços
- **🔑 Macaroon Auth**: Autenticação baseada em macaroons para LND
- **🛡️ Network Segmentation**: Rede Docker privada para comunicação interna
- **📝 Audit Logs**: Logs centralizados para auditoria de segurança

### � Configurações de Segurança

```bash
# Configurar firewall (recomendado)
ufw enable
ufw allow 22/tcp      # SSH
ufw allow 80/tcp      # Interface web
ufw allow 3000/tcp    # Thunderhub
ufw allow 5000/tcp    # LNbits
ufw allow 8889/tcp    # LNDG

# Configurar Tor hidden services (automático)
# Os endereços .onion são gerados automaticamente

# Verificar integridade dos containers
docker-compose config --quiet && echo "Configuração válida"
```

### 📦 Backup Essencial

#### 1. 🔑 Seed LND (CRÍTICO - FAÇA PRIMEIRO!)
```bash
# A seed é exibida APENAS na primeira inicialização do LND
# ANOTE IMEDIATAMENTE em local seguro offline!

# Formato: 24 palavras em inglês
# Exemplo: abandon ability able about above absent absorb...

# ⚠️ SEM A SEED, VOCÊ PERDE TODOS OS FUNDOS! ⚠️
```

#### 2. ⚡ Backup dos Canais Lightning
```bash
# Exportar backup de todos os canais
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup

# Copiar backup para sistema host
docker cp lnd:/tmp/channels.backup ./backup-canais-$(date +%Y%m%d).backup

# Script automático de backup
cat > backup-lightning.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/lightning/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup
docker cp lnd:/tmp/channels.backup "$BACKUP_DIR/"
echo "Backup realizado em: $BACKUP_DIR"
EOF

chmod +x backup-lightning.sh
```

#### 3. 💾 Backup das Configurações
```bash
# Backup completo das configurações
tar -czf backup-brln-os-$(date +%Y%m%d).tar.gz \
    container/ \
    scripts/.env \
    lnd_client_config.ini \
    --exclude="container/*/data"

# Backup das carteiras Bitcoin e Elements
docker exec bitcoin bitcoin-cli backupwallet /tmp/bitcoin-wallet.backup
docker exec elements elements-cli backupwallet /tmp/elements-wallet.backup

docker cp bitcoin:/tmp/bitcoin-wallet.backup ./backup-bitcoin-$(date +%Y%m%d).backup
docker cp elements:/tmp/elements-wallet.backup ./backup-elements-$(date +%Y%m%d).backup
```

#### 4. 📋 Script de Backup Automatizado
```bash
#!/bin/bash
# Salvar como: backup-completo.sh

BACKUP_ROOT="/backup/brln-os"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$DATE"

mkdir -p "$BACKUP_DIR"

echo "🔄 Iniciando backup completo BRLN-OS..."

# Backup canais Lightning
echo "⚡ Backup canais Lightning..."
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup
docker cp lnd:/tmp/channels.backup "$BACKUP_DIR/"

# Backup carteiras
echo "💰 Backup carteiras..."
docker exec bitcoin bitcoin-cli backupwallet /tmp/bitcoin-wallet.backup 2>/dev/null || true
docker exec elements elements-cli backupwallet /tmp/elements-wallet.backup 2>/dev/null || true
docker cp bitcoin:/tmp/bitcoin-wallet.backup "$BACKUP_DIR/" 2>/dev/null || true
docker cp elements:/tmp/elements-wallet.backup "$BACKUP_DIR/" 2>/dev/null || true

# Backup configurações
echo "⚙️ Backup configurações..."
tar -czf "$BACKUP_DIR/config-backup.tar.gz" container/ scripts/.env lnd_client_config.ini

echo "✅ Backup completo realizado em: $BACKUP_DIR"

# Limpar backups antigos (manter últimos 7 dias)
find "$BACKUP_ROOT" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
```

### 🔄 Rotina de Backup Recomendada

```bash
# Adicionar ao crontab para backup automático
crontab -e

# Backup diário às 3:00 AM
0 3 * * * /root/brln-os/backup-completo.sh

# Backup dos canais a cada 6 horas
0 */6 * * * docker exec lnd lncli exportchanbackup --all --output_file=/backup/channels-$(date +\%Y\%m\%d-\%H\%M).backup
```

## �️ Troubleshooting e Manutenção

### � Diagnóstico de Problemas

#### Container não inicia
```bash
# Verificar logs específicos
docker-compose logs <nome_do_serviço>

# Verificar configuração
docker-compose config

# Recriar container com problema
docker-compose up -d --force-recreate <nome_do_serviço>

# Verificar recursos do sistema
docker system df
free -h
df -h
```

#### Sincronização lenta
```bash
# Verificar progresso Bitcoin Core
docker exec bitcoin bitcoin-cli getblockchaininfo | grep -E "(blocks|headers|verificationprogress)"

# Verificar progresso Elements
docker exec elements elements-cli getblockchaininfo

# Verificar status LND
docker exec lnd lncli getinfo

# Verificar conectividade de rede
docker exec bitcoin bitcoin-cli getnetworkinfo
```

#### Problemas de conectividade
```bash
# Testar conectividade Tor
docker exec tor curl -x socks5h://localhost:9050 https://check.torproject.org

# Verificar peers Bitcoin
docker exec bitcoin bitcoin-cli getpeerinfo | grep -E "(addr|version|subver)"

# Testar conexão LND gRPC
docker exec lnd lncli getinfo

# Verificar certificados LND
docker exec lnd ls -la /data/lnd/
```

### 🔧 Comandos de Manutenção

#### Limpeza do sistema
```bash
# Limpar containers parados
docker container prune -f

# Limpar imagens não utilizadas
docker image prune -f

# Limpar volumes órfãos
docker volume prune -f

# Limpeza completa (CUIDADO!)
docker system prune -a --volumes
```

#### Atualizações
```bash
# Atualizar código do repositório
cd /root/brln-os
git pull origin main

# Reconstruir containers com novas versões
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Verificar versões atuais
docker exec bitcoin bitcoin-cli --version
docker exec lnd lncli --version
docker exec elements elements-cli --version
```

#### Monitoramento de recursos
```bash
# Uso de CPU e memória por container
docker stats --no-stream

# Espaço em disco usado pelos containers
docker system df

# Verificar logs com tamanho
docker system events &
docker-compose logs --tail=100 | grep -i error
```

### ⚡ Troubleshooting Específico

#### LND não conecta
```bash
# Verificar se LND está executando
docker exec lnd lncli getinfo

# Verificar certificados
docker exec lnd ls -la /data/lnd/tls.cert

# Regenerar certificados se necessário
docker-compose restart lnd

# Verificar macaroons
docker exec lnd ls -la /data/lnd/data/chain/bitcoin/mainnet/
```

#### Bitcoin Core sincronização lenta
```bash
# Verificar configuração de dbcache
docker exec bitcoin bitcoin-cli getmemoryinfo

# Verificar conexões de rede
docker exec bitcoin bitcoin-cli getconnectioncount

# Adicionar nós manualmente se necessário
docker exec bitcoin bitcoin-cli addnode "node.address:8333" "add"
```

#### PeerSwap não funciona
```bash
# Verificar status PeerSwap
docker exec peerswap pscli listpeers

# Verificar logs PeerSwap
docker-compose logs peerswap

# Verificar configuração
docker exec peerswap cat /home/peerswap/.peerswap/peerswap.conf
```

### 📊 Monitoramento de Saúde

#### Script de verificação de saúde
```bash
#!/bin/bash
# Salvar como: health-check.sh

echo "🏥 BRLN-OS Health Check"
echo "======================"

# Verificar containers ativos
echo "🐳 Status dos Containers:"
docker-compose ps

echo -e "\n⚡ Status Lightning Network:"
docker exec lnd lncli getinfo 2>/dev/null | grep -E "(alias|synced_to_chain|num_active_channels)" || echo "❌ LND não disponível"

echo -e "\n₿ Status Bitcoin Core:"
docker exec bitcoin bitcoin-cli getblockchaininfo 2>/dev/null | grep -E "(blocks|headers|verificationprogress)" || echo "❌ Bitcoin não disponível"

echo -e "\n🔷 Status Elements:"
docker exec elements elements-cli getblockchaininfo 2>/dev/null | grep -E "(blocks|headers)" || echo "❌ Elements não disponível"

echo -e "\n💾 Uso de Disco:"
df -h /data/ 2>/dev/null || df -h /

echo -e "\n🧠 Uso de Memória:"
free -h

echo -e "\n🔗 Conectividade de Rede:"
curl -s --max-time 5 https://google.com >/dev/null && echo "✅ Internet OK" || echo "❌ Sem internet"

echo -e "\n======================"
echo "Health check completo!"
```

```bash
chmod +x health-check.sh
./health-check.sh
```

---

<div align="center">

**Feito com ⚡ e ❤️ pela comunidade BRLN**

</div>

---

## 🆘 Suporte e Comunidade

- 🎥 [Tutoriais em vídeo](https://www.youtube.com/@brlightningclub)

### Comunidade
- 💬 [Telegram](https://t.me/pagcoinbr)
- 🐦 [Twitter](https://twitter.com/pagcoinbr)
- ✉️ [Suporte por Email](mailto:suporte@pagcoin.org) — Entre em contato diretamente para dúvidas ou suporte!

### Problemas e Bugs
- 🐛 [Reportar bug](https://github.com/pagcoinbr/brln-os/issues)
- 💡 [Sugerir feature](https://github.com/pagcoinbr/brln-os/discussions)
- 🔍 [Buscar soluções](https://github.com/pagcoinbr/brln-os/issues?q=is%3Aissue)

---

## 📝 Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE) - veja o arquivo LICENSE para detalhes.

---

## 🙏 Agradecimentos

- **Bitcoin Core Team** - Pela base sólida do Bitcoin
- **Lightning Labs** - Pelo LND e inovações Lightning
- **Blockstream** - Pelo Elements e Liquid Network
- **Comunidade BRLN** - Pelo suporte e feedback contínuo
- **Contribuidores Open Source** - Por todas as ferramentas e bibliotecas utilizadas

---

## 📚 Referências e Documentação

### Documentação Oficial
- [Bitcoin Core Documentation](https://bitcoin.org/en/developer-documentation)
- [Elements Documentation](https://elementsproject.org/elements-code-tutorial/desktop-application-tutorial)
- [LND Documentation](https://docs.lightning.engineering/)
- [Lightning Network Specifications](https://github.com/lightning/bolts)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PeerSwap Documentation](https://github.com/ElementsProject/peerswap)

### Recursos de Aprendizado
- [Mastering Bitcoin (Andreas Antonopoulos)](https://github.com/bitcoinbook/bitcoinbook)
- [Mastering the Lightning Network](https://github.com/lnbook/lnbook)
- [Elements/Liquid Developer Resources](https://docs.blockstream.com/)
- [Python gRPC Tutorial](https://grpc.io/docs/languages/python/)

### Ferramentas Externas Integradas
- [LNbits](https://lnbits.com) - Sistema bancário Lightning
- [Thunderhub](https://thunderhub.io) - Interface de gerenciamento LND
- [LNDG](https://github.com/cryptosharks131/lndg) - Dashboard Lightning Network
- [Grafana](https://grafana.com) - Plataforma de monitoramento

---

## ⚠️ Aviso Legal

- **Use por sua conta e risco**: Os desenvolvedores não são responsáveis por perdas de fundos
- **Ambiente de teste**: Teste sempre em ambiente testnet antes de usar com fundos reais
- **Backup obrigatório**: Sempre mantenha backups seguros de suas seeds e configurações
- **Mantenha-se atualizado**: Acompanhe atualizações de segurança dos componentes
- **Conhecimento técnico necessário**: Este sistema requer compreensão de Bitcoin e Lightning Network
- **Responsabilidade do usuário**: A segurança dos fundos é responsabilidade exclusiva do usuário

---

**BRLN-OS** - *Empowering the Bitcoin Lightning Network Revolution* ⚡
