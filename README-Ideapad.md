# 🚀 BR⚡LN Bolt - Node Lightning Simplificado

![Tela principal](https://github.com/user-attachments/assets/efbed0d2-5199-4e21-8d10-40bb742b5ef7)

Node Bitcoin e Lightning com interface gráfica e ferramentas completas para gerenciamento, monitoramento e uso diário.

## 📋 Índice
- [Instalação Rápida](#instalação-rápida)
- [Requisitos de Sistema](#requisitos-de-sistema)
- [Guia Detalhado](#guia-detalhado-de-instalação)
- [Componentes Instalados](#componentes-instalados)
- [Acessando as Interfaces](#acessando-as-interfaces)
- [Manutenção e Atualizações](#manutenção-e-atualizações)
- [Recuperação e Backup](#recuperação-e-backup)
- [Solução de Problemas](#solução-de-problemas)
- [Contribuições](#contribuições)
- [Licença](#licença)
- [Contato](#contato)

## ⚡ Instalação Rápida

```bash
bash <(curl -sSL https://install.pagcoin.org)
```

## 🖥️ Requisitos de Sistema
- Ubuntu Server 22.04 LTS ou 24.04 LTS (recomendado)
- Mínimo 8GB RAM / 32GB armazenamento (recomendado: 16GB RAM / 1TB SSD)
- Processador x86_64 ou arm64 (ambos suportados)
- Conexão à internet estável
- Portas liberadas para Bitcoin e Lightning Network

## 📝 Guia Detalhado de Instalação

### 1. 🖥️ Preparar o Ubuntu Server

Prepare seu hardware:
- Baixe o [Ubuntu Server](https://ubuntu.com/download/server)
- Crie mídia de instalação com [Balena Etcher](https://etcher.io) ou [Rufus](https://rufus.ie)
- **Importante durante a instalação:**
  - Ative o **OpenSSH Server**
  - Desative a opção **usar como LVM** na formatação do disco
  - Crie um usuário `admin` durante a instalação (ou será criado pelo script)

Conecte via SSH após a instalação:
```bash
ssh admin@192.168.1.xxx
```

Se não souber o IP:
- Ele aparece na tela do Ubuntu após o login
- Ou use um app de scan de rede como Fing

### 2. ⚡ Instalar o BR⚡LN Bolt

Execute nosso script de instalação com um único comando:

```bash
bash <(curl -sSL https://install.pagcoin.org)
```

Este script automatiza:
- Criação do usuário `admin` (se necessário)
- Download do repositório principal
- Configuração de ambiente, firewall e permissões
- Instalação do menu interativo

**ATENÇÃO!** Após a criação do usuário `admin`, o script vai finalizar da seguinte maneira:

![Captura de tela 2025-05-03 143532](https://github.com/user-attachments/assets/3a7f16f6-b6f9-4430-85f1-98ca78029681)

### 3. 🌐 Acessar a Interface Web

Após instalação inicial:
```
http://<seu_ip_local>
```

No painel principal, clique em **⚡ BRLN Node Manager**

### 4. 🧭 Seguir o Menu de Instalação

Siga a ordem recomendada:

1. **Interface de Rede e Gráfica** - Configura Tor, interface web, Tailscale
2. **Bitcoin Core** - Instala e configura bitcoind
3. **LND + Carteira** - Instala LND e cria sua wallet Lightning
4. **Simple LNWallet** - Interface simplificada para pagamentos
5. **Thunderhub + BOS** - Ferramentas avançadas de gerenciamento
6. **LNDG** - Dashboard e ferramentas de rebalanceamento 
7. **LNbits** - Sistema bancário completo sobre Lightning
8. **Opções adicionais** - BOS Telegram, Tor Access, etc

> ⚠️ **Importante**: Anote e guarde com segurança suas 24 palavras da seed LND. Sem elas, seus fundos serão perdidos permanentemente!

### 5. 🤖 Configurar BOS Telegram (opcional)

Tenha acesso ao seu node direto pelo Telegram:
1. Crie um bot via [@BotFather](https://t.me/BotFather)
2. No Terminal Web (`http://<seu_ip>:3232`), execute `bos telegram`
3. No menu principal, escolha opção 8 → 4 (Ativar BOS Telegram)
4. Siga as instruções para inserir o connection code

### 6. 🛰️ Ativar Acesso Remoto via Tailscale

Para acessar seu node de qualquer lugar:
1. No menu principal, vá para "Mais opções" → Tailscale VPN
2. Escaneie o QR code com o [app Tailscale](https://tailscale.com/download)
3. Seu node estará acessível pelo IP Tailscale em qualquer lugar

## 🧩 Componentes Instalados

O BR⚡LN Bolt instala e configura:

- **Bitcoin Core** - Validação completa da blockchain
- **LND** - Node Lightning Network da Lightning Labs
- **Interfaces Web**:
  - Thunderhub - Gerenciamento completo de LN
  - Simple LNWallet - Interface simplificada de pagamentos
  - LNDG - Dashboard e rebalanceamento
  - LNbits - Sistema bancário sobre Lightning
- **Ferramentas CLI**:
  - Balance of Satoshis (bos) - Utilitários avançados
  - BOS Telegram - Controle via Telegram
- **Acesso e Segurança**:
  - Tor Hidden Services - Acesso anônimo
  - Tailscale VPN - Acesso remoto seguro
  - UFW Firewall - Configurado automaticamente

## 🔌 Acessando as Interfaces

Todas interfaces acessíveis via navegador:

| Aplicação | URL | Descrição |
|-----------|-----|-----------|
| Painel Principal | http://IP:80 | Interface central com todos links |
| BRLN Node Manager | http://IP:3131 | Terminal interativo de gerenciamento |
| Terminal Web | http://IP:3232 | Acesso CLI via navegador |
| Thunderhub | http://IP:3000 | Gerenciamento completo de canais e pagamentos |
| LNbits | http://IP:5000 | Sistema bancário e loja sobre Lightning |
| LNDG | http://IP:8889 | Dashboard e estatísticas |
| Simple LNWallet | http://IP:35671 | Interface simplificada para usuários |
| Logs Bitcoin | http://IP:3434 | Logs em tempo real do Bitcoin Core |
| Logs LND | http://IP:3535 | Logs em tempo real do LND |
| Editor bitcoin.conf | http://IP:3636 | Editor de configurações do Bitcoin Core |
| Editor lnd.conf | http://IP:3333 | Editor de configurações do LND |

## 🔄 Manutenção e Atualizações

Para manter seu node atualizado:

1. Acesse o BRLN Node Manager (`http://<seu_ip>:3131`)
2. Escolha opção 8 → 3 (Atualizar e desinstalar programas)
3. Escolha qual componente atualizar:
   - LND
   - Bitcoin Core
   - Thunderhub
   - LNDg
   - LNbits
   - Pacotes do Sistema

## 💾 Recuperação e Backup

É extremamente importante fazer backup:

1. **Seed de 24 palavras do LND**: É gerada ao criar carteira (anote offline)
2. **Arquivo de backup estático**: Gerado automaticamente em `~/.lnd/data/chain/bitcoin/mainnet/channel.backup`
3. **SCB (Signed Channel Backup)**: Atualizações via Thunderhub

Para recuperar seu node:
1. Reinstale seguindo os passos anteriores
2. Durante a criação da carteira LND, escolha "importar seed existente"
3. Digite suas 24 palavras
4. Restaure seu SCB pelo Thunderhub

## 🛠️ Solução de Problemas

Se encontrar dificuldades:

1. **Consulte os logs**:
   - Web: Use as interfaces de log em `http://<seu_ip>:3434` e `http://<seu_ip>:3535`
   - CLI: Use `journalctl -u lnd` ou `journalctl -u bitcoind`

2. **Reinicie serviços** pela interface web no Painel Principal

3. **Como último recurso**: Se não conseguir resolver e não tiver fundos no node, reinstale o Ubuntu e recomece o processo.

## 📚 Projetos Integrados

O BR⚡LN Bolt integra e agradece aos projetos:

- [Bitcoin Core](https://github.com/bitcoin/bitcoin)
- [LND](https://github.com/lightningnetwork/lnd)
- [Thunderhub](https://github.com/apotdevin/thunderhub)
- [LNbits](https://github.com/lnbits/lnbits)
- [LNDG](https://github.com/cryptosharks131/lndg)
- [Balance of Satoshis](https://github.com/alexbosworth/balanceofsatoshis)
- [Simple LNwallet](https://github.com/jvxis/simple-lnwallet-go)
- [Gotty](https://github.com/yudai/gotty)
- [Tailscale](https://github.com/tailscale/tailscale)

## 👩‍💻 Contribuições

Quer contribuir para o BR⚡LN Bolt? Veja nosso [guia de contribuição](CONTRIBUTING.md) para detalhes sobre:

- Arquitetura do código
- Fluxo de desenvolvimento
- Como adicionar novos componentes
- Diretrizes para Pull Requests

## ⚖️ Licença

Este projeto é distribuído sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 💬 Contato

- Telegram: [t.me/pagcoinbr](https://t.me/pagcoinbr)
- Email: suporte.brln@gmail.com ou suporte@pagcoin.org
- Website: [services.br-ln.com](https://services.br-ln.com)
