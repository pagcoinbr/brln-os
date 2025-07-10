# ThunderHub - Lightning Node Manager

ThunderHub é uma interface web moderna para gerenciar nós Lightning Network através do LND.

## Configuração

### Docker Compose

O ThunderHub está configurado para funcionar automaticamente com o LND via Docker Compose:

```yaml
thunderhub:
  build:
    context: .
    dockerfile: ./thunderhub/Dockerfile.thunderhub
  container_name: thunderhub
  ports:
    - 3000:3000
  volumes:
    - thunderhub_data:/data/thunderhub
    - /data/lnd:/data/lnd:ro  # Volume compartilhado com LND
  depends_on:
    - lnd
  environment:
    - THUNDERHUB_PORT=3000
    - LND_HOST=lnd:10009
    - THUB_PASSWORD=changeme123
```

### Variáveis de Ambiente

- `THUNDERHUB_PORT`: Porta onde o ThunderHub será executado (padrão: 3000)
- `LND_HOST`: Endereço do LND (padrão: lnd:10009)
- `THUB_PASSWORD`: Senha master para acessar o ThunderHub

### Volumes Compartilhados

O ThunderHub precisa acessar os certificados e macaroons do LND:

- `/data/lnd:/data/lnd:ro` - Volume compartilhado com LND (somente leitura)
  - Acessa `tls.cert` para comunicação segura
  - Acessa `admin.macaroon` para autenticação

## Acesso

Após iniciar o serviço, acesse:
- URL: http://localhost:3000
- Senha: A senha configurada na variável `THUB_PASSWORD`

## Dependências

- LND deve estar executando e sincronizado
- Certificados TLS e macaroons devem estar disponíveis
- PostgreSQL (usado pelo LND)

## Logs

Os logs do ThunderHub são salvos em `/data/thunderhub/logs/` no container.

## Configuração de Conta

A configuração da conta é automaticamente criada no arquivo:
`/data/thunderhub/config/thubConfig_runtime.yaml`

Exemplo:
```yaml
masterPassword: 'changeme123'
accounts:
  - name: 'BRLNBolt'
    serverUrl: 'lnd:10009'
    macaroonPath: '/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon'
    certificatePath: '/data/lnd/tls.cert'
    password: 'changeme123'
```

## Funcionalidades

- Visualizar saldo e transações
- Gerenciar canais Lightning
- Enviar e receber pagamentos
- Visualizar roteamento de pagamentos
- Monitorar peers
- Backup de canais
- E muito mais...
