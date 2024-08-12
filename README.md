# Flash Minibolt amd64 install + tools

Esta isntalação consiste em uma instalação rápida do node usando conexão rpc externa podendo abrir seus primeiros canais em menos de 30 minutos, para poder entrar para nosso club e poder receber as credenciais para conexão a um rcp externo e seguro, acesse: https://services.br-ln.com/. Entre no nosso grupo do telegram para suporte personalizado.

# Instalando o Ubuntu Server
Este tutorial se destina a facilitar a instalação do minibolt em um sistema standalone. Parto do pressuposto que você está fazendo uma instalação nova do ubuntu server, que está na sua versão 24.0 atualmente. 05.08.24

Faça o flash do disco/pendrive e realize a instalação do Ubuntu, selecionando [x] o openssh server durante a instalação.

quando te pedir as credenciais para login escreva o seguinte:

name: temp

server name: minibolt

user: temp

password: ********* (você escolhe)

Prossiga com a instalação e quando finalizar, faça o reboot e retire o disco. Provavelmente agora você vai ver uma mensagem de erro no boot, pressione `Enter`.
Agora sem o disco plugado, o sistema deve iniciar.

# Preparando o terreno

Agora faça 

`sudo adduser --gecos "" admin`

Ele vai te pedir a senha atual, que você escolheu na instalação do sistema e em seguida digite duas vezes a nova senha do usuário admin, que estamos criando. 

Depois copie e cole no terminal:
`sudo usermod -a -G sudo,adm,cdrom,dip,plugdev,lxd admin`.

Em seguida faça o `logout` ou `exit`

Agora que criamos um novo usuário "admin", vamos fazer o login novamente e apagar o usuário "temp" anterior.

Mais uma vez faça o comando, agora com o user admin `ssh admin@ip.do.servidor`

Uma vez logado faça: 

`sudo userdel -rf temp` e receba uma mensagem de erro de "not found", ou algo do genero.

E depois `git clone https://github.com/REDACTED_USERbtc/miniboltfullauto.git` para copiar o repositório.

`cd miniboltfullauto` para acessar o diretório dos scripts.

# Iniciando a instalação por scripts

Até agora fizemos a parte mais dificil que não pode ser automatizada por scripts, de agora em diante você vai seguir este passo a passo:

Execute `chmod +x miniboltfullauto.sh` e depois `./miniboltfullauto.sh`, você deve responder `y` sempre que solicitado. 

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

Atenção, no registro das credenciais é onde acontecem a maior parte dos erros, copie os dados ou escreva-os com atenção!!!

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

As credenciais que serão solicitadas no próximo script podem ser adquiridas pelo nosso plano mensal de conexão segura por rpc para um bitcoind externo que não exige instalação local da blockchain e reduz drasticamente a alocação de disco de algo em torno de 600/700Gb para algo em torno de 50 Gb na pior das hipoteses. Saiba mais sobre o projeto em: https://services.br-ln.com/

Caso vocë tenha errado alguma credencial voce pode apertar "Ctrl + C" e começar novamente ou corrigi-la com `nano /data/lnd/lnd.conf` posteriormente a instalação.

No próximo passo vamos criar a carteira lightning, pegue um papel e uma caneta para anotar sua frase secreta.

# Configurando a carteira

Depois `lncli --tlscertpath /data/lnd/tls.cert.tmp create`
Digite a senha 2x para confirmar (a mesma senha escolhida no script anterior) e pressione "n" e "enter".

Output esperado:

lnd@minibolt:~$ lncli --tlscertpath /data/lnd/tls.cert.tmp create
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

 1. absent    2. drive     3. grape    4. inject
 5. nut       6. pencil    7. cloud    8. rude
 9. stomach  10. decline  11. kidney  12. various
13. spawn    14. harvest  15. wage    16. shield
17. debate   18. boring   19. assist  20. foster
21. slender  22. tent     23. deputy  24. any

---------------END LND CIPHER SEED-----------------

!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!

lnd successfully initialized!

Veja o estado do service com `sudo systemctl status lnd.service`

A saída deve ser esta -> [photo-5008557502593346775-w.jpg](https://postimg.cc/zbpWqHP9)

# Caso sua carteira ainda esteja "locked", você pode tentar verificar estas coisas, antes de precisar começar novamente:

A primeira coisa a se fazer é esperar o lnd sincronizar, acesse: 

`sudo journalctl -xeu lnd` - Se a ultima saída for algo como "Started rescan from block 0000000...", aguarde cerca de 2-5 minutos e tente `sudo systemctl status lnd.service`, novamente.

`nano /data/lnd/lnd.conf` - Verificar a senha criada anteriormente que fica salvo em um arquivo de texto, se estiver incorreta com a que você acabou de criar, corrija-o.

`nano /data/lnd/lnd.conf` - Verificar as credenciais do [Bitcoind], são comummente onde há mais erros durante o tutorial.

`sudo systemctl restart lnd` e `sudo systemctl status lnd`, agora ele deve aparecer como "unlocked".

neste ponto você já deve estar pronto para ver as informações do seu node com : `lncli getinfo`

# Instalando o Balance of Satoshis

Agora que seu lnd está pronto vamos construir em cima dele.
Começando pelo script para instalar o bos:

`chmod +x likeabos.sh` e `./likeabos.sh`

*Se você receber o seguinte erro (https://postimg.cc/LYMLQxpg) basta checar a conexão com a internet e rodar novamente o script anterior*

Ao final da instalação você precisa recarregar a sessão com `. ~/.profile` ou sair da sessão e logar novamente.

Asseguir vamos criar o bot para poder monitorar o movimento do nosso nó pelo Telegram: 

Play store: https://play.google.com/store/apps/details?id=org.telegram.messenger&hl=pt_BR&pli=1

Apple store: https://apps.apple.com/br/app/telegram-messenger/id686449807

Acesse: https://t.me/BotFather e crie um bot pelo comand "/newbot" e siga os passos para a criação de um bot no telegram, após o termino copie a "HTTP API", ela será necessária para o próximo passo.

Inicie o comando `bos telegram`

Cole a API e pressione "Enter", volte para o bot recém criado no telegram e envie "/start".

Ele vai te responder algo como: "🤖 Connection code is: 1463539065"

Cole o Connection code no terminal e pressione enter novamente, se tudo estiver correto você vai receber uma resposta "🤖 Connected to <nome do seu node>" e você já pode seguir par ao próximo passo.

Faça, `chmod +x bos-autostart.sh` e `./bos-autostart.sh`

Cole o Connection code quando solicitado. Ao final, basta pressionar "Ctrl + C" para voltar para o terminal.

Pronto o bos está pronto para ser usado no telegram, mas também uma feramenta de terminal que pode ser usado com o comando `bos help`

# Instalando o Zeus App

Use `chmod +x zeusapp.sh` e `./zeusapp.sh`

E por fim, você deve escolher por onde acessar o Zeus Wallet para administrar o node, se for pela rede local, no próximo comando você deve usar o ip da rede local, caso vá acessar pelo tailscale, use o ip da fornecido pelo app.

Tire o zoom ou com "Ctrl + -" pelo menos 6x. E depois:

`lndconnect --host=<0.0.0.0> --port=8080 --nocert`

Apple store: https://apps.apple.com/us/app/zeus-wallet/id1456038895

Play store: [https://play.google.com/store/apps/detailsid=app.zeusln.zeus&hl=pt_BR](https://play.google.com/store/apps/details?id=app.zeusln.zeus&hl=pt_BR)

Escaneie o qr code com o app zeus nas opções avançadas do app, quando vir o aviso, clique em "save node config" e aguarde conectar.

# Instalando o Thunderhub

Primeiro faça `chmod +x thunderhub.sh` e `./thunderhub.sh`

Agora você pode acessar o seu thunderhub pelo ipdominibolt + porta "https://192.168.x.xxx:4002"

# Instalando o TailScale VPN

Digite o seguinte comando:

`curl -fsSL https://tailscale.com/install.sh | sh`

Em seguida escreva `sudo tailscale up` e ele vai te fornecer um link, este link deve ser digitado, letra por letra, no navegador de um outro dispositivo qualquer, de preferência no computador que você vai fazer o SSH no servidor. 

Crie uma conta na tailscale e adicione o dispositivo.

Em seguida baixe o tailscale pelo link `https://tailscale.com/download/windows` e faça o login com a sua conta recém criada.
Pronto, agora já podemos fazer o ssh no servidor, digitando no cmd o seguinte comando:

`ssh temp@ip.do.tailscale`

Este ipv4 é o que é fornecido sob o nome de "minibolt" no tailsacale, que se você estiver usando windows, deve estar na sua barra de icones próximo ao relógio.

Assim você pode acessar qualquer serviço de fora de casa usando o ip do tailscale, ao invés do ip da rede local.

# Disclaimers:
A lightining não é brinquedo, use com responsabilidade e sempre cuidando dos seus peers.
Boas transações!

Por segurança, aos que tiverem conhecimento para, sugiro revisão dos scripts por segurança. Aos leigos infelizmente é necessário um pouco de confiança, mas esta instalação é livre de malwares e com uma capacidade de te fornecer uma gama de possibilidades, se feita corretamente. Para mais informações sobre o projeto de emancipação pelo bitcoin, acesse: https://br-ln.com/ e faça sua associação para o nosso clube lightning do Brasil hoje mesmo!

