# Configuração Apache Proxy Reverso para BRLN-OS

## Problema Resolvido

O Simple LNWallet (e outros serviços) usam cookies com `SameSite=Lax` que impedem o funcionamento correto quando carregados em iframes cross-origin.

## Solução Implementada

### 1. **Proxy Reverso Apache**
- Todos os serviços agora são acessíveis através do mesmo domínio
- Cookies SameSite são reescritos automaticamente para `SameSite=None; Secure`
- Elimina problemas de cross-origin em iframes

### 2. **Mapeamento de Serviços**
```
Serviço              Porta Original    Novo Caminho
Simple LNWallet      35671            /simple-lnwallet/
LNDg                 8889             /lndg/
ThunderHub          3000             /thunderhub/
LNBits              5000             /lnbits/
API                 5001             /api/
GoTTY               3131             /gotty/
CLI                 3232             /cli/
Bitcoin Logs        3434             /bitcoin-logs/
LND Logs            3535             /lnd-logs/
BTC Editor          3636             /btc-editor/
LND Editor          3333             /lnd-editor/
```

### 3. **Instalação**

```bash
# Executar o script de configuração
sudo /root/brln-os/conf_files/setup-apache-proxy.sh
```

### 4. **Arquivos Criados**
- `/root/brln-os/conf_files/brln-apache.conf` - Configuração principal Apache
- `/root/brln-os/conf_files/brln-proxy-rules.conf` - Regras de proxy reutilizáveis  
- `/root/brln-os/conf_files/setup-apache-proxy.sh` - Script de instalação

### 5. **Modificações no Código**
- `pages/components/header.html` - Link do Lightning atualizado para `/simple-lnwallet/`
- `pages/components/tools/tools.js` - Função `abrirApp()` usa novos caminhos de proxy

### 6. **Benefícios**
- ✅ **Cookies funcionam em iframes** - SameSite reescrito automaticamente
- ✅ **Mesmo domínio** - Elimina problemas de cross-origin  
- ✅ **WebSocket support** - Para aplicações que precisam
- ✅ **HTTPS ready** - Configuração SSL incluída
- ✅ **Segurança mantida** - Headers de segurança apropriados

### 7. **Teste da Configuração**

Após executar o script, teste:

1. **Interface principal**: `http://SEU_IP/main.html`
2. **Simple LNWallet**: `http://SEU_IP/simple-lnwallet/`
3. **Via iframe**: Clicar em "LIGHTNING" na interface deve funcionar perfeitamente

### 8. **Troubleshooting**

```bash
# Verificar status Apache
sudo systemctl status apache2

# Verificar configuração
sudo apache2ctl configtest

# Ver logs de erro
sudo tail -f /var/log/apache2/brln_error.log

# Testar proxy específico
curl -I http://localhost/simple-lnwallet/
```

### 9. **Configurações de Firewall**

O script já configura automaticamente:
- Porta 80 (HTTP) - permitida da rede local
- Porta 443 (HTTPS) - permitida da rede local
- Portas originais dos serviços mantidas para acesso direto se necessário

### 10. **Produção**

Para produção, recomenda-se:
- Usar HTTPS com certificados válidos
- Configurar domínio real (não localhost)  
- Ajustar configurações de segurança conforme necessário

## Resultado Final

Agora o Simple LNWallet funciona perfeitamente dentro do iframe da interface BRLN-OS, resolvendo completamente o problema de cookies SameSite!