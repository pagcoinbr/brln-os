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
curl -fsSL https://pagcoin.org/install.sh | sh
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

## � Estrutura do Projeto

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

## 🚀 Uso

### Primeiros Passos

1. **Aguarde a sincronização**: Bitcoin Core levará algumas horas para sincronizar
2. **Acesse a interface**: Abra `http://localhost:8080` no navegador
3. **Configure sua carteira Lightning**: Use o Thunderhub para criar canais
4. **Comece a usar**: Faça pagamentos Lightning instantâneos!

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

---

## 🆘 Suporte e Comunidade

### Documentação
- 📖 [Wiki completo](https://github.com/pagcoinbr/brln-os/wiki)
- 📋 [FAQ - Perguntas frequentes](https://github.com/pagcoinbr/brln-os/wiki/FAQ)
- 🎥 [Tutoriais em vídeo](https://youtube.com/@pagcoin)

### Comunidade
- 💬 [Telegram](https://t.me/pagcoin)
- 🐦 [Twitter](https://twitter.com/pagcoin)
- 🌐 [Site oficial](https://pagcoin.org)

### Problemas e Bugs
- 🐛 [Reportar bug](https://github.com/pagcoinbr/brln-os/issues)
- 💡 [Sugerir feature](https://github.com/pagcoinbr/brln-os/discussions)
- 🔍 [Buscar soluções](https://github.com/pagcoinbr/brln-os/issues?q=is%3Aissue)

---

## 🤝 Contribuindo

Adoramos contribuições! Veja como você pode ajudar:

1. **🍴 Fork** o repositório
2. **🌿 Crie** uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. **💾 Commit** suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. **📤 Push** para a branch (`git push origin feature/AmazingFeature`)
5. **🔄 Abra** um Pull Request

### Desenvolvimento

Para desenvolvimento local:

```bash
# Clone o repositório
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os

# Instale dependências de desenvolvimento
./dev-setup.sh

# Execute em modo desenvolvimento
./setup.sh --dev
```

---

## 📝 Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE) - veja o arquivo LICENSE para detalhes.

---

## 🙏 Agradecimentos

- **Bitcoin Core Team** - Pela base sólida do Bitcoin
- **Lightning Labs** - Pelo LND e inovações Lightning
- **Blockstream** - Pelo Elements e Liquid Network
- **Comunidade Bitcoin Brasil** - Pelo suporte e feedback contínuo

---

<div align="center">

**Feito com ⚡ e ❤️ pela comunidade Bitcoin Brasil**

[Website](https://pagcoin.org) • [Twitter](https://twitter.com/pagcoin) • [Telegram](https://t.me/pagcoin)

</div>

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

## � Scripts Auxiliares

O projeto inclui vários scripts auxiliares para facilitar o uso e manutenção do sistema:

### 🚀 Scripts Principais

| Script | Descrição | Uso |
|--------|-----------|-----|
| `setup.sh` | Instalação automática completa | `./setup.sh` |
| `extract_passwords.sh` | Extração de senhas dos logs | `./extract_passwords.sh` |
| `monitor_seeds.sh` | Monitor de seeds em tempo real | `./monitor_seeds.sh [monitor\|extract]` |

### 📄 Scripts de Extração de Credenciais

#### extract_passwords.sh
- **Função**: Extrai e documenta todas as senhas e credenciais
- **Saída**: Gera `passwords.md` e `passwords.txt`
- **Uso**: `./extract_passwords.sh [--display-only]`

#### monitor_seeds.sh
- **Função**: Monitora logs em tempo real para capturar seeds
- **Modos**:
  - `monitor`: Monitoramento em tempo real
  - `extract`: Extração de logs existentes
- **Saída**: Gera `seeds_backup.txt`

### 🔧 Scripts de Configuração

#### setup.sh
- **Função**: Instalação automatizada completa
- **Recursos**:
  - Verificação de pré-requisitos
  - Instalação de dependências
  - Configuração de permissões
  - Inicialização de todos os serviços
  - Extração automática de credenciais

Consulte as seções específicas deste README para detalhes sobre cada script.

## �🛠️ Configuração e Uso

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

### 🌱 Monitor de Seeds e Senhas

O projeto inclui o script `monitor_seeds.sh` para capturar automaticamente seeds e senhas geradas durante a instalação:

#### Monitoramento em Tempo Real (Recomendado)
Use este modo **DURANTE** a instalação para capturar seeds conforme são geradas:

```bash
# Terminal 1 - Iniciar monitoramento
./monitor_seeds.sh monitor
# ou apenas
./monitor_seeds.sh

# Terminal 2 - Executar instalação
./setup.sh
```

#### Extração de Seeds dos Logs Existentes
Use este modo **APÓS** a instalação para tentar recuperar seeds dos logs:

```bash
# Extrair seeds dos logs existentes
./monitor_seeds.sh extract
```

#### Ajuda e Instruções
```bash
# Mostrar ajuda completa
./monitor_seeds.sh help
```

#### Arquivos Gerados
- **`seeds_backup.txt`** - Backup das seeds encontradas
- **`/tmp/seed_monitor.log`** - Log do monitoramento (modo monitor)

#### Cenários de Uso

**Cenário 1: Durante a Instalação** (Recomendado)
```bash
# Abrir dois terminais
# Terminal 1:
./monitor_seeds.sh monitor

# Terminal 2:
./setup.sh
```

**Cenário 2: Recuperação Após Instalação**
```bash
# Se você esqueceu de monitorar durante a instalação
./monitor_seeds.sh extract
```

**⚠️ Importante**: 
- O modo `monitor` fica executando até você pressionar Ctrl+C
- É recomendado usar em terminal separado durante a instalação
- As seeds são salvas automaticamente no arquivo `seeds_backup.txt`

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

#### 2. Extração Automática de Senhas e Seeds
O sistema inclui um script para documentar automaticamente todas as senhas e seeds:

```bash
# Extrair todas as senhas dos logs
./extract_passwords.sh

# Apenas exibir senhas (sem gerar arquivos)
./extract_passwords.sh --display-only
```

**Arquivos gerados:**
- **`passwords.md`** - Documentação completa em Markdown
- **`passwords.txt`** - Versão simplificada em texto
- **`startup.md`** - Relatório completo da instalação

**Funcionalidades:**
- ✅ Extrai senhas padrão dos arquivos de configuração
- ✅ Captura senhas geradas automaticamente dos logs
- ✅ Remove códigos de escape ANSI das senhas
- ✅ Documenta URLs de acesso e comandos úteis
- ✅ Opção de autodestruição dos arquivos por segurança

#### 3. Backup dos Canais Lightning
```bash
# Exportar backup de todos os canais
docker exec lnd lncli exportchanbackup --all

# Salvar em arquivo
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup

# Copiar para fora do container
docker cp lnd:/tmp/channels.backup ./channels-backup-$(date +%Y%m%d).backup
```

#### 4. Backup das Configurações
```bash
# Backup completo do diretório de configurações
tar -czf backup-config-$(date +%Y%m%d).tar.gz container/
```

#### 5. Backup das Carteiras
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
