# Balance of Satoshis (BOS) - Docker Setup

Este diretório contém a configuração Docker para o Balance of Satoshis (BOS), uma ferramenta de linha de comando para gerenciar nós Lightning Network.

## Arquivos

- `Dockerfile.bos` - Dockerfile para construir a imagem do BOS
- `configure-bos.sh` - Script de configuração para conectar com o LND
- `README.md` - Este arquivo

## Como usar

### 1. Construir e iniciar os containers

```bash
# Na pasta principal do projeto
docker-compose up -d bos
```

### 2. Verificar se o container está rodando

```bash
docker-compose ps bos
```

### 3. Configurar o BOS (primeira vez)

```bash
# Execute o script de configuração
docker exec -it bos /home/bos/configure-bos.sh
```

### 4. Usar comandos do BOS

```bash
# Entrar no container
docker exec -it bos sh

# Dentro do container, usar comandos BOS:
bos balance              # Ver saldo
bos peers               # Ver peers conectados
bos forwards            # Ver forwards recentes
bos accounting          # Ver contabilidade
bos help                # Ver todos os comandos disponíveis
```

### 5. Comandos diretos (sem entrar no container)

```bash
# Executar comandos BOS diretamente
docker exec -it bos bos balance
docker exec -it bos bos peers
docker exec -it bos bos forwards
```

## Configuração

O BOS se conecta automaticamente ao LND usando:
- **Host**: lnd:10009 (via rede Docker interna)
- **TLS Certificate**: `/home/bos/.lnd/tls/tls.cert`
- **Macaroon**: `/home/bos/.lnd/macaroons/admin.macaroon`

## Volumes

- `lnd_tls`: Certificados TLS do LND (read-only)
- `lnd_macaroons`: Macaroons do LND (read-only)
- `./data/lnd`: Dados do LND no host (read-only)

## Segurança

- O container roda com usuário não-root (bos:1009)
- Acesso read-only aos certificados e dados do LND
- Rede interna (`core`) sem exposição externa

## Troubleshooting

### Container não consegue conectar ao LND

1. Verifique se o LND está rodando:
   ```bash
   docker-compose ps lnd
   ```

2. Verifique se os certificados estão disponíveis:
   ```bash
   docker exec -it bos ls -la /home/bos/.lnd/tls/
   docker exec -it bos ls -la /home/bos/.lnd/macaroons/
   ```

3. Teste a conectividade:
   ```bash
   docker exec -it bos bos balance
   ```

### Erro de permissão

Se houver erros de permissão, verifique se os volumes estão montados corretamente e se o usuário tem as permissões adequadas.

## Comandos úteis do BOS

```bash
# Verificar saldo e canais
bos balance

# Ver peers conectados
bos peers

# Ver forwards recentes
bos forwards

# Accounting/contabilidade
bos accounting

# Rebalancear canais
bos rebalance

# Probe para testar rotas
bos probe INVOICE_OR_PUBKEY

# Certificados e informações do nó
bos cert-validity-days
bos credentials

# Help completo
bos help
```
