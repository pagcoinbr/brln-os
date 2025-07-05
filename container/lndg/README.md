# LNDG - LND Dashboard Docker Container

Este diretório contém os arquivos necessários para executar o LNDG (LND Dashboard) em um container Docker como parte do projeto BRLN Full Auto.

## Arquivos Incluídos

- `Dockerfile.lndg` - Dockerfile para construir a imagem do LNDG
- `entrypoint.sh` - Script de inicialização do container
- `service.json` - Configuração de serviço para integração com o sistema
- `lndg.conf.example` - Arquivo de configuração de exemplo
- `README.md` - Este arquivo

## Funcionalidades

- Dashboard web para monitoramento do LND
- Gestão de canais e peers
- Estatísticas de roteamento
- Análise de fees e liquidez
- Interface web intuitiva
- Integração com PostgreSQL para persistência de dados

## Configuração

### Volumes Persistentes

- `/data/lndg` - Dados da aplicação LNDG
- `/data/lnd` - Dados do LND (somente leitura)

### Portas

- `8889` - Interface web do LNDG

### Variáveis de Ambiente

- `LND_HOST` - Endereço do LND (padrão: lnd:10009)
- `LND_NETWORK` - Rede do LND (mainnet/testnet)
- `DB_HOST` - Host do PostgreSQL
- `DB_PORT` - Porta do PostgreSQL
- `DB_USER` - Usuário do PostgreSQL
- `DB_PASSWORD` - Senha do PostgreSQL

## Uso

### Via Docker Compose

O serviço está configurado no `docker-compose.yml` principal:

```bash
cd /home/admin/brlnfullauto/container
docker-compose up -d lndg
```

### Via Script Shell

Use o script de instalação tradicional:

```bash
bash ~/brlnfullauto/shell/adm_apps/lndg.sh
```

### Construção Manual

```bash
cd /home/admin/brlnfullauto/container
docker build -f lndg/Dockerfile.lndg -t lndg:latest .
```

## Acesso

Após a inicialização, acesse a interface web em:
- URL: http://localhost:8889
- Usuário: admin (configurado durante a inicialização)

## Dependências

- LND em execução
- PostgreSQL em execução
- Rede Docker: grafana-net

## Segurança

- Executa como usuário não-root (lndg:1005)
- Acesso somente leitura aos dados do LND
- Dados persistentes com permissões apropriadas

## Troubleshooting

### Verificar logs
```bash
docker logs lndg
```

### Verificar status dos serviços
```bash
docker-compose ps
```

### Reiniciar serviço
```bash
docker-compose restart lndg
```

## Backup

Os dados importantes estão em `/data/lndg` e são automaticamente incluídos no backup diário do sistema.
