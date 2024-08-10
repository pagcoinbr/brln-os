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

Em seguida faça o `logout` ou `exit`.

Agora que criamos um novo usuário "admin", vamos fazer o login novamente e apagar o usuário "temp" anterior.

Mais uma vez faça o comando, agora com o user admin `ssh admin@ip.do.servidor`.

Uma vez logado faça: 

`sudo userdel -rf temp` e receba uma mensagem de erro de "not found", ou algo do genero.

E depois `git clone https://github.com/REDACTED_USERbtc/miniboltsemiauto.git` para copiar o repositório.

`cd miniboltsemiauto` para acessar o diretório dos scripts.

# Iniciando a instalação por scripts

Até agora fizemos a parte mais dificil que não pode ser automatizada por scripts, de agora em diante você vai seguir este passo a passo:

Execute `chmod +x network_setup1.sh` e depois `./network_setup1.sh`, vão acontecer alguns prompts e você deve responder `y` quando solicitado. 

# Finalmente instalando o lnd

Como fizemos com os scripts anteriores, vamos fazer agora:

1. `chmod +x install_lnd2.sh`
2. `./install_lnd2.sh`

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Atenção, no próximo script é onde acontecem a maior parte
dos erros, copie os dados ou escreva-os com atenção!!!
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

As credenciais que serão solicitadas no próximo script podem ser adquiridas pelo nosso plano mensal de conexão segura por rpc para um bitcoind externo que não exige instalação local da blockchain e reduz drasticamente a alocação de disco de algo em torno de 600/700Gb para algo em torno de 50 Gb na pior das hipoteses. Saiba mais sobre o projeto em: https://services.br-ln.com/

Depois `chmod +x setup_lnd3.sh` e `./setup_lnd3.sh`

Caso vocë tenha errado alguma credencial voce pode corrigi-la com `nano /data/lnd/lnd.conf`

Basta alterar o [Bitcoind]

# Criando o service o systemd para automatizar no boot do sistema.

2. `chmod +x create_lndservice4.sh`
3. `./create_lndservice4.sh`
4. `sudo systemctl status lnd.service`

Neste ponto o lnd.service já deve estar como "active" mas "Wallet locked". Vamos prosseguir.

# Configurando a carteira

Depois `lncli --tlscertpath /data/lnd/tls.cert.tmp create`.
Digite a senha 2x para confirmar (a mesma senha escolhida anteriormente) e pressione `n` e `enter`

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

 1. xxx     2. xxxxxxx   3. xxxxxxxx   4. xxxxxx
 5. xxx      6. xxxxxxx   7. xxxx       8. xxxxx
 9. xxx      10. xxxxx     11. xxxxxxx    12. xxxxxx
13. xxx      14. xxxxx    15. xxxxxxxx   16. xxxxx
17. xxx      18. xxxxxx  19. xxxxxxx    20. xxxx
21. xxx     22. xxxxxx    23. xxxxxx    24. xxxxx

---------------END LND CIPHER SEED-----------------

!!!YOU MUST WRITE DOWN THIS SEED TO BE ABLE TO RESTORE THE WALLET!!!

lnd successfully initialized!

Em seguida dê `exit` para sair do lnd user, mais uma vez.

Mais uma vez veja o estado do service com `sudo systemctl status lnd.service`

A saída deve ser esta -> [photo-5008557502593346775-w.jpg](https://postimg.cc/zbpWqHP9)

# Caso sua carteira ainda esteja "locked", você pode tentar verificar duas coisas, antes de precisar começar novamente:

`nano /data/lnd/lnd.conf` - Verificar a senha criada anteriormente que fica salvo em um arquivo de texto, se estiver incorreta com a que você acabou de criar, corrija-o.

`nano /data/lnd/lnd.conf` - Verificar as credenciais do [Bitcoind], são comummente onde há mais erros durante o tutorial.

`sudo systemctl restart lnd` e `sudo systemctl status lnd`, agora ele deve aparecer como "unlocked".

neste ponto você já deve estar pronto para ver as informações do seu node com : `lncli getinfo`

# Disclaimers:
Por segurança, aos que tiverem conhecimento para, sugiro revisão dos scripts por segurança. Aos leigos infelizmente é necessário um pouco de confiança no criador dos scripts, mas esta instalação é livre de malwares se feita corretamente. Para mais informações sobre o projeto de emancipação do cidadão comum pelo bitcoin, acesse: https://br-ln.com/ e faça sua associação para o nosso clube lightning do Brasil hoje mesmo!

# Instalando o TailScale VPN (Opcional)

Digite o seguinte comando:

`curl -fsSL https://tailscale.com/install.sh | sh`

Em seguida escreva `sudo tailscale up` e ele vai te fornecer um link, este link deve ser digitado, letra por letra, no navegador de um outro dispositivo qualquer, de preferência no computador que você vai fazer o SSH no servidor. 

Crie uma conta na tailscale e adicione o dispositivo.

Em seguida baixe o tailscale pelo link `https://tailscale.com/download/windows` e faça o login com a sua conta recém criada.
Pronto, agora já podemos fazer o ssh no servidor, digitando no cmd o seguinte comando:

`ssh temp@ip.do.servidor`

Este ipv4 é o que é fornecido sob o nome de "minibolt" no tailsacale, que se você estiver usando windows, deve estar na sua barra de icones próximo ao relógio.

A lightining não é brinquedo, use com responsabilidade e sempre cuidando dos seus peers.
Boas transações!
