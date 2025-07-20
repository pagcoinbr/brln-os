# Serviço LND RPC JS

Este documento explica como configurar e gerenciar o servidor LND RPC JS como um serviço systemd no Linux.

## Arquivos do Serviço

- `lnd-rpc-js.service` - Arquivo de configuração do systemd
- `service.sh` - Script para gerenciar o serviço
- `start.sh` - Script de inicialização (agora com suporte a serviço)

## Instalação do Serviço

### Opção 1: Usando o script start.sh
```bash
sudo ./start.sh --service
```

### Opção 2: Usando o script service.sh diretamente
```bash
sudo ./service.sh install
sudo ./service.sh start
```

## Comandos Disponíveis

### Gerenciamento do Serviço
```bash
# Instalar o serviço
sudo ./service.sh install

# Iniciar o serviço
sudo ./service.sh start

# Parar o serviço
sudo ./service.sh stop

# Reiniciar o serviço
sudo ./service.sh restart

# Verificar status
./service.sh status

# Ver logs em tempo real
./service.sh logs

# Desinstalar o serviço
sudo ./service.sh uninstall
```

### Comandos systemctl (alternativos)
```bash
# Verificar status
sudo systemctl status lnd-rpc-js

# Iniciar serviço
sudo systemctl start lnd-rpc-js

# Parar serviço
sudo systemctl stop lnd-rpc-js

# Reiniciar serviço
sudo systemctl restart lnd-rpc-js

# Habilitar inicialização automática
sudo systemctl enable lnd-rpc-js

# Desabilitar inicialização automática
sudo systemctl disable lnd-rpc-js

# Ver logs
sudo journalctl -u lnd-rpc-js -f
```

## Características do Serviço

### Recursos de Confiabilidade
- **Auto-restart**: O serviço reinicia automaticamente em caso de falha
- **Restart delay**: Aguarda 10 segundos antes de tentar reiniciar
- **Graceful shutdown**: Permite até 30 segundos para encerramento gracioso
- **Signal handling**: Usa SIGINT para encerramento limpo

### Recursos de Monitoramento
- **Logs estruturados**: Todos os logs são direcionados ao journald
- **Identificador único**: Logs identificados como 'lnd-rpc-js'
- **Níveis de log**: Suporte a diferentes níveis de logging

### Recursos de Segurança
- **Privilege dropping**: NoNewPrivileges ativado
- **Temporary files**: PrivateTmp ativado para isolamento
- **Resource limits**: Limites de arquivo e processo configurados

## Configuração

O serviço utiliza as mesmas configurações do arquivo `config/config.json` usado pelo script manual.

### Variáveis de Ambiente
- `NODE_ENV=production` - Define ambiente de produção
- `PATH=/usr/bin:/usr/local/bin` - Path para executáveis

### Diretório de Trabalho
O serviço roda no diretório `/root/lnd-rpc-js`

## Verificação de Funcionamento

Após instalar e iniciar o serviço:

1. **Verificar status**:
   ```bash
   ./service.sh status
   ```

2. **Testar conectividade**:
   ```bash
   curl -H "x-secret-key: YOUR_SECRET_KEY" http://localhost:5002/health
   ```

3. **Monitorar logs**:
   ```bash
   ./service.sh logs
   ```

## Troubleshooting

### Serviço não inicia
1. Verificar configuração: `config/config.json` deve existir
2. Verificar dependências: `npm install` deve ter rodado
3. Verificar logs: `./service.sh logs`

### Falha de conectividade
1. Verificar configurações de rede nos nós Lightning/Liquid
2. Verificar firewall
3. Verificar se os serviços Lightning/Liquid estão rodando

### Performance
- O serviço é configurado para reiniciar automaticamente
- Logs são mantidos pelo systemd (usar `journalctl` para gerenciar)
- Limites de recursos podem ser ajustados no arquivo `.service`

## Logs

Os logs do serviço são gerenciados pelo systemd e podem ser acessados via:
- `./service.sh logs` - Logs em tempo real
- `sudo journalctl -u lnd-rpc-js` - Histórico completo
- `sudo journalctl -u lnd-rpc-js --since "1 hour ago"` - Logs da última hora
- `sudo journalctl -u lnd-rpc-js -n 100` - Últimas 100 linhas

## Desinstalação

Para remover completamente o serviço:
```bash
sudo ./service.sh uninstall
```

Isso irá:
1. Parar o serviço
2. Desabilitar a inicialização automática
3. Remover o arquivo de serviço do systemd
4. Recarregar a configuração do systemd
