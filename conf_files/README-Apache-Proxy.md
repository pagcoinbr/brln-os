# Configuracao Apache Proxy Reverso para BRLN-OS

## Problema Resolvido

Servicos web internos precisam compartilhar o mesmo host para evitar problemas de cookies SameSite e iframes.

## Solucao Implementada

### 1. Proxy Reverso Apache
- Todos os servicos ficam acessiveis sob o mesmo dominio
- Cookies SameSite funcionam em iframes
- WebSocket suportado para a API e terminal

### 2. Mapeamento de Servicos
```
Servico              Porta Original    Novo Caminho
LNDg                 8889             /lndg/
API                 2121             /api/
API WebSocket       2121             /ws/
GoTTY (Terminal)     3131             /terminal/
GoTTY (Alias)        3131             /gotty-fullauto/
```

### 3. Instalacao

```bash
# Executar o script de configuracao
sudo /root/brln-os/conf_files/setup-apache-proxy.sh
```

### 4. Arquivos Criados
- `/root/brln-os/conf_files/brln-apache.conf` - Configuracao principal Apache (HTTP)
- `/root/brln-os/conf_files/brln-ssl-api.conf` - Configuracao SSL (HTTPS)
- `/root/brln-os/conf_files/setup-apache-proxy.sh` - Script de instalacao

### 5. Modificacoes no Codigo
- `pages/components/tools/tools.js` - Funcao `abrirApp()` usa caminhos de proxy

### 6. Beneficios
- Cookies funcionam em iframes
- Mesmo dominio evita problemas de cross-origin
- WebSocket suportado
- HTTPS pronto

### 7. Teste da Configuracao

Apos executar o script, teste:

1. Interface principal: `http://SEU_IP/main.html`
2. LNDg: `http://SEU_IP/lndg/`
3. Terminal: `http://SEU_IP/terminal/`

### 8. Troubleshooting

```bash
# Verificar status Apache
sudo systemctl status apache2

# Verificar configuracao
sudo apache2ctl configtest

# Ver logs de erro
sudo tail -f /var/log/apache2/brln_error.log

# Testar proxy especifico
curl -I http://localhost/lndg/
```

### 9. Configuracoes de Firewall

O script configura automaticamente:
- Porta 80 (HTTP) - permitida da rede local
- Porta 443 (HTTPS) - permitida da rede local

### 10. Producao

Para producao, recomenda-se:
- Usar HTTPS com certificados validos
- Configurar dominio real
- Ajustar headers de seguranca conforme necessario

## Resultado Final

Servicos internos acessiveis sob o mesmo host, com cookies e WebSockets funcionando corretamente.
