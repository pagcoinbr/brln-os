# BR⚡LN Bolt - Seu Node Lightning Standalone com Interface Web

Bem-vindo ao **BR⚡LN Bolt**, um projeto da comunidade **BR⚡️LN - Brasil Lightning Network**, voltado para facilitar a instalação e administração de nós Lightning com uma interface simples, intuitiva e acessível diretamente pelo navegador.

---

## 🌎 Quem somos

A **BR⚡LN** é uma comunidade brasileira comprometida com a educação, adoção e soberania no uso do Bitcoin e da Lightning Network. Nosso objetivo é **empoderar indivíduos e empresas** com ferramentas fáceis de usar, sempre com foco em descentralização e privacidade.

---

## 🧰 O que é o BR⚡LN Bolt?

O **BR⚡LN Bolt** é um conjunto de scripts automatizados que instala:

- ⚡ Lightning Daemon (LND)
- ₿ Bitcoin Core (bitcoind)
- 🔒 Tor
- 📊 Thunderhub
- 📬 LNDg
- 🧪 LNbits
- ⚙️ Painel web interativo
- 🤖 Integração com Telegram via BOS

[![Captura-de-tela-2025-04-03-232915.png](https://i.postimg.cc/ZYH8DC3b/Captura-de-tela-2025-04-03-232915.png)](https://postimg.cc/G9BT43qV)

---

## 🚀 Instalação passo a passo

### 1. 📥 Instale o Ubuntu Server 24.04

- Faça o download em: https://ubuntu.com/download/server
- Grave a ISO em um pendrive com [Balena Etcher](https://etcher.io) ou [Rufus](https://rufus.ie)
- Instale com as opções padrões, **ativando o OpenSSH Server** quando solicitado.

Após o primeiro login, estabeleça a conexão SSH com o IP atual da máquina, conforme explicado abaixo.

## 🔐 O que é SSH?

**SSH (Secure Shell)** é um protocolo que permite **acessar e controlar outro computador pela rede, de forma segura**, usando criptografia.

### 🧠 Em outras palavras:
Com o SSH, você pode **entrar no terminal de outro computador**, como se estivesse sentado na frente dele, mesmo que ele esteja do outro lado do mundo 🌍.

## 💡 Exemplo prático:
Seu node BR⚡LN Bolt, que está na rede local, deve ter um IP parecido com este `192.168.1.104`. Se você já souber o IP da rede interna da sua casa, você pode acessá-lo com:

```bash
ssh temp@192.168.1.104 <- coloque seu IP aqui.
```
O IP da sua máquina está apontado no script:
```bash


No caso, o IP é `192.168.0.104`, então o comando para fazer SSH será:

```bash
ssh temp@192.168.0.104 <- coloque seu IP aqui.
```

---

### 4. 📦 Instale o BR⚡LN Bolt

Clone o projeto, copie e cole todos os comandos juntos:

```bash
git clone https://github.com/pagcoinbr/brlnfullauto.git
cd brlnfullauto
chmod +x brlnfullauto.sh
./brlnfullauto.sh
```

---

## 🧭 Como usar o menu

Você verá um menu com as seguintes opções:

```bash
🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟

⚡ Este Sript Instalará um Node Lightning Standalone
  🛠️ Bem vindo ao seu novo banco, ele é BRASILEIRO. 

📝 Escolha uma opção:

   1- Instalar Tor + nodejs + firewall
   2- Instalar LND & criar carteira
   3- Instalar Bitcoin Core

3- Estas são as opções de instalação de aplicativos de administração:

   4- Instalar Balance of Satoshis (Exige LND)
   5- Instalar Thunderhub (Exige LND)
   6- Instalar Lndg (Exige LND)
   7- Instalar LNbits
   8- Instalar Tailscale VPN
   9- Mais opções
   0- Sair

👉 Digite sua escolha:
```
Como é o processo de criação das 24 palavras?
O processo é feito usando o próprio criador integrado com o lnd. Abaixo você pode ver como o processo se passa durante o passo 2 do lnd, usando um bitcoin remoto da BRLN para a primeira conexão, enquanto seu bitcoin core ainda está sincronizando.
```bash
################################################################
 A seguir você será solicitado a adicionar suas credenciais do 
 bitcoind.rpcuser e bitcoind.rpcpass, caso você seja membro da BRLN.
 Caso você não seja membro, escolha a opção não e prossiga.
################################################################

Você deseja utilizar o bitcoind da BRLN? (yes/no): yes
 Você escolheu usar o bitcoind remoto da BRLN! 
Digite o bitcoind.rpcuser(BRLN): meu_user_BRLN
Digite o bitcoind.rpcpass(BRLN): minha_senha_BRLN
############################################################################################### 
Agora Você irá criar sua FRASE DE 24 PALAVRAS, digite a senha de desbloqueio do lnd, depois repita mais 2x para registra-la no lnd e pressione 'n' para criar uma nova carteira. 
apenas pressione ENTER quando questionado se quer adicionar uma senha a sua frase de 24 palavras.
AVISO!: Anote sua frase de 24 palavras com ATENÇÃO, AGORA! Esta frase não pode ser recuperada no futuro se não for anotada agora. 
Se voce não guardar esta informação de forma segura, você pode perder seus fundos depositados neste node, permanentemente!!!
############################################################################################### 
Digite sua senha de desbloqueio automático do lnd: 97629073
Created symlink /etc/systemd/system/multi-user.target.wants/lnd.service → /etc/systemd/system/lnd.service.
Input wallet password: 
Confirm password: 
Passwords don't match, please try again

Input wallet password: 
Confirm password: 

Do you have an existing cipher seed mnemonic or extended master root key you want to use?
Enter 'y' to use an existing cipher seed mnemonic, 'x' to use an extended master root key 
or 'n' to create a new seed (Enter y/x/n): n

Your cipher seed can optionally be encrypted.
Input your passphrase if you wish to encrypt it (or press enter to proceed without a cipher seed passphrase): 

Generating fresh cipher seed...

!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!

---------------BEGIN LND CIPHER SEED---------------
 1. abstract   2. gold      3. wrong     4. salute 
 5. region     6. letter    7. leg       8. supreme
 9. guilt     10. witness  11. flock    12. ridge  
13. orient    14. car      15. swarm    16. traffic
17. correct   18. tower    19. refuse   20. reward 
21. crane     22. cup      23. disease  24. hard   
---------------END LND CIPHER SEED-----------------

!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!

lnd successfully initialized!
```

Imagem da criação da carteira no passo 2 do script.

---

## 🖥️ Acesse o painel via navegador

Depois da instalação, acesse:

```
http://192.168.0.104 <- coloque seu IP aqui.
```

Você verá botões para acessar:

- Thunderhub
- LNDg
- LNbits
- AMBOSS
- MEMPOOL
- Configurações

[![Captura-de-tela-2025-04-03-232915.png](https://i.postimg.cc/ZYH8DC3b/Captura-de-tela-2025-04-03-232915.png)](https://postimg.cc/G9BT43qV)
Imagem 1 - Menu principal do BR⚡LN Bolt

Se conseguiu acessar a interface gráfica, seu node está quase pronto. Basta realizar mais algumas etapas para configurar a conexão com o Telegram, assim podendo acompanhar todos os eventos que acontecem no seu node.

---

## ⚠️ Corrigir `lnd.conf` se necessário

Se errou alguma configuração, como a senha do bitcoind, edite com:

```bash
nano /data/lnd/lnd.conf
```

Depois, reinicie o LND:

```bash
sudo systemctl restart lnd
```

---

## ✅ Verifique se está tudo certo

Execute:

```bash
lncli getinfo
```

Você deve ver o status do seu node Lightning rodando!

---

## Ao final da instalação, volte no terminal para recarregar/atualizar a sessão atual. Para isso, dê o seguinte comando:
```bash
. ~/.profile
```
Em seguida, continue para a configuração do *bos telegram*.
---

## 🔐 Configurar seu Telegram para alertas

Primeiramente, acesse a loja do seu smartphone e instale o app do Telegram e crie uma conta, caso você não tenha:
- [Play store](https://play.google.com/store/apps/details?id=org.telegram.messenger&hl=pt_BR&pli=1)
- [Apple store](https://apps.apple.com/br/app/telegram-messenger/id686449807)

1. No Telegram, pesquise: [@BotFather](https://t.me/BotFather)
2. Crie seu bot com o comando `/newbot`, copie a API token exibida na mensagem e acesse o link no topo da mensagem para abrir o chat com seu novo bot recém-criado. 
[![Captura-de-tela-2025-04-01-132927.png](https://i.postimg.cc/9fyhVp45/Captura-de-tela-2025-04-01-132927.png)](https://postimg.cc/8Fk3mLBt)
Imagem 2 - Exemplo de criação de bot no Telegram

3. Em seguida, no terminal, digite:
```bash
bos telegram
```
4. Cole a API token fornecida pelo BotFather do Telegram no terminal e pressione `Enter`.

*ATENÇÃO!* A API token não é exibida quando colada na tela. Preste atenção para não colar duas vezes ou você pode obter um erro ao final do processo. Se isso acontecer, basta começar novamente o processo do comando `bos telegram`.

5. Volte para o bot recém-criado no Telegram e envie o seguinte comando: `/start` e depois `/connect`.
6. Ele vai te responder algo como: `🤖 Connection code is: ########`
7. Cole o Connection code no terminal e pressione *Enter* novamente. Se tudo estiver correto, você vai receber uma resposta `🤖 Connected to <nome do seu node>` no chat do novo bot. Agora, volte para o terminal e pressione *Ctrl + C* para sair da execução do comando. Você já pode seguir para o próximo passo.

Para iniciar o serviço automaticamente e mantê-lo rodando em segundo plano, vamos inserir o connection code no arquivo de serviço com o comando:

```bash
sudo nano -l +12 /etc/systemd/system/bos-telegram.service
```

Vá até o fim da linha e apague *<seu_connect_code_aqui>* (removendo também as chaves <>) e coloque no lugar o **Connection code** obtido no seu bot do Telegram. Saia salvando com *Ctrl + X*, pressione *y* e depois *Enter* para confirmar.

[![Captura-de-tela-2025-04-01-151857.png](https://i.postimg.cc/wMjvYdvG/Captura-de-tela-2025-04-01-151857.png)](https://postimg.cc/xJBYLhLv)
Imagem 3 - Exemplo da alteração do arquivo de serviço do bos telegram.

Agora, dê os seguintes comandos para reiniciar o serviço:
```bash
systemctl daemon-reload
```

```bash
sudo systemctl enable bos-telegram
sudo systemctl start bos-telegram
```
Pronto, agora você receberá novamente a mensagem `🤖 Connected to <nome do seu node>` se tudo tiver corrido bem.

---

## 🛰️ Use Tailscale VPN (acesso remoto)

Para acessar seu node de qualquer lugar, instale a opção 9. Ao final, será exibido um QR code. Caso receba um erro ao receber encontrar o link, realize a opção 9 novamente. Isso provavelmente vai funcionar.

Escaneie o QR code no app de câmera do seu celular. Isso vai te levar ao site de login do Tailscale. Faça login no navegador com email ou entre com sua conta Google.  
Baixe o app para [Android](https://play.google.com/store/apps/details?id=com.tailscale.ipn) ou [iOS](https://apps.apple.com/us/app/tailscale/id1470499037).

Em seguida, basta copiar o IPV4 no app do Tailscale e colar no seu navegador. Pronto, seu node pode ser acessado até mesmo fora de casa!

---

## 🤝 Suporte e Comunidade

- Site: https://services.br-ln.com
- Email: suporte.brln@gmail.com

---

## ⚡ Vamos rodar um node soberano!

Com o BR⚡LN Bolt, você tem controle, praticidade e soberania.  
Com a Lightning Network, você faz parte da revolução monetária global.

**Seja bem-vindo à descentralização!** ⚡🇧🇷

---

> Feito com amor pela comunidade BR⚡LN.  
> Compartilhe, instale, rode e nos ajude a construir um futuro livre!
