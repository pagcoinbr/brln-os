# 🔌 Documentação de Serviços e Portas - BR⚡LN Bolt

Este documento detalha os serviços instalados pelo BR⚡LN Bolt, suas portas, configurações e como eles se comunicam entre si.

## 📋 Resumo de Portas

| Porta | Serviço | Descrição | Acesso | Configurável |
|-------|---------|-----------|--------|--------------|
| 80 | Apache | Interface Web Principal | LAN | ✅ |
| 3000 | Thunderhub | Gerenciamento de LN | LAN | ✅ |
| 3131 | Gotty - BRLNFullAuto | Terminal interativo web | LAN | ✅ |
| 3232 | Gotty - CLI | Terminal de comandos | LAN | ✅ |
| 3333 | Gotty - LND Editor | Editor de lnd.conf | LAN | ✅ |
| 3434 | Gotty - Bitcoin Logs | Logs Bitcoin Core | LAN | ✅ |
| 3535 | Gotty - LND Logs | Logs LND | LAN | ✅ |
| 3636 | Gotty - BTC Editor | Editor de bitcoin.conf | LAN | ✅ |
| 5000 | LNbits | Sistema bancário LN | LAN | ✅ |
| 5001 | Control-systemd | API para controle de serviços | LAN | ✅ |
| 8889 | LNDG | Dashboard e estatísticas | LAN | ✅ |
| 35671 | Simple LNWallet | Interface simplificada | LAN | ✅ |
| 8080 | PeerSwapWeb | Interface PeerSwap (opcional) | LAN | ✅ |
| 9050/9051 | Tor SOCKS | Proxy Tor (interno) | localhost | ❌ |
| 8333 | Bitcoin | P2P Bitcoin (opcional) | Externo/Tor | ✅ |
| 9735 | Lightning | P2P Lightning (opcional) | Externo/Tor | ✅ |

## 🌐 Comunicação entre Serviços

O diagrama abaixo ilustra como os serviços se comunicam:

```
                                   +-------------+
                                   |   Cliente   |
                                   | (Navegador) |
                                   +------+------+
                                          |
                                          v
+-----------------+            +----------------------+
|  Tor Network    |<--+        |      Apache (80)     |
+-----------------+   |        +----------------------+
                      |                   |
                      |                   v
+----------------+    |         +-------------------+
| Internet / P2P |<---+---------|   Control API     |<-------+
+----------------+    |         |      (5001)       |        |
                      |         +-------------------+        |
                      |                   |                  |
+-----------------+   |                   v                  |
| Tailscale VPN   |<--+         +-------------------+        |
+-----------------+              |     Systemd      |        |
                                 |   Service Mgmt   |        |
                                 +-------------------+        |
                                          |                  |
        +---------------+----------------------------------------+
        |               |                 |                  |    |
        v               v                 v                  v    v
+----------------+ +---------+ +-------------------+ +-------+----+-----+
|    bitcoind    | |   LND   | |  Web Interfaces   | |  Gotty Services  |
|    (8333)      | | (9735)  | | (3000,5000,8889)  | |  (3131-3636)     |
+----------------+ +---------+ +-------------------+ +------------------+
```

## 🔧 Configuração de Serviços

### Bitcoin Core (bitcoind)

**Arquivo de configuração**: `~/.bitcoin/bitcoin.conf`
**Arquivo de serviço**: `services/bitcoind.service`

**Portas principais**:
- `8333`: P2P Bitcoin (opcional para abrir externamente)
- `8332`: RPC Bitcoin (somente localhost)

**Dependências**: Nenhuma
**Depende dele**: LND, LNDG

### LND (Lightning Network Daemon)

**Arquivo de configuração**: `~/.lnd/lnd.conf`
**Arquivo de serviço**: `services/lnd.service`

**Portas principais**:
- `9735`: P2P Lightning (opcional para abrir externamente)
- `8080`: REST API (somente localhost)
- `10009`: gRPC API (somente localhost)

**Dependências**: Bitcoin Core
**Depende dele**: Thunderhub, LNbits, LNDG, Simple LNWallet, BOS

### Thunderhub

**Arquivo de configuração**: `~/.thunderhub/.env`
**Arquivo de serviço**: `services/thunderhub.service`

**Portas principais**:
- `3000`: Interface Web

**Dependências**: LND
**Depende dele**: Nenhum

### LNbits

**Arquivo de configuração**: Banco de dados SQLite ou PostgreSQL
**Arquivo de serviço**: `services/lnbits.service`

**Portas principais**:
- `5000`: Interface Web

**Dependências**: LND
**Depende dele**: Nenhum

### LNDG

**Arquivo de configuração**: Banco de dados PostgreSQL
**Arquivo de serviço**: `services/lndg.service`

**Portas principais**:
- `8889`: Interface Web

**Dependências**: LND, PostgreSQL
**Depende dele**: Nenhum

## 🔒 Firewall e Configurações de Segurança

O sistema configura automaticamente o UFW (Uncomplicated Firewall) com as seguintes regras:

### Configurações Padrão
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

### Acesso SSH (somente rede local)
```bash
sudo ufw allow from 192.168.0.0/16 to any port 22 proto tcp comment 'allow SSH from local network'
```

### Interfaces Web (somente rede local)
```bash
sudo ufw allow from 192.168.0.0/16 to any port 80 proto tcp comment 'allow HTTP from local network'
sudo ufw allow from 192.168.0.0/16 to any port 3000 proto tcp comment 'allow Thunderhub from local network'
# ... outras portas web
```

### Acesso Externo (opcional)
```bash
# Se habilitado pelo usuário
sudo ufw allow 8333/tcp comment 'allow Bitcoin Core p2p'
sudo ufw allow 9735/tcp comment 'allow LND p2p'
```

## 🛡️ Tor Hidden Services

O sistema configura automaticamente Tor Hidden Services para os seguintes serviços:

```
HiddenServiceDir /var/lib/tor/bitcoind/
HiddenServicePort 8333 127.0.0.1:8333

HiddenServiceDir /var/lib/tor/lnd/
HiddenServicePort 9735 127.0.0.1:9735

HiddenServiceDir /var/lib/tor/web/
HiddenServicePort 80 127.0.0.1:80
```

## 📡 Tailscale VPN

O Tailscale é configurado para permitir acesso remoto seguro a todas as interfaces web. O script de configuração:

1. Instala o pacote Tailscale
2. Configura para inicialização automática
3. Gera um link de login único (via QR code ou URL)
4. Registra o dispositivo na sua rede Tailscale

Para acessar os serviços remotamente, use o IP Tailscale atribuído ao seu node.

## 🔄 Alterando Portas Padrão

Para alterar as portas dos serviços:

1. **Interfaces Gotty**: Edite os arquivos em `services/gotty-*.service`
2. **Thunderhub**: Edite o arquivo `.env` em `~/.thunderhub/`
3. **LNbits**: Edite a configuração em `~/.lnbits/`
4. **LNDG**: Edite o arquivo de serviço `services/lndg.service`
5. **Apache**: Edite `/etc/apache2/ports.conf`

Após alterar, reinicie o serviço correspondente:
```bash
sudo systemctl restart <nome-do-servico>
```

E atualize o firewall se necessário:
```bash
sudo ufw allow from 192.168.0.0/16 to any port <nova-porta> proto tcp
```

## 📊 Monitoramento de Serviços

O sistema monitora os serviços através de:

1. **Systemd Watchdog**: Para serviços críticos
2. **Control-systemd API**: Para a interface web
3. **CGI Scripts**: Para verificações detalhadas

O status pode ser visualizado no painel principal ou via linha de comando:
```bash
sudo systemctl status <nome-do-servico>
```

## 🔍 Solucionando Problemas de Porta

Se um serviço não iniciar devido a um conflito de porta:

1. Verifique se a porta está em uso:
   ```bash
   sudo ss -tulpn | grep <numero-da-porta>
   ```

2. Identifique qual aplicativo está usando a porta:
   ```bash
   sudo lsof -i :<numero-da-porta>
   ```

3. Altere a porta no arquivo de configuração correspondente

4. Reinicie o serviço:
   ```bash
   sudo systemctl restart <nome-do-servico>
   ```
