# ⚡ BR⚡LN Bolt - Seu Node Lightning com Interface Web

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

[![photo-2025-04-01-13-21-50.jpg](https://i.postimg.cc/5tGrFMLh/photo-2025-04-01-13-21-50.jpg)](https://postimg.cc/JyNx9vTx)

---

## 🚀 Instalação passo a passo

### 1. 📥 Instale o Ubuntu Server 24.04

- Faça o download em: https://ubuntu.com/download/server
- Grave a ISO em um pendrive com [Balena Etcher](https://etcher.io) ou [Rufus](https://rufus.ie)
- Instale com as opções padrões, **ativando o OpenSSH Server** quando solicitado

### 2. 🧑 Crie o usuário TEMP durante a instalação

Durante a instalação inicial:

- Nome: `temp`
- Hostname: `brlnbolt`
- Usuário: `temp`
- Senha: escolha a sua

Após o primeiro login, fazendo o ssh com o ip atual da maquina como explicado asseguir, siga com os próximos comandos para criar o usuário final.

Fazendo a primeira conexão via SSH:

## 🔐 O que é SSH?

**SSH (Secure Shell)** é um protocolo que permite **acessar e controlar outro computador pela rede, de forma segura**, usando criptografia.

### 🧠 Em outras palavras:
Com o SSH, você pode **entrar no terminal de outro computador**, como se estivesse sentado na frente dele, mesmo que ele esteja do outro lado do mundo 🌍.

## 💡 Exemplo prático:
Se seu node BR⚡LN Bolt está na rede local com IP `192.168.1.100`, você pode acessá-lo com:

```bash
ssh temp@192.168.1.100 <- coloque seu ip aqui.
```

Depois disso, você verá o terminal do seu node, podendo controlar tudo por lá.

 Para encontrar o ip da sua máquina na rede local, faça o comando ->
```
ip a
```
Você verá uma saída parecida com essa:
```
enp4s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether e8:9c:25:7c:0b:8e brd ff:ff:ff:ff:ff:ff
    inet 192.168.0.104/24 metric 100 brd 192.168.0.255 scope global enp4s0 <- **Seu ip está aqui.**
       valid_lft forever preferred_lft forever
    inet6 fe80::ea9c:25ff:fe7c:b8e/64 scope link 
       valid_lft forever preferred_lft forever
```
No caso, o ip é `192.168.0.104`, então o comando para fazer ssh será:

```bash
ssh temp@192.168.0.104 <- coloque seu ip aqui.
```

---

### 3. 👤 Crie o usuário `admin`
ATENÇÃO! Apenas é necessário 1 destes comandos, caso ele permita você criar e solicite escolher a nova senha do usuário admin, você já pode passar para a próxima etapa.

Entre com o usuário `temp` e execute:

```bash
sudo adduser --gecos "" admin
```
Caso receba o erro: `fatal: The group 'admin' already exists.`, você precisa fazer:

```bash
sudo adduser --gecos "" --ingroup admin admin
```

Caso ainda receba o mesmo erro, tente:
```bash
sudo passwd admin
```

ATENÇÃO! Apenas é necessário 1 destes comandos, caso ele permita você criar e solicite escolher a nova senha do usuário admin, você já pode passar para a próxima etapa.

```bash
sudo usermod -aG sudo,adm,cdrom,dip,plugdev,lxd admin
```

Depois, troque para o usuário `admin`:

```bash
sudo su - admin
```

E remova o usuário temporário:

```bash
sudo userdel -rf temp
```

---

### 4. 📦 Instale o BR⚡LN Bolt

Clone o projeto:

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
Instalação Automática
1 - Instalação do BR⚡LN Bolt (Tor + LND + BTCd + Ferramentas)

Instalação Manual
2 - Instalar Rede + Interface (Obrigatório para as opções 2-8)
3 - Instalar Bitcoin Core (Tor + BTCd)
4 - Instalar Lightning Daemon/LND - Exige Bitcoin Core Externo
5 - Instalar Balance of Satoshis (Exige LND)
6 - Instalar Thunderhub (Exige LND)
7 - Instalar Lndg (Exige LND)
8 - Instalar LNbits
9 - Tailscale VPN
0 - Sair
```

> **Recomendado**: use a opção **1** para instalar tudo automaticamente. Apesar de ela não contemplar a vpn e o lnbits, que podem ser instalados a parte escolhendo a opção 8 e 9.

---

## 🖥️ Acesse o painel via navegador

Depois da instalação, acesse:

```
http://192.168.0.104 <- coloque seu ip aqui.
```

Você verá botões para acessar:

- Thunderhub
- LNDg
- LNbits
- AMBOSS
- MEMPOOL
- Configurações

[![photo-2025-04-01-13-21-50.jpg](https://i.postimg.cc/5tGrFMLh/photo-2025-04-01-13-21-50.jpg)](https://postimg.cc/JyNx9vTx)
Imagem 1 - Menu principal do BR⚡LN Bolt

Se conseguiu acessar a interface gráfica, seu node está quase pronto, basta realizar mais algumas etapas para configurar a conexão com o telegram, assim podendo acompanhar todos os eventos que acontecem no seu node.

## Ao final da instalação, volte no terminal para recarregar/atualizar a sessão atual. Para isso, de o seguinte comando:
```bash
. ~/.profile
```
Em seguida continue para a configuração do *bos telegram*.
---

## 🔐 Configurar seu Telegram para alertas

Primeiramente acesse a loja do seu smartphone e instale o app do Telegram e crie uma conta, caso você não tenha:
- [Play store](https://play.google.com/store/apps/details?id=org.telegram.messenger&hl=pt_BR&pli=1)
- [Apple store](https://apps.apple.com/br/app/telegram-messenger/id686449807)

1. No Telegram, pesquise: [@BotFather](https://t.me/BotFather)
2. Crie seu bot com o comando `/newbot`, copie a API token exibida na mensagem e acesse o link no topo da mensagem para abrir o chat com seu novo bot recém criado. 
[![Captura-de-tela-2025-04-01-132927.png](https://i.postimg.cc/9fyhVp45/Captura-de-tela-2025-04-01-132927.png)](https://postimg.cc/8Fk3mLBt)
Imagem 2 - Exemplo de criação de bot no telegram

3. Em seguida no terminal, digite:
```bash
bos telegram
```
4. Cole a APItoken fornecido pelo BotFathter do Telegram, no terminal, e pressione ` Enter `.

*ATENÇÃO!* A API token não é exibida quando colada na tela, preste atenção para não colar duas vezes ou você pode obter um erro ao final do processo, se isso acontecer, basta começar novamente o processo do comando `bos telegram`.

5. Volte para o bot recém criado no telegram e envie o seguinte comando: `/start ` e depois `/connect`.
6. Ele vai te responder algo como: `🤖 Connection code is: ########`
7. Cole o Connection code no terminal e pressione *enter* novamente. Se tudo estiver correto você vai receber uma resposta `🤖 Connected to <nome do seu node>` no chat do novo bot. Agora, volte para o terminal e pressione *Ctrl + C* para sair da execução do comando, você já pode seguir para o próximo passo.

Para iniciar o serviço automaticamente e manter ele rodando em segundo plano, vamos inserir o connection code no arquivo de serviço com o comando:

```bash
sudo nano -l +12 /etc/systemd/system/bos-telegram.service
```

Vá até o fim da linha e apague *<seu_connect_code_aqui>* (removendo também as chaves <>) e coloque no lugar o **Connection code** obtido no seu bot do telegram. Saia salvando com *Ctrl + X*, pressione *y* e depois *Enter* para confirmar.

[![Captura-de-tela-2025-04-01-151857.png](https://i.postimg.cc/wMjvYdvG/Captura-de-tela-2025-04-01-151857.png)](https://postimg.cc/xJBYLhLv)
Imagem 3 - Exemplo da alteração do arquivo de serviço do bos telegram.

Agora de o seguintes comandos, para reiniciar o serviço:
```bash
systemctl daemon-reload
```

```bash
sudo systemctl enable bos-telegram
sudo systemctl start bos-telegram
```
Pronto, agora você receberá novamente a mensagem `🤖 Connected to <nome do seu node>` se tudo tiver corrido bem.
---

## ⚠️ Corrigir `lnd.conf` se necessário

Se errou alguma configuração, como a senha do bitcoind, edite com:

```bash
nano /data/lnd/lnd.conf
```

Depois reinicie o LND:

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

## 🛰️ Use Tailscale VPN (acesso remoto)

Para acessar seu node de qualquer lugar, intale a opção 9, ao final será exibido um qr code.

Escaneie o QR code no app de câmera do seu celular, isso vai te levar ao site de login do Tailscale, faça login no navegador com email ou entre com sua conta Google.  
Baixe o app para [Android](https://play.google.com/store/apps/details?id=com.tailscale.ipn) ou [iOS](https://apps.apple.com/us/app/tailscale/id1470499037).

Em seguida, basta copiar o IPV4 no app do tailscale e colar no seu navegador. Pronto, seu node pode ser acessado até mesmo fora de casa!

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