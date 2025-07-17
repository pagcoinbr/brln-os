# ⚡ BRLN-OS

<div align="center">

![BRLN-OS Logo](https://img.shields.io/badge/BRLN--OS-Lightning%20Node-orange?style=for-the-badge&logo=bitcoin&logoColor=white)

**Sistema operacional containerizado completo para Bitcoin, Lightning Network e Liquid Network**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![Lightning](https://img.shields.io/badge/lightning-network-yellow.svg)](https://lightning.network)
[![Bitcoin](https://img.shields.io/badge/bitcoin-core-orange.svg)](https://bitcoincore.org)

</div>

---

## 🚀 Instalação Rápida

Execute este comando simples para instalar o BRLN-OS em seu sistema:

```bash
Em manutenção
```

**É isso!** O BRLN-OS será instalado automaticamente com todos os componentes necessários.

---

## 📖 Sobre o Projeto

O **BRLN-OS** é uma distribuição containerizada que transforma qualquer sistema Linux em um poderoso nó Bitcoin e Lightning Network. Baseado em Docker, oferece uma solução completa e automatizada para executar:

### 🏗️ Componentes Principais

#### ⚡ **Lightning Network**
- **LND**: Daemon Lightning Network para pagamentos instantâneos
- **LNbits**: Sistema bancário Lightning completo
- **Thunderhub**: Interface web moderna para gerenciamento
- **LNDG**: Dashboard avançado com estatísticas detalhadas

#### ₿ **Bitcoin & Liquid**
- **Bitcoin Core**: Nó completo Bitcoin com sincronização total
- **Elements**: Suporte completo ao Liquid Network (sidechain)
- **Electrum Server**: Servidor Electrum para carteiras leves

#### 🔄 **Ferramentas Avançadas**
- **PeerSwap**: Swaps automáticos entre Bitcoin e Liquid
- **Balance of Satoshis**: Ferramentas profissionais para nós Lightning
- **Tor**: Integração completa para privacidade
- **Monitoring**: Prometheus, Grafana e Loki para observabilidade

### ✨ **Principais Características**

- **🎯 Instalação em um comando**: `curl -fsSL https://pagcoin.org/install.sh | sh`
- **🔒 Segurança total**: Isolamento por containers e integração Tor
- **📊 Monitoramento completo**: Dashboards e métricas em tempo real
- **🔧 Configuração automática**: Zero configuração manual necessária
- **🌐 Interface web**: Acesso via navegador a todos os serviços
- **📱 Mobile ready**: Interfaces otimizadas para dispositivos móveis
- **🔄 Auto-updates**: Atualizações automáticas dos componentes

---

## 🛠️ Instalação Manual

Se preferir instalar manualmente ou quiser mais controle sobre o processo:

### Pré-requisitos

- **Sistema**: Linux (Ubuntu 20.04+ recomendado)
- **RAM**: Mínimo 4GB (8GB+ recomendado)
- **Armazenamento**: 1TB+ (SSD recomendado para Bitcoin Core)
- **Docker**: Será instalado automaticamente se não presente

### Processo Manual

```bash
# 1. Clone o repositório
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os

# 2. Execute o script de configuração
./setup.sh
```

---

## 🏗️ Estrutura do Projeto

```
brln-os/
├── 📄 install.sh                 # Script de instalação rápida
├── ⚙️  setup.sh                  # Configuração principal do sistema
│
└── container/                    # Stack de containers
    ├── 🐳 docker-compose.yml     # Orquestração dos serviços
    │
    ├── ₿ bitcoin/                # Bitcoin Core
    ├── ⚡ lnd/                   # Lightning Network Daemon  
    ├── 🔷 elements/              # Liquid Network (Elements)
    ├── 💰 lnbits/                # Sistema bancário Lightning
    ├── 🌩️  thunderhub/           # Interface web LND
    ├── 📊 lndg/                  # Dashboard Lightning
    ├── 🔄 peerswap/              # Swaps BTC/Liquid
    ├── 🌐 psweb/                 # Interface PeerSwap
    ├── 🧅 tor/                   # Proxy Tor
    ├── 📈 monitoring/            # Prometheus & Grafana
    └── 🎨 graphics/              # Interface gráfica web
```

---

## 🌐 Acesso aos Serviços

Após a instalação, os serviços estarão disponíveis através das seguintes URLs:

| Serviço | URL | Descrição |
|---------|-----|-----------|
| 🎨 **Interface Principal** | `http://localhost:8080` | Dashboard principal do sistema |
| ⚡ **Thunderhub** | `http://localhost:3000` | Gerenciamento avançado LND |
| 💰 **LNbits** | `http://localhost:5000` | Sistema bancário Lightning |
| 📊 **LNDG** | `http://localhost:8889` | Dashboard e estatísticas LND |
| 🔄 **PeerSwap Web** | `http://localhost:8081` | Interface PeerSwap |
| 📈 **Grafana** | `http://localhost:3030` | Monitoramento e métricas |
| 📋 **Logs** | `http://localhost:8888` | Visualização de logs |

---

## 🔧 Configuração

### Configuração Automática

O BRLN-OS configura automaticamente:
- ✅ Endereços Tor para todos os serviços
- ✅ Conexões seguras entre componentes  
- ✅ Carteiras e senhas do Lightning
- ✅ Configurações otimizadas do Bitcoin Core
- ✅ Integração completa Bitcoin ↔ Lightning ↔ Liquid

### Personalização

Para personalizar configurações específicas, edite os arquivos em:
- `container/bitcoin/bitcoin.conf` - Configurações Bitcoin Core
- `container/lnd/lnd.conf` - Configurações Lightning Network
- `container/elements/elements.conf` - Configurações Liquid Network

---

### Comandos Úteis

```bash
# Ver status dos containers
docker-compose ps

# Ver logs de um serviço específico
docker-compose logs -f bitcoin

# Parar todos os serviços
docker-compose down

# Reiniciar um serviço específico
docker-compose restart lnd

# Backup da carteira Lightning
docker-compose exec lnd lncli exportchanbackup
```

---

## 📱 Recursos Mobile

O BRLN-OS inclui interfaces otimizadas para dispositivos móveis:

- **📱 LNbits Mobile**: App web progressivo para pagamentos Lightning
- **📊 Dashboard Mobile**: Interface responsiva para monitoramento
- **🔗 Conexão remota**: Acesse seu nó de qualquer lugar via Tor

---

## 🔒 Segurança

### Características de Segurança

- **🧅 Tor integrado**: Todos os serviços disponíveis via Tor hidden services
- **🐳 Isolamento**: Cada componente roda em container isolado
- **🔐 Criptografia**: Comunicação criptografada entre serviços
- **🔑 Gerenciamento de chaves**: Armazenamento seguro de chaves privadas

### Boas Práticas

- 💾 **Faça backup regular** da carteira Lightning
- 🔄 **Mantenha o sistema atualizado** executando `./setup.sh` periodicamente
- 🛡️ **Use firewall** para limitar acesso externo se necessário
- 📱 **Monitore o sistema** através dos dashboards disponíveis


Após a inicialização completa, você pode acessar:

1. **LNDG Dashboard** (http://localhost:8889)
   - Estatísticas completas do seu nó LND
   - Gestão de canais e peers
   - Análise de fees e roteamento

2. **Thunderhub** (http://localhost:3000)
   - Interface completa para gerenciamento do LND
   - Controle de canais, transações e configurações

3. **LNbits** (http://localhost:5000)
   - Sistema bancário Lightning Network
   - Criação de carteiras e aplicações

4. **PeerSwap Web** (http://localhost:8081)
   - Interface para swaps entre Bitcoin e Liquid
   - Gerenciamento de liquidez entre redes

## 📋 Guia de Comandos

### 🟠 Bitcoin Core CLI

#### Comandos básicos de verificação
```bash
# Verificar informações da blockchain
docker exec bitcoin bitcoin-cli getblockchaininfo

# Verificar saldo da carteira
docker exec bitcoin bitcoin-cli getbalance

# Gerar novo endereço
docker exec bitcoin bitcoin-cli getnewaddress

# Listar transações
docker exec bitcoin bitcoin-cli listtransactions

# Enviar bitcoin
docker exec bitcoin bitcoin-cli sendtoaddress <endereco> <valor>
```

### 💧 Elements (Liquid) CLI

#### Comandos básicos
```bash
# Verificar informações do nó Liquid
docker exec elements elements-cli getblockchaininfo

# Verificar saldo (por asset)
docker exec elements elements-cli getbalance

# Gerar novo endereço Liquid
docker exec elements elements-cli getnewaddress

# Listar assets disponíveis
docker exec elements elements-cli listissuances
```

#### Transações com assets específicos
```bash
# Enviar L-BTC (Bitcoin na Liquid)
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false false false "bitcoin"

# Assets conhecidos na Liquid:
# DePix: 02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189
# USDT: ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2

# Enviar DePix
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false 1 "UNSET" false 02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189

# Enviar USDT
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false 1 "UNSET" false ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2
```

### ⚡ Lightning Network (LND) CLI

#### Informações do nó
```bash
# Informações gerais do nó LND
docker exec lnd lncli getinfo

# Verificar saldo on-chain
docker exec lnd lncli walletbalance

# Verificar saldo em canais
docker exec lnd lncli channelbalance

# Listar canais ativos
docker exec lnd lncli listchannels
```

#### Transações on-chain
```bash
# Gerar endereço bitcoin
docker exec lnd lncli newaddress p2tr

# Enviar bitcoin on-chain
docker exec lnd lncli sendcoins --addr=<endereco> --amt=<sats>

# Enviar com taxa específica
docker exec lnd lncli sendcoins --addr=<endereco> --amt=<sats> --sat_per_vbyte=<taxa>

# Listar transações on-chain
docker exec lnd lncli listchaintxns
```

#### Gestão de canais Lightning
```bash
# Conectar a um peer
docker exec lnd lncli connect <pubkey>@<host>:<porta>

# Abrir canal
docker exec lnd lncli openchannel --node_key=<pubkey> --local_amt=<sats>

# Listar peers conectados
docker exec lnd lncli listpeers

# Fechar canal
docker exec lnd lncli closechannel <funding_txid> <output_index>
```

#### Pagamentos Lightning
```bash
# Decodificar invoice
docker exec lnd lncli decodepayreq <invoice>

# Pagar invoice
docker exec lnd lncli payinvoice <invoice>

# Criar invoice
docker exec lnd lncli addinvoice --amt=<sats> --memo="<descricao>"

# Listar invoices
docker exec lnd lncli listinvoices
```

### 🔄 PeerSwap CLI

```bash
# Listar peers disponíveis para swap
docker exec peerswap pscli listpeers

# Iniciar swap out (Bitcoin -> Liquid)
docker exec peerswap pscli swapout --peer_id=<peer> --channel_id=<channel> --amt=<sats> --asset=lbtc

# Iniciar swap in (Liquid -> Bitcoin)
docker exec peerswap pscli swapin --peer_id=<peer> --channel_id=<channel> --amt=<sats> --asset=lbtc

# Listar swaps ativos
docker exec peerswap pscli listswaps
```

## 🚨 Monitoramento e Logs

### Verificar status dos containers
```bash
# Status de todos os serviços
docker-compose ps

# Logs de um serviço específico
docker-compose logs -f <nome_do_servico>

# Logs dos últimos 50 linhas
docker-compose logs --tail=50 <nome_do_servico>
```

### Monitoramento via Web

- **Prometheus**: Métricas dos containers (interno)
- **Grafana**: Dashboard de monitoramento (opcional)
- **Loki**: Agregação de logs (opcional)

### Verificar saúde dos serviços
```bash
# Verificar se todos os serviços estão saudáveis
docker-compose ps --filter "health=healthy"

# Verificar logs de erro
docker-compose logs --tail=100 | grep -i error
```

## 🔒 Segurança e Backup

### 🛡️ Medidas de Segurança

- **Firewall**: Configure apenas portas necessárias
- **Acesso limitado**: Use apenas interfaces locais por padrão
- **Tor**: Proxies configurados para comunicação anônima
- **Senhas fortes**: Altere senhas padrão imediatamente
- **Atualizações**: Mantenha containers sempre atualizados

### 📦 Backup Essencial

#### 1. Backup da Seed LND (CRÍTICO)
```bash
# A seed é exibida durante a primeira inicialização
# SALVE IMEDIATAMENTE em local seguro offline!

# Formato da seed:
# 24 palavras em inglês separadas por espaços
# Exemplo: abandon ability able about above absent absorb abstract...
```

#### 2. Backup dos Canais Lightning
```bash
# Exportar backup de todos os canais
docker exec lnd lncli exportchanbackup --all

# Salvar em arquivo
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup

# Copiar para fora do container
docker cp lnd:/tmp/channels.backup ./channels-backup-$(date +%Y%m%d).backup
```

#### 3. Backup das Configurações
```bash
# Backup completo do diretório de configurações
tar -czf backup-config-$(date +%Y%m%d).tar.gz container/
```

#### 4. Backup das Carteiras
```bash
# Backup da carteira Bitcoin
docker exec bitcoin bitcoin-cli backupwallet /tmp/bitcoin-wallet.backup
docker cp bitcoin:/tmp/bitcoin-wallet.backup ./

# Backup da carteira Elements
docker exec elements elements-cli backupwallet /tmp/elements-wallet.backup
docker cp elements:/tmp/elements-wallet.backup ./
```

### 🔐 Rotinas de Segurança

#### Script de Backup Automático
```bash
#!/bin/bash
# Salvar como backup-routine.sh

BACKUP_DIR="/home/admin/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup dos canais LND
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup
docker cp lnd:/tmp/channels.backup "$BACKUP_DIR/"

# Backup das configurações
tar -czf "$BACKUP_DIR/config-backup.tar.gz" container/

echo "Backup realizado em: $BACKUP_DIR"
```

## 🛠️ Manutenção e Troubleshooting

### Problemas Comuns

#### 1. Container não inicia
```bash
# Verificar logs específicos
docker-compose logs <nome_do_servico>

# Verificar configuração
docker-compose config

# Recriar container
docker-compose up -d --force-recreate <nome_do_servico>
```

#### 2. Sincronização lenta
```bash
# Verificar progresso Bitcoin
docker exec bitcoin bitcoin-cli getblockchaininfo

# Verificar progresso Elements
docker exec elements elements-cli getblockchaininfo

# Verificar progresso LND
docker exec lnd lncli getinfo
```

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

---

## 📚 Referências e Documentação

- [Bitcoin Core Documentation](https://bitcoin.org/en/developer-documentation)
- [Elements Documentation](https://elementsproject.org/elements-code-tutorial/desktop-application-tutorial)
- [LND Documentation](https://docs.lightning.engineering/)
- [Lightning Network Specifications](https://github.com/lightning/bolts)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PeerSwap Documentation](https://github.com/ElementsProject/peerswap)

---

## ⚠️ Aviso Legal

- **Use por sua conta e risco**: Os desenvolvedores não são responsáveis por perdas de fundos
- **Ambiente de teste**: Teste sempre em ambiente testnet antes de usar com fundos reais
- **Backup obrigatório**: Sempre mantenha backups seguros de suas seeds e configurações
- **Mantenha-se atualizado**: Acompanhe atualizações de segurança dos componentes

---

**Nota**: Este sistema é uma ferramenta avançada que requer conhecimento técnico sobre Bitcoin e Lightning Network. Use apenas se você entende os riscos envolvidos.
