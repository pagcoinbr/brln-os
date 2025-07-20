const express = require('express');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
const config = require('../config/config.json');
const PaymentProcessor = require('./payment-processor');

// Configurar logger
const logger = winston.createLogger({
  level: config.logging.level,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: config.logging.filename }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

const app = express();
app.use(express.json());

// Middleware para validar IP e chave secreta
app.use((req, res, next) => {
  const clientIp = req.ip || req.connection.remoteAddress;
  logger.info(`Requisição recebida de IP: ${clientIp}`);
  
  // Verificar IP permitido
  if (!config.server.allowedIps.includes(clientIp) && clientIp !== '::1' && clientIp !== '127.0.0.1') {
    logger.warn(`IP não autorizado: ${clientIp}`);
    return res.status(403).json({ error: 'IP não autorizado' });
  }
  
  // Verificar chave secreta
  const secretKey = req.headers['x-secret-key'];
  if (secretKey !== config.server.secretKey) {
    logger.warn(`Chave secreta inválida de IP: ${clientIp}`);
    return res.status(401).json({ error: 'Chave secreta inválida' });
  }
  
  next();
});

// Instanciar processador de pagamentos
const paymentProcessor = new PaymentProcessor(logger);

// Endpoint para receber requisições de pagamento
app.post('/payment', async (req, res) => {
  try {
    const { 
      transactionId, 
      username, 
      amount, 
      network, 
      destinationWallet,
      webhookUrl,
      webhookSecret 
    } = req.body;
    
    // Validar dados obrigatórios
    if (!transactionId || !username || !amount || !network || !destinationWallet) {
      return res.status(400).json({ 
        error: 'Dados obrigatórios faltando',
        required: ['transactionId', 'username', 'amount', 'network', 'destinationWallet']
      });
    }
    
    // Validar rede suportada
    if (!['bitcoin', 'lightning', 'liquid'].includes(network.toLowerCase())) {
      return res.status(400).json({ 
        error: 'Rede não suportada',
        supported: ['bitcoin', 'lightning', 'liquid']
      });
    }
    
    // Validar URL do webhook se fornecida
    if (webhookUrl && !paymentProcessor.webhookManager.validateWebhookUrl(webhookUrl)) {
      return res.status(400).json({ 
        error: 'URL de webhook inválida',
        message: 'A URL deve ser um endereço HTTP ou HTTPS válido'
      });
    }
    
    // Criar objeto de requisição
    const paymentRequest = {
      id: uuidv4(),
      transactionId,
      username,
      amount: parseInt(amount),
      network: network.toLowerCase(),
      destinationWallet,
      webhookUrl: webhookUrl || null,
      webhookSecret: webhookSecret || null,
      timestamp: new Date().toISOString(),
      status: 'pending'
    };
    
    logger.info(`Nova requisição de pagamento: ${JSON.stringify(paymentRequest)}`);
    
    // Salvar requisição no diretório payment_req
    const filename = `${paymentRequest.id}_${transactionId}.json`;
    const filepath = path.join(__dirname, '../payment_req', filename);
    
    fs.writeFileSync(filepath, JSON.stringify(paymentRequest, null, 2));
    logger.info(`Requisição salva: ${filepath}`);
    
    // Processar pagamento
    const result = await paymentProcessor.processPayment(paymentRequest);
    
    res.json({
      success: true,
      message: 'Pagamento processado com sucesso',
      paymentId: paymentRequest.id,
      transactionHash: result.transactionHash
    });
    
  } catch (error) {
    logger.error(`Erro ao processar pagamento: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro interno do servidor',
      message: error.message 
    });
  }
});

// Endpoint para consultar saldo
app.get('/balance/:network', async (req, res) => {
  try {
    const { network } = req.params;
    
    if (!['bitcoin', 'lightning', 'liquid', 'all'].includes(network.toLowerCase())) {
      return res.status(400).json({ 
        error: 'Rede não suportada',
        supported: ['bitcoin', 'lightning', 'liquid', 'all']
      });
    }
    
    if (network.toLowerCase() === 'all') {
      // Obter todos os saldos
      const allBalances = await paymentProcessor.getAllBalances();
      res.json({
        success: true,
        balances: allBalances
      });
    } else {
      // Obter saldo específico
      const balance = await paymentProcessor.getBalance(network.toLowerCase());
      res.json({
        success: true,
        network: network.toLowerCase(),
        balance
      });
    }
    
  } catch (error) {
    logger.error(`Erro ao consultar saldo: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao consultar saldo',
      message: error.message 
    });
  }
});

// Endpoint para listar transações pendentes
app.get('/pending', (req, res) => {
  try {
    const pendingDir = path.join(__dirname, '../payment_req');
    const files = fs.readdirSync(pendingDir);
    
    const pendingPayments = files.map(file => {
      const filepath = path.join(pendingDir, file);
      const data = JSON.parse(fs.readFileSync(filepath, 'utf8'));
      return {
        filename: file,
        ...data
      };
    });
    
    res.json({
      success: true,
      count: pendingPayments.length,
      payments: pendingPayments
    });
    
  } catch (error) {
    logger.error(`Erro ao listar pagamentos pendentes: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao listar pagamentos pendentes',
      message: error.message 
    });
  }
});

// Endpoint para listar transações enviadas
app.get('/sent', (req, res) => {
  try {
    const sentDir = path.join(__dirname, '../payment_sent');
    const files = fs.readdirSync(sentDir);
    
    const sentPayments = files.map(file => {
      const filepath = path.join(sentDir, file);
      const data = JSON.parse(fs.readFileSync(filepath, 'utf8'));
      return {
        filename: file,
        ...data
      };
    });
    
    res.json({
      success: true,
      count: sentPayments.length,
      payments: sentPayments
    });
    
  } catch (error) {
    logger.error(`Erro ao listar pagamentos enviados: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao listar pagamentos enviados',
      message: error.message 
    });
  }
});

// Endpoint para consultar todos os saldos
app.get('/balance/all', async (req, res) => {
  try {
    const allBalances = await paymentProcessor.getAllBalances();
    
    res.json({
      success: true,
      balances: allBalances
    });
    
  } catch (error) {
    logger.error(`Erro ao consultar todos os saldos: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao consultar saldos',
      message: error.message 
    });
  }
});

// Endpoint para testar webhook
app.post('/webhook/test', async (req, res) => {
  try {
    const { webhookUrl, webhookSecret } = req.body;
    
    if (!webhookUrl) {
      return res.status(400).json({ 
        error: 'URL de webhook é obrigatória',
        required: ['webhookUrl']
      });
    }
    
    // Validar URL do webhook
    if (!paymentProcessor.webhookManager.validateWebhookUrl(webhookUrl)) {
      return res.status(400).json({ 
        error: 'URL de webhook inválida',
        message: 'A URL deve ser um endereço HTTP ou HTTPS válido'
      });
    }
    
    logger.info(`Testando webhook: ${webhookUrl}`);
    
    const success = await paymentProcessor.webhookManager.sendTestWebhook(webhookUrl, webhookSecret);
    
    res.json({
      success: success,
      message: success ? 'Webhook de teste enviado com sucesso' : 'Falha ao enviar webhook de teste',
      webhookUrl: webhookUrl,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    logger.error(`Erro ao testar webhook: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao testar webhook',
      message: error.message 
    });
  }
});

// Endpoint para obter estatísticas de webhook
app.get('/webhook/stats', (req, res) => {
  try {
    const stats = paymentProcessor.webhookManager.getWebhookStats();
    
    res.json({
      success: true,
      stats: stats
    });
    
  } catch (error) {
    logger.error(`Erro ao obter estatísticas de webhook: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao obter estatísticas de webhook',
      message: error.message 
    });
  }
});

// Endpoint para reprocessar webhooks falhados
app.post('/webhook/retry-failed', async (req, res) => {
  try {
    logger.info('Iniciando reprocessamento de webhooks falhados');
    
    await paymentProcessor.webhookManager.reprocessFailedWebhooks();
    
    res.json({
      success: true,
      message: 'Reprocessamento de webhooks falhados concluído',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    logger.error(`Erro ao reprocessar webhooks: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao reprocessar webhooks',
      message: error.message 
    });
  }
});

// Endpoint original para consultar todos os saldos (manter compatibilidade)
app.get('/balance/all', async (req, res) => {
  try {
    const allBalances = await paymentProcessor.getAllBalances();
    
    res.json({
      success: true,
      balances: allBalances
    });
    
  } catch (error) {
    logger.error(`Erro ao consultar todos os saldos: ${error.message}`, error);
    res.status(500).json({ 
      error: 'Erro ao consultar saldos',
      message: error.message 
    });
  }
});

// Iniciar servidor
app.listen(config.server.port, () => {
  logger.info(`Servidor iniciado na porta ${config.server.port}`);
  console.log(`🚀 Servidor rodando na porta ${config.server.port}`);
  console.log(`📝 Logs sendo salvos em: ${config.logging.filename}`);
  console.log(`🔑 IPs permitidos: ${config.server.allowedIps.join(', ')}`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('Servidor sendo encerrado...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('Servidor sendo encerrado...');
  process.exit(0);
});
