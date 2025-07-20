# 🔔 Webhook System - Como Usar e Configurar

## 📋 Visão Geral

O sistema de webhooks do LND-RPC-Server permite que você receba notificações em tempo real sobre o status dos pagamentos diretamente no seu sistema, eliminando a necessidade de fazer polling (consultas repetidas) para verificar o status.

### 🎯 Como Funciona

1. **Você fornece uma URL** onde deseja receber as notificações
2. **O servidor envia requisições HTTP POST** para sua URL quando eventos ocorrem
3. **Seu sistema recebe e processa** as notificações automaticamente

## 🚀 Eventos de Webhook Disponíveis

| Evento | Descrição | Quando é Enviado |
|--------|-----------|------------------|
| `payment.pending` | Pagamento foi recebido e está sendo processado | Imediatamente após receber a requisição |
| `payment.completed` | Pagamento foi processado com sucesso | Quando o pagamento é confirmado na rede |
| `payment.failed` | Pagamento falhou por algum motivo | Quando ocorre erro no processamento |
| `webhook.test` | Evento de teste para validar configuração | Quando você usar o endpoint `/webhook/test` |

## 💻 Como Integrar em Sua Aplicação

### 1. Configuração Básica - Enviando Webhook URL

Adicione os campos `webhookUrl` e opcionalmente `webhookSecret` na sua requisição de pagamento:

```json
{
  "transactionId": "seu_id_unico",
  "username": "usuario",
  "amount": 50000,
  "network": "lightning",
  "destinationWallet": "destino@wallet.com",
  "webhookUrl": "https://seusite.com/webhook/pagamentos",
  "webhookSecret": "sua-chave-secreta-webhook"
}
```

### 2. Exemplo de Requisição com Webhook

```bash
curl -X POST http://localhost:5002/payment \
  -H "Content-Type: application/json" \
  -H "x-secret-key: sua-chave-secreta-super-segura-aqui-123456" \
  -d '{
    "transactionId": "order_12345",
    "username": "cliente_loja",
    "amount": 25000,
    "network": "lightning",
    "destinationWallet": "loja@getalby.com",
    "webhookUrl": "https://minhaloja.com/webhook/pagamentos",
    "webhookSecret": "minha-chave-webhook-secreta"
  }'
```

## 📥 Estrutura das Notificações Webhook

### Formato do Payload

Todas as notificações webhook seguem esta estrutura:

```json
{
  "event": "payment.completed",
  "timestamp": "2024-07-20T15:30:45.123Z",
  "data": {
    "id": "uuid-do-pagamento",
    "transactionId": "order_12345",
    "username": "cliente_loja",
    "amount": 25000,
    "network": "lightning",
    "destinationWallet": "loja@getalby.com",
    "status": "sent",
    "transactionHash": "hash_da_transacao",
    "completedAt": "2024-07-20T15:30:45.123Z",
    "networkFee": 150,
    "webhookUrl": "https://minhaloja.com/webhook/pagamentos"
  },
  "server": {
    "name": "LND-RPC-Server",
    "version": "2.0.0"
  }
}
```

### Headers de Segurança

Cada webhook inclui headers para verificação de autenticidade:

```
Content-Type: application/json
User-Agent: LND-RPC-Webhook/1.0
X-Webhook-Signature: sha256=hash_hmac_da_mensagem
X-Webhook-Signature-256: sha256=hash_hmac_da_mensagem
X-Webhook-Timestamp: 1721486445
```

## 🛡️ Verificação de Autenticidade

### Verificação da Assinatura HMAC

Para garantir que o webhook veio realmente do servidor, verifique a assinatura:

#### Exemplo em Node.js

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload, 'utf8')
    .digest('hex');
  
  const receivedSignature = signature.replace('sha256=', '');
  
  return crypto.timingSafeEqual(
    Buffer.from(expectedSignature, 'hex'),
    Buffer.from(receivedSignature, 'hex')
  );
}

// Uso no seu endpoint
app.post('/webhook/pagamentos', (req, res) => {
  const signature = req.headers['x-webhook-signature'];
  const payload = JSON.stringify(req.body);
  const secret = 'minha-chave-webhook-secreta';
  
  if (!verifyWebhookSignature(payload, signature, secret)) {
    return res.status(401).json({ error: 'Assinatura inválida' });
  }
  
  // Processar o webhook
  const { event, data } = req.body;
  console.log(`Webhook recebido: ${event} para transação ${data.transactionId}`);
  
  res.status(200).json({ received: true });
});
```

#### Exemplo em Python

```python
import hmac
import hashlib
import json
from flask import Flask, request

app = Flask(__name__)

def verify_webhook_signature(payload, signature, secret):
    expected_signature = hmac.new(
        secret.encode('utf-8'),
        payload.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()
    
    received_signature = signature.replace('sha256=', '')
    
    return hmac.compare_digest(expected_signature, received_signature)

@app.route('/webhook/pagamentos', methods=['POST'])
def handle_webhook():
    signature = request.headers.get('X-Webhook-Signature')
    payload = request.get_data(as_text=True)
    secret = 'minha-chave-webhook-secreta'
    
    if not verify_webhook_signature(payload, signature, secret):
        return {'error': 'Assinatura inválida'}, 401
    
    webhook_data = request.json
    event = webhook_data['event']
    data = webhook_data['data']
    
    print(f"Webhook recebido: {event} para transação {data['transactionId']}")
    
    return {'received': True}
```

#### Exemplo em PHP

```php
<?php
function verifyWebhookSignature($payload, $signature, $secret) {
    $expectedSignature = hash_hmac('sha256', $payload, $secret);
    $receivedSignature = str_replace('sha256=', '', $signature);
    
    return hash_equals($expectedSignature, $receivedSignature);
}

// webhook.php
$signature = $_SERVER['HTTP_X_WEBHOOK_SIGNATURE'] ?? '';
$payload = file_get_contents('php://input');
$secret = 'minha-chave-webhook-secreta';

if (!verifyWebhookSignature($payload, $signature, $secret)) {
    http_response_code(401);
    echo json_encode(['error' => 'Assinatura inválida']);
    exit;
}

$webhookData = json_decode($payload, true);
$event = $webhookData['event'];
$data = $webhookData['data'];

error_log("Webhook recebido: $event para transação {$data['transactionId']}");

http_response_code(200);
echo json_encode(['received' => true]);
?>
```

## 🔧 Implementação do Receptor de Webhook

### Exemplo Completo em Node.js/Express

```javascript
const express = require('express');
const crypto = require('crypto');

const app = express();
app.use(express.json());

// Configurações
const WEBHOOK_SECRET = 'minha-chave-webhook-secreta';

// Middleware para verificar assinatura
function verifyWebhookSignature(req, res, next) {
  const signature = req.headers['x-webhook-signature'];
  
  if (!signature) {
    return res.status(401).json({ error: 'Assinatura não fornecida' });
  }
  
  const payload = JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(payload, 'utf8')
    .digest('hex');
  
  const receivedSignature = signature.replace('sha256=', '');
  
  if (!crypto.timingSafeEqual(
    Buffer.from(expectedSignature, 'hex'),
    Buffer.from(receivedSignature, 'hex')
  )) {
    return res.status(401).json({ error: 'Assinatura inválida' });
  }
  
  next();
}

// Endpoint do webhook
app.post('/webhook/pagamentos', verifyWebhookSignature, (req, res) => {
  const { event, timestamp, data } = req.body;
  
  console.log(`🔔 Webhook recebido: ${event}`);
  console.log(`📊 Dados:`, data);
  
  // Processar diferentes tipos de eventos
  switch (event) {
    case 'payment.pending':
      console.log(`⏳ Pagamento ${data.transactionId} está sendo processado`);
      // Atualizar status no seu banco de dados
      updatePaymentStatus(data.transactionId, 'processing');
      break;
      
    case 'payment.completed':
      console.log(`✅ Pagamento ${data.transactionId} concluído com sucesso!`);
      console.log(`💰 Valor: ${data.amount} sats`);
      console.log(`🔗 Hash: ${data.transactionHash}`);
      // Liberar produto/serviço
      releaseProduct(data.transactionId);
      updatePaymentStatus(data.transactionId, 'completed', data.transactionHash);
      break;
      
    case 'payment.failed':
      console.log(`❌ Pagamento ${data.transactionId} falhou: ${data.error}`);
      // Cancelar pedido
      cancelOrder(data.transactionId, data.error);
      updatePaymentStatus(data.transactionId, 'failed', null, data.error);
      break;
      
    case 'webhook.test':
      console.log(`🧪 Webhook de teste recebido - configuração OK!`);
      break;
      
    default:
      console.log(`⚠️  Evento desconhecido: ${event}`);
  }
  
  // SEMPRE responder com 200 para confirmar recebimento
  res.status(200).json({ 
    received: true, 
    event: event,
    transactionId: data.transactionId 
  });
});

// Funções auxiliares (implementar conforme sua lógica)
function updatePaymentStatus(transactionId, status, hash = null, error = null) {
  // Atualizar no seu banco de dados
  console.log(`Atualizando status: ${transactionId} -> ${status}`);
}

function releaseProduct(transactionId) {
  // Liberar produto/serviço para o cliente
  console.log(`Liberando produto para transação: ${transactionId}`);
}

function cancelOrder(transactionId, reason) {
  // Cancelar pedido
  console.log(`Cancelando pedido ${transactionId}: ${reason}`);
}

app.listen(3000, () => {
  console.log('🔔 Servidor de webhook rodando na porta 3000');
});
```

## 🧪 Testando Webhooks

### 1. Teste com ngrok (Para Desenvolvimento Local)

```bash
# Instalar ngrok (se não tiver)
npm install -g ngrok

# Executar seu servidor local na porta 3000
node webhook-server.js

# Em outro terminal, expor via ngrok
ngrok http 3000

# Use a URL do ngrok como webhookUrl
# Exemplo: https://abc123.ngrok.io/webhook/pagamentos
```

### 2. Endpoint de Teste do Servidor

```bash
# Testar webhook sem secret
curl -X POST http://localhost:5002/webhook/test \
  -H "Content-Type: application/json" \
  -H "x-secret-key: sua-chave-secreta-super-segura-aqui-123456" \
  -d '{
    "webhookUrl": "https://seusite.com/webhook/pagamentos"
  }'

# Testar webhook com secret
curl -X POST http://localhost:5002/webhook/test \
  -H "Content-Type: application/json" \
  -H "x-secret-key: sua-chave-secreta-super-segura-aqui-123456" \
  -d '{
    "webhookUrl": "https://seusite.com/webhook/pagamentos",
    "webhookSecret": "sua-chave-webhook"
  }'
```

### 3. Teste com Webhook.site

Para testes rápidos, use [webhook.site](https://webhook.site):

1. Acesse https://webhook.site
2. Copie a URL única gerada
3. Use essa URL como `webhookUrl` em seus testes
4. Veja as requisições chegando em tempo real

## ⚙️ Configuração do Servidor

### Configurações Disponíveis no config.json

```json
{
  "webhooks": {
    "enabled": true,
    "timeout": 10000,
    "retryAttempts": 3,
    "retryDelay": 5000,
    "defaultHeaders": {
      "User-Agent": "LND-RPC-Webhook/1.0",
      "Content-Type": "application/json"
    },
    "logFailures": true,
    "saveFailedWebhooks": true
  }
}
```

| Campo | Descrição | Padrão |
|-------|-----------|---------|
| `enabled` | Habilitar/desabilitar webhooks | `true` |
| `timeout` | Timeout em ms para requisições | `10000` |
| `retryAttempts` | Número de tentativas em caso de falha | `3` |
| `retryDelay` | Delay entre tentativas em ms | `5000` |
| `defaultHeaders` | Headers padrão enviados | Ver config |
| `logFailures` | Logar falhas de webhook | `true` |
| `saveFailedWebhooks` | Salvar webhooks falhados para reprocessamento | `true` |

## 🔄 Sistema de Retry e Recuperação

### Tentativas Automáticas

O sistema tenta enviar webhooks até 3 vezes (configurável) com delay de 5 segundos entre tentativas.

### Reprocessamento de Webhooks Falhados

```bash
# Reprocessar todos os webhooks que falharam
curl -X POST http://localhost:5002/webhook/retry-failed \
  -H "x-secret-key: sua-chave-secreta-super-segura-aqui-123456"
```

### Estatísticas de Webhook

```bash
# Ver estatísticas do sistema de webhook
curl -H "x-secret-key: sua-chave-secreta-super-segura-aqui-123456" \
  http://localhost:5002/webhook/stats
```

## 📊 Monitoramento e Logs

### Logs de Webhook

Todos os eventos de webhook são logados em `logs/payment-server.log`:

```bash
# Acompanhar logs de webhook
tail -f logs/payment-server.log | grep -i webhook

# Filtrar apenas falhas
grep "WEBHOOK_FAILURE" logs/payment-server.log
```

### Webhooks Falhados

Webhooks que falharam após todas as tentativas são salvos em `webhook_failures/` para reprocessamento posterior.

## ❌ Tratamento de Erros Comuns

### 1. URL Inválida

```json
{
  "error": "URL de webhook inválida",
  "message": "A URL deve ser um endereço HTTP ou HTTPS válido"
}
```

**Solução**: Verificar se a URL está correta e acessível.

### 2. Timeout de Conexão

**Sintomas**: Webhook não recebido, logs mostram timeout

**Soluções**:
- Verificar se o servidor de destino está respondendo
- Aumentar o timeout no config.json
- Verificar firewall/proxy

### 3. Assinatura Inválida

**Sintomas**: Webhook recebido mas assinatura não confere

**Soluções**:
- Verificar se o `webhookSecret` está correto
- Conferir implementação da verificação HMAC
- Verificar se o payload não foi modificado

## 🔒 Melhores Práticas de Segurança

### 1. **SEMPRE use HTTPS** em produção
```
❌ http://minhaapi.com/webhook
✅ https://minhaapi.com/webhook
```

### 2. **SEMPRE verifique a assinatura**
```javascript
// ❌ Não fazer isso
app.post('/webhook', (req, res) => {
  processPayment(req.body); // Perigoso!
});

// ✅ Fazer isso
app.post('/webhook', verifySignature, (req, res) => {
  processPayment(req.body); // Seguro!
});
```

### 3. **Use secrets únicos** para cada aplicação
```json
// ❌ Não reutilizar
"webhookSecret": "123456"

// ✅ Usar chave forte e única
"webhookSecret": "wh_prod_7f8g9h0j1k2l3m4n5o6p7q8r9s0t1u2v"
```

### 4. **Implemente idempotência**
```javascript
// Verificar se já processou este webhook
const processedWebhooks = new Set();

app.post('/webhook', (req, res) => {
  const webhookId = req.body.data.id;
  
  if (processedWebhooks.has(webhookId)) {
    return res.status(200).json({ received: true, duplicate: true });
  }
  
  processedWebhooks.add(webhookId);
  // Processar webhook...
});
```

## 🚀 Exemplos Práticos de Uso

### E-commerce

```javascript
app.post('/webhook/pagamentos', verifyWebhookSignature, async (req, res) => {
  const { event, data } = req.body;
  
  switch (event) {
    case 'payment.completed':
      // Marcar pedido como pago
      await db.orders.update(data.transactionId, { 
        status: 'paid',
        transactionHash: data.transactionHash 
      });
      
      // Enviar email de confirmação
      await emailService.sendPaymentConfirmation(data.username, data.transactionId);
      
      // Processar entrega
      await shippingService.processOrder(data.transactionId);
      break;
  }
  
  res.status(200).json({ received: true });
});
```

### API/SaaS

```javascript
app.post('/webhook/subscriptions', verifyWebhookSignature, async (req, res) => {
  const { event, data } = req.body;
  
  if (event === 'payment.completed') {
    // Ativar/renovar assinatura
    await subscriptionService.activate(data.username, {
      planId: data.transactionId,
      paidAmount: data.amount,
      validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 dias
    });
    
    // Notificar usuário
    await notificationService.send(data.username, 'Assinatura ativada com sucesso!');
  }
  
  res.status(200).json({ received: true });
});
```

## 📞 Suporte e Debugging

### Verificação de Conectividade

```bash
# Testar se sua URL está acessível
curl -X POST https://seusite.com/webhook/pagamentos \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Logs Detalhados

Para debugging, ative logs em nível debug no `config.json`:

```json
{
  "logging": {
    "level": "debug"
  }
}
```

### Problemas Comuns

1. **Webhook não recebido**: Verificar URL, firewall, SSL
2. **Duplicatas**: Implementar verificação de idempotência
3. **Latência alta**: Otimizar processamento do webhook
4. **Rate limiting**: Implementar rate limiting no seu endpoint

---

## 🎉 Conclusão

Com este sistema de webhooks, você terá notificações em tempo real sobre todos os pagamentos, permitindo uma integração robusta e responsiva com seu sistema. Lembre-se sempre de:

- ✅ Verificar assinaturas HMAC
- ✅ Usar HTTPS em produção  
- ✅ Implementar tratamento de erros
- ✅ Responder com status 200 quando receber o webhook
- ✅ Implementar idempotência para evitar processamento duplicado

**Precisa de ajuda?** Verifique os logs em `logs/payment-server.log` e use o endpoint `/webhook/test` para validar sua implementação!
