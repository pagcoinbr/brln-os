# Cliente Python gRPC para LND e Elements

Este projeto implementa um cliente Python que utiliza gRPC para se conectar aos contêineres Lightning Network Daemon (LND) e Elements do projeto BRLN-OS, exibindo saldos Lightning Network, Bitcoin on-chain e Liquid.

## 📋 Requisitos

- Python 3.7+
- pip3
- Docker (com contêineres LND e Elements rodando)
- Acesso aos certificados e macaroons do LND

## 🚀 Instalação e Setup

### 1. Executar o Script de Setup

O script de setup automatiza todo o processo de instalação:

```bash
./setup_lnd_client.sh
```

Este script irá:
- Criar um ambiente virtual Python
- Instalar as dependências necessárias (`grpcio-tools`, `requests`)
- Baixar os arquivos `.proto` do LND
- Compilar os arquivos proto em módulos Python
- Criar arquivos de configuração

### 2. Ativar o Ambiente Virtual

```bash
source ./activate_env.sh
```

### 3. Configurar o Arquivo de Configuração

Edite o arquivo `lnd_client_config.ini` com suas configurações específicas:

```ini
[LND]
host = localhost
port = 10009
tls_cert_path = /data/lnd/tls.cert
macaroon_path = /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon

[ELEMENTS]
host = localhost
port = 18884
rpc_user = elementsuser
rpc_password = elementspassword123
```

## 🔧 Uso

```bash
# Exibir saldos gerais
python lnd_balance_client_v2.py

# Exibir detalhes dos canais Lightning
python lnd_balance_client_v2.py --channels

# Usar arquivo de configuração personalizado
python lnd_balance_client_v2.py --config minha_config.ini
```

## 📊 Exemplo de Saída

```
================================================================================
🏦 BRLN-OS - Saldos das Carteiras
📅 2025-07-15 14:30:22
================================================================================

⚡ Nó Lightning: BRLN-Node-01
   Pubkey: 03f1a5b2c8d9e3f4a6b7c8d9...
   Versão: 0.18.5-beta
   Peers: 12
   Canais Ativos: 5
   Canais Pendentes: 0
   Sincronizado Chain: ✅
   Sincronizado Graph: ✅
   Altura do Bloco: 825,123

⚡ LIGHTNING NETWORK
----------------------------------------
   Saldo Local:     0.05000000 BTC (5,000,000 sats)
   Saldo Remoto:    0.03000000 BTC (3,000,000 sats)
   Total no Canal:  0.08000000 BTC (8,000,000 sats)

₿ BITCOIN ON-CHAIN
----------------------------------------
   Confirmado:      0.10000000 BTC (10,000,000 sats)
   Não Confirmado:  0.00000000 BTC (0 sats)
   Total:           0.10000000 BTC (10,000,000 sats)

🌊 LIQUID (ELEMENTS)
----------------------------------------
   Confirmado:      0.02000000 L-BTC, 1000.00000000 USDT
   Transações:      45
   Chain: liquidv1
   Blocos: 3,245,678
   Progresso Sync: 100.00%

================================================================================
📊 Status das Conexões:
   LND: ✅ Conectado
   Elements: ✅ Conectado
================================================================================
```

## 🔐 Configuração de Segurança

### Certificados e Macaroons

O cliente precisa de acesso aos seguintes arquivos:

1. **Certificado TLS**: `/data/lnd/tls.cert`
   - Necessário para estabelecer conexão segura com o LND

2. **Macaroon de Admin**: `/data/lnd/data/chain/bitcoin/mainnet/admin.macaroon`
   - Necessário para autenticação e autorização

### Permissões de Arquivos

Certifique-se de que o usuário que executa o cliente tem permissão de leitura nos arquivos:

```bash
# Verificar permissões
ls -la /data/lnd/tls.cert
ls -la /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon

# Ajustar permissões se necessário (como root)
chmod 644 /data/lnd/tls.cert
chmod 600 /data/lnd/data/chain/bitcoin/mainnet/admin.macaroon
```

## 🐳 Configuração Docker

### Conectando de Fora do Docker

Se você está executando o cliente fora dos contêineres Docker, certifique-se de que as portas estão expostas:

```yaml
# No docker-compose.yml
lnd:
  ports:
    - "10009:10009"  # gRPC
    - "8080:8080"    # REST

elements:
  ports:
    - "18884:18884"  # RPC
```

### Conectando de Dentro do Docker

Se executar o cliente dentro de um contêiner na mesma rede:

```ini
[LND]
host = lnd
port = 10009

[ELEMENTS]
host = elements
port = 18884
```

## 🛠️ Funcionalidades

### Cliente LND (gRPC)
- ✅ Conexão segura via TLS
- ✅ Autenticação com macaroons
- ✅ Saldo da carteira on-chain
- ✅ Saldo dos canais Lightning
- ✅ Informações do nó
- ✅ Lista detalhada de canais
- ✅ Status de sincronização

### Cliente Elements (RPC)
- ✅ Conexão HTTP com autenticação
- ✅ Saldos por asset (L-BTC, USDT, etc.)
- ✅ Informações da blockchain
- ✅ Status da carteira
- ✅ Progresso de sincronização

## 🔧 Personalização

### Configurações de Exibição

```ini
[DISPLAY]
show_pubkey_full = false      # Exibir pubkey completa
show_millisats = false        # Exibir millisatoshis
currency_format = BTC         # Formato da moeda
decimal_places = 8            # Casas decimais
```

### Configurações de Log

```ini
[LOGGING]
level = INFO                  # DEBUG, INFO, WARNING, ERROR
format = %(asctime)s - %(levelname)s - %(message)s
file = lnd_client.log        # Arquivo de log
```

## 🚨 Troubleshooting

### Erro: "Certificado TLS não encontrado"

```bash
# Verificar se o contêiner LND está rodando
docker ps | grep lnd

# Verificar se o certificado existe
ls -la /data/lnd/tls.cert

# Regenerar certificado se necessário
docker restart lnd
```

### Erro: "Macaroon não encontrado"

```bash
# Verificar macaroon
ls -la /data/lnd/data/chain/bitcoin/mainnet/

# Se não existir, pode precisar criar a carteira
docker exec -it lnd lncli create
```

### Erro: "Conexão recusada"

```bash
# Verificar portas
netstat -tulpn | grep :10009
netstat -tulpn | grep :18884

# Verificar logs dos contêineres
docker logs lnd
docker logs elements
```

### Erro: "RPC unauthorized"

Verifique as credenciais do Elements no arquivo de configuração:

```ini
[ELEMENTS]
rpc_user = elementsuser
rpc_password = elementspassword123
```

## 📁 Estrutura de Arquivos

```
brln-os/
├── lnd_balance_client.py       # Cliente básico
├── lnd_balance_client_v2.py    # Cliente avançado (recomendado)
├── lnd_client_config.ini       # Arquivo de configuração
├── setup_lnd_client.sh         # Script de setup
├── activate_env.sh             # Script para ativar ambiente
├── requirements.txt            # Dependências Python
├── lightning.proto             # Arquivo proto do LND
├── lightning_pb2.py            # Módulo proto compilado
├── lightning_pb2_grpc.py       # Stub gRPC
├── router_pb2.py              # Módulo router subserver
├── invoices_pb2.py            # Módulo invoices subserver
├── lnd_client.log             # Arquivo de log
└── lnd_client_env/            # Ambiente virtual Python
```

## 🔄 Integração com control-systemd.py

Para integrar com o sistema de controle existente, você pode adicionar uma nova rota:

```python
@app.route('/wallet-balances')
def wallet_balances():
    try:
        # Executar o cliente e capturar saída
        result = subprocess.run(
            ['python', 'lnd_balance_client_v2.py', '--json'],
            capture_output=True,
            text=True,
            cwd='/path/to/brln-os'
        )
        
        if result.returncode == 0:
            return jsonify({"success": True, "data": result.stdout})
        else:
            return jsonify({"success": False, "error": result.stderr}), 500
            
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500
```

## 📚 Referências

- [LND gRPC Documentation](https://lightning.engineering/api-docs/api/lnd/lightning/get-info)
- [Elements RPC Documentation](https://elementsproject.org/en/doc/rpc/)
- [gRPC Python Tutorial](https://grpc.io/docs/languages/python/basics/)
- [Protocol Buffers](https://developers.google.com/protocol-buffers)

## 🤝 Contribuição

Para contribuir com melhorias:

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto segue a mesma licença do projeto BRLN-OS.
