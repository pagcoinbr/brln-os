# Balance of Satoshis (BOS) - Docker/Podman Setup

Este diretório contém a configuração Docker/Podman para o Balance of Satoshis (BOS), uma ferramenta de linha de comando para gerenciar nós Lightning Network.

## Arquivos

- `Dockerfile.bos` - Dockerfile para construir a imagem do BOS
- `configure-bos.sh` - Script de configuração para conectar com o LND
- `README.md` - Este arquivo

## Status da Implementação

✅ **CONCLUÍDO** - Container BOS construído com sucesso usando Podman  
✅ **CONCLUÍDO** - Script de criação/recuperação de carteira LND funcionando  
✅ **CONCLUÍDO** - Configuração para conectar BOS ao LND via rede interna  
⚠️ **PENDENTE** - Necessário recriar dados da carteira LND para sincronização completa  

### Build realizado com Podman

```bash
# Imagem construída com sucesso usando Podman
podman build -f bos/Dockerfile.bos -t pagcoin/brln-bos:latest .
# Resultado: localhost/pagcoin/brln-bos:latest (671 MB)
```

## Como usar

### 1. Construir a imagem (se necessário)

```bash
# Com Podman (testado e funcionando)
cd /home/pagcoin/brln-os/container/nodes
podman build -f bos/Dockerfile.bos -t pagcoin/brln-bos:latest .

# Com Docker
docker build -f bos/Dockerfile.bos -t pagcoin/brln-bos:latest .
```

### 2. Configurar e iniciar LND primeiro

```bash
# Iniciar LND (necessário antes do BOS)
podman run -d --name lnd \
  --network nodes_core \
  -e NODE_ENV=production \
  -e NETWORK=mainnet \
  -v lnd_data:/data/lnd \
  -v ./lnd/lnd.conf:/data/lnd/lnd.conf:ro \
  -v ./lnd/password.txt:/data/lnd/password.txt:ro \
  -p 9735:9735 \
  -p 10009:10009 \
  --user 1008:1008 \
  pagcoin/brln-lnd:latest
```

### 3. Criar/Recuperar carteira LND

```bash
# Script interativo para criação ou recuperação de carteira
podman exec -it lnd /tmp/wallet-setup.sh
```

**Nota importante**: Se você já tem uma carteira existente mas os dados estão corrompidos ou desatualizados, será necessário:
1. Parar o container LND
2. Remover/backup do volume `lnd_data` 
3. Recriar a carteira usando o seed de backup
4. Permitir que o LND ressincronize com a blockchain

### 4. Iniciar o container BOS

```bash
# Com Podman
podman run -d --name bos \
  --network nodes_core \
  -e NODE_ENV=production \
  -e HOME=/home/bos \
  -e NPM_CONFIG_PREFIX=/home/bos/.npm-global \
  -e PATH=/home/bos/.npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -v lnd_data:/home/bos/.lnd:ro \
  -v ./bos/configure-bos.sh:/home/bos/configure-bos.sh:ro \
  --user 1009:1009 \
  localhost/pagcoin/brln-bos:latest \
  tail -f /dev/null

# Com docker-compose (após configurar o LND)
docker-compose up -d bos
```

### 5. Verificar se o container está rodando

```bash
# Com Podman
podman ps | grep bos

# Com Docker
docker-compose ps bos
```

### 6. Configurar o BOS (primeira vez)

```bash
# Execute o script de configuração
podman exec bos /home/bos/configure-bos.sh
# OU com docker:
# docker exec -it bos /home/bos/configure-bos.sh
```

### 7. Usar comandos do BOS

```bash
# Entrar no container
podman exec -it bos sh
# OU: docker exec -it bos sh

# Dentro do container, usar comandos BOS:
bos balance              # Ver saldo
bos peers               # Ver peers conectados
bos forwards            # Ver forwards recentes
bos accounting          # Ver contabilidade
bos help                # Ver todos os comandos disponíveis
```

### 8. Comandos diretos (sem entrar no container)

```bash
# Executar comandos BOS diretamente com Podman
podman exec bos bos balance
podman exec bos bos peers
podman exec bos bos forwards

# OU com docker:
docker exec -it bos bos balance
docker exec -it bos bos peers
docker exec -it bos bos forwards
```

## Processo de Setup Realizado (Agosto 2025)

### Build da imagem BOS
- ✅ Container construído com sucesso usando `podman build`
- ✅ Imagem final: `localhost/pagcoin/brln-bos:latest` (671 MB)
- ✅ BOS versão 19.5.4 instalado e funcionando

### Configuração LND
- ✅ LND configurado para usar Bitcoin externo (bitcoin.br-ln.com:8085)
- ✅ Script interativo de criação/recuperação de carteira criado
- ✅ Carteira recuperada com sucesso usando seed de 24 palavras
- ⚠️ **Observação**: Necessário recriar dados da carteira para sincronização completa

### Próximos passos
1. Parar containers atuais
2. Limpar dados antigos do volume `lnd_data`
3. Recriar carteira LND usando script desenvolvido
4. Aguardar sincronização completa
5. Testar conectividade BOS ↔ LND

### Scripts desenvolvidos
- `lnd/wallet-setup.sh` - Script interativo com suporte a jq
- `lnd/wallet-setup-simple.sh` - Versão sem dependência do jq (testado e funcionando)
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
