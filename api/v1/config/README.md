# BRLN-OS Config API

API para gerenciamento de status do sistema e controle de serviços.

## Instalação

1. Instalar dependências:
```bash
source /home/admin/envflask/bin/activate
pip install -r requirements.txt
```

2. Configurar o serviço:
```bash
sudo cp /root/brln-os/services/brln-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable brln-api
sudo systemctl start brln-api
```

3. Verificar status:
```bash
sudo systemctl status brln-api
```

## Endpoints

### GET /api/v1/config/system-status
Retorna informações sobre CPU, RAM, LND, Bitcoin, Tor e Blockchain.

### GET /api/v1/config/services-status
Retorna o status (ativo/inativo) de todos os serviços.

### POST /api/v1/config/service
Gerencia serviços (start/stop/restart).

Body:
```json
{
  "service": "lnd",
  "action": "start"
}
```

### GET /api/v1/config/health
Health check do serviço.

## Porta

A API roda na porta **5001**.

## Configuração do Nginx

Para expor a API através do Nginx, adicione ao seu nginx.conf:

```nginx
location /api/ {
    proxy_pass http://localhost:5001/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```
