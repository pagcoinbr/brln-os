# ⚡ BRLN-OS

<div align="center">

![BRLN-OS Logo](https://img.shields.io/badge/BRLN--OS-Lightning%20Node-orange?style=for-the-badge&logo=bitcoin&logoColor=white)

**Sistema operacional containerizado completo para Bitcoin, Lightning Network e Liquid Network**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://docker.com)
[![Lightning](https://img.shields.io/badge/lightning-network-yellow.svg)](https://lightning.network)
[![Bitcoin](https://img.shields.io/badge/bitcoin-core-orange.svg)](https://bitcoincore.org)
[![JavaScript](https://img.shields.io/badge/javascript-gRPC%20server-yellow.svg)](https://nodejs.org)
[![Elements](https://img.shields.io/badge/elements-liquid%20network-green.svg)](https://elementsproject.org)

*Uma plataforma completa de nó Bitcoin, Lightning e Liquid Network com interface web integrada, servidor JavaScript gRPC e suporte a PeerSwap*

</div>

---

## 🚀 Instalação Rápida

**⚠️ IMPORTANTE: Sempre inicie como root**

```bash
# 1. PRIMEIRO: Acesse o super uruário "root"
sudo su

# 2. OPÇÃO A: Instalação automática via script
curl -fsSL https://pagcoin.org/start.sh | bash ###EM MANUTENÇÃO###

# OU OPÇÃO B: Instalação manual
sudo su -c "git clone https://github.com/pagcoinbr/brln-os.git /root/brln-os && cd /root/brln-os && bash run.sh"

# 3. Após a instalação inicial, você verá um qr code para acessar sua rede tailscale (VPN), caso não queira utilizar, acesse a interface web (http://SEU_IP ou http://localhost) e finalize a configuração do node:
# - Clique no botão "⚡ BRLN Node Manager" 
# - Siga o passo a passo na interface gráfica para:
#   • Configurar rede (mainnet/testnet) 
#   • Instalar os aplicativos de administração.
```

**É isso!** O BRLN-OS será instalado com todos os componentes necessários e você poderá configurar tudo através da interface web moderna.

---

## 📖 Sobre o Projeto

O **BRLN-OS** é uma distribuição containerizada que transforma qualquer sistema Linux (Ubuntu recomendado) em um poderoso nó Bitcoin, Lightning e Elements Network. Baseado em Docker Compose, oferece uma solução completa e automatizada para executar um stack completo de serviços Bitcoin, incluindo interface web moderna, servidor JavaScript gRPC para monitoramento.

### 🏗️ Arquitetura do Stack

- **LND v0.18.5**: Daemon Lightning Network com suporte completo a gRPC.
- **LNbits 1.0**: Sistema bancário Lightning web-based com múltiplas extensões.
- **Thunderhub**: Interface web moderna para gerenciamento do LND.
- **LNDG**: Dashboard com estatísticas detalhadas e análise de canais.
- **BRLN-RPC-Server**: Servidor JavaScript gRPC para automação e integração programática.
- **Bitcoin Core v28.1**: Full Node Bitcoin com ZMQ, I2P e Tor.
- **Elements v23.2.7**: Suporte completo ao Liquid Network (sidechain do Bitcoin).
- **PeerSwap v4.0**: Ferramenta para swaps BTC ↔ Liquid com seus pares na LN.
- **Interface Web Integrada**: Dashboard unificado com rádio player e controle de serviços
- **BRLN-RPC-Server**: Servidor JavaScript para gerenciamento e monitoramento de serviços via API ou Interface web.
- **Scripts de Automação**: Ferramentas para instalação, configuração e manutenção (Script Shell)

#### 🛡️ **Segurança e Privacidade**
- **Tor & I2P Integration**: Proxy Tor para os serviços, .
- **Container Isolation**: Cada serviço isolado em container próprio.
- **Network Security**: Rede Docker privada para comunicação entre serviços de forma segura.

### ✨ **Principais Características**

- **🎯 Instalação Zero-Config**: Um comando instala e configura tudo automaticamente.
- **🐳 Arquitetura Containerizada**: Isolamento completo com Docker Compose.
- **🔒 Segurança Máxima**: Integração Tor, isolamento de rede e criptografia.
- **🖥️ Interface Web Moderna**: Dashboard responsivo com controle total dos serviços.
- **⚡ Servidor JavaScript gRPC**: API programática para LND e Elements.
- **🔄 Updates**: Sistema de atualizações manuais dos componentes, impedindo atualizações automáticas, permitindo o usuário decidir entre atualizar ou não uma ferramenta.
- **📱 Mobile Friendly**: Interfaces otimizadas para dispositivos móveis.
- **⚡ PeerSwap Ready**: Troque liquidez entre Bitcoin e Liquid Network com menos custos.

---

## 🏗️ Arquitetura do Projeto

```
brln-os/
├── 📄 run.sh                     # Script principal de instalação
├── 📄 brunel.sh                  # Setup avançado e configuração GUI
├── ⚡ brln-rpc-server/           # Servidor JavaScript gRPC
│   ├── server.js                # Servidor principal multi-chain
│   ├── package.json             # Dependências Node.js
│   ├── config/config.json       # Configurações do servidor
│   └── src/                     # Módulos JavaScript
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
│   └── cgi-bin/                 # Scripts CGI (Shell Script)
│
├── 📁 scripts/                  # Scripts de automação
│   ├── .env.example             # Variáveis de ambiente
│   ├── install-*.sh             # Scripts de instalação individuais
│   ├── command-central.sh       # Centro de comandos
│   └── generate-services.sh     # Gerador de serviços systemd
│
└── 📁 local_apps/               # Aplicações locais
    └── gotty/                   # Terminal web em Go (GoTTY)
```  
## 🌐 Painel de Controle Web

O BRLN-OS inclui uma interface web para controle completo do sistema:

### 🎨 Interface Principal
- **Dashboard Unificado**: Controle de todos os serviços em uma única tela
- **Player de Rádio**: Rádio BRL Lightning Club integrado
- **Tema Claro/Escuro**: Alternância de temas para o dia e a noite.
- **Design Responsivo**: Otimizado para desktop e mobile

### 🔗 Acesso aos Serviços

Após a instalação, os serviços estarão disponíveis através das seguintes URLs:

| Serviço | URL | Porta | Descrição |
|---------|-----|-------|-----------|
| 🎨 **Interface Principal** | `http://localhost/` | 80 | Dashboard principal BRLN-OS |
| ⚡ **Thunderhub** | `http://localhost:3000` | 3000 | Gerenciamento avançado LND |
| 💰 **LNbits** | `http://localhost:5000` | 5000 | Sistema bancário Lightning |
| 📊 **LNDG** | `http://localhost:8889` | 8889 | Dashboard e estatísticas LND |
| 🔄 **PeerSwap Web** | `http://localhost:4000` | 4000 | Interface PeerSwap |
| 📈 **Grafana** | `http://localhost:3010` | 3010 | Monitoramento e métricas |
| 🖥️ **BRLN Node Manager** | `http://localhost:3131` | 3131 | Terminal configuração via GoTTY |

### 🔧 APIs e Conectividade

| Protocolo | Endpoint | Porta | Finalidade |
|-----------|----------|-------|-----------|
| ⚡ **LND gRPC** | `localhost:10009` | 10009 | API gRPC Lightning Network |
| 🌐 **LND REST** | `http://localhost:8080` | 8080 | API REST Lightning Network |
| ₿ **Bitcoin RPC** | `localhost:8332` | 8332 | RPC Bitcoin Core |
| 🔷 **Elements RPC** | `localhost:18884` | 18884 | RPC Liquid Network |
| 🔄 **PeerSwap** | `localhost:42069` | 42069 | API PeerSwap |
| 🧅 **Tor SOCKS** | `localhost:9050` | 9050 | Proxy Tor |
| ⚙️ **BRLN-RPC-Server** | `localhost:5003` | 5003 | API JavaScript multi-chain |

### 🔮 Recursos Futuros

- **🔌 Electrum Server**: Suporte planejado para conexão com hardware wallets Bitcoin e Liquid Network.
- **📱 Mobile Apps**: Interface otimizada para iOS e Android

---

## 🔧 Configuração e Personalização

### Configuração Automática

O BRLN-OS configura automaticamente:
- ✅ Certificados TLS e autenticação macaroon para LND
- ✅ Conexões seguras entre componentes Docker
- ✅ Configurações otimizadas do Bitcoin em todas as suas redes
- ✅ Integração completa Bitcoin ↔ Lightning ↔ Liquid, permitindo maior flexibilidade
- ✅ Setup automático do PeerSwap para liquidez
- ✅ Servidor JavaScript gRPC configurado com arquivo .proto (Original Lightning Labs)
- ✅ Interface web com controle de serviços (Exclusivo do BRLN-OS)

### Personalização Avançada

Para personalizar configurações específicas o botão de *"Configurações"* na tela principal da interface gráfica.

## ⚡ BRLN-RPC-Server JavaScript

O BRLN-OS inclui um servidor JavaScript avançado para automação e integração:

### Características do Servidor

- **🔌 Conectividade gRPC**: Conexão direta com LND via gRPC
- **🔷 Suporte Elements**: Integração com RPC Elements/Liquid
- **📋 Configuração JSON**: Arquivo de configuração flexível e de simples configuração
- **📊 Monitoramento**: Consulta de saldos e status dos serbiços do servidor
- **🔒 Autenticação**: Suporte completo a macaroons e TLS
- **🌐 API REST**: Endpoints para controle e consulta

### Principais Endpoints da API RPC

```bash
# Status de saúde do servidor
GET /health

# Saldos das carteiras (incluindo todos os assets Elements)
GET /wallet-balances

# Status de serviços Docker
GET /service-status?app=lnd

# Controle de serviços (start/stop)
POST /toggle-service?app=lnd

# Endpoint específico para rádio da interface web
GET /status_novidade
```

### Exemplo de Uso da API

```javascript
// Consultar saldos de todas as carteiras
const response = await fetch('http://localhost:5003/wallet-balances');
const data = await response.json();

console.log('Lightning:', data.lightning);
console.log('Bitcoin:', data.bitcoin);
console.log('Elements:', data.elements); // Mostra todos os saldos nas 3 redes

// Controlar serviços
await fetch('http://localhost:5003/toggle-service?app=lnd', {
  method: 'POST'
});
```
```

### Integração com Systemd

```bash
# Verificar status do serviço
systemctl status brln-rpc-server

# Ver logs do servidor
journalctl -u brln-rpc-server -f

# Reiniciar servidor
systemctl restart brln-rpc-server

# API de controle disponível em localhost:5003
curl http://localhost:5003/health
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
docker-compose down -v

# Reiniciar serviço específico
docker-compose restart <serviço>

# Ver logs em tempo real
docker-compose logs -f <serviço>

# Exemplo: Monitorar logs do Bitcoin
docker-compose logs -f bitcoin

# Exemplo: Reiniciar LND
docker-compose restart lnd

# Parar um serviço específico
docker stop <serviço>

# Remover um volume específico (Não causa perda de dados críticos)
docker rm -sf <serviço> 
ou
docker-compose rm -sf <serviço>
```
*Todos os comandos que usam "docker-compose" precisam executados dentro do diretório /root/brln-os/container.*

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

# Gerar novo endereço liquid
docekr exec elements elements-cli getnewaddress
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

### ⚡ BRLN-RPC-Server API

```bash
# Verificar status do BRLN-RPC-Server
systemctl status brln-rpc-server

# Ver logs do servidor JavaScript
journalctl -fu brln-rpc-server

# Testar conectividade da API
curl http://localhost:5003/health

# Consultar saldos de todas as carteiras
curl http://localhost:5003/wallet-balances

# Verificar status de serviços
curl http://localhost:5003/service-status?app=lnd
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

### 🌐 Acesso Remoto via Tor e Tailscale VPN

- **🧅 Hidden Services**: Todos os serviços disponíveis via endereços .onion (configuração adicional necessária)
- **🔒 Conexão Segura**: Acesso criptografado de qualquer lugar do mundo com IP tailnet ou endereço .onion
- **🔐 Sem Exposição de IP**: Mantenha privacidade e segurança total

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
# Configurar firewall é recomendado para acesso à rede local, já que para maior segurança o acesso a todos os serviços vem com sua conexão bloqueada, sendo liberado apenas a porta 22 (SSH) para recuperação emergencial.
ufw enable
ufw allow 80/tcp      # Interface web
ufw allow 3000/tcp    # Thunderhub
ufw allow 5000/tcp    # LNbits
ufw allow 8889/tcp    # LNDG
```

### 📦 Backup Essencial

#### 1. 🔑 Seed LND + Elements (CRÍTICO - FAÇA PRIMEIRO!)
```bash
# A seed é exibida na primeira inicialização do LND
# ANOTE IMEDIATAMENTE em local seguro offline!

# Formato: 24 palavras em inglês
# Exemplo: abandon ability able about above absent absorb...

# Para mitigação de riscos, recomendamos utilizar o mecanismo de autodestruição do arquivo temporário seed.txt durante a instalação, assim evitando armazenamento digital da seed do seu node.

# ⚠️ SEM A SEED, VOCÊ PERDE TODOS OS FUNDOS! ⚠️

# ATENÇÃO!!! Como o node Elements (Liquid Node) não trabalha com o padrão de seed para recuperação da carteira, a forma mais recomendada de backup é fazer um processo de backup automático do arquivo /data/elements/liquidv1/wallets/peerswap/wallet.dat -> Segundo os próprios devs do elements, é necessário realizar o backup após cada transação.
```

#### 2. ⚡ Backup dos Canais Lightning
```bash
# Exportar backup de todos os canais
docker exec lnd lncli exportchanbackup --all --output_file=/tmp/channels.backup

# Copiar backup para sistema host
docker cp lnd:/tmp/channels.backup ./backup-canais-$(date +%Y%m%d).backup
```
Ou você pode optar por solicitar o arquivo de backup para o Balance of Satoshis bot no telegram.

## �️ Troubleshooting e Manutenção

### � Diagnóstico de Problemas

#### Comandos úteis para diagnóstico docker
```bash
# Verificar logs gerais
docker-compose logs

# Verificar logs específicos
docker logs <container>

# Erro ao recriar container
docker rm -sf <container>
docker-compose up -d <container>

# Verificar recursos do sistema
docker system df
# Ou alternativamente
df -h
```

#### Acompanhar Sincronização
```bash
# Verificar progresso Bitcoin Core
docker exec bitcoin bitcoin-cli getblockchaininfo | grep -E "(blocks|headers|verificationprogress)"

# Verificar progresso Elements
docker exec elements elements-cli getblockchaininfo

# Verificar status LND 
docker exec lnd lncli getinfo | grep graph

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

Caso esteja conectado à lnd testnet e receba o erro

```bash
root@brlnbolt:~/brln-os# docker exec lnd lncli getinfo 
[lncli] could not load global options: unable to read macaroon path (check the network setting!): open /home/lnd/.lnd/data/chain/bitcoin/mainnet/admin.macaroon: no such file or directory
```
Na testnet é necessário indicar o arquivo macaron:

```bash
docker exec lnd lncli --macaroonpath=/home/lnd/.lnd/data/chain/bitcoin/testnet/admin.macaroon getinfo 
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
