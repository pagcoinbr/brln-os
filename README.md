# 🚀 Instalação Passo a Passo - BR⚡LN Bolt
# Lightning Node Bootstrap

![Tela principal](https://github.com/user-attachments/assets/efbed0d2-5199-4e21-8d10-40bb742b5ef7)

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

💡 Esse script vai:
- Criar o usuário `admin`
- Iniciar o script principal `brunel.sh`
- Apresentar o menu gráfico interativo.

**ATENÇÃO!** Após a criação do usuário `admin`, o script vai finalizar da seguinte maneira:

![Captura de tela 2025-04-21 141434](https://github.com/user-attachments/assets/419765f3-83ab-45ca-863e-f5d45c3c7651)

### . 🌐 Agora Acesse a Interface Gráfica

Após a instalação inicial, acesse via navegador:
```bash
http://<seu_ip_local> ou http://<seu_ip_tailscale>
```

---

No menu de botões escolha: ⚡ BRLN Node Manager.

### 3. 🧭 Use o Menu Interativo

O script exibe um menu com várias opções. Siga a ordem de cima pra baixo:

```bash
   1 - Instalar Interface de Rede e Gráfica
   2 - Instalar Bitcoin Core ( bitcoind )
   3 - Instalar LND e criar a carteira
   4 - Instalar Simple LNWallet
   5 - Instalar Thunderhub + Balance of Satoshis
   6 - Instalar LNDG
   7 - Instalar LNbits
   8 - Mais opções ( Atualizações, Telegram )
```

💬 Durante a instalação, o script vai perguntar:
- Se você quer exibir os logs ("y" para ver o que acontece por trás, "n" para uma instalação mais limpa.)
** É sabido que alguns sistemas podem travar durante a instalação sem logs, dê preferência por ver os logs**
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

### 6. 🤖 Ative o BOS Telegram

O script inclui um assistente para configurar o bot BOS Telegram:
1. Crie seu bot via @BotFather no Telegram
2. Rode `bos telegram` no "Terminal Web"
3. Execute a opção "8" do Node Manager
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

- **Teve algum problema? Até agora, se você não depositou nenhum fundo e não está conseguindo progredir pois fez alguma coisa errada? Basta reiniciar o processo formatando a máquina e fazendo a instalação do ubuntu, novamente.**

---
![ChatGPT Image 21 de abr  de 2025, 02_47_48](https://github.com/user-attachments/assets/cabf3db7-8b91-4289-8078-49f78444d7b4)
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

## 💬 Contato

- Telegram: https://t.me/pagcoinbr
- Email: suporte.brln@gmail.com ou suporte@pagcoin.org
- Projeto: https://services.br-ln.com
- Colabore: Fork, PRs e ideias são bem-vindos!
