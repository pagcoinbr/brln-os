<div align="center">
   
<img width="640" height="360" alt="Untitled design(4)" src="https://github.com/user-attachments/assets/ea7bc12b-8409-4259-ad0f-eb084d492dc8" />
   
# BRLN-OS alfa-v2.0 – Sistema Operacional Multi-Node

[![Bitcoin](https://img.shields.io/badge/Bitcoin-₿-FF9900?style=for-the-badge&logo=bitcoin&logoColor=white)](https://bitcoin.org)
[![Lightning](https://img.shields.io/badge/Lightning-⚡-792EE5?style=for-the-badge&logo=lightning&logoColor=white)](https://lightning.network)
[![Linux](https://img.shields.io/badge/Linux-Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Open Source](https://img.shields.io/badge/Open%20Source-MIT-yellow?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)

**BRLN-OS** é uma distribuição Aplicação completa que transforma qualquer servidor Linux em um nó completo de Bitcoin + Lightning, focada em soberania individual, privacidade financeira e usabilidade para o público brasileiro e além.

<img width="1541" height="915" alt="Interface Principal do BRLN-OS" src="https://github.com/user-attachments/assets/530a8642-38b6-4f77-85c9-1f53ced2aa7a" />

Ela automatiza a instalacao, configuracao e integracao do **Bitcoin Core** (local ou remoto), **LND** e um conjunto completo de ferramentas e sistemas de monitoramento, expondo tudo atraves de uma interface web propria, sem depender de terceiros.

---

<img width="1087" height="712" alt="Arquitetura do Nó Bitcoin" src="https://github.com/user-attachments/assets/cabf3db7-8b91-4289-8078-49f78444d7b4" />

---

</div>

## ?? ?ndice

- [Por Que Este Projeto Existe](#-por-que-este-projeto-existe)
- [Guia de Instala??o](#-guia-de-instala??o)
- [Vis?o Geral da Arquitetura](#-vis?o-geral-da-arquitetura)
- [Requisitos de Sistema](#-requisitos-de-sistema)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Cr?ditos e Projetos Relacionados](#-cr?ditos-e-projetos-relacionados)
- [Comunidade e Suporte](#-comunidade-e-suporte)
- [Licen?a](#-licen?a)

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

## Guia de Instalação

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

Uma vez conectado via SSH, execute estes comandos para iniciar a instalação:

```bash
git clone https://github.com/pagcoinbr/brln-os.git && cd brln-os && bash brunel.sh
```

Estes comandos irão:
- Clonar o repositório do BRLN-OS
- Iniciar o script de instalação com menu interativo

Durante a instalacao, voce pode escolher Bitcoin local (full ou pruned, default pruned) ou Bitcoin remoto via RPC + ZMQ.

### Passo 6: Configuração Inicial

Quando você acessar pela primeira vez a interface web em `https://SEU_ENDERECO_IP`:

---

<div align="center">

## Visão Geral da Arquitetura

O BRLN-OS oferece:

**Bitcoin Core** (local ou remoto) com opcao pruned/full  
**LND** como no Lightning  
**Aplicacoes Lightning**: LNDg e Balance of Satoshis  
**Interface Web em Portugues** servida via Apache  
**API BRLN** (Flask + gRPC) para fornecer status do sistema, carteira e operar seu node via HTTP  
**Terminal Web** para acesso limitado ao terminal para debug, via navegador  
**Servicos gerenciados pelo systemd** resiliente e nativo.

<img width="1487" height="912" alt="Arquitetura do Sistema" src="https://github.com/user-attachments/assets/b1c1eb9b-49b4-40bb-864f-aab7b89d97d2" />


Tudo é projetado para rodar localmente, atrás de Tor e/ou VPN, reduzindo a necessidade de expor portas do seu servidor.

</div>

---

<div align="center">

## 📋 Requisitos de Sistema

<img width="1513" height="912" alt="Requisitos de Sistema" src="https://github.com/user-attachments/assets/e5300d16-a11a-40e0-bf3e-3674ef21e1d0" />

</div>

### Sistema Operacional

- **Ubuntu Server 24.04 LTS** (recomendado)
- Arquiteturas suportadas:
  - `x86_64` (PC/servidor padrão)
  - `arm64`/`aarch64` (incluindo Raspberry Pi mais recentes)

### Hardware Mínimo

- **CPU**: Processador 64 bits, i5 ou Ryzen 5 de 3ª geração ou superior
- **RAM**: 8 GB mínimo, **16 GB recomendado**
- **Armazenamento**: SSD de 1 TB mínimo para Bitcoin mainnet (menos para testnet ou pruning)
- **Rede**: Conexão de internet estável com boa banda de upload

### Requisitos de Rede

- Acesso SSH ao servidor (porta 22)
- Acesso HTTPS na rede local (porta 443) para a interface web
- **Recomendado**: NÃO expor portas diretamente na Internet; use Tailscale ou outra VPN

---

## 📁 Estrutura do Projeto

```text
brln-os/
|-- brunel.sh                  # script principal: instalacao, menu e updates
|-- main.html                  # pagina principal da interface web
|-- README.md                  # documentacao principal
|-- LICENSE                    # licenca MIT
|-- favicon.ico                # icone da interface
|-- api/
|   `-- v1/
|       |-- app.py             # API Flask + gRPC
|       |-- requirements.txt   # dependencias da API
|       |-- install.sh         # setup do ambiente da API
|       |-- HD_WALLET_GUIDE.md # guia da carteira HD
|       |-- LOGIN_FLOW_CHANGES.md # notas do fluxo de login
|       `-- messager_monitor_grpc.py # monitor gRPC de mensagens
|-- brln-tools/
|   |-- secure_password_manager.py   # gerenciador de senhas
|   |-- secure_password_manager.sh   # wrapper shell
|   |-- secure_password_api.py       # API do gerenciador
|   |-- API_INTEGRATION_GUIDE.md     # guia de integracao
|   `-- requirements.txt             # dependencias das ferramentas
|-- conf_files/
|   |-- bitcoin.conf
|   |-- lnd.conf
|   |-- brln-apache.conf
|   |-- brln-ssl-api.conf
|   |-- README-Apache-Proxy.md
|   |-- setup-apache-proxy.sh
|   `-- testnet/
|       |-- bitcoin.conf
|       `-- lnd.conf
|-- pages/
|   |-- home/                  # pagina inicial e assets
|   `-- components/
|       |-- bitcoin/           # interface on-chain
|       |-- lightning/         # interface Lightning
|       |-- wallet/            # gerenciador de carteira HD
|       |-- tools/             # ferramentas (LNDg, BOS)
|       |-- config/            # painel de configuracao
|       |-- header.html
|       |-- header.css
|       |-- association-footer.html
|       |-- association-footer.css
|       `-- pages-style.css
`-- scripts/
    |-- config.sh
    |-- utils.sh
    |-- menu.sh
    |-- bitcoin.sh
    |-- lightning.sh
    |-- apache.sh
    |-- system.sh
    |-- gotty.sh
    |-- services.sh
    |-- logs-and-config.sh
    |-- maintenance.sh
    |-- setup-environments.sh
    |-- setup-api-env.sh
    |-- setup-tools-env.sh
    |-- setup-wallet-env.sh
    |-- auto_wallet_integration.py
    |-- init-lnd-wallet.sh
    |-- auto-lnd-create.exp
    |-- auto-lnd-create-new.exp
    |-- auto-lnd-create-masterkey.exp
    |-- auto-lnd-unlock.exp
    |-- generate-protobuf.sh
    |-- gen-proto.sh
    |-- backup-password-manager.sh
    |-- password_manager_menu.sh
    |-- USER_APPLICATION_MATRIX.md
    `-- wallet-manager.sh
```

---

## 🎓 Créditos e Projetos Relacionados

O BRLN-OS integra ou se inspira em vários projetos open source:

- **[Bitcoin Core](https://github.com/bitcoin/bitcoin)** – Implementação de referência
- **[LND](https://github.com/lightningnetwork/lnd)** – Lightning Network Daemon da Lightning Labs
- **[LNDg](https://github.com/cryptosharks131/lndg)** – Dashboard avançado para LND
- **[Balance of Satoshis](https://github.com/alexbosworth/balanceofsatoshis)** – Ferramenta CLI de administração do LND
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
- **E-mail**: suporte.brln@gmail.com | suporte@pagcoin.org
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

**Construído com ❤️ pela liberdade e soberania da comunidade BRLN **

*BRLN-OS – Bitcoin Open Bank*

</div>
