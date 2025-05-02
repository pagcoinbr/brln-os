# 📘 README - BRLN brunel.sh

> Instale e gerencie seu próprio node Bitcoin + Lightning com um script interativo, modular e soberano. Um projeto criado para empoderar brasileiros a rodarem sua infraestrutura financeira com liberdade total.

---

## 🧠 Visão Geral

O `brunel.sh` é um script Bash que automatiza a instalação completa de um node Bitcoin Lightning. Ele:

- Configura Bitcoin Core e LND (Lightning Network Daemon);
- Instala aplicativos web para gerenciamento como ThunderHub, LNbits e LNDg;
- Integra Balance of Satoshis (BOS) com Telegram;
- Fornece uma interface gráfica via navegador usando Gotty;
- Habilita privacidade com Tor, e acesso remoto seguro com Tailscale VPN;
- Permite uso de banco PostgreSQL ou Bbolt;
- Automatiza firewall UFW para segurança de rede;
- Gera serviços Systemd e interface Web com botões HTML + CGI;
- Roda em Ubuntu Server (22.04 ou 24.04).

---

## 📂 Estrutura Geral do Script

O script principal `brunel.sh` organiza sua lógica em funções. Vamos entender cada uma delas com detalhes:

---

### 1. `spinner()` - Indicador de progresso

Função que exibe um spinner animado e emojis ⚡ enquanto processos longos são executados. Ela monitora um processo em background e atualiza o terminal em tempo real com progresso visual. Ideal para longas instalações como o Tor, Tailscale ou pacotes NPM.

### 2. `menu()` - Menu principal interativo

Oferece ao usuário opções numeradas para instalações:
- Interface de rede (Tor, Tailscale, Apache);
- Bitcoin Core (bitcoind);
- LND (Lightning);
- Apps LN (ThunderHub, BOS, LNDg, LNbits);
- Manutenções e atualizações.

Usa `read` para capturar a escolha do usuário e chama a função correspondente.

---

## ⚙️ Serviços Systemd e Interface Web

### 3. `update_and_upgrade()` - Apache e CGI

- Instala Apache2 e ativa os módulos `cgid` e `dir`;
- Cria os diretórios CGI `/usr/lib/cgi-bin` e copia scripts `.sh` para lá;
- Copia HTML da interface para `/var/www/html`;
- Aplica permissões corretas para execução Web via `chmod +x`;
- Insere blocos de configuração CGI no `000-default.conf`;
- Gera o arquivo `sudoers` para `www-data` com acesso restrito aos scripts CGI.

### 4. `gotty_install()` - Interface terminal via navegador

- Detecta arquitetura (x86_64 ou arm);
- Baixa e extrai o binário do [gotty](https://github.com/yudai/gotty);
- Move para `/usr/local/bin/`;
- Instala serviços systemd para acesso a comandos gráficos:
  - gotty-fullauto.sh
  - gotty-logs-lnd
  - gotty-logs-bitcoind
  - gotty-btc-editor / gotty-lnd-editor
- Habilita portas no UFW (3131 a 3636) para uso interno via navegador.

### 5. `terminal_web()` - Valida usuário e reexecuta

- Garante que o script está sendo executado como `admin`;
- Se não estiver, relança como `sudo -u admin`.

---

## 🔒 Segurança de Rede e Acesso

### 6. `configure_ufw()`

- Força `IPV6=no`;
- Habilita UFW e adiciona regras:
  - Libera porta 22 apenas para a sub-rede `192.168.0.0/23`;
  - Libera portas 80, 5000, 3000, 8889, 35671, etc, apenas para LAN.

### 7. `tailscale_vpn()`

- Instala Tailscale via script oficial;
- Gera QR Code com link de ativação da rede segura.

---

## 🕵️ Privacidade com Tor

### 8. `install_tor()`

- Adiciona o repositório oficial do Tor;
- Instala `tor` e `i2pd` para conexões I2P;
- Verifica se as portas 9050 e 9051 estão ativas;
- Permite conexão onion no `bitcoind` e `lnd`.

---

## 🪙 Bitcoin & Lightning Core

### 9. `install_bitcoind()`

- Baixa e valida o binário do Bitcoin Core;
- Instala em `/usr/local/bin`;
- Copia o `bitcoin.conf` para `/data/bitcoin`;
- Cria symlink para `~/.bitcoin`;
- Gera `rpcauth` com script oficial;
- Ativa serviço systemd `bitcoind.service`.

### 10. `download_lnd()`

- Baixa a última versão do LND + arquivos de validação;
- Instala `lnd` e `lncli` em `/usr/local/bin`;
- Remove temporários e aplica GPG.

### 11. `configure_lnd()`

- Pergunta se o usuário vai usar node remoto ou local;
- Solicita `alias`, `rpcuser`, `rpcpass` e backend (bbolt ou postgres);
- Insere no `lnd.conf`;
- Aplica permissões para Tor, cria `/data/lnd`, configura `lnd.service`;
- Chama `create_wallet` ou orienta sincronização do Bitcoin.

### 12. `create_wallet()`

- Solicita senha e confirmação;
- Exibe instruções para anotar a frase de 24 palavras;
- Executa `lncli create` com path correto para `tls.cert.tmp`.

---

## 🧩 Instalação de Aplicativos LN

### 13. `install_bos()`

- Instala Node.js e NPM;
- Configura `~/.npm-global` e `~/.bos/credentials.json` com macaroon e tls codificados em base64;
- Instala BOS globalmente via `npm`;
- Ativa `bos-telegram.service`.

### 14. `install_thunderhub()`

- Clona o repositório Thunderhub;
- Gera `thubConfig.yaml` e `.env.local` com configuração do LND;
- Instala dependências NPM e inicia serviço `thunderhub.service`.

### 15. `install_lndg()`

- Clona repositório do LNDg;
- Instala dependências com `venv` + `pip`;
- Executa `initialize.py`;
- Ativa `lndg.service` e `lndg-controller.service`.

### 16. `lnbits_install()`

- Instala dependências Python + Poetry;
- Clona LNbits;
- Executa `poetry install` e cria `start-lnbits.sh`;
- Ativa `lnbits.service` via systemd.

---

## 📲 Outros recursos e utilidades

### 17. `simple_lnwallet()`

- Baixa binário do Simple LNWallet de acordo com a arquitetura;
- Copia serviço systemd `simple-lnwallet.service`;
- Gera arquivos `macaroon.hex` e `tls.hex` com `xxd`.

### 18. `config_bos_telegram()`

- Guia para criação do bot via BotFather;
- Roda `bos telegram` para gerar o `connection_code`;
- Substitui `ExecStart` no systemd;
- Reinicia serviço.

---

## 🔁 Atualizações e Manutenção

O script inclui:
- `lnd_update`
- `bitcoin_update`
- `thunderhub_update`
- `lndg_update`
- `lnbits_update`
- `pacotes_do_sistema`
- `*_uninstall` para cada app

Usados dentro de `menu_manutencao()` e acessados via submenu.

---

## 🛡 Requisitos

- Ubuntu Server 22.04 ou superior
- Usuário "admin" com sudo
- Pelo menos 8GB RAM e 32GB de armazenamento
- Acesso root ou sudo

---

## ✨ Filosofia do Projeto

> Aqui a gente acredita que soberania é: saber o que seu sistema está fazendo, conseguir auditar, adaptar e compartilhar.

Por isso usamos:
- Bash puro e CGI acessível via HTML
- Systemd nativo
- Tor e Tailscale para privacidade
- Interfaces gáficas e conexão com o Telegram.

---

## 💬 Contato

- Telegram: https://t.me/REDACTED_USERbr
- Email: suporte.brln@gmail.com ou suporte@REDACTED_USER.org
- Projeto: https://services.br-ln.com
- Colabore: Fork, PRs e ideias são bem-vindos!

---

## ⚠️ Licença

Este software é fornecido como está. Risco é seu, poder também. Use com consciência, ensine outro irmão de node, e nunca pare de aprender.

---

**#RunYourNode #Verifique #Desobedeça #Automatize**

