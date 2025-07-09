# BR⚡LN Full Auto Container Stack

> **Sistema de containerização completo para Bitcoin, Lightning Network e Liquid Network**

## 🚀 Introdução

O **BRLN Full Auto Container Stack** é uma solução completa em Docker que orquestra múltiplos serviços Bitcoin e Lightning Network de forma automatizada e integrada. O projeto inclui:

### 🏗️ Componentes Principais

#### 1. Bitcoin Core
- Node completo Bitcoin para validação e broadcast de transações
- Sincronização completa da blockchain
- Interface RPC para integração com outros serviços

#### 2. Elements Node (Liquid Network)
O **Elements** é uma implementação do protocolo Liquid Network, uma sidechain do Bitcoin que oferece:
- **Transações mais rápidas**: Confirmações em ~1 minuto
- **Transações confidenciais**: Valores e tipos de ativos são privados
- **Múltiplos ativos**: Suporte para diversos tokens além do L-BTC (DePix, USDT)
- **Federação**: Controlada por uma federação de exchanges e instituições

#### 3. Lightning Network Daemon (LND)
O **LND** é uma implementação do Lightning Network que permite:
- **Pagamentos instantâneos**: Transações off-chain quase instantâneas
- **Micropagamentos**: Taxas muito baixas para pequenos valores
- **Escalabilidade**: Reduz a carga na blockchain principal
- **Canais de pagamento**: Conexões diretas entre nós para transferências

#### 4. Aplicações de Gerenciamento
- **LNbits**: Sistema bancário Lightning Network
- **Thunderhub**: Interface completa para gerenciamento do LND
- **LNDG**: Dashboard e estatísticas avançadas
- **PeerSwap**: Swaps entre Bitcoin on-chain e Liquid
- **Balance of Satoshis**: Ferramentas avançadas para nós Lightning

## 📁 Estrutura do Projeto

```
container/
├── docker-compose.yml           # Orquestração principal dos serviços
├── setup-docker-smartsystem.sh  # Configuração inicial do sistema
├── service.json.example         # Template de configuração de serviços
│
├── bitcoin/                     # Bitcoin Core
│   ├── Dockerfile.bitcoin
│   ├── bitcoin.conf
│   ├── bitcoin.sh
│   └── service.json
│
├── elements/                    # Elements (Liquid Network)
│   ├── Dockerfile.elements
│   ├── elements.conf
│   ├── elements.sh
│   └── service.json
│
├── lnd/                        # Lightning Network Daemon
│   ├── Dockerfile.lnd
│   ├── entrypoint.sh
│   ├── lnd.conf
│   ├── password.txt
│   └── service.json
│
├── lnbits/                     # Sistema bancário LN
│   ├── Dockerfile.lnbits
│   ├── entrypoint.sh
│   └── service.json
│
├── lndg/                       # Dashboard LND
│   ├── Dockerfile.lndg
│   ├── entrypoint.sh
│   └── service.json
│
├── thunderhub/                 # Interface web LND
│   ├── service.json
│   └── thunderhub.sh
│
├── peerswap/                   # Swaps BTC/Liquid
│   ├── Dockerfile.peerswap
│   ├── peerswap.conf
│   └── service.json
│
├── psweb/                      # Interface web PeerSwap
│   ├── Dockerfile.psweb
│   ├── entrypoint.sh
│   └── service.json
│
├── tor/                        # Proxy Tor
│   ├── Dockerfile.tor
│   └── service.json
│
├── monitoring/                 # Monitoramento
│   ├── prometheus.yml
│   ├── loki-config.yml
│   └── dashboards/
│
└── logs/                       # Gestão de logs
    ├── docker-log-manager.sh
    └── install-log-manager.sh
```

## ⚡ Início Rápido

### Pré-requisitos do Sistema

- **Hardware mínimo recomendado**:
  - 4 CPU cores
  - 8 GB RAM
  - Mais de 1Tb de armazenamento SSD (para blockchain completa)
  - Conexão estável com a internet
- **Software**:
  - Docker Engine 20.10+
  - Docker Compose v2.0+
  - Sistema operacional Linux (Ubuntu 24.04+ recomendado)

### � Instalação Simplificada (Recomendado)

```bash
# Clone o repositório
git clone https://github.com/pagcoinbr/brlnfullauto.git
cd brlnfullauto

# Execute a instalação automática
./setup.sh
```

**Ou use o comando alternativo:**
```bash
./install
```

O script de instalação irá:
- ✅ Verificar pré-requisitos (Docker, Docker Compose)
- ✅ Instalar dependências automaticamente se necessário
- ✅ Configurar permissões dos scripts
- ✅ Oferecer opções de instalação (completa ou personalizada)
- ✅ Iniciar todos os serviços do stack

### 🛠️ Instalação Manual (Avançado)

Se preferir controle total sobre o processo:

```bash
# Clone o repositório
git clone https://github.com/pagcoinbr/brlnfullauto.git
cd brlnfullauto/container

# Configure permissões
chmod +x setup-docker-smartsystem.sh

# Execute configuração interativa
./setup-docker-smartsystem.sh
```

### 📊 Portas e Serviços Disponíveis

| Porta | Serviço | Descrição | Acesso |
|-------|---------|-----------|--------|
| 8080 | Bitcoin RPC | API Bitcoin Core | Interno |
| 18884 | Elements RPC | API Elements Core | Interno |
| 10009 | LND gRPC | API Lightning Network | Interno |
| 8889 | LNDG | Dashboard estatísticas LND | http://localhost:8889 |
| 3000 | Thunderhub | Interface completa LND | http://localhost:3000 |
| 5000 | LNbits | Sistema bancário LN | http://localhost:5000 |
| 1984 | PeerSwap Web | Interface PeerSwap | http://localhost:1984 |
| 42069 | PeerSwap | API PeerSwap | Interno |
| 9050 | Tor SOCKS | Proxy Tor | localhost |

## 🛠️ Configuração e Uso

### 🔧 Configuração Inicial

#### 1. Configuração do Bitcoin Core
```bash
# Verificar sincronização
docker exec bitcoin bitcoin-cli getblockchaininfo

# Gerar carteira (se necessário)
docker exec bitcoin bitcoin-cli createwallet "wallet"
```

#### 2. Configuração do Elements (Liquid)
```bash
# Verificar informações da rede Liquid
docker exec elements elements-cli getblockchaininfo

# Verificar assets disponíveis
docker exec elements elements-cli listissuances
```

#### 3. Configuração do LND

O LND está configurado para **criação automática** da carteira na primeira execução:

```bash
# Verificar logs da inicialização
docker logs -f lnd

# Verificar informações do nó
docker exec lnd lncli getinfo

# Verificar saldo da carteira
docker exec lnd lncli walletbalance
```

**⚠️ IMPORTANTE**: Durante a primeira execução, o LND gerará uma seed de 24 palavras que será exibida nos logs. **SALVE ESSA SEED** imediatamente em local seguro!

### 📱 Interfaces Web

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

4. **PeerSwap Web** (http://localhost:1984)
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

#### Monitoramento de Segurança
```bash
# Verificar logs de autenticação
docker-compose logs | grep -i "auth\|login\|fail"

# Verificar conexões ativas
docker exec lnd lncli listpeers
docker exec lnd lncli listchannels
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

#### 3. Problemas de conectividade
```bash
# Testar conectividade de rede
docker exec lnd lncli describegraph | jq '.nodes | length'

# Verificar peers conectados
docker exec lnd lncli listpeers
```

### Atualizações
```bash
# Atualizar imagens
docker-compose pull

# Recrear containers com novas versões
docker-compose up -d --force-recreate

# Limpeza de imagens antigas
docker system prune -a
```

## 📚 Referências e Documentação

- [Bitcoin Core Documentation](https://bitcoin.org/en/developer-documentation)
- [Elements Documentation](https://elementsproject.org/elements-code-tutorial/desktop-application-tutorial)
- [LND Documentation](https://docs.lightning.engineering/)
- [Lightning Network Specifications](https://github.com/lightning/bolts)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PeerSwap Documentation](https://github.com/ElementsProject/peerswap)

## 🤝 Contribuindo

Consulte o arquivo [CONTRIBUTING.md](./CONTRIBUTING.md) para diretrizes sobre:
- Como contribuir com o projeto
- Estrutura de desenvolvimento
- Padrões de código
- Processo de submissão de pull requests

## 📄 Licença

Este projeto está licenciado sob a Licença MIT. Veja o arquivo [LICENSE](./LICENSE) para detalhes.

---

## ⚠️ Aviso Legal

- **Use por sua conta e risco**: Os desenvolvedores não são responsáveis por perdas de fundos
- **Ambiente de teste**: Teste sempre em ambiente testnet antes de usar com fundos reais
- **Backup obrigatório**: Sempre mantenha backups seguros de suas seeds e configurações
- **Mantenha-se atualizado**: Acompanhe atualizações de segurança dos componentes

---

**Nota**: Este sistema é uma ferramenta avançada que requer conhecimento técnico sobre Bitcoin e Lightning Network. Use apenas se você entende os riscos envolvidos.
