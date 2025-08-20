# LNDg - Lightning Network Dashboard

LNDg é um dashboard web para monitoramento e gestão de nós Lightning Network (LND). Esta instalação utiliza Docker e está integrada ao projeto BRLN Full Auto.

## Instalação Simplificada

O LNDg está integrado ao docker-compose.yml principal do projeto e segue a abordagem recomendada pelo [repositório oficial](https://github.com/cryptosharks131/lndg).

### Funcionalidades

- Dashboard web para monitoramento do LND
- Gestão de canais e peers
- Estatísticas de roteamento
- Análise de fees e liquidez
- Interface web intuitiva
- Dados não persistem no host (executam apenas em containers)

## Configuração

### Arquitetura Integrada

O LNDg está configurado no docker-compose.yml principal com:
- **Porta**: 8889 (interface web)
- **Rede**: mainnet (ajustável via variável de ambiente)
- **RPC**: Conecta automaticamente ao container LND (lnd:10009)

### Volumes

- `/root/.lnd` - Acesso somente leitura aos dados do LND
- `/app/data` - Dados temporários da aplicação (não persistem)

## Uso

### Inicialização

Execute a partir do diretório principal do projeto:

```bash
cd /home/admin/brlnfullauto/container
docker-compose up -d lndg
```

### Obter credenciais de acesso

Após a inicialização, obtenha a senha do admin:

```bash
docker exec lndg cat /app/data/lndg-admin.txt
```

## Acesso

Após a inicialização, acesse a interface web em:
- **URL**: http://localhost:8889
- **Usuário**: lndg-admin
- **Senha**: Execute o comando acima para obter a senha

## Dependências Automáticas

- Container LND (conecta automaticamente)
- Rede Docker: grafana-net
- Não requer PostgreSQL (usa banco interno)

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

### Forçar reconstrução
```bash
docker-compose build --no-cache lndg
docker-compose up -d lndg
```

## Monitoramento da Instalação

### Acompanhar logs durante a inicialização
```bash
# Logs em tempo real
docker logs -f lndg

# Verificar se a inicialização foi concluída
docker logs lndg | grep -E "initialized|password|admin"
```

### Verificar conectividade com LND
```bash
# Verificar se LND está respondendo
docker exec lndg python -c "import lndg; print('LND connection test')"
```

## Configuração da Rede

Para alterar entre mainnet/testnet, edite a variável de ambiente no docker-compose.yml:

```yaml
environment:
  - LND_NETWORK=testnet  # ou mainnet
```

E ajuste o comando de inicialização correspondente:
```yaml
command:
  - sh
  - -c
  - python initialize.py -net 'testnet' -rpc 'lnd:10009' -wn && python controller.py runserver 0.0.0.0:8889
```

## Características da Instalação

- **Instalação simplificada**: Segue as melhores práticas do repositório oficial
- **Sem persistência de dados**: Os dados não são salvos no host (conforme solicitado)
- **Integração automática**: Conecta automaticamente com LND e outros serviços
- **Configuração mínima**: Funciona out-of-the-box sem configurações complexas
- **Rede configurável**: Suporta mainnet/testnet via variáveis de ambiente

> **Nota**: Esta configuração segue exatamente as instruções do site oficial do LNDg, integrando-se perfeitamente ao docker-compose.yml do projeto BRLN Full Auto. Os dados não persistem no host conforme solicitado, mantendo a instalação simples e clean.
