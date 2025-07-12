# Balance of Satoshis (BOS) - Docker Integration

Este diretório contém a implementação Docker do Balance of Satoshis (BOS) integrada ao sistema BRLN Full Auto.

## 📋 Arquivos

- `Dockerfile.bos` - Dockerfile para construir a imagem do BOS
- `entrypoint.sh` - Script de inicialização do container
- `service.json` - Configurações do serviço
- `bos_telegram.sh` - Script de configuração do bot Telegram (original)
- `balance_of_satoshis.sh` - Script original (mantido para referência)

## 🚀 Como usar

### 1. Construir e iniciar o serviço

```bash
# No diretório container/
docker-compose up -d bos
```

### 2. Verificar logs

```bash
docker-compose logs -f bos
```

### 3. Acessar o container interativamente

```bash
docker exec -it bos bash
```

### 4. Usar comandos do BOS

Dentro do container ou externamente:

```bash
# Verificar balance
docker exec bos bos balance --node=BRLN-Node

# Ver informações do node
docker exec bos bos info --node=BRLN-Node

# Ver forwards recentes
docker exec bos bos forwards --node=BRLN-Node

# Ver peers
docker exec bos bos peers --node=BRLN-Node
```

## 🤖 Configuração do Telegram Bot

### Opção 1: Via variável de ambiente

1. Obtenha um token do @BotFather no Telegram
2. Edite o `docker-compose.yml` e adicione o token:
   ```yaml
   environment:
     - BOS_TELEGRAM_TOKEN=SEU_TOKEN_AQUI
     - BOS_MODE=telegram
   ```
3. Reinicie o container:
   ```bash
   docker-compose restart bos
   ```

### Opção 2: Via script interativo

1. Execute o script de configuração:
   ```bash
   docker exec -it bos /home/bos/bos_telegram.sh
   ```

## 🔧 Modos de operação

O BOS pode ser executado em diferentes modos via variável `BOS_MODE`:

- **`interactive`** (padrão): Container fica ativo para comandos interativos
- **`telegram`**: Inicia automaticamente o bot do Telegram
- **`daemon`**: Mantém o container ativo em background

## 📊 Monitoramento

O container inclui um healthcheck que verifica se o BOS consegue se conectar ao LND:

```bash
# Verificar status de saúde
docker inspect bos | grep -A 5 '"Health"'
```

## 🔗 Integração com LND

O BOS se conecta automaticamente ao LND através de:

- **Socket**: `lnd:10009` (gRPC)
- **Certificados**: Volume compartilhado `/data/lnd`
- **Credenciais**: Configuradas automaticamente no `~/.bos/BRLN-Node/credentials.json`

## 📂 Volumes

- `/data/bos` - Dados persistentes do BOS
- `/data/lnd` - Dados do LND (somente leitura)

## 🔒 Segurança

- O container roda como usuário não-privilegiado `bos`
- Acesso aos dados do LND é somente leitura
- Credenciais são configuradas automaticamente e seguramente

## 🛠️ Troubleshooting

### BOS não conecta ao LND

```bash
# Verificar se LND está rodando
docker-compose ps lnd

# Verificar logs do LND
docker-compose logs lnd

# Verificar credenciais do BOS
docker exec bos cat ~/.bos/BRLN-Node/credentials.json
```

### Recriar credenciais

```bash
# Remover credenciais existentes
docker exec bos rm -rf ~/.bos/BRLN-Node/

# Reiniciar container para recriar
docker-compose restart bos
```

## 📱 Comandos úteis do BOS

```bash
# Balance detalhado
bos balance --node=BRLN-Node --detailed

# Relatório de forwards do último mês
bos forwards --node=BRLN-Node --days=30

# Informações de channels
bos peers --node=BRLN-Node --table

# Verificar conectividade
bos info --node=BRLN-Node

# Criar backup dos channels
bos backup --node=BRLN-Node

# Verificar chain fees
bos chain-fees --node=BRLN-Node
```

## 🔄 Atualizações

Para atualizar o BOS:

```bash
# Reconstruir a imagem
docker-compose build bos

# Reiniciar o serviço
docker-compose up -d bos
```
