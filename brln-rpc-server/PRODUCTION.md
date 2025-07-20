# Configuração de Produção - LND RPC JS Service

## Configurações Recomendadas para Produção

### 1. Configurações do Sistema

#### Limits.conf
Adicione ao `/etc/security/limits.conf`:
```
root soft nofile 65536
root hard nofile 65536
root soft nproc 4096
root hard nproc 4096
```

#### Sysctl
Adicione ao `/etc/sysctl.conf`:
```
# Network optimizations
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# File descriptor limits
fs.file-max = 2097152
```

#### Aplicar mudanças:
```bash
sudo sysctl -p
```

### 2. Configurações de Firewall

#### UFW (Ubuntu Firewall)
```bash
# Permitir SSH
sudo ufw allow ssh

# Permitir porta do serviço (apenas de IPs confiáveis)
sudo ufw allow from 192.168.1.0/24 to any port 5002
sudo ufw allow from 10.0.0.0/8 to any port 5002

# Ativar firewall
sudo ufw enable
```

#### iptables (alternativo)
```bash
# Permitir porta 5002 apenas de redes privadas
iptables -A INPUT -p tcp --dport 5002 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 5002 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 5002 -j DROP
```

### 3. Monitoramento

#### Script de Health Check
```bash
#!/bin/bash
# /usr/local/bin/lnd-rpc-health-check.sh

SERVICE_NAME="lnd-rpc-js"
ENDPOINT="http://localhost:5002/health"
SECRET_KEY="YOUR_SECRET_KEY"

# Verificar se serviço está ativo
if ! systemctl is-active --quiet $SERVICE_NAME; then
    echo "CRITICAL: Service $SERVICE_NAME is not running"
    systemctl restart $SERVICE_NAME
    exit 2
fi

# Verificar endpoint HTTP
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-secret-key: $SECRET_KEY" \
    $ENDPOINT)

if [ "$HTTP_CODE" = "200" ]; then
    echo "OK: Service responding"
    exit 0
else
    echo "WARNING: HTTP response code $HTTP_CODE"
    exit 1
fi
```

#### Configurar cron para health check
```bash
# Editar crontab
sudo crontab -e

# Adicionar linha (check a cada 5 minutos)
*/5 * * * * /usr/local/bin/lnd-rpc-health-check.sh >> /var/log/lnd-rpc-health.log 2>&1
```

### 4. Backup e Recovery

#### Script de Backup
```bash
#!/bin/bash
# /usr/local/bin/lnd-rpc-backup.sh

PROJECT_DIR="/root/lnd-rpc-js"
BACKUP_DIR="/var/backups/lnd-rpc-js"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup da configuração
tar -czf "$BACKUP_DIR/lnd-rpc-config-$DATE.tar.gz" \
    -C $PROJECT_DIR \
    config/ \
    payment_req/ \
    payment_sent/ \
    logs/

# Manter apenas últimos 7 backups
find $BACKUP_DIR -name "lnd-rpc-config-*.tar.gz" -mtime +7 -delete

echo "Backup completed: lnd-rpc-config-$DATE.tar.gz"
```

#### Configurar backup automático
```bash
# Backup diário às 2:00
sudo crontab -e
0 2 * * * /usr/local/bin/lnd-rpc-backup.sh >> /var/log/lnd-rpc-backup.log 2>&1
```

### 5. Logs e Rotação

#### Configurar logrotate
Criar `/etc/logrotate.d/lnd-rpc-js`:
```
/root/lnd-rpc-js/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload lnd-rpc-js > /dev/null 2>&1 || true
    endscript
}
```

### 6. Hardening de Segurança

#### Configurações adicionais no service file
```ini
# Adicionar ao lnd-rpc-js.service na seção [Service]
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/root/lnd-rpc-js
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictNamespaces=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
```

#### Configurar fail2ban (opcional)
```bash
# Instalar fail2ban
sudo apt install fail2ban

# Criar configuração personalizada
sudo vim /etc/fail2ban/jail.local
```

Conteúdo do jail.local:
```ini
[lnd-rpc-js]
enabled = true
port = 5002
filter = lnd-rpc-js
logpath = /var/log/syslog
maxretry = 5
bantime = 3600
```

### 7. SSL/TLS (Recomendado)

#### Usando nginx como reverse proxy
```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /path/to/your/cert.pem;
    ssl_certificate_key /path/to/your/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:5002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 8. Checklist de Produção

- [ ] Serviço instalado e ativo
- [ ] Firewall configurado
- [ ] Monitoramento configurado
- [ ] Backup automático ativo
- [ ] Rotação de logs configurada
- [ ] SSL/TLS configurado (se necessário)
- [ ] Health checks funcionando
- [ ] Alertas configurados
- [ ] Documentação atualizada
- [ ] Credenciais seguras configuradas
- [ ] IPs permitidos configurados

### 9. Comandos Úteis de Produção

```bash
# Status completo do serviço
sudo systemctl status lnd-rpc-js --no-pager -l

# Logs em tempo real
sudo journalctl -u lnd-rpc-js -f

# Logs de uma hora específica
sudo journalctl -u lnd-rpc-js --since "2024-01-01 10:00:00" --until "2024-01-01 11:00:00"

# Verificar configuração sem reiniciar
sudo systemd-analyze verify /etc/systemd/system/lnd-rpc-js.service

# Recarregar configuração do systemd
sudo systemctl daemon-reload

# Teste de conectividade
curl -H "x-secret-key: YOUR_SECRET" http://localhost:5002/health

# Verificar uso de recursos
sudo systemctl show lnd-rpc-js --property=MemoryCurrent,CPUUsageNSec
```
