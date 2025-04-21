# 🚀 Instalação Passo a Passo - BR⚡LN Bolt

### 1. 🖥️ Instale o Ubuntu Server (Recomendado: 24.04 LTS)

Prepare o terreno:
- Baixe o Ubuntu Server: https://ubuntu.com/download/server
- Grave a ISO em um pendrive usando [Balena Etcher](https://etcher.io) ou [Rufus](https://rufus.ie)
- Durante a instalação, ative o **OpenSSH Server** (importantíssimo para acessar seu node pela rede)
- Durante a escolha de disco desative a opção de **usar como LVM**.

👉 Após a instalação, conecte via SSH usando o IP local do seu node. Exemplo:
```bash
ssh admin@192.168.1.104
```
Se não souber o IP:
- Ele aparece na tela do Ubuntu após o login
- Ou use um app de scan de rede como Fing

---

### 2. ⚡ Inicie o Instalador FullAuto

Execute um comando:
```bash
bash <(curl -s https://raw.githubusercontent.com/pagcoinbr/brlnfullauto/main/run.sh)
```

[![Captura-de-tela-2025-04-21-132716.png](https://i.postimg.cc/L5RwGBsr/Captura-de-tela-2025-04-21-132716.png)](https://postimg.cc/8JKZ6vMH)

💡 Esse script vai:
- Criar o usuário `admin`
- Iniciar o script principal `brlnfullauto.sh`
- Apresentar o menu gráfico interativo.

**ATENÇÃO!** Após a criação do usuário `admin`, você será desconectado. Faça login novamente com:
```bash
ssh admin@<seu_ip_local>
```
E repita o comando de instalação acima.

---

### 3. 🧭 Use o Menu Interativo

O script exibe um menu com várias opções. Siga a ordem de cima pra baixo:

```bash
   1 - Instalar Interface de Rede e Gráfica
   2 - Instalar Bitcoin Core (bitcoind)
   3 - Instalar LND e criar a carteira
   4 - Instalar Simple LNWallet
   5 - Instalar Thunderhub + Balance of Satoshis
   6 - Instalar LNDG
   7 - Instalar LNbits
   8 - Mais opções (VPN, atualizações, Telegram)
```

💬 Durante a instalação, o script vai perguntar:
- Se você quer exibir os logs ("y" para ver o que acontece por trás, "n" para uma instalação mais limpa.)
- Se quer usar o Bitcoin remoto da BRLN ou o local
- Qual nome dar para o seu node Lightning
- Se prefere PostgreSQL ou Bbolt como banco de dados

---

### 4. 🔐 Criação da Wallet Lightning (24 palavras)

Ao instalar o LND (passo 3), o script te guiará para:
- Inserir usuário e senha do bitcoind
- Escolher entre usar o Bitcoin da BRLN ou o local
- Criar a senha do LND (confirmar duas vezes)
- Gerar uma nova seed de 24 palavras

🧠 **IMPORTANTE:** Anote suas 24 palavras com muito carinho e guarde em local seguro. Sem elas, seus fundos podem ser perdidos PARA SEMPRE.

---

### 5. 🌐 Acesse a Interface Gráfica

Após instalar os aplicativos, acesse via navegador:
```bash
http://<seu_ip_local>
```

Você verá um painel com botões para:
- Thunderhub
- LNDg
- LNbits
- Simple LNWallet
- Logs do sistema
- Configurações avançadas

💡 Todos os botões abrem aplicações ou scripts CGI usando o terminal via Gotty (interface web de terminal).

---

### 6. 🤖 Ative o BOS Telegram

O script inclui um assistente para configurar o bot BOS Telegram:
1. Crie seu bot via @BotFather no Telegram
2. Rode `bos telegram` no terminal
3. Cole o token do bot
4. Envie `/start` e `/connect` no Telegram
5. Copie o Connection Code e insira no terminal

⚙️ O script atualiza automaticamente o `bos-telegram.service` com seu código e ativa o bot como serviço systemd.

---

### 7. 🛰️ Ative o Acesso VPN com Tailscale

Via menu > opção VPN:
- Instala o Tailscale
- Gera QR Code com link de login
- Permite que você acesse seu node de qualquer lugar do mundo

📱 Baixe o app do Tailscale no celular e escaneie o QR code. Pronto, seu node virou seu parceiro de viagem!

---

## 📚 Bibliografia e Repositórios Utilizados

Esses são os projetos e repositórios que inspiraram ou foram integrados no BR⚡LN Bolt:

- **Gotty (Terminal Web):** https://github.com/yudai/gotty
- **Thunderhub (Gerenciador LN):** https://github.com/apotdevin/thunderhub
- **Simple LNwallet (Carteira leve):** https://github.com/jvxis/simple-lnwallet-go
- **LNbits (Camada bancária sobre LN):** https://github.com/lnbits/lnbits
- **LNDG (Dashboard com insights e rebalanceamento):** https://github.com/cryptosharks131/lndg
- **Balance of Satoshis (Admin CLI para LND):** https://github.com/alexbosworth/balanceofsatoshis
- **Bitcoin Core:** https://github.com/bitcoin/bitcoin
- **LND - Lightning Labs:** https://github.com/lightningnetwork/lnd
- **Tailscale VPN:** https://github.com/tailscale/tailscale

---

