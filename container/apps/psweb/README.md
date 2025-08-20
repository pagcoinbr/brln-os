# PeerSwap Web UI Docker Container

Este container fornece uma interface web para o PeerSwap, permitindo gerenciar swaps entre LND e Liquid de forma gráfica.

## Pré-requisitos

- LND container rodando
- Elements container rodando
- PeerSwap container rodando

## Configuração

O container usa o arquivo `pswebconfig.json.example` como configuração padrão. Para customizar:

1. Copie o arquivo de exemplo:
   ```bash
   cp pswebconfig.json.example pswebconfig.json
   ```

2. Edite as configurações conforme necessário

## Portas

- **1984**: Interface web do PeerSwap Web UI

## Volumes

- `psweb_data`: Dados do PeerSwap Web UI
- `/home/lnd/.lnd`: Acesso somente leitura aos dados do LND
- `peerswap_data`: Acesso somente leitura aos dados do PeerSwap

## Dependências

O container aguarda que os seguintes serviços estejam disponíveis antes de iniciar:
- LND (porta 10009)
- PeerSwap (porta 42069) 
- Elements (porta 18884)

## Acesso

Após iniciar o container, acesse a interface web em:
```
http://localhost:1984
```

## Logs

Para visualizar os logs:
```bash
docker logs psweb
```

## Health Check

O container inclui um health check que verifica se a aplicação está respondendo na porta 1984.
