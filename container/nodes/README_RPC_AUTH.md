# Configuração de Credenciais RPC do Bitcoin

## Visão Geral

O sistema permite configurar credenciais RPC personalizadas para o Bitcoin Core de duas formas:

1. **Autenticação por Cookie** (padrão): Mais simples, usa o arquivo `.cookie` gerado automaticamente
2. **Autenticação por Usuário/Senha**: Mais segura para ambientes de produção

## Configuração

### Método 1: Autenticação por Cookie (Padrão)

Se você não definir `BITCOIN_RPC_USER` e `BITCOIN_RPC_PASSWORD` no arquivo `.env`, o sistema usará automaticamente a autenticação por cookie.

```bash
# No arquivo .env, deixe as linhas comentadas ou vazias:
# BITCOIN_RPC_USER=
# BITCOIN_RPC_PASSWORD=
```

### Método 2: Autenticação por Usuário/Senha

Para usar credenciais personalizadas, edite o arquivo `.env`:

```bash
# Credenciais RPC do Bitcoin (será gerado automaticamente o rpcauth)
BITCOIN_RPC_USER=seu_usuario_aqui
BITCOIN_RPC_PASSWORD=sua_senha_super_segura_aqui
```

**IMPORTANTE**: 
- Use uma senha forte (recomendado: 32+ caracteres, mistura de letras, números e símbolos)
- Nunca use senhas padrão em produção
- Mantenha o arquivo `.env` seguro e não o commit em repositórios públicos

## Como Funciona

1. **Durante a inicialização do container**:
   - O script `bitcoin.sh` verifica se `BITCOIN_RPC_USER` e `BITCOIN_RPC_PASSWORD` estão definidos
   - Se estiverem, usa o script `rpcauth.py` para gerar o hash da senha
   - Substitui o placeholder `<PLACEHOLDER_RPCAUTH>` no `bitcoin.conf` com a linha `rpcauth` gerada
   - Se não estiverem definidos, remove qualquer linha `rpcauth` e usa autenticação por cookie

2. **Segurança**:
   - A senha nunca é armazenada em texto plano no container
   - Apenas o hash da senha é incluído no arquivo de configuração
   - O script `rpcauth.py` é o mesmo usado oficialmente pelo Bitcoin Core

## Testando a Configuração

### Com Autenticação por Cookie:
```bash
# Dentro do container ou usando docker exec
bitcoin-cli -datadir=/home/bitcoin/.bitcoin getblockchaininfo
```

### Com Autenticação por Usuário/Senha:
```bash
# Dentro do container ou usando docker exec
bitcoin-cli -datadir=/home/bitcoin/.bitcoin -rpcuser=seu_usuario -rpcpassword=sua_senha getblockchaininfo

# Ou via curl (de outro container na mesma rede)
curl -u seu_usuario:sua_senha -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblockchaininfo","params":[]}' \
  http://bitcoind:8332/
```

## Exemplos de Uso

### Para desenvolvimento local:
```bash
BITCOIN_RPC_USER=dev
BITCOIN_RPC_PASSWORD=dev123456789
```

### Para produção:
```bash
BITCOIN_RPC_USER=brln_production
BITCOIN_RPC_PASSWORD=$(openssl rand -base64 32)
```

## Troubleshooting

1. **Container não inicia**: Verifique se as variáveis estão bem definidas no `.env`
2. **Erro de autenticação**: Confirme se o usuário/senha estão corretos
3. **Logs do container**: `docker logs bitcoind` para ver mensagens de erro

## Arquivos Relacionados

- `.env`: Configuração das variáveis de ambiente
- `bitcoin/bitcoin.conf`: Template de configuração com placeholder
- `bitcoin/bitcoin.sh`: Script de inicialização que gera o rpcauth
- `bitcoin/rpcauth.py`: Script oficial do Bitcoin Core para gerar hashes
