# AlfredP2P API - Guia de Uso dos CLIs

## Introdução

Este projeto utiliza dois nós importantes para operações com Bitcoin e Lightning Network:

### 1. Elements Node (Liquid Network)
O **Elements** é uma implementação do protocolo Liquid Network, uma sidechain do Bitcoin que oferece:
- **Transações mais rápidas**: Confirmações em ~1 minuto
- **Transações confidenciais**: Valores e tipos de ativos são privados
- **Múltiplos ativos**: Suporte para diversos tokens além do L-BTC (Depix e USDT)
- **Federação**: Controlada por uma federação de exchanges e instituições

### 2. Lightning Network Daemon (LND)
O **LND** é uma implementação do Lightning Network que permite:
- **Pagamentos instantâneos**: Transações off-chain quase instantâneas
- **Micropagamentos**: Taxas muito baixas para pequenos valores
- **Escalabilidade**: Reduz a carga na blockchain principal
- **Canais de pagamento**: Conexões diretas entre nós para transferências

## Estrutura do Projeto

```
container/
├── docker-compose.yml      # Orquestração dos serviços
├── Dockerfile.elements     # Build do container Elements
├── elements.conf          # Configuração do Elements
├── elements.sh            # Script de inicialização do Elements
├── lnd.conf              # Configuração do LND
└── password.txt          # Senha para desbloqueio automático da carteira on-chain
```

## Pré-requisitos

### Requisitos de Sistema
- Mínimo de 80 GB de espaço em disco livre para a blockchain do Elements
- Docker e Docker Compose instalados
- Conexão estável com a internet

### Inicialização dos Containers

Certifique-se de que os containers estão rodando:

```bash
cd container
docker-compose up -d
```

Verifique o status:
```bash
docker-compose ps
```

## Usando o Elements CLI

### Comandos Básicos

#### Verificar informações do nó
```bash
docker exec elements elements-cli getblockchaininfo
```

#### Verificar saldo da carteira
```bash
docker exec elements elements-cli getbalance
```

#### Configuração de Assets na Liquid
```bash
# Configuração dos assets conhecidos (apenas para referência)
# DePix asset ID
assetdir=02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189:DePix
# USDT asset ID
assetdir=ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2:USDT
```

#### Gerar novo endereço
```bash
docker exec elements elements-cli getnewaddress
```

#### Listar transações
```bash
docker exec elements elements-cli listtransactions
```


#### Transações
```bash
# Enviar L-BTC para endereço (especificando o asset L-BTC explicitamente)
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false false false "bitcoin"

# Enviar DePix para endereço
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false 1 "UNSET" false 02f22f8d9c76ab41661a2729e4752e2c5d1a263012141b86ea98af5472df5189

# Enviar USDT para endereço
docker exec elements elements-cli sendtoaddress <endereco> <valor> "" "" false false 1 "UNSET" false ce091c998b83c78bb71a632313ba3760f1763d9cfcffae02258ffa9865a37bd2

# Comando completo com todos os parâmetros:
# sendtoaddress <endereco> <valor> <comentario> <comentario-to> <subtractfeefromamount> <avoidreuse> <fee_rate> <ignoreblindfail> <assetlabel> <asset-hex>

## Usando o LND CLI

### Transações On-Chain

#### Enviar Bitcoin on-chain
```bash
# Enviar para endereço Bitcoin (valor em satoshis)
docker exec lnd lncli sendcoins --addr=<endereco_bitcoin> --amt=<valor_em_sats>

# Enviar com taxa específica (sat/vbyte)
docker exec lnd lncli sendcoins --addr=<endereco_bitcoin> --amt=<valor_em_sats> --sat_per_vbyte=<taxa>

# Enviar todos os fundos (sweep)
docker exec lnd lncli sendcoins --addr=<endereco_bitcoin> --sweepall

# Verificar status da transação
docker exec lnd lncli listchaintxns


```

### Configuração Inicial da Carteira LND

O LND está configurado para **criação automática** da carteira na primeira execução, usando a senha definida no arquivo `password.txt`. Esta configuração é feita através das seguintes opções no arquivo `lnd.conf`:

```properties
wallet-unlock-password-file=/data/lnd/password.txt
wallet-unlock-allow-create=true
```

#### Método Automático (Recomendado)

Se o LND foi iniciado com a configuração padrão, ele criará automaticamente a carteira na primeira execução. Para verificar:

```bash
# Verificar logs do LND para acompanhar a criação automática
docker logs -f lnd
```

Se a carteira foi criada automaticamente, você verá mensagens indicando que o LND foi inicializado com sucesso.

#### Método Manual (Quando necessário)

Caso seja necessário criar a carteira manualmente (por exemplo, se a configuração automática estiver desabilitada), siga estes passos:

##### 1. Verificar se o LND está aguardando a criação da carteira

```bash
# Verificar logs do LND
docker logs lnd
```

Você deverá ver uma mensagem como esta:
```
[INF] LTND: Waiting for wallet encryption password. Use `lncli create` to create a wallet, `lncli unlock` to unlock an existing wallet, or `lncli changepassword` to change the password of an existing wallet and unlock it.
```

##### 2. Localizar o certificado TLS temporário

Quando o LND inicia sem uma carteira, ele gera um certificado TLS temporário:

```bash
# Listar conteúdo do diretório .lnd
docker exec -it lnd ls -la /home/lnd/.lnd/
```

Você verá um arquivo chamado `tls.cert.tmp` que precisará ser usado durante a criação da carteira.

##### 3. Criar a carteira manualmente

```bash
# Método interativo
docker exec -it lnd /opt/lnd/lncli --tlscertpath=/home/lnd/.lnd/tls.cert.tmp create

# Método automático usando script expect (recomendado para automação)
# Primeiro, instale expect se não estiver disponível:
# sudo apt-get update && sudo apt-get install -y expect

# Crie um script expect para automatizar a criação:
cat > create_wallet.exp << 'EOF'
#!/usr/bin/expect -f

# Lê a senha do arquivo
set password_file [open "password.txt" r]
set password [string trim [read $password_file]]
close $password_file

# Configura timeout
set timeout 30

# Executa o comando lncli create
spawn docker exec -it lnd /opt/lnd/lncli --tlscertpath=/home/lnd/.lnd/tls.cert.tmp create

# Espera pelo prompt de senha
expect "Input wallet password:"
send "$password\r"

# Confirma a senha
expect "Confirm password:"
send "$password\r"

# Responde se quer usar seed existente (n = não)
expect "Enter 'y' to use an existing cipher seed mnemonic, 'x' to use an extended master root key"
expect "or 'n' to create a new seed (Enter y/x/n):"
send "n\r"

# Responde se quer passphrase adicional (apenas Enter = sem passphrase)
expect "Input your passphrase if you wish to encrypt it (or press enter to proceed without a cipher seed passphrase):"
send "\r"

# Aguarda a criação da carteira e captura a seed
expect {
    "Your cipher seed is:" {
        expect -re {BEGIN LND CIPHER SEED.*END LND CIPHER SEED.*}
        puts "\n=== SEED CAPTURADA ==="
        puts $expect_out(0,string)
        puts "=== FIM DA SEED ==="
    }
    "lnd successfully initialized!" {
        puts "Carteira criada com sucesso!"
    }
    timeout {
        puts "Timeout aguardando resposta"
        exit 1
    }
}

expect eof
EOF

# Torne o script executável e execute
chmod +x create_wallet.exp
./create_wallet.exp
```

**Explicação do método automático:**
- O script `expect` automatiza a interação com o comando `lncli create`
- Lê a senha do arquivo `password.txt` automaticamente
- Responde "n" para não usar seed existente (criará uma nova)
- Responde com Enter (vazio) para não usar passphrase adicional na seed
- Captura e exibe a seed de 24 palavras gerada

Siga as instruções no prompt (método interativo):
- Digite e confirme a senha (use a senha do arquivo `password.txt`)
- Escolha se deseja usar uma seed existente (geralmente, escolha "n" para criar uma nova)
- Decida se deseja criptografar sua seed (opcional)
- **IMPORTANTE**: Anote as 24 palavras da seed em um local seguro. Esta é a única forma de recuperar sua carteira em caso de problemas!

**ATENÇÃO:** O script expect exibirá a seed de 24 palavras na tela. **COPIE E GUARDE essas palavras imediatamente** em um local seguro offline!

#### Desbloqueio da carteira

Com a configuração automática, a carteira será desbloqueada automaticamente em futuras inicializações. Se necessário desbloquear manualmente:

```bash
docker exec -it lnd lncli unlock
```

### Comandos Básicos

#### Verificar informações do nó
```bash
docker exec lnd lncli getinfo
```

#### Verificar saldo
```bash
# Saldo on-chain
docker exec lnd lncli walletbalance
```

#### Gerar endereço
```bash
docker exec lnd lncli newaddress p2tr
```

## Segurança

- **NUNCA compartilhe** chaves privadas ou seeds
- **GUARDE a seed de 24 palavras** do LND em um local seguro offline
- **Faça backup** regular das carteiras
  - Elements: `elements-cli backupwallet /path/to/backup`
  - LND: `lncli exportchanbackup --all` para backup de canais
- **Use senhas fortes** para os wallets
- **Mantenha backups do arquivo** `channel.backup` do LND sempre que abrir novos canais
- **Monitore** regularmente os logs para atividades suspeitas
- **Mantenha** os containers atualizados

### Backup da carteira LND

Backup da seed (obrigatório durante a criação):
```
---------------BEGIN LND CIPHER SEED---------------
 1. palavra1   2. palavra2   3. palavra3   4. palavra4
...
21. palavra21 22. palavra22 23. palavra23 24. palavra24
---------------END LND CIPHER SEED-----------------
```

Backup de canais (necessário sempre que criar novos canais):
```bash
# Exportar backup de todos os canais
docker exec -it lnd lncli exportchanbackup --all

# Exportar para um arquivo
docker exec -it lnd lncli exportchanbackup --all --output_file=/home/lnd/backup/channels.backup
```

## Referências

- [Elements Documentation](https://elementsproject.org/)
- [LND Documentation](https://docs.lightning.engineering/)
- [Lightning Network Specification](https://github.com/lightning/bolts)
- [Docker Documentation](https://docs.docker.com/)

---

**Nota**: Este guia assume que você está executando os comandos do diretório `container/` onde está localizado o `docker-compose.yml`.
