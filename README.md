<div align="center">
<img alt="Untitled design(1)" src="https://github.com/user-attachments/assets/673060c6-7110-44e9-b492-feeb649275d7" />
# BRLN-OS v2.0 – Sistema Operacional Multi-Node

[![Bitcoin](https://img.shields.io/badge/Bitcoin-₿-FF9900?style=for-the-badge&logo=bitcoin&logoColor=white)](https://bitcoin.org)
[![Lightning](https://img.shields.io/badge/Lightning-⚡-792EE5?style=for-the-badge&logo=lightning&logoColor=white)](https://lightning.network)
[![Liquid](https://img.shields.io/badge/Liquid-₿-blue?style=for-the-badge&logo=liquid&logoColor=white)](https://liquid.net)
[![TRON](https://img.shields.io/badge/TRON-TRX-E50914?style=for-the-badge&logo=tron&logoColor=white)](https://tron.network)
[![Linux](https://img.shields.io/badge/Linux-Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Open Source](https://img.shields.io/badge/Open%20Source-MIT-yellow?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Free Banking](https://img.shields.io/badge/Free%20Banking-Self%20Sovereign-red?style=for-the-badge&logo=bank&logoColor=white)](#)
[![Privacy First](https://img.shields.io/badge/Privacy-First-purple?style=for-the-badge&logo=tor&logoColor=white)](#)

**BRLN-OS** é uma distribuição Aplicação completa que transforma qualquer servidor Linux em um nó completo de Bitcoin + Lightning + Liquid, focada em soberania individual, privacidade financeira e usabilidade para o público brasileiro e além.

<img width="1541" height="915" alt="Interface Principal do BRLN-OS" src="https://github.com/user-attachments/assets/530a8642-38b6-4f77-85c9-1f53ced2aa7a" />

Ela automatiza a instalação, configuração e integração do **Bitcoin Core**, **LND**, **Elements** e um conjunto completo de ferramentas e sistemas de monitoramento, expondo tudo através de uma interface web própria, sem depender de terceiros.

---

<img width="1487" height="912" alt="Arquitetura do Nó Bitcoin" src="https://github.com/user-attachments/assets/cabf3db7-8b91-4289-8078-49f78444d7b4" />

---

</div>

## 📑 Índice

- [Por Que Este Projeto Existe](#-por-que-este-projeto-existe)
- [Guia de Instalação](#-guia-de-instalação)
- [Visão Geral da Arquitetura](#-visão-geral-da-arquitetura)
- [Principais Componentes](#-principais-componentes)
- [Requisitos de Sistema](#-requisitos-de-sistema)
- [Início Rápido](#-início-rápido)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Privacidade e Segurança](#-privacidade-e-segurança)
- [Atualização do Sistema](#-atualização-do-sistema)
- [Créditos e Projetos Relacionados](#-créditos-e-projetos-relacionados)
- [Comunidade e Suporte](#-comunidade-e-suporte)
- [Licença](#-licença)

---

<div align="center">

## Por Que Este Projeto Existe?

O BRLN-OS é construído sobre princípios fundamentais:

**Privacidade Como um Direito**  
Transações e saldos devem ser controlados por você, rodando na sua própria infraestrutura, sem custódia de terceiros. Sua vida está prestes a mudar, pois grandes poderes, vêm grandes responsabilidades.

**Soberania Digital**  
O nó roda no seu hardware, com software livre e serviços auto-hospedados.

**Resistência à Vigilância**  
Uso de Tor, suporte a I2P (i2pd) e VPN opcional (Tailscale) para reduzir a exposição em qualquer lugar.

**Empoderamento Individual**  
Interface em português, menus interativos e automação para reduzir a barreira técnica de operar um nó completo de Bitcoin.

A principal motivação é **proteger a privacidade e a liberdade** das pessoas, especialmente em contextos onde a vigilância e o controle financeiro podem colocar sua vida em risco.

</div>

---

## 🚀 Guia de Instalação

### Passo 1: Baixar o Ubuntu 24.04 LTS

1. Acesse o site oficial da Canonical: [https://ubuntu.com/download/server](https://ubuntu.com/download/server)
2. Baixe o **Ubuntu 24.04 LTS Server** (arquivo ISO)
3. Salve o arquivo ISO no seu computador

### Passo 2: Criar USB Bootável

1. Baixe o **Balena Etcher**: [https://www.balena.io/etcher/](https://www.balena.io/etcher/)
2. Instale o Balena Etcher no seu computador
3. Insira o pendrive USB (mínimo 8GB) - ⚠️ **Todos os dados serão apagados!**
4. Abra o Balena Etcher:
   - Clique em "Flash from file" e selecione o ISO do Ubuntu
   - Clique em "Select target" e escolha o seu pendrive
   - Clique em "Flash!" e aguarde a conclusão (5–15 minutos)
5. Ejete o USB com segurança

### Passo 3: Instalar o Ubuntu Server

1. Insira o USB na máquina alvo e inicialize por ele
   - Pressione F12, F2, ESC ou DEL para acessar o menu de boot
   - Selecione o pendrive USB
2. Siga o assistente de instalação do Ubuntu:
   - Configure idioma, teclado e rede
   - **Crie uma conta de usuário** (guarde as credenciais!)
   - 🚨 **Selecione "Install OpenSSH server"** (OBRIGATÓRIO!)
   - Conclua a instalação e reinicie

### Passo 4: Conectar via SSH

1. Descubra o endereço IP da sua máquina Ubuntu:
   ```bash
   ip addr show
   ```
   Procure por um IP como 192.168.x.x ou 10.0.x.x

2. Conecte de outro computador:
   ```bash
   ssh seu_usuario@SEU_ENDERECO_IP
   ```

### Passo 5: Instalar o BRLN-OS

Uma vez conectado via SSH, execute este comando único:

```bash
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

Este comando irá:
- Clonar o repositório do BRLN-OS
- Entrar no diretório
- Rodar o script de instalação com menu interativo

### Passo 6: Configuração Inicial

Quando você acessar pela primeira vez a interface web em `http://SEU_ENDERECO_IP`:

**Cenário 1: Instalação Nova**
- Abre automaticamente o setup interativo no terminal
- Siga os prompts do `menu.sh` para configurar o sistema
- Crie sua primeira carteira

**Cenário 2: Diretório do LND Existe, mas Sem Carteira**
- Abre a interface de criação de carteira
- Crie ou importe uma carteira
- Configure seu nó Lightning

**Cenário 3: Tudo Configurado**
- Acessa diretamente o painel principal
- Seu sistema está pronto para uso!

Para instruções de instalação detalhadas, veja [INSTALLATION_TUTORIAL.md](INSTALLATION_TUTORIAL.md).

---

<div align="center">

## 🏗️ Visão Geral da Arquitetura

O BRLN-OS oferece:

**Bitcoin Core** como backend on-chain, configurado para uso com Tor e I2P  
**LND (Lightning Network Daemon)** como nó Lightning principal  
**Aplicações Lightning**: ThunderHub, LNbits, LNDg, Balance of Satoshis e Simple LNWallet  
**Interface Web em Português** servida via Apache, com página principal em `main.html` e componentes em `pages/`  
**API BRLN** (Flask + gRPC) para expor status do sistema, carteira e operações Lightning via HTTP  
**Terminal Web (Gotty)** para acesso ao shell via navegador (se habilitado)  
**Serviços gerenciados pelo systemd** com arquivos de unidade em `services/`

<img width="1487" height="912" alt="Arquitetura do Sistema" src="https://github.com/user-attachments/assets/b1c1eb9b-49b4-40bb-864f-aab7b89d97d2" />

Tudo é projetado para rodar localmente, atrás de Tor e/ou VPN, reduzindo a necessidade de expor portas diretamente à Internet.

</div>

---

## 🔧 Principais Componentes

### 3.1 Bitcoin e Lightning Core

**Bitcoin Core**
- Instalado a partir dos binários oficiais via `scripts/bitcoin.sh`
- Diretório de dados padrão: `/home/bitcoin/.bitcoin`
- Configuração base em `conf_files/bitcoin.conf` (inclui proxy Tor e suporte I2P via i2pd)

**LND (Lightning Network Daemon)**
- Instalado via `scripts/bitcoin.sh` (função `download_lnd`)
- Diretório de dados padrão: `/home/lnd/.lnd`
- Configuração base em `conf_files/lnd.conf`
- Integração gRPC com a API BRLN (veja `api/v1/`)

### 3.2 Aplicações Lightning

<div align="center">

<img width="1463" height="908" alt="Aplicações Lightning" src="https://github.com/user-attachments/assets/e231791c-67d4-4f33-a85f-9fab1848a5c7" />

</div>

Instaladas e gerenciadas por `scripts/lightning.sh` e pelo menu interativo em `scripts/menu.sh`:

- **ThunderHub** – Interface web moderna para o LND
- **LNbits** – Servidor de carteira Lightning multiusuário
- **LNDg** – Dashboard avançado para gestão e rebalanceamento de canais
- **Balance of Satoshis (BOS)** – Ferramenta CLI para automação e gestão de canais
- **Simple LNWallet** – Carteira Lightning minimalista integrada à interface

### 3.3 Interface Web e Proxy

**Servidor Web Apache** configurado por `scripts/apache.sh` e `scripts/system.sh`:
- Copia `main.html`, `pages/` e assets estáticos para `/var/www/html/`
- Serve a interface em `http://IP_DO_SEU_NO/`

**Proxy Reverso Apache** documentado em `conf_files/README-Apache-Proxy.md`:
- Mapeia serviços internos para caminhos únicos (`/thunderhub/`, `/lnbits/`, `/lndg/`, `/simple-lnwallet/`, `/api/`)
- Resolve problemas de SameSite cookie e iframe, mantendo tudo sob o mesmo domínio

### 3.4 API BRLN

Implementada em `api/v1/app.py` (Flask + gRPC):

**Gestão do Sistema**
- Status do sistema (CPU, RAM, LND, Bitcoin, etc.)
- Gestão de serviços (start/stop/restart)
- Health checks

**Carteira On-chain**
- Saldo e transações de Bitcoin
- Envio de BTC, geração de endereços, gestão de UTXOs

**Lightning Network**
- Peers, canais, faturas, pagamentos
- Keysend, taxas, roteamento
- Gestão de canais

Faz a ponte com o LND via gRPC usando protos em `api/v1/proto/`  
- Serviço systemd: `services/brln-api.service`

### 3.5 Privacidade e Rede

**Tor**
- Instalado e habilitado via `scripts/system.sh`
- Bitcoin Core configurado para usar proxy Tor (veja `conf_files/bitcoin.conf`)

**I2P (i2pd)**
- Suporte configurado em `bitcoin.conf` para conexões I2P (i2psam)

**Tailscale VPN**
- Instalado via `scripts/system.sh`
- Recomendado para acesso remoto seguro em vez de redirecionar portas públicas

### 3.6 Terminal Web (Gotty)

- Instalado e gerenciado via `scripts/gotty.sh`
- Serviços systemd: `gotty.service`, `gotty-fullauto.service` e serviços de log/editor
- Abre em um modal com iframe para integração transparente

---

<div align="center">

## 📋 Requisitos de Sistema

<img width="1513" height="912" alt="Requisitos de Sistema" src="https://github.com/user-attachments/assets/e5300d16-a11a-40e0-bf3e-3674ef21e1d0" />

</div>

### Sistema Operacional

- **Ubuntu Server 22.04 LTS ou 24.04 LTS** (recomendado)
- Arquiteturas suportadas:
  - `x86_64` (PC/servidor padrão)
  - `arm64`/`aarch64` (incluindo Raspberry Pi mais recentes)

### Hardware Mínimo

- **CPU**: Processador 64 bits, 2 GHz dual-core ou melhor
- **RAM**: 4 GB mínimo, **8 GB recomendado**
- **Armazenamento**: SSD de 500 GB mínimo para Bitcoin mainnet (menos para testnet ou pruning agressivo)
- **Rede**: Conexão de internet estável com boa banda de upload

### Requisitos de Rede

- Acesso SSH ao servidor (porta 22)
- Acesso HTTP/HTTPS na rede local (portas 80 e 443) para a interface web
- **Recomendado**: NÃO expor portas diretamente na Internet; use Tailscale ou outra VPN

---

## ⚡ Início Rápido

Para quem já está confortável com linha de comando no Ubuntu Server:

1. Garanta que você está logado como usuário com privilégios `sudo` (por exemplo, `admin`).

2. Atualize o sistema:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install git -y
   ```

3. Clone o repositório:
   ```bash
   git clone https://github.com/pagcoinbr/brln-os.git
   cd brln-os
   ```

4. Rode o menu de instalação interativo:
   ```bash
   chmod +x brunel.sh
   ./brunel.sh
   ```

5. Acesse a interface web:
   - Abra o navegador em `http://IP_DO_SEU_NO/`

---

## 📁 Estrutura do Projeto

Visão simplificada dos principais diretórios:

```text
brln-os/
├── brunel.sh              # Script principal de instalação com menu interativo
├── main.html              # Página principal da interface web
├── pages/                 # Componentes da interface (home, tools, bitcoin, lightning, etc.)
│   ├── home/              # Página inicial com verificação de status da carteira
│   ├── components/        # Componentes de UI
│   │   ├── bitcoin/       # Interface on-chain de Bitcoin
│   │   ├── lightning/     # Interface da Lightning Network
│   │   ├── elements/      # Interface para Elements/Liquid
│   │   ├── wallet/        # Gerenciador de carteira HD
│   │   ├── tron/          # Carteira TRON (gas-free)
│   │   └── config/        # Painel de configuração do sistema
├── scripts/               # Scripts shell modulares
│   ├── config.sh          # Configuração global, caminhos, arquitetura
│   ├── utils.sh           # Funções utilitárias (spinner, safe_cp, firewall, etc.)
│   ├── apache.sh          # Configuração e deploy do Apache
│   ├── bitcoin.sh         # Instalação do Bitcoin Core + LND
│   ├── lightning.sh       # Apps Lightning (ThunderHub, LNbits, BOS, API)
│   ├── gotty.sh           # Terminal web
│   ├── system.sh          # Ferramentas de sistema (Tor, Tailscale, cron, sudoers)
│   ├── menu.sh            # Menu interativo principal
│   ├── elements.sh        # Suporte a Elements/Liquid
│   └── peerswap.sh        # Integração PeerSwap
├── api/
│   └── v1/
│       ├── app.py         # API Flask + gRPC integrando com LND
│       ├── requirements.txt
│       ├── proto/         # Arquivos .proto do LND
│       └── *_pb2*.py      # Arquivos gRPC gerados
├── conf_files/
│   ├── bitcoin.conf       # Configuração padrão do Bitcoin Core (Tor + I2P)
│   ├── lnd.conf           # Configuração padrão do LND
│   ├── README-Apache-Proxy.md
│   └── setup-apache-proxy.sh
├── services/              # Arquivos de unidade systemd para todos os serviços
├── brln-tools/            # Ferramentas utilitárias (BIP39, gerenciador de senhas, etc.)
└── INSTALLATION_TUTORIAL.md  # Guia detalhado de instalação
```

---

## 🔐 Privacidade e Segurança

O BRLN-OS é projetado para **proteger a privacidade**, mas a configuração final depende de você. Recomendações:

### Boas Práticas de Privacidade

**Rodar Atrás de Tor e I2P**
- Use o `bitcoin.conf` fornecido como base
- Instale o Tor pelo menu "Ferramentas de Sistema" (`scripts/system.sh`)
- O Bitcoin Core usa automaticamente o proxy Tor

**Evitar Exposição Direta de Portas**
- Acesse via LAN ou VPN Tailscale
- Se precisar de acesso externo, use HTTPS com certificados válidos e firewall adequado

**Backups Seguros**
- Backups regulares de:
  - `/home/bitcoin/.bitcoin` (ou seu diretório de dados)
  - `/home/lnd/.lnd` (inclui seed, macaroon, channels.db)
  - Diretórios de dados do LNbits, LNDg e outros serviços

**Segregação de Usuários**
- Cada serviço roda com seu próprio usuário de sistema (bitcoin, lnd, lnbits, etc.)
- Reduz o impacto de falhas e melhora a segurança

**Atualizações Frequentes**
- O BRLN-OS pode configurar `git pull` automático via cron
- Rode `./brunel.sh` periodicamente para verificar atualizações

### Checklist de Segurança

- [ ] Tor instalado e rodando
- [ ] Firewall (UFW) configurado
- [ ] Senhas fortes para todas as carteiras
- [ ] Autenticação por chave SSH habilitada
- [ ] Backups regulares das seeds
- [ ] Sistema atualizado regularmente

**Lembre-se**: privacidade é um processo contínuo. Revise regularmente sua superfície de ataque, portas abertas e dependências.

---

## 🔄 Atualização do Sistema

Para atualizar o código do BRLN-OS e os componentes gerenciados:

```bash
cd /caminho/para/brln-os
./brunel.sh update
```

Este comando:
- Executa `git pull` no repositório
- Atualiza dependências Python (API)
- Atualiza e redeploya a interface web via Apache
- Revalida permissões no sudoers e atualiza cron

---

## 🛠️ Serviços Systemd

Os arquivos em `services/` definem como cada componente roda em segundo plano:

| Serviço | Descrição |
|---------|-----------|
| `bitcoind.service` | Daemon do Bitcoin Core |
| `lnd.service` | Lightning Network Daemon |
| `lnbits.service` | Servidor de carteira LNbits multiusuário |
| `thunderhub.service` | Dashboard web ThunderHub |
| `lndg.service` + `lndg-controller.service` | Dashboard LNDg e controlador |
| `simple-lnwallet.service` | Interface web Simple LNWallet |
| `bos-telegram.service` | Bot Telegram do Balance of Satoshis |
| `lightning-monitor.service` | Serviço de monitoramento Lightning |
| `brln-api.service` | API BRLN (Flask + gRPC) |
| `gotty*.service` | Terminal web e ferramentas administrativas |
| `elementsd.service` | Daemon do Elements/Liquid |
| `peerswapd.service` + `psweb.service` | PeerSwap e interface web |

Interaja com os serviços via `systemctl`:

```bash
sudo systemctl status bitcoind
sudo systemctl start lnd
sudo systemctl enable thunderhub
sudo systemctl restart brln-api
```

O BRLN-OS adiciona entradas específicas no sudoers para permitir que o usuário admin gerencie serviços sem solicitar senha.

---

## 🎓 Créditos e Projetos Relacionados

O BRLN-OS integra ou se inspira em vários projetos open source:

- **[Bitcoin Core](https://github.com/bitcoin/bitcoin)** – Implementação de referência
- **[LND](https://github.com/lightningnetwork/lnd)** – Lightning Network Daemon da Lightning Labs
- **[ThunderHub](https://github.com/apotdevin/thunderhub)** – Interface web moderna para LND
- **[LNbits](https://github.com/lnbits/lnbits)** – Camada bancária sobre Lightning
- **[LNDg](https://github.com/cryptosharks131/lndg)** – Dashboard avançado para LND
- **[Balance of Satoshis](https://github.com/alexbosworth/balanceofsatoshis)** – Ferramenta CLI de administração do LND
- **[Simple LNWallet](https://github.com/jvxis/simple-lnwallet-go)** – Carteira Lightning minimalista
- **[Gotty](https://github.com/yudai/gotty)** – Terminal baseado na web
- **[Tailscale](https://github.com/tailscale/tailscale)** – Rede VPN em malha

Estude a documentação oficial de cada projeto para entender limites, riscos e melhores práticas.

---

<div align="center">

## 💬 Comunidade e Suporte

<img width="842" height="332" alt="Comunidade" src="https://github.com/user-attachments/assets/9a7369ec-438d-40ea-bf91-41dc717d9d96" />

</div>

### Como Obter Ajuda

- **Telegram**: [https://t.me/pagcoinbr](https://t.me/pagcoinbr)
- **E-mail**: suporte.brln@gmail.com | suporte@brln-os
- **Website**: [https://services.br-ln.com](https://services.br-ln.com)
- **GitHub Issues**: [https://github.com/pagcoinbr/brln-os/issues](https://github.com/pagcoinbr/brln-os/issues)

### Contribuindo

Contribuições são bem-vindas! Nós valorizamos:

- Melhorias de segurança e privacidade
- Aprimoramentos de UX
- Correções de bugs e atualizações de documentação
- Traduções para outros idiomas

**Como contribuir:**

1. Faça um fork do repositório
2. Crie uma branch de feature (`git checkout -b feature/sua-feature`)
3. Faça commit das mudanças (`git commit -m 'Adiciona nova funcionalidade'`)
4. Envie para o repositório remoto (`git push origin feature/sua-feature`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto é licenciado sob a **Licença MIT**. Veja o arquivo [LICENSE](LICENSE) para o texto completo.

---

<div align="center">

## 🌟 Recursos em Destaque

✅ **Nó Completo de Bitcoin** – Sincronize e valide toda a blockchain  
✅ **Lightning Network** – Envie/receba pagamentos instantâneos e de baixo custo  
✅ **Interface Web** – Dashboard amigável em português  
✅ **Privacidade em Primeiro Lugar** – Integração com Tor e I2P por padrão  
✅ **Auto-Hospedado** – Sem dependência de terceiros  
✅ **Suporte Multi-Moeda** – Bitcoin, Elements/Liquid, TRON  
✅ **Gerenciador de Carteira HD** – Gestão de seeds BIP39  
✅ **Gestão de Canais** – Integração com ThunderHub, LNDg, BOS  
✅ **Acesso via API** – API RESTful com backend gRPC  
✅ **Atualizações Automáticas** – Auto-update configurável via cron  
✅ **Monitoramento Profissional** – Status do sistema e gestão de serviços  
✅ **Open Source** – Licença MIT, orientado pela comunidade  

---

**Construído com ❤️ pela liberdade e soberania financeira em Bitcoin**

*BRLN-OS – Banco pelo Povo e para o Povo*

</div>
