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

Execute o comando:

```bash
sudo su
```

Para instalar a versão 2.0-alfa: (EM DESENVOLVIMENTO)
```bash
passwd root && cd && git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash run.sh
```

Para instalar a vesão 1.0-alfa: (FUNCIONAL)
```bash
passwd root && cd && git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && git switch brlnfullauto && bash run.sh
```
```
# Após a instalação inicial, você verá um qr code para acessar sua rede tailscale (VPN), caso não queira utilizar, acesse a interface web (http://SEU_IP ou http://localhost) e finalize a configuração do node:
# - Clique no botão "⚡ BRLN Node Manager" 
# - Siga o passo a passo na interface gráfica para:
#   • Configurar rede (mainnet/testnet) 
#   • Instalar os aplicativos de administração.
#
# Digite a nova senha do Super usuário (root), para continuar:
```

**É isso!** O BRLN-OS será instalado com todos os componentes necessários e você poderá configurar tudo através da interface web moderna.

---

## 🔧 Instalação Manual com Podman

Para quem preferir uma instalação manual com podman e controle total sobre os componentes:

### 🚀 Início Rápido

```bash
# Clone o repositório e execute o script de início rápido
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os/container/nodes
sudo ./start-brln.sh
```

O script `start-brln.sh` executará automaticamente:
1. Configuração de permissões
2. Criação de arquivos de configuração
3. Inicialização de todos os serviços

### 📋 Instalação Passo a Passo

### 1. Pré-requisitos

```bash
# Instale o podman e podman-compose
sudo apt update && sudo apt install -y podman podman-compose

# Clone o repositório
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os/container/nodes
```

### 2. Configuração de Permissões (CRÍTICO)

As aplicações precisam de diretórios persistentes com permissões específicas.

**Opção A: Script Automático (Recomendado)**

```bash
# Execute o script de configuração de permissões
sudo ./setup-permissions.sh
```

**Opção B: Configuração Manual**

```bash
# Crie os diretórios de dados
sudo mkdir -p /data/{elements,lnd}

# Configure ownership para os UIDs dos containers
sudo chown 1001:1001 /data/elements  # Elements daemon
sudo chown 1008:1008 /data/lnd        # LND daemon

# Configure permissões (777 temporariamente para Elements devido a bug no container)
sudo chmod -R 777 /data/elements
sudo chmod -R 755 /data/lnd
```

**⚠️ NOTA DE SEGURANÇA**: As permissões 777 para Elements são necessárias devido a um bug no script de inicialização do container que tenta criar arquivos temporários. Em produção, considere usar volumes do podman ou corrigir o script do container.

### 3. Configuração dos Arquivos

```bash
# Os arquivos de configuração serão criados automaticamente pelo script setup-permissions.sh
# Ou você pode copiá-los manualmente:
cp bitcoin/bitcoin.conf.example bitcoin/bitcoin.conf
cp elements/elements.conf.example elements/elements.conf  
cp lnd/lnd.conf.example lnd/lnd.conf
```

### 4. Configuração para Bitcoin Remoto (Opcional)

Se você quiser usar um Bitcoin Core remoto em vez do local:

```bash
# Edite elements/elements.conf para apontar para seu nó Bitcoin
# Substitua as linhas do mainchain:
mainchainrpchost=bitcoin.br-ln.com
mainchainrpcport=8085
mainchainrpcuser=seu_usuario
mainchainrpcpassword=sua_senha
```

### 5. Inicialização dos Serviços

```bash
# Inicie todos os serviços
podman-compose up -d

# Verifique o status
podman-compose ps

# Acompanhe os logs
podman-compose logs -f
```

### 6. Dados Persistentes

Os seguintes dados são persistidos no host:

- **`/data/elements/`**: Blockchain do Liquid Network, configurações do Elements
- **`/data/lnd/`**: Wallet Lightning, canais, macaroons, certificados TLS
- **`nodes_bitcoin_data`**: Volume do Bitcoin Core (se usando local)
- **`nodes_tor_data`**: Configurações e chaves do Tor

### 7. Portas Expostas

- **8085**: Bitcoin Core RPC (se local)
- **7041**: Elements RPC
- **9735**: LND P2P (Lightning Network)
- **28332-28333**: Bitcoin ZMQ (para LND)

### 8. Verificação da Instalação

```bash
# Teste conexão com Elements
podman exec -it elementsd elements-cli getblockchaininfo

# Teste LND (após sincronização)
podman exec -it lnd lncli getinfo

# Verifique logs detalhados
podman logs elementsd
podman logs lnd
```

### 🛠️ Scripts Disponíveis

- **`setup-permissions.sh`**: Configura permissões e diretórios necessários
- **`start-brln.sh`**: Script completo que configura e inicia todos os serviços
- **`docker-compose.yml`**: Configuração dos contêineres

### 🔄 Comandos Úteis

```bash
# Parar todos os serviços
podman-compose down

# Reiniciar um serviço específico
podman-compose restart [service_name]

# Ver logs em tempo real
podman-compose logs -f [service_name]

# Executar comandos dentro dos contêineres
podman exec -it bitcoind bitcoin-cli getinfo
podman exec -it elementsd elements-cli getinfo
podman exec -it lnd lncli getinfo
```

### 🚨 Solução de Problemas Comuns

#### Bitcoin Container Error: "Device or resource busy"

**Problema**: O container do Bitcoin falha ao iniciar com erro "sed: can't move '/home/bitcoin/.bitcoin/bitcoin.conf.tmp' to '/home/bitcoin/.bitcoin/bitcoin.conf': Device or resource busy"

**Causa**: O arquivo `bitcoin.conf` está montado diretamente do host, impedindo que o container o modifique.

**Solução**:

1. **Remova o mount direto do arquivo de configuração** no `docker-compose.yml`:
   ```yaml
   # Remova ou comente esta linha:
   # - ./bitcoin/bitcoin.conf:/home/bitcoin/.bitcoin/bitcoin.conf
   ```

2. **Copie o arquivo para o diretório de dados**:
   ```bash
   # Pare o serviço Bitcoin
   podman-compose down bitcoind
   
   # Copie o arquivo de configuração para o volume de dados
   sudo cp container/nodes/bitcoin/bitcoin.conf /var/lib/containers/storage/volumes/nodes_bitcoin_data/_data/
   
   # Configure as permissões corretas
   sudo chown 1007:1007 /var/lib/containers/storage/volumes/nodes_bitcoin_data/_data/bitcoin.conf
   sudo chmod 644 /var/lib/containers/storage/volumes/nodes_bitcoin_data/_data/bitcoin.conf
   ```

3. **Reinicie o container**:
   ```bash
   # Remove containers existentes se necessário
   podman-compose down
   
   # Inicie novamente
   podman-compose up -d bitcoind
   
   # Verifique os logs
   podman-compose logs bitcoind
   ```

**Resultado**: O container agora consegue ler a configuração e modificar o arquivo conforme necessário, seguindo o mesmo padrão usado pelo Elements.

---

