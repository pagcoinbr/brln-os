const express = require('express');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const winston = require('winston');
const { exec } = require('child_process');
const { promisify } = require('util');
const cors = require('cors');
const config = require('../config/config.json');
const PaymentProcessor = require('./payment-processor');

const execAsync = promisify(exec);

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

// Middleware
app.use(cors()); // Permitir CORS para interface web
app.use(express.json());

// Middleware para logging de todas as requisições
app.use((req, res, next) => {
  const clientIp = req.ip || req.connection.remoteAddress || req.headers['x-forwarded-for'];
  logger.info(`${req.method} ${req.path} - IP: ${clientIp}`);
  next();
});

// Middleware para validar chave secreta (apenas para endpoints sensíveis)
const authenticateSecretKey = (req, res, next) => {
  const secretKey = req.headers['x-secret-key'];
  if (secretKey !== config.server.secretKey) {
    logger.warn(`Chave secreta inválida de IP: ${req.ip}`);
    return res.status(401).json({ error: 'Chave secreta inválida' });
  }
  next();
};

// Instanciar processador de pagamentos
const paymentProcessor = new PaymentProcessor(logger);

// ========================================
// ENDPOINTS DE PAGAMENTOS E BALANÇOS
// ========================================

// Endpoint para receber requisições de pagamento (protegido)
app.post('/payment', authenticateSecretKey, async (req, res) => {
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
    
    // Criar diretório se não existir
    const dir = path.dirname(filepath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    
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
      const allBalances = await paymentProcessor.getAllBalances();
      res.json({
        success: true,
        balances: allBalances,
        timestamp: new Date().toISOString()
      });
    } else {
      const balance = await paymentProcessor.getBalance(network.toLowerCase());
      res.json({
        success: true,
        network: network.toLowerCase(),
        balance,
        timestamp: new Date().toISOString()
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

// ========================================
// ENDPOINTS DE GERENCIAMENTO DOCKER
// ========================================

// Verificar status de serviço Docker
app.get('/service-status', async (req, res) => {
  try {
    const appName = req.query.app;
    if (!appName) {
      return res.status(400).json({ error: 'App não informado' });
    }

    // Mapear nome do app para nome do container
    const containerName = config.docker.services[appName] || appName;
    
    // Verificar se container está rodando
    const { stdout } = await execAsync(`docker ps --filter "name=${containerName}" --format "{{.Names}}"`);
    const isActive = stdout.trim().includes(containerName);
    
    res.json({ active: isActive });
    
  } catch (error) {
    logger.error(`Erro ao verificar status do serviço ${req.query.app}:`, error);
    res.json({ active: false });
  }
});

// Controlar serviços Docker (start/stop/restart)
app.post('/toggle-service', async (req, res) => {
  try {
    const appName = req.query.app;
    if (!appName) {
      return res.status(400).json({ error: 'App não informado' });
    }

    const containerName = config.docker.services[appName] || appName;
    
    // Verificar status atual
    try {
      const { stdout } = await execAsync(`docker ps --filter "name=${containerName}" --format "{{.Names}}"`);
      const isRunning = stdout.trim().includes(containerName);
      
      if (isRunning) {
        // Parar container
        await execAsync(`docker stop ${containerName}`);
        logger.info(`Container ${containerName} parado`);
        res.json({ success: true, action: 'stopped', service: containerName });
      } else {
        // Iniciar container
        await execAsync(`docker start ${containerName}`);
        logger.info(`Container ${containerName} iniciado`);
        res.json({ success: true, action: 'started', service: containerName });
      }
    } catch (dockerError) {
      // Se container não existe, tentar usar docker-compose
      try {
        const { stdout: composeStatus } = await execAsync(`cd /root/brln-os/container && docker-compose ps ${containerName}`);
        
        if (composeStatus.includes('Up')) {
          await execAsync(`cd /root/brln-os/container && docker-compose stop ${containerName}`);
          res.json({ success: true, action: 'stopped', service: containerName });
        } else {
          await execAsync(`cd /root/brln-os/container && docker-compose start ${containerName}`);
          res.json({ success: true, action: 'started', service: containerName });
        }
      } catch (composeError) {
        throw new Error(`Falha ao controlar serviço: ${dockerError.message}`);
      }
    }
    
  } catch (error) {
    logger.error(`Erro ao controlar serviço ${req.query.app}:`, error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// ========================================
// ENDPOINT PARA SALDOS DAS CARTEIRAS (compatibilidade com interface atual)
// ========================================

app.get('/wallet-balances', async (req, res) => {
  try {
    // Obter todos os saldos
    const allBalances = await paymentProcessor.getAllBalances();
    
    // Formatar para compatibilidade com interface atual
    const lightning = allBalances.lightning || {};
    const bitcoin = allBalances.bitcoin || {};
    const liquid = allBalances.liquid || {};
    
    // Simular saída do cliente Python para compatibilidade
    const rawOutput = formatBalancesAsLegacyOutput(lightning, bitcoin, liquid);
    
    res.json({
      success: true,
      raw_output: rawOutput,
      timestamp: new Date().toLocaleString('pt-BR'),
      connections: {
        lnd: !!(lightning.local_balance || bitcoin.total_balance),
        elements: !!liquid.balance
      },
      balances: {
        lightning,
        bitcoin, 
        liquid
      }
    });
    
  } catch (error) {
    logger.error(`Erro ao obter saldos das carteiras: ${error.message}`, error);
    res.status(500).json({
      success: false,
      error: error.message,
      raw_output: '',
      timestamp: new Date().toLocaleString('pt-BR'),
      connections: {
        lnd: false,
        elements: false
      }
    });
  }
});

// Função para formatar saldos no formato legado (compatibilidade)
function formatBalancesAsLegacyOutput(lightning, bitcoin, liquid) {
  let output = '';
  
  // Lightning
  if (lightning && lightning.local_balance) {
    const localSat = lightning.local_balance.sat || 0;
    const localBtc = (localSat / 100000000).toFixed(8);
    output += `\\n⚡ LIGHTNING NETWORK (LND)\\n`;
    output += `Saldo Local: ${localBtc} BTC (${localSat.toLocaleString()} sats)\\n`;
  }
  
  // Bitcoin on-chain
  if (bitcoin && bitcoin.total_balance) {
    const totalBalance = bitcoin.total_balance;
    const confirmedBalance = bitcoin.confirmed_balance || totalBalance;
    output += `\\n₿ BITCOIN ON-CHAIN (VIA LND)\\n`;
    output += `Total: ${(totalBalance / 100000000).toFixed(8)} BTC (${totalBalance.toLocaleString()} sats)\\n`;
    output += `Confirmado: ${(confirmedBalance / 100000000).toFixed(8)} BTC (${confirmedBalance.toLocaleString()} sats)\\n`;
  }
  
  // Liquid
  if (liquid && liquid.balance) {
    const balance = liquid.balance;
    output += `\\n🌊 LIQUID (ELEMENTS)\\n`;
    output += `Confirmado: ${(balance / 100000000).toFixed(8)} L-BTC (${balance.toLocaleString()} sats)\\n`;
  }
  
  output += `\\nStatus das Conexões:\\n`;
  output += `LND: ${lightning ? '✅ Conectado' : '❌ Desconectado'}\\n`;
  output += `Elements: ${liquid ? '✅ Conectado' : '❌ Desconectado'}\\n`;
  
  return output;
}

// ========================================
// ENDPOINTS DE PAGAMENTOS (compatibilidade)
// ========================================

// Listar transações pendentes
app.get('/pending', (req, res) => {
  try {
    const pendingDir = path.join(__dirname, '../payment_req');
    
    // Criar diretório se não existir
    if (!fs.existsSync(pendingDir)) {
      fs.mkdirSync(pendingDir, { recursive: true });
    }
    
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

// Listar transações enviadas
app.get('/sent', (req, res) => {
  try {
    const sentDir = path.join(__dirname, '../payment_sent');
    
    // Criar diretório se não existir
    if (!fs.existsSync(sentDir)) {
      fs.mkdirSync(sentDir, { recursive: true });
    }
    
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

// ========================================
// ENDPOINTS DE WEBHOOK (protegidos)
// ========================================

app.post('/webhook/test', authenticateSecretKey, async (req, res) => {
  try {
    const { webhookUrl, webhookSecret } = req.body;
    
    if (!webhookUrl) {
      return res.status(400).json({ 
        error: 'URL de webhook é obrigatória',
        required: ['webhookUrl']
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

app.get('/webhook/stats', authenticateSecretKey, (req, res) => {
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

app.post('/webhook/retry-failed', authenticateSecretKey, async (req, res) => {
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

// ========================================
// ENDPOINT DE SAÚDE E STATUS
// ========================================

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'BRLN-RPC-Server',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// ========================================
// INICIALIZAÇÃO DO SERVIDOR
// ========================================

// Criar diretórios necessários
const requiredDirs = [
  path.join(__dirname, '../payment_req'),
  path.join(__dirname, '../payment_sent'),
  path.join(__dirname, '../logs')
];

requiredDirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    logger.info(`Diretório criado: ${dir}`);
  }
});

// Iniciar servidor
app.listen(config.server.port, () => {
  logger.info(`BRLN-RPC-Server iniciado na porta ${config.server.port}`);
  console.log(`🚀 BRLN-RPC-Server rodando na porta ${config.server.port}`);
  console.log(`📝 Logs sendo salvos em: ${config.logging.filename}`);
  console.log(`🔑 IPs permitidos: ${config.server.allowedIps.join(', ')}`);
  console.log(`🐳 Docker services: ${Object.keys(config.docker.services).length} configurados`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('BRLN-RPC-Server sendo encerrado...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('BRLN-RPC-Server sendo encerrado...');
  process.exit(0);
});

module.exports = app;
