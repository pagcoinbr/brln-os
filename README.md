# BRLN Bolt

<div align="center">
  <a href="https://postimg.cc/hfpCPVwd">
    <img src="https://i.postimg.cc/JzWSxq5P/Logo-Branco.png" alt="Logo-Branco.png" />
  </a>
</div>

Este tutorial aborda a instalação rápida de um nó Lightning (segunda camada do Bitcoin) utilizando a conexão RPC (Remote Procedure Call), permitindo a abertura dos primeiros canais em menos de 30 minutos. Para acessar este serviço, os membros do BRLN devem realizar o cadastro por meio do bot oficial [BRLN Server Bot](https://t.me/brlnbtcserver_bot), utilizando o comando /generate para obter as credenciais de acesso. Este serviço é oferecido separadamente, com condições especiais para os membros do BR⚡️LN. Porém caso você já tenha, este script pode ser utilizado para criação do seu node lnd com um bitcoin core na rede local ou mesmo na máquina local, de graça!

---
## Instalando o Ubuntu Server 24.04 - (Obrigatório)

**Passos para instalação:**
Baixar a imagem do Ubuntu Server: Acesse o site oficial [Clicando aqui](https://ubuntu.com/download/server) e faça o download da imagem ISO correspondente a versão do Ubuntu Server 24.04.

Criar um pendrive de boot: Utilize o **Balena Etcher**, **Rufus** ou outro software de sua preferência para gravar a imagem ISO no pendrive.

**Instalação do sistema:**

Inicie o computador a partir do pendrive e siga os passos para instalar o Ubuntu Server.
Durante a instalação, certifique-se de marcar a opção `[x] OpenSSH Server` para habilitar o acesso remoto ao servidor via SSH.

**Configuração de credenciais:**
Quando solicitado a inserir as credenciais de login, use as seguintes informações:

Nome: `temp`

Nome do servidor: `brlnbolt`

Usuário: `temp`

Senha: Escolha uma senha de sua preferência.

---
## Preparando o sistema - (Obrigatório)

**Finalização da instalação:**

Após concluir a instalação, realize o reboot e remova o pendrive.
Caso uma mensagem de erro seja exibida no boot, pressione `Enter` para continuar.
Agora, sem o pendrive conectado, o sistema deve inicializar corretamente.

Agora vamos criar o usuário admin, para isso, de o seguinte comando: 

```bash
sudo adduser --gecos "" admin
```

Ele vai te pedir a senha atual, que você escolheu na instalação do sistema e em seguida digite duas vezes a nova senha para o usuário admin, que estamos criando. 

Depois copie e cole no terminal:
```bash
sudo usermod -a -G sudo,adm,cdrom,dip,plugdev,lxd admin
```

Em seguida faça o `logout` ou `exit` para retornar ao usuário `temp`

Agora que criamos um novo usuário "admin", vamos fazer o login neste novo usuário, novamente e apagar o usuário "temp" anterior.

Mais uma vez faça o comando, agora com o user admin:
```bash
ssh admin@ip.do.servidor
```

Uma vez logado, de o seguinte comando: 

```bash
sudo userdel -rf temp
```
Você receberá uma mensagem de erro de `not found`, ou algo semelhante, se tudo correr bem.

---

## Instalação do Lightning Network Daemon (lnd) - (Obrigatório)

Até agora fizemos a parte mais dificil que não pode ser automatizada por scripts, de agora em diante você vai seguir este passo a passo:

Primeiro de o seguinte comando, para clonar o repositório:
```bash
git clone https://github.com/REDACTED_USERbr/brlnfullauto.git
```

Agora acesse o diretório copiado, com o seguinte comando:
```bash
cd brlnfullauto
```

Execute o seguinte comando para aplicar as permissões necessárias ao programa:
```bash
chmod +x brlnfullauto.sh
```
Em seguida, execute o programa com o seguinte comando:
```bash
./brlnfullauto.sh
```
---
As credenciais que são solicitadas neste script, podem ser adquiridas pelo nosso plano mensal de conexão segura por rpc para um bitcoind externo permitindo já fazer as primeiras configurações do seu nó, antes do término do download da blockchain. Após realizar a associação em https://br-ln.com.br, acesse o bot: https://t.me/brlnbtcserver_bot

Envie a mensagem:

```bash
\linkemail <seu@email.com>
```

```bash
\generate <usuário>
```

**Selecione a opção numero 1 e inicie a intalação preenchendo com os dados solicitados**

```bash
admin@brlnbolt:~$ ./brln.sh
🌟 Bem-vindo à instalação de node Lightning personalizado da BRLN! 🌟

⚡ Este script instalará:
  🛠️ Nó Lightning Standalone
  🏗️ Bitcoin Core
  🖥️ Ferramentas de administração:
    - ThunderHub
    - Balance of Satoshis (BOS)
    - LNDG

📝 Escolha uma opção:
   1- Instalação do BRLN Bolt
   2- Alterne Bitcoin Local/Remoto
   0- Sair

👉 Digite sua escolha: 1
🚀 Iniciando a instalação...
Digite a senha para ThunderHub: <senha_thunderhub>
Digite o alias: <nome_do_seu_nó>
Digite o bitcoind.rpcuser: <rpc_user_BRLN_aqui>
Digite o bitcoind.rpcpass: <sua_senha_BRLN_aqui>
Escolha sua senha do Bitcoin Core: <senha_rpcauth>
```
---

Caso você tenha errado alguma credencial voce pode corrigi-la após a instalação editando o arquivo de configuração com o seguinte comando:
```bash
nano -l +66 /data/lnd/lnd.conf
```
Saia do modo de edição digitando: `CTRL + X` e se você fez alterações no arquivo, digite ` Y ` para salvar, e reinicie o serviço:
```bash
sudo systemctl restart lnd
```
---

Veja o estado do serviço com o seguinte comando:

```bash
sudo systemctl status lnd.service
```

**Exemplo de resultado esperado:**

```bash
admin@minibolt:~$ sudo systemctl status lnd.service
[sudo] password for admin:
● lnd.service - Lightning Network Daemon
     Loaded: loaded (/etc/systemd/system/lnd.service; enabled; preset: enabled)
     Active: active (running) since Tue 2024-09-10 02:03:49 UTC; 1 week 0 days ago
   Main PID: 124698 (lnd)
     Status: "Wallet unlocked"
      Tasks: 23 (limit: 38229)
     Memory: 145.6M (peak: 286.0M)
        CPU: 1h 30min 4.458s
     CGroup: /system.slice/lnd.service
             └─124698 /usr/local/bin/lnd

Sep 17 20:57:49 minibolt lnd[124698]: 2024-09-17 20:57:49.843 [INF] WTCL: (anchor) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 20:58:49 minibolt lnd[124698]: 2024-09-17 20:58:49.844 [INF] WTCL: (legacy) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 20:58:49 minibolt lnd[124698]: 2024-09-17 20:58:49.844 [INF] WTCL: (taproot) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquire>
Sep 17 20:58:49 minibolt lnd[124698]: 2024-09-17 20:58:49.844 [INF] WTCL: (anchor) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 20:59:49 minibolt lnd[124698]: 2024-09-17 20:59:49.843 [INF] WTCL: (legacy) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 20:59:49 minibolt lnd[124698]: 2024-09-17 20:59:49.843 [INF] WTCL: (taproot) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquire>
Sep 17 20:59:49 minibolt lnd[124698]: 2024-09-17 20:59:49.843 [INF] WTCL: (anchor) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 21:00:49 minibolt lnd[124698]: 2024-09-17 21:00:49.843 [INF] WTCL: (taproot) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquire>
Sep 17 21:00:49 minibolt lnd[124698]: 2024-09-17 21:00:49.843 [INF] WTCL: (legacy) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
Sep 17 21:00:49 minibolt lnd[124698]: 2024-09-17 21:00:49.843 [INF] WTCL: (anchor) Client stats: tasks(received=0 accepted=0 ineligible=0) sessions(acquired>
lines 1-21/21 (END)
```

Agora você já deve estar pronto para ver as informações do seu node com o seguinte comando: 

 ```bash
lncli getinfo
```

#Ao final da instalação você precisa recarregar a sessão. Para isso, de o seguinte comando:
```bash
. ~/.profile
```

#Alternativamente, você pode sair da sessão com ` exit ` e logar novamente.

### Agora vamos criar um **bot** para poder monitorar o node pelo Telegram.

Primeiramente acesse a loja do seu smartphone e instale o app do Telegram:
- [Play store](https://play.google.com/store/apps/details?id=org.telegram.messenger&hl=pt_BR&pli=1)
- [Apple store](https://apps.apple.com/br/app/telegram-messenger/id686449807)

Agora acesse a ferramenta de criação de bots do Telegram no seguinte endereço: [Bot Father, no Telegram](https://t.me/BotFather) e crie um bot com o comando
```bash
/newbot
```
e siga os passos para a criação de um bot no Telegram, após o término copie a APItoken entregue, ele será necessária para o próximo passo.

Agora retorne ao terminal do seu computador e de o comando:
```bash
bos telegram
```

Cole a APItoken fornecido pelo BotFathter do Telegram, no terminal e pressione ` Enter `, volte para o bot recém criado no telegram e envie o seguinte comando: `/start ` e depois `connect`.

Ele vai te responder algo como: `🤖 Connection code is: ########`

Cole o Connection code no terminal e pressione enter novamente, se tudo estiver correto você vai receber uma resposta `🤖 Connected to <nome do seu node>`, agora pressione *Ctrl + C* para sair e você já pode seguir para o próximo passo.

Acesse o arquivo:
```bash
sudo nano -l +12 /etc/systemd/system/bos-telegram.service
```

Vá até o fim da linha e apague *<seu_connect_code_aqui>* e coloque no lugar o **Connection code** obtido no seu bot do telegram. Saia salvando com *Ctrl + X* e pressione *y* para confirmar.

Agora de o seguintes comandos, para reiniciar o serviço:
```bash
systemctl daemon-reload
```

Escolha a opção 1 e digite a senha do seu usuário linux.

```bash
sudo systemctl restart bos-telegram.service
```

Agora verifique se o serviço está funcionando, com o seguinte comando:
```bash
sudo systemctl status bos-telegram.service
```

O resultado esperado é o seguinte:

```bash
admin@minibolt:~$ sudo systemctl status bos-telegram.service 
[sudo] password for admin: 
● bos-telegram.service - bos-telegram
     Loaded: loaded (/etc/systemd/system/bos-telegram.service; enabled; preset: enabled)
     Active: active (running) since Thu 2024-10-24 08:52:24 UTC; 17h ago
   Main PID: 2761 (node)
      Tasks: 11 (limit: 38305)
     Memory: 101.2M (peak: 131.5M)
        CPU: 9.469s
     CGroup: /system.slice/bos-telegram.service
             └─2761 node /home/admin/.npm-global/bin/bos telegram --use-small-units --connect <connect-code-aqui>

Oct 24 08:51:50 minibolt systemd[1]: bos-telegram.service: Scheduled restart job, restart counter is at 1.
Oct 24 08:52:24 minibolt systemd[1]: Started bos-telegram.service - bos-telegram.
```

Use **Ctrl + C** para sair.

- Pronto o **bos** está pronto para ser usado no Telegram,
* você também pode acessar seu **lndg** pelo endereço, no navegador, `seuiplocal:8889`
- O **Thunderhub** por `seuiplocal:3000` (Ex. 192.168.0.101:3000)
---
### Esta ultima ferramenta serve para atualizar os programas do seu BRLNBolt, USE COM SABEDORIA, atualizar o *bitcoind* pode ser um erro caso não tenha lido as notas de atualização.

Na primeira vez que executar:
```bash
chmod +x manutencao.sh
```
e depois
```bash
./manutencao.sh
```
<img src="https://i.postimg.cc/Wpn8FbZz/manutencao.png" alt="manutencao" width="600"/>

Escolha a opção que quiser atualiar ou desinstalar e aguarde a operação ser completa.

## Instalando e sincronizando o seu proprio bitcoin core (opcional)

Com o próximo script vamos instalar o bitcoin core, o coração de toda nossa operação. *Fique atento aos comandos a serem dados a final do script, eles são necessários para o sucesso da intalação correta.*

Caso você ainda não esteja no diretório brlnfullauto, execute:

```bash
cd 
```
E depois:
```bash
cd brlnfullauto/
```
E por fim:
```bash
./brlnfullauto.sh
```
Escolha a opção 3, digite seu usuário e senha para acesso ao bitcoin core e aguarde o final da instalação.

Verifique se a instalação foi corretamente feita com:
```bash
sudo systemctl status bitcoind
```

Saia com *Ctrl + C*

Em alguns dias, seu Bitcoin Core já vai estar sincronizando, basta acompanhar usando o comando:
```bash
journalctl -fu bitcoind
```

## Instalando o TailScale VPN - (Opcional)

Para instalar o **TailScale VPN**, execute o seguinte comando no terminal:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Após a instalação, inicie o TailScale com o comando:

```bash
sudo tailscale up
```

O terminal fornecerá um link. Esse link deve ser transcrito, letra por letra, no navegador de outro dispositivo, preferencialmente no computador que será utilizado para realizar o acesso SSH ao servidor.

Crie uma conta na tailscale e adicione o dispositivo.

Em seguida baixe o tailscale pelo link (https://tailscale.com/download/windows) e faça o login com a sua conta recém criada.
Pronto, agora você já pode fazer o acesso via ssh no servidor, digitando no Terminal do Windows o seguinte comando:

```bash
ssh admin@ip.do.tailscale
```

Este ipv4 é o que é fornecido sob o nome de "minibolt" no tailsacale, que se você estiver usando Windows, deve estar na sua barra de icones próximo ao relógio.

Assim você pode acessar qualquer serviço de fora de casa usando o ip do tailscale, ao invés do ip da rede local.

---
###### Apesar de muitas ferramentas serem opcionais, elas são imprescindíveis na vida de um node runner, recomendamos a sua intalação.
###### **A lightining não é brinquedo, use com responsabilidade.**
###### Boas transações!
###### Por segurança, aos que tiverem conhecimento para, sugiro revisão dos scripts. Aos leigos infelizmente é necessário um pouco de confiança, mas esta instalação é livre de malwares e com uma capacidade de te fornecer uma gama de possibilidades, se feita corretamente. Para mais informações sobre o projeto de emancipação pelo bitcoin, acesse: https://br-ln.com/ e faça sua associação para o nosso clube lightning do Brasil hoje mesmo!
---
###### Em caso de problemas técnicos, envie uma mensagem para suporte.brln@gmail.com

### Bibliografia:
###### 1- https://github.com/cryptosharks131/lndg - Cryptosharks131 - lndg
###### 2- https://github.com/lnbits/lnbits/tree/main - Lnbits
###### 3- https://minibolt.minibolt.info/ - O grande poço de conhecimento.
###### 4- https://plebnet.wiki/wiki/Main_Page - Uma pena ter saído do ar.
