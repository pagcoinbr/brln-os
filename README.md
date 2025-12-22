# BRLN-OS v1.0 – Bitcoin Lightning Node OS

BRLN-OS é uma distribuição voltada a transformar qualquer servidor Ubuntu em um nó Bitcoin + Lightning completo, com foco em soberania individual, privacidade financeira e usabilidade para o público brasileiro.

Ele automatiza a instalação, configuração e integração de Bitcoin Core, LND e um conjunto de ferramentas Lightning e de monitoramento, expondo tudo através de uma interface web própria e serviços locais, sem depender de terceiros.

---

![ChatGPT Image 21 de abr  de 2025, 02_47_48](https://github.com/user-attachments/assets/cabf3db7-8b91-4289-8078-49f78444d7b4)

---

## 1. Por que este projeto existe?

BRLN-OS nasce de alguns princípios fundamentais:

- **Privacidade financeira como direito**: transações e saldos devem ser controlados por você, rodando em sua própria infraestrutura, sem custódia de terceiros.
- **Soberania digital**: o nó roda em seu hardware, com software livre e serviços auto-hospedados.
- **Resistência à vigilância**: uso de Tor, suporte a I2P (i2pd) e VPN opcional (Tailscale) para reduzir exposição de metadados.
- **Empoderamento individual**: interface em português, menus interativos e automação para reduzir a barreira técnica de operar um nó Bitcoin/Lightning completo.

A motivação principal é proteger a privacidade e a liberdade financeira de indivíduos, especialmente em contextos onde a vigilância e o controle financeiro são crescentes.

---

## 2. Visão geral da arquitetura

No alto nível, o BRLN-OS provê:

- **Bitcoin Core** como backend on-chain, configurado para uso com Tor e I2P.
- **LND (Lightning Network Daemon)** como nó Lightning principal.
- **Aplicações Lightning** como ThunderHub, LNbits, LNDg, Balance of Satoshis e Simple LNWallet.
- **Interface Web em português** servida via Apache, com página principal em `main.html` e componentes em `pages/`.
- **API BRLN** (Flask + gRPC) para expor status do sistema, carteira e operações Lightning via HTTP.
- **Terminal web (Gotty)** para acesso ao shell via navegador, se habilitado.
- **Serviços gerenciados por systemd**, com arquivos de unidade em `services/`.

Tudo é pensado para rodar localmente, atrás de Tor e/ou VPN, reduzindo a necessidade de abrir portas diretamente para a Internet.

---

## 3. Principais componentes

### 3.1 Core Bitcoin & Lightning

- **Bitcoin Core**
  - Instalado a partir dos binários oficiais através de `scripts/bitcoin.sh`.
  - Diretório de dados padrão: `/home/bitcoin/.bitcoin`.
  - Arquivo de configuração base em `conf_files/bitcoin.conf` (inclui proxy via Tor e suporte I2P via i2pd).

- **LND (Lightning Network Daemon)**
  - Instalado via `scripts/bitcoin.sh` (função `download_lnd`).
  - Diretório de dados padrão: `/home/lnd/.lnd`.
  - Arquivo de configuração base em `conf_files/lnd.conf`.
  - Integração via gRPC com a API BRLN (ver `api/v1/`).

### 3.2 Aplicações Lightning

Instaladas e gerenciadas por `scripts/lightning.sh` e menu interativo em `scripts/menu.sh`:

- **ThunderHub** – interface web moderna para LND.
- **LNbits** – servidor de carteiras Lightning multiusuário.
- **LNDg** – dashboard avançado para canais e rebalanceamento.
- **Balance of Satoshis (BOS)** – ferramenta CLI para automação e gestão de canais.
- **Simple LNWallet** – carteira web minimalista integrada à interface.

### 3.3 Interface Web & Proxy

- **Apache Web Server** configurado por `scripts/apache.sh` e `scripts/system.sh`:
  - Copia `main.html`, `pages/` e assets estáticos para `/var/www/html/`.
  - Permite servir a interface em `http://IP_DO_SEU_NODE/`.
- **Proxy reverso Apache** documentado em `conf_files/README-Apache-Proxy.md`:
  - Mapeia serviços internos para caminhos únicos (ex.: `/thunderhub/`, `/lnbits/`, `/lndg/`, `/simple-lnwallet/`, `/api/`).
  - Resolve problemas de cookies SameSite e iframes, mantendo tudo sob o mesmo domínio.

### 3.4 API BRLN

- Implementada em `api/v1/app.py` (Flask + gRPC):
  - **System Management**: status da máquina, serviços, health-check.
  - **Wallet On-chain**: saldo, transações, envio de BTC, geração de endereços, UTXOs.
  - **Lightning**: peers, canais, invoices, pagamentos, keysend, taxas, etc.
  - Faz ponte com LND via gRPC usando os protos em `api/v1/proto/`.
- Serviço systemd correspondente em `services/brln-api.service`.

### 3.5 Privacidade e Rede

- **Tor**
  - Instalado e habilitado via `scripts/system.sh` (função `install_tor`).
  - Bitcoin Core configurado para usar proxy Tor (ver `conf_files/bitcoin.conf`).
- **I2P (i2pd)**
  - Suporte configurado no `bitcoin.conf` para conexões via I2P (i2psam).
- **Tailscale VPN**
  - Instalado via `scripts/system.sh` (função `tailscale_vpn`).
  - Recomendado para acesso remoto seguro ao seu nó em vez de port forwarding público.

### 3.6 Terminal Web (Gotty)

- Instalado e gerenciado via `scripts/gotty.sh` ou funções equivalentes em `brunel.sh`.
- Serviços systemd:
  - `gotty.service`, `gotty-fullauto.service`, serviços de logs e editores (`gotty-logs-lnd`, `gotty-btc-editor` etc.).

---

## 4. Requisitos

### 4.1 Sistema operacional

- Ubuntu Server 22.04 LTS ou 24.04 LTS (recomendado).
- Arquiteturas suportadas:
  - `x86_64` (PC/servidor padrão).
  - `arm64`/`aarch64` (inclui Raspberry Pi mais novos).

### 4.2 Hardware mínimo sugerido

- CPU 64 bits.
- 4 GB de RAM (8 GB recomendado).
- 500 GB de espaço em disco para Bitcoin mainnet (pode ser menos em testnet ou prune agressivo).
- Conexão de internet estável e com boa banda de upload.

### 4.3 Rede

- Acesso SSH ao servidor (porta 22).
- Acesso HTTP/HTTPS na rede local (portas 80 e 443) para a interface web.
- Recomenda-se **NÃO** expor portas diretamente para a Internet; use Tailscale ou outra VPN.

---

## 5. Instalação rápida

Para quem já está confortável com linha de comando em Ubuntu Server.

1. Certifique-se de que está logado como usuário com privilégios de `sudo` (por exemplo, `admin`).
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

   Opcionalmente, troque para o branch específico utilizado no seu ambiente (por exemplo `brlnfullauto`), se existir:

   ```bash
   git switch brlnfullauto
   ```

4. Torne o script principal executável e rode a instalação rápida:

   ```bash
   chmod +x brunel_new.sh
   ./brunel_new.sh install
   ```

5. Ao final, a interface web deverá estar disponível em:

   - `http://IP_DO_SEU_NODE/` (Apache servindo `main.html`).

---

## 6. Instalação passo a passo (recomendada)

### 6.1 Instale o Ubuntu Server

1. Baixe o Ubuntu Server em: https://ubuntu.com/download/server
2. Grave a ISO em um pendrive com Balena Etcher ou Rufus.
3. Durante a instalação:
   - Ative o **OpenSSH Server** (fundamental para acessar o nó via rede).
   - Desative a opção de **usar como LVM** (partição simples facilita backups e migrações).

Após a instalação, descubra o IP do servidor (mostrado no login do Ubuntu ou por apps como Fing).

Conecte via SSH a partir da sua máquina:

```bash
ssh admin@192.168.1.104
```

(adapte o usuário e IP ao seu ambiente).

### 6.2 Prepare o sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install git curl -y
```

### 6.3 Clone e entre no repositório

```bash
git clone https://github.com/pagcoinbr/brln-os.git
cd brln-os
```

### 6.4 Inicie o instalador BRLN-OS

Use o script modularizado principal:

```bash
chmod +x brunel_new.sh
./brunel_new.sh menu
```

Você verá o menu principal com opções como:

- Bitcoin & Lightning Stack
- Lightning Applications
- Elements/Liquid
- PeerSwap
- Interface Web
- Ferramentas do Sistema

A partir desse menu, você pode:

- Instalar apenas o **Bitcoin Core**.
- Instalar apenas o **LND**.
- Instalar o **stack completo (Bitcoin + LND)**.
- Adicionar **ThunderHub, LNbits, LNDg, BOS**.
- Configurar **Apache**, **Gotty**, **Tor**, **Tailscale**, firewall (UFW) e mais.

### 6.5 Deploy da Interface Web

No menu "Interface Web":

- Configure o Apache: instala e habilita o servidor HTTP.
- Deploy para Apache: copia `main.html`, `pages/` e assets para `/var/www/html`.
- Opcionalmente, configure SSL/HTTPS se tiver domínio e certificados.

### 6.6 Proxy reverso e Simple LNWallet

Em muitos casos, você desejará rodar os serviços Lightning por trás do mesmo domínio, para evitar problemas de cookies/iframe.

- Siga as instruções em `conf_files/README-Apache-Proxy.md`.
- Execute:

  ```bash
  sudo /root/brln-os/conf_files/setup-apache-proxy.sh
  ```

Isso criará as configurações Apache necessárias para mapear:

- `/simple-lnwallet/`, `/lndg/`, `/thunderhub/`, `/lnbits/`, `/api/`, `/gotty/`, etc.

---

## 7. Estrutura do projeto

Visão simplificada dos diretórios principais:

```text
brln-os/
├── brunel_new.sh          # Script principal modular (recomendado)
├── brunel.sh              # Script monolítico legado (mantido por compatibilidade)
├── MODULAR_STRUCTURE.md   # Documentação da estrutura modular dos scripts
├── main.html              # Página principal da interface web
├── pages/                 # Componentes da interface (home, tools, bitcoin, lightning, etc.)
├── scripts/               # Scripts shell modulares
│   ├── config.sh          # Configuração global, caminhos, arquitetura, rede
│   ├── utils.sh           # Funções utilitárias (spinner, safe_cp, firewall, etc.)
│   ├── apache.sh          # Setup e deploy do Apache
│   ├── bitcoin.sh         # Instalação Bitcoin Core + LND
│   ├── lightning.sh       # Apps Lightning (ThunderHub, LNbits, BOS, BRLN API)
│   ├── gotty.sh           # Terminal web
│   ├── system.sh          # Update, Tor, Tailscale, cron, sudoers
│   ├── menu.sh            # Menu interativo principal
│   ├── elements.sh        # Suporte a Elements/Liquid
│   └── peerswap.sh        # Integração PeerSwap
├── api/
│   └── v1/
│       ├── app.py         # API Flask + gRPC integrando com LND
│       ├── requirements.txt
│       ├── proto/         # Arquivos .proto do LND e serviços auxiliares
│       └── *_pb2*.py      # Arquivos gerados do gRPC
├── conf_files/
│   ├── bitcoin.conf       # Config padrão Bitcoin Core (Tor + I2P)
│   ├── lnd.conf           # Config padrão LND
│   ├── README-Apache-Proxy.md
│   └── setup-apache-proxy.sh
├── services/              # Unidades systemd para todos os serviços
├── simple-lnwallet/       # Frontend Simple LNWallet integrado à interface
├── localApps/             # Binários/arquivos locais (por ex. gotty)
└── nr-tools-by-jvx/       # Ferramentas auxiliares (scripts Python, etc.)
```

---

## 8. Serviços systemd

Os arquivos em `services/` definem como cada componente roda em segundo plano. Alguns exemplos:

- `bitcoind.service` – Bitcoin Core.
- `lnd.service` – LND (Lightning Network Daemon).
- `lnbits.service` – LNbits.
- `thunderhub.service` – ThunderHub.
- `lndg.service` e `lndg-controller.service` – LNDg.
- `simple-lnwallet.service` – Simple LNWallet.
- `bos-telegram.service` – Balance of Satoshis (modo bot/telegram, se configurado).
- `lightning-monitor.service` – Monitoramento Lightning.
- `brln-api.service` – API BRLN (Flask + gRPC).
- `gotty*.service` – Terminal web e ferramentas administrativas.

Você pode interagir com eles via `systemctl`:

```bash
sudo systemctl status bitcoind
sudo systemctl start lnd
sudo systemctl enable thunderhub
```

O próprio BRLN-OS adiciona uma entrada `sudoers` específica para permitir que o usuário admin gerencie serviços sem precisar digitar senha o tempo todo, mantendo a operação diária mais fluida.

---

## 9. Privacidade, segurança e boas práticas

BRLN-OS é pensado para **proteger a privacidade**, mas a configuração final depende de você. Algumas recomendações:

- **Rodar atrás de Tor e I2P**:
  - Use o `bitcoin.conf` fornecido como base.
  - Execute a função de instalação do Tor em `scripts/system.sh` (via menu "Ferramentas do Sistema").
- **Evite expor portas diretamente**:
  - Prefira acesso pela LAN ou via Tailscale VPN.
  - Se precisar de acesso externo, use HTTPS com certificados válidos e firewall bem configurado.
- **Backup seguro**:
  - Faça backup regular de:
    - `/home/bitcoin/.bitcoin` (ou diretório de dados que você usar).
    - `/home/lnd/.lnd` (inclui seed, macaroon, channels.db etc.).
    - Diretórios de dados de LNbits, LNDg e demais serviços, conforme sua configuração.
- **Segregação de usuários**:
  - Cada serviço roda com seu próprio usuário de sistema (bitcoin, lnd, lnbits, thunderhub etc.), reduzindo impacto de falhas.
- **Atualizações frequentes**:
  - O BRLN-OS pode configurar um cron para `git pull` automático do repositório.
  - Você também pode rodar `./brunel_new.sh update` periodicamente.

Privacidade é um processo contínuo; revise periodicamente sua superfície de ataque, portas abertas e dependências.

---

## 10. Atualização do sistema BRLN-OS

Para atualizar código e componentes gerenciados pelos scripts:

```bash
cd /caminho/para/brln-os
./brunel_new.sh update
```

Este comando:

- Dá `git pull` no repositório.
- Garante que dependências Python (API) estejam atualizadas.
- Atualiza e redeploya a interface web via Apache.
- Revalida permissões sudoers e cron de atualização.

---

## 11. Créditos, bibliografia e projetos relacionados

BRLN-OS integra ou se inspira em diversos projetos de software livre, entre eles:

- Gotty (terminal web): https://github.com/yudai/gotty
- Thunderhub (gerenciador LN): https://github.com/apotdevin/thunderhub
- Simple LNwallet (carteira leve): https://github.com/jvxis/simple-lnwallet-go
- LNbits (camada bancária sobre LN): https://github.com/lnbits/lnbits
- LNDg (dashboard para LND): https://github.com/cryptosharks131/lndg
- Balance of Satoshis (CLI admin LND): https://github.com/alexbosworth/balanceofsatoshis
- Bitcoin Core: https://github.com/bitcoin/bitcoin
- LND (Lightning Labs): https://github.com/lightningnetwork/lnd
- Tailscale VPN: https://github.com/tailscale/tailscale

Recomenda-se estudar a documentação oficial de cada projeto para entender limites, riscos e melhores práticas.

---

## 12. Contato e contribuição

- Telegram: https://t.me/pagcoinbr
- E-mail: suporte.brln@gmail.com | suporte@pagcoin.org
- Site do projeto: https://services.br-ln.com

Contribuições são bem-vindas:

- Faça fork do repositório, abra issues e envie Pull Requests.
- Sugestões de melhoria de segurança, privacidade e UX são especialmente valiosas.

---

## 13. Licença

Este projeto é licenciado sob a licença MIT. Veja o arquivo `LICENSE` para o texto completo.
