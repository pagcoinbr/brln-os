# 🌊 Liquid Testnet Configuration Guide

Este guia explica como alternar entre **Liquid Mainnet** e **Liquid Testnet** no arquivo `elements.conf`.

## 📋 Instruções de Configuração

### Para Ativar MAINNET
1. **Comente** a linha: `chain=liquidtestnet` (adicione `#`)
2. **Descomente** a linha: `# chain=liquidv1` (remova `#`)

### Para Ativar TESTNET (Configuração Atual)
1. **Comente** a linha: `chain=liquidv1` (adicione `#`)
2. **Descomente** a linha: `# chain=liquidtestnet` (remova `#`)

## ⚠️ Estrutura do Arquivo de Configuração

O arquivo está organizado com:
- **Seção Global**: Configurações comuns (daemon, server, listen, etc.)
- **Seção [liquidv1]**: Configurações específicas da mainnet
- **Seção [liquidtestnet]**: Configurações específicas da testnet

## 🔧 Diferenças Importantes

### Mainnet vs Testnet

| Parâmetro | Mainnet | Testnet |
|-----------|---------|---------|
| Linha de ativação | `chain=liquidv1` | `chain=liquidtestnet` |
| RPC Port | `7041` | `7040` |
| Bitcoin RPC Port | `8332` | `18332` |
| Assets | DePix, USDT | Nenhum configurado |
| Seção no arquivo | `[liquidv1]` | `[liquidtestnet]` |

## 🔧 Procedimento para Mudança

### Passo 1: Parar o Container Elements
```bash
docker-compose down elements
```

### Passo 2: Editar APENAS a Linha Chain

#### Para TESTNET:
```properties
# Comente mainnet:
# chain=liquidv1

# Descomente testnet:
chain=liquidtestnet
```

#### Para MAINNET:
```properties
# Comente testnet:
# chain=liquidtestnet

# Descomente mainnet:
chain=liquidv1
```

### Passo 3: Reiniciar o Container
```bash
docker-compose up -d elements
```

### Passo 4: Verificar Logs
```bash
docker-compose logs -f elements
```

## 📝 Verificação da Configuração

Para verificar em qual rede está conectado:
```bash
# Via RPC
curl -u elementsuser:elementspassword123 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"1.0","id":"test","method":"getblockchaininfo","params":[]}' \
  http://localhost:7041/  # ou 7040 para testnet
```

## ⚡ Dicas Importantes

1. **Backup dos Dados**: Sempre faça backup antes de mudar de rede
2. **Sincronização**: A testnet pode demorar menos para sincronizar
3. **Assets**: Na testnet não há assets específicos configurados por padrão
4. **Bitcoin Core**: Certifique-se que o Bitcoin Core também está na rede correta
5. **Dados Incompatíveis**: Dados da mainnet não são compatíveis com testnet

## 🔍 Solução de Problemas

### Container não inicia após mudança
- Verifique se todas as configurações foram alteradas corretamente
- Confirme que o Bitcoin Core está na rede correspondente
- Verifique os logs: `docker-compose logs elements`

### Erro de conexão RPC
- Confirme a porta correta (7041 para mainnet, 7040 para testnet)
- Verifique se as credenciais RPC estão corretas
- Teste a conectividade: `docker exec elements elements-cli getblockchaininfo`

### Sincronização lenta
- Para testnet, a sincronização é geralmente mais rápida
- Monitore o progresso: `docker exec elements elements-cli getblockchaininfo`

---

**⚠️ Aviso**: Sempre teste em ambiente de desenvolvimento antes de fazer mudanças em produção.
